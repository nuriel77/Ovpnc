package Ovpnc::Controller::Api::Server;
use Ovpnc::Plugins::Connector;
use strict;
use warnings;
use Module::Locate qw(locate);
scalar locate('File::Slurp')  ? 0 : do { use File::Slurp; };
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

# Define global regex(s)
$REGEX = {
	client_list => 'CLIENT_LIST,(.*?),(.*?),(.*?),([0-9]+),([0-9]+),(.*?),([0-9]+)$',
    log_line  	=> '^([0-9]+),(.*)\n',
    verb_line	=> '^SUCCESS: verb=(\d+)\n',
};

=head1 NAME

Ovpnc::Controller::Api::Server - Catalyst Controller

=head1 DESCRIPTION

OpenVPN Controller API (Server Controller)
Controls all OpenVPN server actions

=cut

=head2 begin

default method, will start connection to mgmt port


=head2 status

get openvpn server status


=head2 view_log

get openvpn log


=head2 restart

restart openvpn



=head2 server

For REST action class

=cut

sub server : Local : ActionClass('REST') { }


=head2 before ...

Establish connection
before accessing any 
of these actions

=cut

around [qw/status control set_verb/] => sub {
    my $orig = shift;
	my $self = shift;
	my $c = shift;

	$self->assign_params($c)
		unless $pid_file;

	return $self->$orig($c, @_)
		if $self->_has_vpn;

    # Establish connection to management port
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

=head2 assign_params

On start assign
params to globals

=cut

sub assign_params : Private {
	my ( $self, $c ) = @_;

	# Remove trailing /
	$c->config->{openvpn_dir} =~ s/\/$//;
	$c->config->{application_root} =~ s/\/$//;

	# Assing to global variables
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
		Ovpnc::Controller::Api::Config->get_openvpn_config_file(
	        $c->config->{ovpnc_conf} ) 
		|| $c->config->{application_root} . '/openvpn/conf/openvpn.ovpnc.conf';

    $vpn_dir 
		= $c->config->{openvpn_dir} || $c->config->{application_root} . '/openvpn';

    $utils_dir = $c->config->{openvpn_utils} || 'conf/2.0';

	$ssl_config = $c->config->{openssl_conf};

	return 1;
}



# Main actions
{

	sub status : Path('server/status') : Args(0) #Does('NeedsLogin')
    {
        my ( $self, $c ) = @_;

		# Verify can run
		$self->sanity( $c, {
			method 		=> $c->request->method,
			permitted 	=> 'GET', 
		});

  		# Trait names should match action name
	    # (class names in ucfirst)
		my ($_fn) = (caller(0))[3] =~ /::(\w+)$/;
    	my $_role = $self->new_with_traits(
	        traits  => [ ucfirst( $_fn ) ],
			vpn 	=> $self->vpn,
			regex	=> $REGEX
	    ) or die "Could not get role '" . ucfirst( $_fn ) . "': $!";

		# Check connection to mgmt port
        if ( my $_status = $_role->get_status ) {
	        $c->stash( $_status );
			$self->_disconnect_vpn;
        } else {
            $c->stash( { error => 'Did not get status data from management port' } );
			$self->_disconnect_vpn;
		}
    }


=head2 set_verb

Sets the verbosity level live

=cut
    sub set_verb : Path('server/set_verb') Args(1) #Does('NeedsLogin')
	{
        my ( $self, $c, $level ) = @_;

		# Verify can run
		$self->sanity( $c, {
			method 		=> $c->request->method,
			permitted 	=> 'GET', 
		});

        # Set the verbosity level
        $c->stash(
            {
                    status => $self->set_verbosity( $level ? $level : 4 )
                  . ' Now at level: '
                  . $self->get_verbosity()
            }
        );
		$self->_disconnect_vpn;
    }

    sub view_log : Chained('base') PathPart('log') Args(0) {
        my ( $self, $c ) = @_;

        # Request params
        my $req = $c->request;

        # Check connected with mgmt port
        unless ( $self->vpn->connect ) {
            $c->stash( { status => 'Server offline' } );
			$self->_disconnect_vpn;
			$c->detach;
        }

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

        $c->stash( log => $log_object );
    }


=head2

VPN control commands
/api/server/[start, stop, restart]

=cut

    sub control : Path('server') Args(1) #Does('NeedsLogin') 
	{
        my ( $self, $c, $command ) = @_;

		# Verify can run
        $self->sanity( $c, {
            method      => $c->request->method,
            permitted   => 'GET',
			no_connect	=> 1
        });

  		# Trait names should match action name
	    # (class names in ucfirst)
		my ($_fn) = (caller(0))[3] =~ /::(\w+)$/;
    	my $_role = $self->new_with_traits
		(
	        traits  		=> [ ucfirst( $_fn ) ],
			vpn 			=> $self->vpn,
            openvpn_bin 	=> $openvpn_bin,
            openvpn_pid 	=> $pid_file,
            openvpn_config 	=> $openvpn_config,
			openvpn_tmpdir	=> $tmp_dir
	    ) 
		or die "Could not get role '" . ucfirst( $_fn ) . "': $!";

        # Dict of possible commands
        my $_cmds = {
            start   => sub { $_role->start },
            stop    => sub { $_role->stop },
            restart => sub { $_role->restart }
        };

        my ( $_found_command, $_ret_val );

        # Run the matched command (closure)
        for my $_cmd ( keys %{$_cmds} ) {
            if ( $_cmd eq $command ) {
                $_ret_val       = $_cmds->{$_cmd}->();
                $_found_command = 1;
            }
        }

        # If no command was matched
        unless ($_found_command) {
            $c->stash( { status => $command . ' is unrecognized' } );
			$self->_disconnect_vpn;
			$c->detach;
        }

        $c->stash( $_ret_val );
		$self->_disconnect_vpn;
    }

}

# Private methods
# ===============
{

    sub get_verbosity : Private {
        my $self = shift;

        # Get verb level
        my $verb = $self->vpn->verb();

        # Parse the verb level
        $verb =~ s/$REGEX->{verb_line}/$1/;
        return $verb;
    }

    sub set_verbosity : Private {
        my ( $self, $level ) = @_;
        my $verb = $self->vpn->verb($level);
        return $verb;
    }

}

{

    sub stop_vpn : Private {
        my $self = shift;

        if ( $self->vpn and $self->vpn->connect() ) {

            # send SIGINT signal to daemon
            $self->vpn->signal('SIGINT');

            # If can still connect try killing
            if ( $self->vpn->connect() ) {

                # Get openvpn last pid
                my $pid = read_file $pid_file;
                chomp($pid);

                # Try to kill
                kill 9, $pid or return "Cannot kill OpenVPN with pid " . $pid;
                if ( $self->vpn->connect() ) {
                    return "OpenVPN did not turn off with pid " . $pid;
                }
            }
            else {
				unlink glob $tmp_dir.'/openvpn_cc_*.tmp'
					or warn 'Did not manage to empty '.$tmp_dir.'/*tmp';
				$self->_disconnect_vpn;
                return "OpenVPN is stopped";
            }
        }
        else {
            return "OpenVPN is already stopped";
        }
    }

    sub start_vpn : Private {
        my $self = shift;

        # Check connected or not to mgmt port
        if ( $self->vpn && $self->vpn->connect() ) {
            return 'Server already started';
        }
        else {

            # Build command
            my $command = '/usr/bin/sudo '
              . $openvpn_bin
              . ' --writepid ' 			. $pid_file
              . ' --daemon ovpn-server'
			  . ' --setenv PATH /bin'
              . ' --script-security 3 system'	
			  . ' --client-connect /bin/client_connect'				# Optional checker script
			  . ' --echo \'on all\''								# For management log
			  . ' --tmp-dir /tmp'									# openvpn tmp directiry
			  . ' --ccd-exclusive'									# Force client-config-dir usage
              . ' --cd /'											# Cd to dir after startup
              . ' --config '	        . $openvpn_config;			# The main openvpn server config

			warn 'Executing command: "' . $command . '"';

            # Run command
            my $output = `$command 2>&1`;

            # Check exit staatus
            if ( $? >> 8 != 0 ) {
                return
                    "An error occured starting server with code "
                  . ( $? >> 8 ) . ": "
                  . $output;
            }
            else {

                # Get pid number
                if ( -e $pid_file and -r $pid_file ) {
                    my $pid = read_file $pid_file;
                    chomp($pid);
                    return 'Server started ok with pid ' . $pid;
                }
                else {
                    return 'Server failed to create pid file and/or start!';
                }
            }
        }
    }

    sub restart_vpn : Private {
        my $self = shift;

        # stop
        $self->stop_vpn;

        # wait
        sleep 2;

        # start
        my $ret_val = $self->start_vpn;
        return $ret_val if $ret_val;
    }
}

=head2 sanity

Verify parameters
and state before 
an action can begin

=cut

sub sanity : Private {
	my ( $self, $c, $params ) = @_;

	# Check method
	if ( $params->{method} ne $params->{permitted} ){
		$c->stash({ 
			error => 'Method ' . $params->{method} 
					. ' not permitted, permitted: ' . $params->{permitted} 
		});
		$self->_disconnect_vpn;
        $c->detach;
	}
	# Check connection
    if ( ! $params->{no_connect} && ! $self->vpn->connect ) {
        $c->stash( { status => 'Server offline' } );
		$self->_disconnect_vpn;
		$c->detach;
    }
	return 1;
}

sub default : Private {
    my ( $self, $c ) = @_;
    $c->stash( { status => 'Control action not found' } );
    $c->response->status(404);
}

sub end : Private {
    my ( $self, $c ) = @_;

    # Close connection to management port
    $self->_disconnect_vpn;

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
