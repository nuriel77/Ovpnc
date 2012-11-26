package Ovpnc::Controller::Api::Server;
use warnings;
use strict;
use Ovpnc::Plugins::Connector;
#use Module::Locate qw(locate);
#scalar locate('File::Slurp')  ? 0 : do { use File::Slurp; };
use Moose;
use namespace::autoclean;

use vars qw/
  $REGEX
  $pid_file
  $openvpn_bin
  $openvpn_config
  $tmp_dir
  $ssl_config
  $utils_dir
  $vpn_dir
  $app_root
/;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config( namespace => 'api' );

with 'MooseX::Traits';
has '+_trait_namespace' => (
    # A litte hack in order
    # to get the correct namespace.
    # Wanted to keep traits out of
    # the Controller directory
    default => sub {
        my ($P, $SP) = __PACKAGE__ =~ /^(\w+)::(.*)$/;
        return $P . '::TraitFor::' . $SP;
    }
	#'Ovpnc::TraitFor::Controller::Api::Server'
);

has 'vpn' => (
    isa       => 'Object',
    is        => 'rw',
    predicate => '_has_vpn',
    clearer   => '_disconnect_vpn'
);

$REGEX = {
	client_list => 'CLIENT_LIST,(.*?),(.*?),(.*?),([0-9]+),([0-9]+),(.*?),([0-9]+)$',
    log_line  	=> '^([0-9]+),(.*)\n',
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

sub server : Local : ActionClass('REST') { }


=head2 around modifier

Establish connection
before accessing any 
of these actions

=cut

around [qw/
		server_POST
		logs_GET
	/] => sub {
    my $orig = shift;
	my $self = shift;
	my $c = shift;

	$self->assign_params($c)
		unless $pid_file;

	return $self->$orig($c, @_)
		if $self->_has_vpn;

    # Establish connection to management port
	# =======================================
    $self->vpn(
		Ovpnc::Plugins::Connector->new({
            host     => $c->config->{host}     || '127.0.0.1',
            port     => $c->config->{port}     || '7505',
            timeout  => $c->config->{timeout}  || 5,
            password => $c->config->{password} || '',
        })
    );

	return $self->$orig($c, @_);
};


=head2 after modifier

Makes sure to disconnect
and release the mgmt port

=cut

after [qw/
	server_POST
	logs_GET
/] => sub { shift->_disconnect_vpn; };


# Main actions
# ============

=head2 logs_GET

Gets the server logs
Caller can specify
number of lines
or 'all':  ?lines=20

=cut

sub logs_GET : Path('server/logs') Args(0) #Does('NeedsLogin') 
{
    my ( $self, $c ) = @_;

    # Request params
    my $req = $c->request;

	# Verify can run
	$self->sanity( $c ); 

    # Get all or (n) lines of log
    my $_log = $self->vpn->log( $req->params->{lines} || 'all' );

    my $log_object;

    # Check if any log is returned (should be array_ref)
    if ( ref $_log eq 'ARRAY' ) {

        # Read line by line
        for my $line ( @{$_log} ) {

            # Get time and data
            my ( $_time, $_data ) = $line =~ /$REGEX->{log_line}/;

            # Convert epoc time to human if requested
            $_time = scalar localtime($_time)
            			if ( $req->params->{time} );

	        # Add log data to new array_ref
            push( @{$log_object}, { $_time => $_data } );
        }
    }

    $c->stash( status => $log_object );
}


=head2

VPN control commands
/api/server/[start, stop, restart]
or in post param:
command=[...]

=cut

sub server_POST : Local : Args(1) #Does('NeedsLogin') 
{
    my ( $self, $c, $command ) = @_;

	unless ( $command || $c->request->params->{command} ){
		$self->status_no_content($c);
		$self->_disconnect_vpn;
		$c->detach;
	}

	# Assign from post parameters
	# will override anything in the path
	# ==================================
	$command = $c->request->params->{command} if $c->request->params->{command};

   	my $_role = $self->new_with_traits
	(
        traits  		=> [ 'Control' ],
		vpn 			=> $self->vpn,
        openvpn_bin 	=> $openvpn_bin,
        openvpn_pid 	=> $pid_file,
	    openvpn_config 	=> $openvpn_config,
		openvpn_tmpdir	=> $tmp_dir
    ) or die "Could not get role 'Control': $!";

    # Dict of possible commands
	# =========================
    my $_cmds = {
        start   => sub { $_role->start },
        stop    => sub { $_role->stop },
        restart => sub { $_role->restart }
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
	if (ref $_ret_val and $_ret_val->{error} ){
		$self->status_not_found( $c, message => $_ret_val->{error} );
		$self->_disconnect_vpn;
        $c->detach;
	}

    # If no command was matched
	# =========================
    unless ( $_found_command ) {
		$self->status_not_found($c,
			message => 'Command \'' . $command 
					. '\' is unrecognized. Possible commands: start, stop, restart.' 
		);
		$self->_disconnect_vpn;
		$c->detach;
    }

	$self->status_ok($c, entity => $_ret_val );
	$self->_disconnect_vpn;
}


=head2 assign_params

On start assign
params to globals

=cut

sub assign_params : Private {
	my ( $self, $c ) = @_;

	# Remove trailing / if any
	# ========================
	$c->config->{openvpn_dir} =~ s/\/$//;
	$c->config->{application_root} =~ s/\/$//;

	# Assing configurations to global variables
	# ==========================================
	$app_root	 = $c->config->{application_root} or die "No application root?!";

	$tmp_dir = $c->config->{application_root} . '/openvpn/tmp/';

    $pid_file =
		$c->config->{openvpn_pid}
			|| $c->config->{application_root} . '/openpvpn/var/run/openvpn.server.pid';

	$pid_file = 
		$c->config->{application_root} . '/' . $pid_file if ( $pid_file !~ /^\// );

    $openvpn_bin =
		$c->config->{openvpn_bin} || '/usr/sbin/openvpn';

    $openvpn_config =
		Ovpnc::Controller::Api::Configuration->get_openvpn_config_file(
	        $c->config->{ovpnc_conf} ) 
		|| $c->config->{application_root} . '/openvpn/conf/openvpn.ovpnc.conf';

    $vpn_dir 
		= $c->config->{openvpn_dir} || $c->config->{application_root} . '/openvpn';

    $utils_dir = $c->config->{openvpn_utils} || 'conf/2.0';

	$ssl_config = $c->config->{openssl_conf};

	return 1;
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
	if ( $params && ref $params->{permitted} ){
		for ( @{$params->{permitted}} ){
			$_flag++ && last if ( $c->request->method eq $_ );
		}
		unless ( $_flag ){
			$self->_disconnect_vpn;
			$self->status_forbidden( $c,
				message => 'Method ' . $c->request->method 
						 . ' not permitted at ' . ( caller(1) )[3]
			);
			$c->detach;
			return;
		}
	}

	# Check connection
	# ================
    if ( ! $params->{no_connect} && $self->vpn && ! $self->vpn->connect ){
			$self->_disconnect_vpn; # Just to clear the handle		
    	    $self->status_forbidden( $c, message => 'Server offline' );
			$c->detach;
    }
	return 1;
}


sub end : Private {
    my ( $self, $c ) = @_;

	# Clean up the File::Assets
    # it is set to null but
    # is not needed in JSON output
	delete $c->stash->{assets};

    # Debug if requested
    die "forced debug" if $c->req->params->{dump_info};

    # Forward to JSON view
    $c->forward(
        ( $c->request->params->{xml} ? 'View::XML::Simple' : 'View::JSON' ) );
}

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
