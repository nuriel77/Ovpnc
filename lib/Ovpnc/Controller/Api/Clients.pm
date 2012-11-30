package Ovpnc::Controller::Api::Clients;
use warnings;
use strict;
use Ovpnc::Plugins::Connector;
use Moose;
use namespace::autoclean;
use vars qw( $REGEX );

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config( namespace => 'api' );

=head1 NAME

Ovpnc::Controller::Api::Clients - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller for Clients.

=head1 METHODS

=cut

with 'MooseX::Traits';
has '+_trait_namespace' => (

    # get the correct namespace.
    # To keep traits out of
    # the Controller directory.
    default => sub {
        my ( $P, $SP ) = __PACKAGE__ =~ /^(\w+)::(.*)$/;
        return $P . '::TraitFor::' . $SP;
    }
);

has openvpn_dir => (
    is        => 'rw',
    isa       => 'Str',
    required  => 0,
    predicate => '_has_vpn_dir'
);

has openvpn_utils => (
    is        => 'rw',
    isa       => 'Str',
    required  => 0,
    predicate => '_has_utils_dir'
);

has 'cfg' => (
    is        => 'rw',
    isa       => 'HashRef',
    predicate => '_has_conf'
);

$REGEX = {
    client => {
        list =>
          'CLIENT_LIST,(.*?),(.*?),(.*?),([0-9]+),([0-9]+),(.*?),([0-9]+)$',
        crl => 'R\s*\w+\s*(\w+).*\/C.*\/CN=(.*)\/name=.*',
    }
};

=head2 Method Modifiers

Run before other actions
or after, or around...

=cut

# For methods requiring
# management port connection
# ==========================
has vpn => (
    is        => 'rw',
    isa       => 'Object',
    predicate => '_has_vpn',
    clearer   => '_disconnect_vpn',
    required  => 0
);

around [
    qw(
      clients_UNREVOKE
      clients_DISABLE
      clients_ENABLE
      clients_GET
      list_revoked
      )
  ] => sub {
    my ( $orig, $self, $c, $params ) = @_;

    $self->cfg( Ovpnc::Controller::Api->assign_params($c) )
      unless $self->_has_conf;

    return $self->$orig( $c, $params );

};

around [
    qw(
      clients_REVOKE
      clients_REMOVE
      kill_connection
      )
  ] => sub {
    my ( $orig, $self, $c, $params ) = @_;

    # Do not process twice
    # ====================
    if ( ref $c && !$self->_has_vpn_dir ) {
        $self->cfg( Ovpnc::Controller::Api->assign_params($c) );
    }

    # Get global configurations
    # if not assigned yet
    # =========================
    $self->cfg( Ovpnc::Controller::Api->assign_params($c) )
      unless $self->_has_conf;

    # Also here, don't process twice
    # ==============================
    return $self->$orig( $c, $params )
      if $self->_has_vpn;

    # Instantiate connector
    # =====================
    $self->vpn( Ovpnc::Plugins::Connector->new( $self->cfg->{mgmt_params} ) );

    # Check connection to mgmt port
    # =============================
    unless ( $self->vpn->connect ) {
        $c->stash( { status => 'Server offline' } );
        $self->_disconnect_vpn if $self->_has_vpn;
        $c->detach;
    }

    return $self->$orig( $c, $params );
  };

=head2 after modifier

Makes sure to disconnect
and release the mgmt port

=cut

after [
    qw/
      clients_REVOKE
      clients_REMOVE
      kill_connection
      /
] => sub { shift->_disconnect_vpn; };

=head2 clients

For REST action class

=cut

sub clients : Local : ActionClass('REST') {
}

=head2 get_clients

Gets all clients / users
of Ovpnc/OpenVPN

=cut

sub clients_GET : Local : Args(0) : Sitemap

#: Does('ACL') AllowedRole('admin') AllowedRole('can_edit') ACLDetachTo('denied')
#: Does('NeedsLogin')
{
    my ( $self, $c, $client ) = @_;

    # Assign from post params if exists
    # This will override params in the path
    $client = $c->req->params->{client} if $c->req->params->{client};

    # client configuration dir
    # ========================
    my $_ccd_dir = $self->cfg->{openvpn_ccd}  =~ /^\//
        ? $self->cfg->{openvpn_ccd}
        : $self->cfg->{app_root} . '/' . $self->cfg->{openvpn_ccd};

    # return only role 'client'
    # we get the id of role type 'client'
    my $_role_name =
      $c->model('DB::Role')->search( { name => 'client' } )->single;

    # Assign the flexgrid request params
    my ( $page, $search_by, $search_text, $rows, $sort_by, $sort_order ) =
      @{ $c->req->params }{qw/page qtype query rp sortname sortorder/};

    my $_columns = [
        qw/
          id
          username
          enabled
          email
          fullname
          revoked
          phone
          address
          created
          modified/
    ];

    # Check if these are columns which exists
    # in the resultset, otherwise they are
    # from openvpn mgmt port status.
    # for now set default to user, and
    # sort after having mapped the two data sources
    my $_dont_sort_in_query;
    if ($sort_by) {
        unless ( $sort_by ~~ @{$_columns} ) {

            # Just set some default
            $sort_by             = 'username';
            $_dont_sort_in_query = 1;
        }
    }

    # There is a mismatch between the hardcoded
    # username of simplelogin and of openvpn
    # that's why need to make sure they match
    # before mapping the two data sources
    $sort_by =~ s/\bname\b/username/ if $sort_by;

    # Query resultset
    my @_clients = $c->model('DB::User')->search(
        { 'user_roles.role_id' => $_role_name->id },
        {
            order_by => ( $sort_by && $sort_order )
            ? "$sort_by $sort_order"
            : "username ASC",
            join   => 'user_roles',
            select => $_columns
        },
    )->all;

    # Let's see who is online
    my $_online_clients = $c->forward('/api/server/status');

    # Now let's start matching the list of
    # all users to those who are online
    # we shall append the online data
    # for this response
    @_clients = map { $_->{_column_data} } @_clients;

    # Simple login uses hardcoded 'username'
    # and openvpn returns 'name'
    # here we first map so they two
    # arrays match, we can run a simple comparison
    # to find out to which client's data
    # to append the online data.
    $_online_clients->{clients} = [
        map {

            # match to second hash's keyname
            $_->{username} = $_->{name};
            delete $_->{name};
          LP: for my $i ( 0 .. @_clients ) {
                if ( $_clients[$i]->{username} eq $_->{username} ) {

                    # Merge the two hashes
                    my %temp_hash = ( %{ $_clients[$i] }, %{$_} );
                    $_clients[$i] = \%temp_hash;
                    last LP;
                }
            }
          } @{ $_online_clients->{clients} }
    ];

    # here we sort the hashes inside the array
    # according to what is specified in the
    # request. The sort is being done here
    # if these are columns which do not originate
    # in the database but from server status
    if ( $_dont_sort_in_query && $sort_by ) {
        my @_sorted = sort { $$a{$sort_by} cmp $$b{$sort_by} } @_clients;
        @_clients = lc($sort_order) eq 'asc' ? @_sorted : reverse @_sorted;
    }

    $self->status_ok( $c, entity => [@_clients] )
      if @_clients > 0;
}

=head2 clients_POST

Add new client(s)

=cut

sub clients_POST : Local : Args(0) : Sitemap

  #: Does('NeedsLogin')
{
    my ( $self, $c ) = @_;
}

=head2 clients_UPDATE

Update client(s) data

=cut

sub clients_UPDATE : Local : Args(0) : Sitemap

  #:Does('NeedsLogin')
{
    my ( $self, $c ) = @_;
}

=head2 clients_REMOVE

Delete client(s)

=cut

sub clients_REMOVE : Local : Args(0) : Sitemap

  #: Does('NeedsLogin')
{
    my ( $self, $c ) = @_;
}

=head2 clients_DISABLE

Disable a client's ccd file
(having --exclusive-ccd in server run
options means client cannot connect
anymore, this is based on CN)
Will ppends .disabled to client's
file in ccd. Expects client's CN name and
optionally provide ?no_kill=1
to avoid killing any active
connections of this client.
(by default it will disconnect a disabled
client.)

=cut

sub clients_DISABLE : Local : Args(1) : Sitemap

  #: Does('NeedsLogin')
{
    my ( $self, $c, $client ) = @_;

    # Verify that a client name was provided
    # ======================================
    $self->_client_error($c)
      unless defined( $client // $c->req->params->{client} );

    # Assign from post params if exists
    # This will override params in the path
    # =====================================
    $client = $c->req->params->{client} if $c->req->params->{client};

    # Client configuration dir
    # ========================
    my $_ccd_dir = $self->cfg->{openvpn_ccd} =~ /^\//
        ? $self->cfg->{openvpn_ccd}
        : $self->cfg->{openvpn_dir} . '/'
            . $self->cfg->{openvpn_ccd};

    if ( -e $_ccd_dir . '/' . $client ) {

        # Rename the file so it becomes .disabled
        # =======================================
        rename( $_ccd_dir . '/' . $client,
            $_ccd_dir . '/' . $client . '.disabled' )
          or die "Cannot rename $client: $!";
        $self->status_ok( $c,
            entity => { status => "Configuration file for $client disabled ok" }
        );
    }
    else {
        if ( -e $_ccd_dir . '/' . $client . '.disabled' ) {
            $self->status_forbidden( $c,
                message => "Client is already disabled." );
        }
        else {
            $self->status_not_found( $c,
                message => "Cannot find '" . $_ccd_dir . '/' . $client . "'." );
        }
    }

    # kill any active connections of this client
    # This will even occur if the file above
    # was not found (in a strange case...)
    unless ( $c->request->params->{no_kill} ) {
        $c->stash->{kill_status} = $self->kill_connection( $c, $client );
    }
    $self->_disconnect_vpn;

}

=head2 clients_ENABLE

Re-enable a disabled client

=cut

sub clients_ENABLE : Local
                   : Args(1)
                   : Sitemap
                   #: Does('NeedsLogin')
{
    my ( $self, $c, $client ) = @_;

    # Verify that a client name was provided
    # either a single via clients/[client_name]
    # or via params '?client=client_name&...'
    # ========================================
    $self->_client_error($c)
      unless $client
          or $c->req->params->{client};

    # TODO: Make all actions array capable!
    $client = $c->req->params->{client} if $c->req->params->{client};

    my $_ccd_dir = $c->config->{openvpn_dir} . '/conf/ccd';
    if ( -e $_ccd_dir . '/' . $client ) {
        $self->status_forbidden( $c, message => "Client is already enabled." );
        $c->detach;
    }

    if ( -e $_ccd_dir . '/' . $client . '.disabled' ) {
        rename( $_ccd_dir . '/' . $client . '.disabled',
            $_ccd_dir . '/' . $client )
          or $self->status_not_found(
            $c,
            message =>
              "Is this the correct name? I cannot rename $client and got: $!"
          );
        $self->status_ok( $c,
            entity => { status => "Client $client enabled ok" } );
    }
    else {
        $self->status_not_found( $c,
                message => "Enable failed, cannot find client's file '"
              . $_ccd_dir . '/'
              . $client
              . ".disabled'." );
    }
}

=head2

Revoke's client certificate
using crl.pem

=cut

sub clients_REVOKE : Local : Args(1) : Sitemap

  #: Does('NeedsLogin')
{
    my ( $self, $c, $client ) = @_;

    # Verify that a client name was provided
    # ======================================
    $self->_client_error($c)
      unless defined( $client // $c->request->params->{client} );

    # Override anything in the path by setting
    # params from post if they exists
    # ========================================
    $client = $c->request->params->{client} if $c->request->params->{client};

    # Trait names should match request method
    # =======================================
    my $role = $self->_get_roles( $c->request->method );

    my $_ret_val;

    # Revoke client's certificate
    # ===========================
    unless ( $c->request->params->{no_revoke} ) {
        $_ret_val = $role->revoke_certificate($client);
    }

    # If error from above don't proceed
    # =================================
    if ( !$_ret_val || ( ref $_ret_val && $_ret_val->{error} ) ) {
        $self->_disconnect_vpn if $self->_has_vpn;
        Ovpnc::Controller::Api->detach_error( $c, $_ret_val->{error} );
    }

    # Kill the connection (just incase
    # client is currently connected).
    # ================================
    if ( my $str = $self->kill_connection($client) ) {
        $_ret_val .= ';' . $str;
    }
    else {
        $_ret_val .= ';Client ' . $client . ' not found online';
    }

    $self->status_ok( $c, entity => $_ret_val );
    $self->_disconnect_vpn if $self->_has_vpn;
}

=head2

Unrevoke a client's certificate
and remove the appended
.disabled from the file
in ccd

=cut

sub clients_UNREVOKE : Local : Args(1) : Sitemap

#: Does('ACL') AllowedRole('admin') AllowedRole('can_edit') ACLDetachTo('denied')
#: Does('NeedsLogin')
{
    my ( $self, $c, $client ) = @_;

    # Verify that a client name was provided
    # ======================================
    $self->_client_error($c)
      unless defined ( $client // $c->request->params->{client} );

    # Override anything in the path by setting
    # params from post if they exists
    # ========================================
    $client = $c->request->params->{client} if $c->request->params->{client};

    # Check if client's certificate is revoked
    # ========================================
    my $revoked = $c->forward('list_revoked');

    unless ( $self->_match_revoked( $revoked, $client ) ) {
        delete $c->stash->{status};
        $self->status_not_found( $c,
            message => "Unrevoke faild: client is not the revoked list" );
        $self->_disconnect_vpn if $self->_has_vpn;
        $c->detach;
    }

    # Trait names should match request method
    # =======================================
    my $role = $self->_get_roles( $c->request->method );

    # Unrevoke a revoked client's certificate
    # =======================================
    my $_ret_val = $role->unrevoke_certificate(
        $client,
        $c->config->{openssl_conf},
        $c->config->{openssl_bin}
    );
    $self->status_ok( $c, entity => $_ret_val );
    $self->_disconnect_vpn if $self->_has_vpn;
    delete $c->stash->{status};
}

=head2

Get revoked client list

=cut

sub list_revoked : Path('clients/list_revoked')
                 : Args(0)
                 : Sitemap
                 #: Does('NeedsLogin')
{
    my ( $self, $c ) = @_;

    my $openvpn_dir = $self->cfg->{openvpn_dir} =~ /\//
        ? $self->cfg->{openvpn_dir}
        :  $self->cfg->{app_root} . '/' . $self->cfg->{openvpn_dir};

    # The crl index file from OpenVPN
    # ===============================
    my $crl_index = $self->cfg->{openvpn_utils} =~ /\//
        ? $self->cfg->{openvpn_utils} . '/keys/index.txt'
        : $openvpn_dir . '/'
            . $self->cfg->{openvpn_utils}
            . '/keys/index.txt';

    unless ( -r $crl_index ) {
        $self->status_forbidden( $c,
                message => 'Cannot read '
              . $crl_index
              . ', file does not exists or is not readable' );
        $self->_disconnect_vpn if $self->_has_vpn;
        $c->detach;
    }

    my $revoked_clients = $self->read_crl_index_file($crl_index);

    if (    $revoked_clients
        and ref $revoked_clients eq 'ARRAY'
        and @{$revoked_clients} > 0 )
    {
        $self->status_ok( $c, entity => $revoked_clients );
        $c->stash->{status} = $revoked_clients;
    }
    else {
        $self->status_not_found( $c, message => 'No revoked clients' );
    }
}

# Private methods
# ===============

=head2 Kill_connection

Kill a connection of a
given client/ip:port

=cut

sub kill_connection : Private {
    my ( $self, $connection, $client ) = @_;
    $connection = $client if ref $connection;
    die "No connection?!" unless $self->_has_vpn;
    my $ret_val = $self->vpn->kill($connection);
    return $ret_val;
}

=head2 read_crl_index_file

This file generated by
OpenVPN lists the certificates
and provides us information
who is revoked

=cut

sub read_crl_index_file : Private {
    my ( $self, $crl_index ) = @_;
    my ( $Y, $M, $D, $h, $m, $s );
    my $obj = [];

    open( FH, "<", $crl_index )
      or die "Cannot read $crl_index: $!";

    while ( my $line = <FH> ) {
        my ( $revoke_time, $name ) = $line =~ /$REGEX->{client}->{crl}/g;
        if ( $revoke_time and $name ) {
            ( $Y, $M, $D, $h, $m, $s ) = $revoke_time =~ /(..)/g;
            my $kill_time =
                $D . '-'
              . $M . '-'
              . ( $Y + 2000 ) . ' '
              . $h . ':'
              . $m . ':'
              . $s;
            push( @{$obj}, { name => $name, kill_time => $kill_time } );
        }
    }

    close FH;
    return $obj;
}

=head2 _match_revoked

Will compare the current
client to the list of revoked
to see if he is there

=cut

sub _match_revoked : Private {
    my ( $self, $revoked, $client ) = @_;

    if ( $revoked and ref $revoked eq 'ARRAY' ) {
        for ( @{$revoked} ) {
            return 1 if ( $_->{name} eq $client );
        }
    }
    return 0;
}

=head2 _get_roles

Based on the method name we wish
to load the corresponding trait(s)
Notice we ucfirst format the name
and also sent extra params

=cut

sub _get_roles : Private {
    my $self = shift;

    return $self->new_with_traits(
        traits    => [ ucfirst( lc(shift) ), @_ ],
        openvpn_dir   => $self->cfg->{openvpn_dir},
        openvpn_utils => $self->cfg->{openvpn_utils},
        app_root => $self->cfg->{app_root}
    );
}

=head2 _client_error

Detach not before stashing
the error message
and disconnect the mgmt port

=cut

sub _client_error : Private {
    my ( $self, $c ) = @_;
    $self->status_no_content($c);
    $self->_disconnect_vpn if $self->_has_vpn;
    $c->detach;
}


=head2 denied

Unauthorized access
no match for role

=cut

sub denied : Private {
    my ( $self, $c ) = @_;
    $self->status_forbidden( $c, message => "Access denied" );
    $c->detach;
}

=head2 default

Default action, not found

=cut

sub default : Private {
    my ( $self, $c ) = @_;
    $c->stash( { status => 'Control action not found' } );
    $c->response->status(404);
}

=head2 end

Last auto-action
of this controller
Disconnect the mgmt port
and forward to the view

=cut

sub end : Private {
    my ( $self, $c ) = @_;

    # Debug if requested
    die "forced debug" if $c->req->params->{dump_info};

    # Clean up the File::Assets
    # it is set to null but
    # is not needed in JSON output
    delete $c->stash->{assets};

    # disconnect if exists
    $self->_disconnect_vpn if $self->_has_vpn;

    # Forward to JSON view
    $c->forward(
        ( $c->request->params->{xml} ? 'View::XML::Simple' : 'View::JSON' ) );
}

=head1 AUTHOR

Nuriel Shem-Tov

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
