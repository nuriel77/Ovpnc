package Ovpnc::Controller::Api::Server;
use warnings;
use strict;
use File::Slurp;
use Moose;
use namespace::autoclean;
use vars qw/$REGEX/;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config( namespace => 'api' );

with 'MooseX::Traits';
has '+_trait_namespace' => (
    default => sub {
        my ( $P, $SP ) = __PACKAGE__ =~ /^(\w+)::(.*)$/;
        return $P . '::TraitFor::' . $SP;
    }
);

has 'vpn' => (
    isa       => 'Object',
    is        => 'rw',
    predicate => '_has_vpn',
    clearer   => '_disconnect_vpn'
);

has 'cfg' => (
    is        => 'rw',
    isa       => 'HashRef',
    predicate => '_has_conf'
);

$REGEX = {
    client_list =>
      'CLIENT_LIST,(.*?),(.*?),(.*?),([0-9]+),([0-9]+),(.*?),([0-9]+)$',
    log_line => '^([0-9]+),(.*)\n',
};

=head1 NAME

Ovpnc::Controller::Api::Server - Catalyst Controller

=head1 DESCRIPTION

OpenVPN Controller API (Server Controller)
Controls all OpenVPN server actions

=cut

=head2 server

For REST action class

=cut

sub server : Local : ActionClass('REST') {
}


=head2 begin

Automatic first
action to run

=cut

sub begin : Private {
    my ( $self, $c ) = @_;

    # Log user in if login params are provided
    # =======================================
    $c->controller('Api')->auth_user( $c )
        unless $c->user_exists();

    # Set the expiration time
    # if user is logged in okay
    # =========================
    if ( $c->user_exists() && !$c->req->params->{_} ){
        $c->log->info('Setting session expire to '
            . $c->config->{'api_session_expires'});
        $c->change_session_expires(
            $c->config->{'api_session_expires'} );
    }

}


=head2 around modifier

Establish connection
before accessing any
of these actions

=cut

around 'server_GET' => sub {
    my $orig = shift;
    my $self = shift;
    my $c    = shift;

    $self->cfg( $c->controller('Api')->assign_params( $c ) )
      unless $self->_has_conf;

    return $self->$orig( $c, @_ )
};

around [
    qw/
      server_POST
      logs_GET
      /
  ] => sub {
    my $orig = shift;
    my $self = shift;
    my $c    = shift;

    $self->cfg( $c->controller('Api')->assign_params( $c ) )
      unless $self->_has_conf;

    return $self->$orig( $c, @_ )
        if 'start' ~~ @_;

    return $self->$orig( $c, @_ )
        if $self->_has_vpn;

    # Establish connection to management port
    # ========================================
    $self->vpn( Ovpnc::Plugin::Connector->new( $self->cfg->{mgmt_params} ) );

    return $self->$orig( $c, @_ );
  };

=head2 after modifier

Makes sure to disconnect
and release the mgmt port

=cut

after [
    qw/
      server_POST
      logs_GET
      /
] => sub {
    my $self = shift;
    $self->_disconnect_vpn if $self->_has_vpn;
};

# Main actions
# ============

=head2 logs_GET

Gets the server logs
Caller can specify
number of lines
or 'all':  ?lines=20

=cut

sub logs_GET : Path('server/logs')
             : Args(0)
             : Sitemap(*)
		     : Does('ACL') AllowedRole('admin') AllowedRole('can_edit') ACLDetachTo('denied')
{
    my ( $self, $c ) = @_;

    use constant MAX_LINES => 1000;

    # Verify can run
    # ==============
    $self->sanity($c);

    my $lines = $c->request->params->{lines} if $c->request->params->{lines};

    # Get all or (n) lines of log
    # ===========================
    my $_log = $self->vpn->log( $lines ? $lines : MAX_LINES );
    my $_log_object;

    # Check if any log is returned
    # (should be array_ref)
    # ============================
    if ( ref $_log eq 'ARRAY' ) {

        for my $line ( @{$_log} ) {

            # Get time and data
            # =================
            my ( $_time, $_data ) = $line =~ /$REGEX->{log_line}/;

            # Convert epoc time to
            # readable if requested
            # ====================
            $_time = scalar localtime($_time)
              if ( $c->request->params->{time} );

            # Add log data
            # to new array_ref
            # ================
            push( @{$_log_object}, { $_time => $_data } );
        }
    }

    if ( $_log_object && ref $_log_object eq 'ARRAY' && @{$_log_object} > 0 ) {
        $self->status_ok( $c, entity => $_log_object );
    }
    else {
        $self->status_not_found( $c, message => 'No log data found' );
    }
}

=head2

VPN control commands
/api/server/[start, stop, restart]
or in post param:
command=[...]

=cut

sub server_POST : Local
                : Args(0)
                : Sitemap
				: Does('ACL')
                  AllowedRole('admin')
                  AllowedRole('can_edit')
                  ACLDetachTo('denied')
                : Does('NeedsLogin')
{
    my ( $self, $c, $command ) = @_;

    do {
        $self->status_no_content($c);
        $self->_disconnect_vpn if $self->_has_vpn;
        $c->detach;
    } unless defined( $command // $c->request->params->{command} );

    # Assign from post parameters
    # will override anything in the path
    # ==================================
    $command = $c->request->params->{command}
        if $c->request->params->{command};

    my $_role = $self->new_with_traits(
        traits          => ['Control'],
        cfg             => $self->cfg,
        app_root        => $c->config->{home},
        app_user        => $c->user_exists ? $c->user->get("username") : '',
    ) or die "Could not get role 'Control': $!";

    # Dict of possible commands
    # =========================
    my $_cmds = {
        start   => sub { $_role->start( $self->_has_vpn ? $self->vpn : undef ) },
        stop    => sub { $_role->stop( $self->_has_vpn ? $self->vpn : undef ) },
        restart => sub { $_role->restart( $self->_has_vpn ? $self->vpn : undef ) },
    };

    my ( $_found_command, $_ret_val );

    # Run the matched command (closure)
    # =================================
    for my $_cmd ( keys %{$_cmds} ) {
        if ( $_cmd eq $command ) {
            $_ret_val       = $_cmds->{$_cmd}->();
            $_found_command = 1;
        }
    }

    # If command returned errors
    # ==========================
    if ( ref $_ret_val and $_ret_val->{error} ) {
        $self->status_not_found( $c, message => $_ret_val->{error} );
        $self->_disconnect_vpn;
        $c->detach;
    }

    # If no command was matched
    # =========================
    unless ($_found_command) {
        $self->status_not_found( $c,
                message => 'Command \''
              . $command
              . '\' is unrecognized. Possible commands: start, stop, restart.'
        );
        $self->_disconnect_vpn;
        $c->detach;
    }

    $self->status_ok( $c, entity => $_ret_val );
    $self->_disconnect_vpn;
}

=head2 server_GET

Get pid of running server
or return server offline

=cut

sub server_GET : Local
               : Args(0)
               : Sitemap
               : Does('ACL') AllowedRole('admin') AllowedRole('client') ACLDetachTo('denied')
{
    my ( $self, $c ) = @_;

    my $_role = $self->new_with_traits(
        traits         => ['Control'],
        cfg            => $self->cfg,
        app_root       => $c->config->{home},
        app_user       => $c->user_exists ? $c->user->get("username") : '',
    ) or die "Could not get role 'Control': $!";

    my $_pid = $_role->_check_running( $self->_has_vpn ? $self->vpn : undef );

    if ( $_pid ){
        $self->status_ok($c, entity => { pid => $_pid } );
        return $_pid;
    }
    else {
        $self->status_not_found($c, message => "Server offline");
        return;
    }
}

=head2 sanity

Check connection state for actions that 
require active connection to the mgmt port
Will not return anything in case connection
is down, will return status 403 to user.

=cut

sub sanity : Private {
    my ( $self, $c, $params ) = @_;

    # Check permitted method for
    # non Catalyst REST complient
    # ===========================
    my $_flag = 0;
    if ( $params && ref $params->{permitted} ) {
        for ( @{ $params->{permitted} } ) {
            $_flag++ && last if ( $c->request->method eq $_ );
        }
        unless ($_flag) {
            $self->_disconnect_vpn;
            $c->response->status(415);
            $self->stash->{rest} =
                'Method '
              . $c->request->method
              . ' not permitted at '
              . ( caller(1) )[3];
            $c->detach;
        }
    }

    # Check connection
    # ================
    if ( !$params->{no_connect} && $self->vpn && !$self->vpn->connect ) {
        $self->_disconnect_vpn;    # Just to clear the handle
        $self->status_ok( $c, entity => { status => 'Server offline' });
        $c->detach;
    }
    return 1;
}

=head2 denied

Unauthorized access
no match for role

=cut

sub denied : Private {
    my ( $self, $c ) = @_;
    $self->status_forbidden( $c, message => 'Access denied' );
    $c->detach;
}

sub end : Private {
    my ( $self, $c ) = @_;

    # Clean up the File::Assets
    # it is set to null but
    # is not needed in JSON output
    # ============================
    delete $c->stash->{assets};

    # Forward to JSON view
    # ====================
    $c->forward(
        ( $c->request->params->{xml} ? 'View::XML::Simple' : 'View::JSON' ) );
}

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
