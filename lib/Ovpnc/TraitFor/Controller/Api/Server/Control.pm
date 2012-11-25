package Ovpnc::TraitFor::Controller::Api::Server::Control;
use Module::Locate qw(locate);
scalar locate('File::Slurp')  ? 0 : do { use File::Slurp; };
use Proc::ProcessTable;
use Moose::Role;
use namespace::autoclean;

=head1 NAME

Ovpnc::TraitFor::Controller::Api::Server::Control - Control OpenVPN State

=head1 DESCRIPTION

OpenVPN Server Controller
Controls start/stop/restart

=cut

has vpn => (
	is => 'ro',
	isa => 'Object',
	required => 1,
    predicate => '_has_vpn',
    clearer   => '_disconnect_vpn',
);

has [qw/
	openvpn_bin 
	openvpn_config
	openvpn_tmpdir
	openvpn_pid
	/] => (
	is => 'ro',
	isa => 'Str',
	required => 1
);

sub	start {
	my $self = shift;

	my $_pid = $self->_check_running;

    # Check connected or not to mgmt port
    if ( $_pid || ( $self->_has_vpn && $self->vpn->connect ) ) {
		$self->_disconnect_vpn;
        return { error => 'Server already started with pid ' . $_pid };
    } else {
    	# Build command
        my $_command = '/usr/bin/sudo '
          . $self->openvpn_bin
          . ' --writepid '          . $self->openvpn_pid
          . ' --daemon ovpn-server'
          . ' --setenv PATH /bin'
          . ' --script-security 2'
          . ' --client-connect /bin/client_connect'             # Optional checker script
          . ' --echo \'on all\''                                # For management log
          . ' --tmp-dir /tmp'                                   # openvpn tmp directiry
          . ' --ccd-exclusive'                                  # Force client-config-dir usage
          . ' --cd /'                                           # Cd to dir after startup
          . ' --config '            . $self->openvpn_config;    # The main openvpn server config

        #warn 'Executing command: "' . $_command . '"';

        # Run command
        my $_output = `$_command 2>&1`;
	
		# Check exit staatus
        if ( $? >> 8 != 0 ) {
            return { error =>
                "An error occured starting server with code "
              . ( $? >> 8 ) . ": "
              . $_output };
        } else {
        	# Get pid number
            if ( -e $self->openvpn_pid and -r $self->openvpn_pid ) {
                $_pid = read_file $self->openvpn_pid;
                chomp($_pid);
                return { status => 'Server started ok with pid ' . $_pid };
            } else {
            	return { error => 'Server failed to create pid file and/or start!' };
            }
        }
    }
}

sub stop {
	my ( $self, ) = @_;

	if ( $self->_has_vpn and $self->vpn->connect() ){
	    # send SIGINT signal to daemon
        $self->vpn->signal('SIGINT');
	}

	my $_pid = $self->_check_running;

    if ( $_pid ) {
        # If can still connect try killing
        if ( $self->vpn->connect() ) {
            # Get openvpn last pid
            my $pid = read_file $self->openvpn_pid
				or die "Cannot read '". $self->openvpn_pid . "': $!";
            chomp($pid);
            # Try to kill
            kill 9, $pid or return { error => "Cannot kill OpenVPN with pid " . $pid };
			$_pid = $self->_check_running;
            if ( $self->vpn->connect() || $_pid ) {
                return { error => "OpenVPN did not turn off with pid " . $_pid };
            }
        } else {
        	unlink glob $self->openvpn_tmpdir . 'openvpn_cc_*.tmp';
            $self->_disconnect_vpn;
            return { status => "OpenVPN is stopped" };
        }
    } else {
        return { error => "OpenVPN is already stopped" };
    }
}

sub restart {
	my $self = shift;

	$self->stop;
	sleep 1;
	if ( $self->_check_running ){
		$self->stop;
		sleep 1;
	}
	my $_ret_val = $self->start;
	return $_ret_val;
}

sub _check_running {
	my $self = shift;
	my $_pid;
	my $openvpn_bin = $self->openvpn_bin;

	if ( -e $self->openvpn_pid ){
	    $_pid = read_file ( $self->openvpn_pid )
			or die "Cannot read pidfile '" . $self->openvpn_pid . "': $!";
		chomp $_pid;
	} else {
		die "Pidfile does not exists: " . $self->openvpn_pid;
	}

	my $t = Proc::ProcessTable->new;
	foreach my $p ( @{$t->table} ){
		if ( $p->cmndline =~ /$openvpn_bin/g && $_pid == $p->pid ){
	        return $p->pid;
		}
 	}
	return;
}

1;
