package Ovpnc::Controller::Api::Clients;
use warnings;
use strict;
use Try::Tiny;
use Scalar::Util 'looks_like_number';
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

has '_roles' => (
    is        => 'rw',
    isa       => 'Object',
    predicate => '_has_roles',
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


=head2 Method Modifiers

Run before other actions
or after, or around...

=cut

    around [
        qw(
          clients_UNREVOKE
          clients_DISABLE
          clients_ENABLE
          clients_GET
          clients_POST
          list_revoked
          )
      ] => sub {
        my ( $orig, $self, $c, $params ) = @_;
    
        # Assign global config params
        # ===========================
        $self->cfg( $c->controller('Api')->assign_params( $c ) )
          unless $self->_has_conf;

        # File::Assets might leave an empty hash
        # so we better delete it, no need in api
        # ======================================
        delete $c->stash->{assets} if $c->stash->{assets};
    
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
    
        # File::Assets might leave an empty hash
        # so we better delete it, no need in api
        # ======================================
        delete $c->stash->{assets} if ref $c && $c->stash->{assets};
    
        # Do not process twice
        # ====================
        if ( ref $c && !$self->_has_vpn_dir ) {
            $self->cfg( $c->controller('Api')->assign_params( $c ) );
        }
    
        # Get global configurations
        # if not assigned yet
        # =========================
        $self->cfg( $c->controller('Api')->assign_params( $c ) )
          unless $self->_has_conf;
    
        # Also here, don't process twice
        # ==============================
        return $self->$orig( $c, $params )
          if $self->_has_vpn;
    
        # Instantiate connector
        # =====================
        $self->vpn( Ovpnc::Plugin::Connector->new( $self->cfg->{mgmt_params} ) );
    
        # Check connection to mgmt port
        # =============================
        unless ( $self->vpn->connect ) {
            $c->stash( { status => 'Server offline' } );
            $self->_disconnect_vpn if $self->_has_vpn;
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
    ] => sub {
        my $self = shift;
        $self->_disconnect_vpn if $self->_has_vpn;
    };


=head2 begin

Automatic first
action to run

=cut

    sub begin : Private {
        my ( $self, $c ) = @_;

        # Test database connection
        # ========================
        $c->controller('Root')->auto( $c );

        # Log user in if login params are provided
        # =======================================
        $c->controller('Api')->auth_user( $self, $c )
            unless $c->user_exists();

        # Set the expiration time
        # if user is logged in okay
        # =========================
        if ( $c->user_exists() && !$c->req->params->{_} ){
            $c->log->info('Setting session expire to '
                . $c->config->{'api_session_expires'});
            $c->change_session_expires(
                $c->config->{'api_session_expires'} )
        }

    }


=head2 clients

For REST action class

=cut

    sub clients : Local : ActionClass('REST') {
    }


=head2 get_clients

Gets all clients / users
of Ovpnc/OpenVPN

=cut

    sub clients_GET : Local
                    : Args(0)
                    : Does('ACL')
                      AllowedRole('admin')
                      AllowedRole('client')
                      ACLDetachTo('denied')
                    : Sitemap
    {
        my ( $self, $c ) = @_;
    
        # Assign the request param
        # Only when param 'page' does not
        # exists, because that would be
        # a call originating from flexgrid
        # When param (fieldname) is provided
        # the action will return a result
        # of a client which was found to match
        # ====================================
        my ( $param, $keyname );
        if ( ref $c->req->params && !$c->req->params->{page} ) {
            delete $c->req->params->{_} if $c->req->params->{_};
            # We expect only one
            # parameter to be sent
            # ====================
            $keyname = ( keys %{$c->req->params} )[0];
            $param->{$keyname} = $c->req->params->{$keyname}
                if $keyname;
        }
    
        # client configuration dir
        # ========================
        my $_ccd_dir = $self->cfg->{openvpn_ccd}  =~ /^\//
            ? $self->cfg->{openvpn_ccd}
            : $self->cfg->{home} . '/' . $self->cfg->{openvpn_ccd};
    
        # Assign the flexgrid request params
        # ==================================
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
    
        # If req param 'page' we don't
        # run this check, this means
        # the call originated from 
        # the flexgrid table
        # ============================
        if ( $keyname && !$c->req->params->{page}
            && ! ( $keyname ~~ @{$_columns} )
        ){
            $self->status_not_found(
                $c,
                message => "Unknown field name: '" . $keyname . "'",
            );
            $c->detach;
        }
    
        # Check if these are columns which exists
        # in the resultset, otherwise they are
        # from openvpn mgmt port status.
        # for now set default to user, and
        # sort after having mapped the two data sources
        # =============================================
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
        # =========================================
        $sort_by =~ s/\bname\b/username/ if $sort_by;
    
        # return only role 'client'
        # we get the id of role type 'client'
        # ===================================
        my @_role_names;
        try {
            @_role_names = $c->model('DB::Role')->search({ name => ['admin', 'client'] });
        }
        catch {
            push @{$c->stash->{error}}, $_;
        };
    
        # Query resultset
        # ===============
    
        my @_clients;
        try {
                @_clients = $c->model('DB::User')->search_rs(
                # If $param is provided, return
                # only the result of $param
                # Otherwise, only clients which
                # have role_id of 'client', this
                # is then for use by flexgrid
                # ==============================
                ( $keyname && $param->{$keyname}
                    ? { $keyname => $param->{$keyname} }
                    : { 'user_roles.role_id' => [ map { $_->id } @_role_names ] }
                ),
                {
                    order_by => ( $sort_by && $sort_order )
                    ? "$sort_by $sort_order"
                    : "username ASC",
                    join   => 'user_roles',
                    select => $_columns
                },
            )->all;
        }
        catch {
            push @{$c->stash->{error}}, $_;
        };
    
        # - Now let's start matching the list of
        # all users to those who are online
        # we shall append the online data
        # for this response
        # - Simplify the resultset array.
        # =====================================
        @_clients = map { $_->{_column_data} } @_clients;
    
        if ( $keyname && $param->{$keyname} ) {
            my $_client_data = $_clients[0]->{$keyname};
            $self->status_ok( $c, entity => { $keyname => $_client_data } );
            $c->detach;
        }
    
        # Check if server is online
        # this is to know if to check
        # for online clients or skip
        # ===========================
        my $_pid = $c->forward('/api/server' , $self->cfg );
    
        # Let's see who is online
        # =======================
        my $_online_clients;
        if ( $_pid != 0 ){
            $_online_clients = $c->forward('/api/server/status', $self->cfg );
        }
        
        my @_list;
    
        if ( ref $_online_clients && $_online_clients->{clients} ){
    
            # Simple login uses hardcoded 'username'
            # and openvpn returns 'name'
            # here we first map so they two
            # arrays match, we can run a simple comparison
            # to find out to which client's data
            # to append the online data.
            # ============================================
            $_online_clients->{clients} = [
                map {
        
                    # match to second hash's keyname
                    # ==============================
                    $_->{username} = $_->{name};
                    delete $_->{name};
                    my $_found;
                  LP: for my $i ( 0 .. @_clients ) {
                        if ( $_clients[$i]->{username}
                          && $_clients[$i]->{username} eq $_->{username}
                        ) {
                            # Merge the two hashes
                            # ====================
                            my %temp_hash = ( %{ $_clients[$i] }, %{$_} );
                            $_clients[$i] = \%temp_hash;
                            $_found++;
                        }
                    }
                    push @_list, $_
                        unless $_found;
                  } @{ $_online_clients->{clients} }
            ];
        }
    
        # Here we sort the hashes inside the array
        # according to what is specified in the
        # request. The sort is being done here
        # if these are columns which do not originate
        # in the database but from server status
        # ===========================================
        if ( $_dont_sort_in_query && $sort_by ) {
            my @_sorted = sort {
                    ( $$a{$sort_by} ? $$a{$sort_by} : 0 )
                cmp
                    ( $$b{$sort_by} ? $$b{$sort_by} : 0 )
            } @_clients;
            @_clients = lc($sort_order) eq 'asc' ? @_sorted : reverse @_sorted;
        }
      
        # Remove any empty elements
        # Merge any unknown clients
        # =========================
        for ( @_clients ){
            push @_list, $_ if scalar keys %{$_} != 0;
        }
        
        $self->status_ok( $c, entity => [ @_list ] )
          if @_list > 0;
    }
        

=head2 clients_POST

Add new client(s)

=cut

    sub clients_POST : Local
                     : Args(0)
                     : Does('ACL')
                       AllowedRole('admin')
                       AllowedRole('can_edit')
                       ACLDetachTo('denied')
                     : Does('NeedsLogin')
                     : Sitemap
    {
        my ( $self, $c ) = @_;
    }


=head2 clients_UPDATE

Update client(s) data

=cut

    sub clients_UPDATE : Local
                       : Args(0)
                       : Does('ACL')
                         AllowedRole('admin')
                         AllowedRole('can_edit')
                         ACLDetachTo('denied')
                       : Does('NeedsLogin')
                       : Sitemap
    {
        my ( $self, $c ) = @_;
    }


=head2 clients_REMOVE

Delete client(s)

=cut

    sub clients_REMOVE : Local
                       : Args(0)
                       : Does('ACL')
                         AllowedRole('admin')
                         AllowedRole('can_edit')
                         ACLDetachTo('denied')
                       : Does('NeedsLogin')
                       : Sitemap
    {
        my ( $self, $c, $client_list ) = @_;
    
        my $_ccd_dir = $self->cfg->{openvpn_ccd} =~ /^\//
            ? $self->cfg->{openvpn_ccd}
            : $self->cfg->{openvpn_dir} . '/'
                . $self->cfg->{openvpn_ccd};
    
        # Verify that a client name was provided
        # ======================================
        $self->_client_error($c)
          unless defined( $client_list // $c->request->params->{client} );
    
        # Override anything in the path by setting
        # params from post if they exists
        # ========================================
        $client_list = $c->request->params->{client} if $c->request->params->{client};
    
        my @clients = split ',', $client_list;
    
        my ( @_delete_ok , @_not_ok );
        for my $client (@clients){
            # Find client in database
            # =======================
            my $_res;
            try {
                 $_res = $c->model('DB::User')->find({ username => $client });
            }
            catch {
                push @{$c->stash->{error}}, $_;
            };
    
            if ( $_res ){
                
                # Deny removal of default
                # administrator user
                # =======================
                if ( $_res->id == 1 ){
                    push @{$c->stash->{error}}, "Denied: Cannot delete default administrator!";
                    $c->res->status(400);
                    $c->detach;
                    return;
                }
    
                # Delete entry
                # ============
                if ( $_res->delete ) {
                    push (@_delete_ok, $client);
                }
                else {
                    push (@_not_ok, $client);
                }
                # Remove any ccd file
                # ===================
                if ( -e $_ccd_dir . '/' . $client ){
                    unlink $_ccd_dir . '/' . $client
                        or push (@_not_ok, $client);
                }
            }
        }
    
        $self->status_ok($c,
            entity => { deleted => [ @_delete_ok ], failed => [ @_not_ok ] }
        );
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

    sub clients_DISABLE : Local
                        : Args(1)
                        : Does('ACL')
                          AllowedRole('admin')
                          AllowedRole('can_edit')
                          ACLDetachTo('denied')
                        : Does('NeedsLogin')
                        : Sitemap
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
        # ==========================================
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
                       : Does('ACL')
                         AllowedRole('admin')
                         AllowedRole('can_edit')
                         ACLDetachTo('denied')
                       : Does('NeedsLogin')
                       : Sitemap
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

    sub clients_REVOKE : Local
                       : Args(0)
                       : Does('ACL')
                         AllowedRole('admin')
                         AllowedRole('can_edit')
                         ACLDetachTo('denied')
                       : Does('NeedsLogin')
                       : Sitemap
    {
        my ( $self, $c, $client_list ) = @_;
    
        # Verify that a client name was provided
        # ======================================
        $self->_client_error($c)
          unless defined( $client_list // $c->request->params->{client} );
    
        # Override anything in the path by setting
        # params from post if they exists
        # ========================================
        $client_list = $c->request->params->{client}
            if $c->request->params->{client};
    
        my @clients = split ',', $client_list;
    
        # Trait names should match request method
        # =======================================
        $self->_roles(
            $self->_get_roles(
                $c->request->method,
                '+Ovpnc::TraitFor::Controller::Api::Certificates::Vars'
            )
        );
    
        # Same as source ./vars
        # =====================
        $self->_roles->set_environment_vars;
    
        # HashRef Will contain after return:
        # {warnings}, {errors}, {status}
        # ==================================
        my $_ret_val;
    
        # Revoke client's certificate
        # ===========================
        unless ( $c->request->params->{no_revoke} ) {
            $_ret_val = $self->_roles->revoke_certificate( \@clients );
        }
    
        unless ( $_ret_val ){
            $self->_disconnect_vpn if $self->_has_vpn;
            $c->controller('Api')->detach_error( $c,
                { errors => [ 'No reply from backend!' ] } );
            return;
        }
       
        # Proceed with disconnecting
        # the client if online and
        # update the status in DB
        # ==========================
        my $_disconnect_client_ok;
        $_disconnect_client_ok = 1 if $self->_has_vpn;
        for my $client ( @clients ){
            # See if vpn is currently on,
            # if yes, try to diconnect the
            # client (might not be online)
            # ============================
            if ( $_disconnect_client_ok ){
                if ( my $str = $self->kill_connection( $client ) ) {
                    push @{$_ret_val->{$client}->{status}},
                        'Disconnect from VPN status: ' . $str;
                }
                else {
                    push @{$_ret_val->{$client}->{warnings}},
                        'Disconnect from VPN status: not found online';
                }
            }
            # Update database
            # ===============
            try {
                $c->model('DB::User')->find({ username => $client })
                    ->update({ revoked => 1 });
            }
            catch {
                push @{$c->stash->{$client}->{errors}},
                    "Failed to update database for '$client': " . $_;
            };
        }
            
        # Done processing client(s)
        # =========================
        $self->status_ok( $c, entity => { resultset => $_ret_val } );
        $self->_disconnect_vpn if $self->_has_vpn;
    }
    

=head2

Unrevoke a client's certificate
and remove the appended
.disabled from the file
in ccd

=cut

    sub clients_UNREVOKE : Local
                         : Args(0)
                         : Does('ACL')
                           AllowedRole('admin')
                           AllowedRole('can_edit')
                           ACLDetachTo('denied')
                         : Does('NeedsLogin')
                         : Sitemap
    {
        my ( $self, $c, $client_list ) = @_;
    
        # Verify that a client name was provided
        # ======================================
        $self->_client_error($c)
          unless defined ( $client_list // $c->request->params->{client} );
    
        # Override anything in the path by setting
        # params from post if they exists
        # ========================================
        $client_list = $c->request->params->{client} if $c->request->params->{client};
    
        my @clients = split ',', $client_list;
    
        # Trait names should match request method
        # =======================================
        $self->_roles (
            $self->_get_roles(
                $c->request->method,
                '+Ovpnc::TraitFor::Controller::Api::Certificates::Vars'
            )
        );
    
        # Same as source ./vars
        # =====================
        $self->_roles->set_environment_vars;
    
        # Check if client's certificate is revoked
        # ========================================
        my $revoked = $c->forward('list_revoked');
    
        my $_ret_val;
    
      CLIENT:
        for my $client ( @clients ){
            # Prepare a return object
            # for client status/errors
            # ========================
            $_ret_val->{$client} = {
                errors => [],
                warnings => [],
                status => []
            };

            # Check if in CRL
            # ===============
            unless ( $self->_match_revoked( $revoked, $client ) ) {
                push @{$_ret_val->{$client}->{errors}},
                    "Unrevoke failed: not in the Revoked list";
                next CLIENT;
            }
    
            # Update database
            # ===============
            try {
                $c->model('DB::User')->find({ username => $client })
                    ->update({ revoked => 0 });
            }
            catch {
                push @{$_ret_val->{$client}->{errors}},
                    "DB query failed: " . $_;
            };
    
            # Unrevoke a revoked client's certificate
            # =======================================
            my $_revoke_status = 
                $self->_roles->unrevoke_certificate(
                    $client,
                    $self->cfg->{ssl_config},
                    $c->config->{openssl_bin}
                );
            for ( keys %{$_revoke_status} ){
                push @{ $_ret_val->{$client}->{$_} },
                    $_revoke_status->{$_};                
            }
        }
    
        # Done processing client(s)
        # =========================
        $self->status_ok( $c, entity => { resultset => $_ret_val } );
        $self->_disconnect_vpn if $self->_has_vpn;
        delete $c->stash->{status} if $c->stash->{status};
    }


=head2 list_recent
    
List recently created books
    
=cut
    
    sub list_recent : Path('clients/list_recent')
                    : Args(1)
                    : Does('ACL')
                      AllowedRole('admin')
                      AllowedRole('can_edit')
                      ACLDetachTo('denied')
                    : Does('NeedsLogin')
                    : Sitemap
    {
        my ($self, $c, $mins) = @_;
        
        $mins ||= $c->req->params->{time};
    
        # Verify the minutes provided
        # ===========================
        $self->_client_error($c,'204')                      unless defined $mins;
        $self->_client_error($c,'400', 'Not a number')      unless looks_like_number($mins);
        $self->_client_error($c,'400', 'Invalid range')     if $mins > 5259487;

        my $res;
        try {
            $res = $c->model('DB::User')
                       ->created_after( DateTime->now->subtract(minutes => $mins) );
        }
        catch {
            push @{$c->stash->{error}}, $_;
        };
    
        my $_data = [];
        for ( $res->all ){
            push @{$_data},
                {
                    created  => '' . $_->created,
                    username => '' . $_->username,
                    id       => '' . $_->id,
                };
        }
        
        $self->status_ok($c, entity => $_data );
    }
    
    
=head2

Get revoked client list

=cut

    sub list_revoked : Path('clients/list_revoked')
                     : Args(0)
                     : Does('ACL')
                       AllowedRole('admin')
                       AllowedRole('can_edit')
                       ACLDetachTo('denied')
                     : Does('NeedsLogin')
                     : Sitemap
    {
        my ( $self, $c ) = @_;
    
        my $openvpn_dir = $self->cfg->{openvpn_dir} =~ /^\//
            ? $self->cfg->{openvpn_dir}
            :  $self->cfg->{home} . '/' . $self->cfg->{openvpn_dir};
    
        # The crl index file from OpenVPN
        # ===============================
        my $crl_index = $self->cfg->{openvpn_utils} =~ /^\//
            ? $self->cfg->{openvpn_utils} . '/keys/index.txt'
            : $openvpn_dir . '/'
                . $self->cfg->{openvpn_utils}
                . '/keys/index.txt';
    
        # Check readable
        # ==============
        unless ( -r $crl_index ) {
            $self->status_forbidden( $c,
                    message => 'Cannot read '
                  . $crl_index
                  . ', file does not exists or is not readable' );
            $self->_disconnect_vpn if $self->_has_vpn;
            $c->detach;
        }
    
        my $revoked_clients = $self->_read_crl_index_file($crl_index);
    
        if (    $revoked_clients
            and ref $revoked_clients eq 'ARRAY'
            and @{$revoked_clients} > 0 )
        {
            # Keep data also in stash->{status}
            # It is being used by other controllers
            # =====================================
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


=head2 _read_crl_index_file

This file generated by
OpenVPN lists the certificates
and provides us information
who is revoked

=cut

    sub _read_crl_index_file : Private {
        my ( $self, $crl_index ) = @_;
        my ( $Y, $M, $D, $h, $m, $s );
        my $obj = [];

        open( FH, "<", $crl_index )
          or die "Cannot read $crl_index: $!";

        while ( my $line = <FH> ) {
            # 'R\s*\w+\s*(\w+).*\/C.*\/CN=(.*)\/name=.*'
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
            openvpn_dir     => $self->cfg->{openvpn_dir},
            openvpn_utils   => $self->cfg->{openvpn_utils},
            home            => $self->cfg->{home},
            openssl_conf    => $self->cfg->{openssl_conf},
            _req            => {},
            _cfg            => $self->cfg,
        );
    
    }

    
=head2 _client_error

Detach not before stashing
the error message
and disconnect the mgmt port

=cut

    sub _client_error : Private {
        my ( $self, $c, $status, $msg ) = @_;
        $status ||= 204;
        if ( $status == 204 ){
            $self->status_no_content( $c );
        }
        elsif ( $status == 400 ){
            $self->status_bad_request(
                $c,
                message => 'Invalid request: ' . ( $msg ? $msg : '' )
            );
        }
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

        # Clean up the File::Assets
        # it is set to null but
        # is not needed in JSON output
        # ============================
        delete $c->stash->{assets};

        # disconnect if exists
        # ====================
        $self->_disconnect_vpn if $self->_has_vpn;

        # Forward to JSON view
        # ====================
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
