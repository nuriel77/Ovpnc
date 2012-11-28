package Ovpnc::TraitFor::Controller::Api::Server::Control;
use warnings;
use strict;
use Module::Locate qw(locate);
scalar locate('File::Slurp') ? 0 : do { use File::Slurp; };
use Proc::Simple;
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
    is        => 'ro',
    isa       => 'Object',
    required  => 1,
    predicate => '_has_vpn',
    clearer   => '_disconnect_vpn',
);

has [
    qw/
      openvpn_bin
      openvpn_config
      openvpn_tmpdir
      openvpn_pid
      /
  ] => (
    is       => 'ro',
    isa      => 'Str',
    required => 1
  );

sub start {
    my $self = shift;

    my $_pid = $self->_check_running;

    # Check connected or not to mgmt port
    # ===================================
    if ( $_pid || ( $self->_has_vpn && $self->vpn->{objects} ) ) {
        $self->_disconnect_vpn;
        return { error => 'Server already started with pid ' . $_pid };
    } 
	else {
		# TODO: Pass args from assign_params
        # Build command
        my @cmd = (
            '/usr/bin/sudo',     $self->openvpn_bin,
            '--writepid',        $self->openvpn_pid,
			'--management',		 '127.0.0.1',	 '7505', '/home/ovpnc/Ovpnc/openvpn/conf/2.0/keys/.management',
			'--management-log-cache',	 2000,
            '--tls-server',
		    '--daemon',          'ovpn-server',
	        '--setenv',          'PATH',              '/bin',
            '--script-security', '2',
            '--client-connect',  '/bin/client_connect',
            '--echo',            'on all',
            '--tmp-dir',         '/tmp',
            '--ccd-exclusive',   '--cd',
            '/',                 '--config',
            $self->openvpn_config
        );

		warn join " ", @cmd;
        # Run a new openvpn process
        # =========================
        my $proc    = Proc::Simple->new();
        my $_status = $proc->start(@cmd);

        sleep 1;    # give it a moment, very important.

        return { error => "An error occured starting up the openvpn server!" }
          unless ($_status);

        unless ( $self->_check_running ) {

            # Not running?
            return { error =>
                  "Server failed to start up! Please check the log files." };
        }
        else {

            # Compare active and file pid numbers
            if ( -e $self->openvpn_pid and -r $self->openvpn_pid ) {
                undef $_pid;
                $_pid = $self->_check_running;
                my $_file_pid = read_file( $self->openvpn_pid );
                chomp($_file_pid);
                if ( $_file_pid == $_pid ) {

                    # Report status ok
                    return { status => 'Server started ok with pid ' . $_pid };
                }
                else {

                    # Report the error
                    return {
                            error => 'Found two different pid numbers: Active: '
                          . $_pid
                          . ' and from pid file: '
                          . $_file_pid
                          . '. Something has probably gone wrong while starting up'
                    };
                }
            }
            else {
                return { error =>
                      'Server failed to create pid file and/or startup!' };
            }
        }
    }
}

sub stop {
    my $self = shift;

    # First find out if the openvpn
    # process is running
    # =============================
    my $_pid = $self->_check_running;

    if ( $_pid && $self->_has_vpn ) {

        # Connect mgmt port
        # =================
        $self->vpn->connect;

        # If there is a connection to mgmt port,
        # try to first kill it with SIGINT
        # =====================================
        warn "Sending SIGINT to OpenVPN daemon";
        $self->vpn->signal('SIGINT');
        sleep 1;    # give it a moment

        # Now we check again
        # ==================
        undef $_pid;
        $_pid = $self->_check_running;

        # Stopped? End this action
        # ========================
        return $self->_stop_end_action
          unless $_pid;

    }

    # If we are here, we should
    # have $_pid not undef
    # =========================
    if ($_pid) {

        # Okay, we have a running process,
        # Let's try killing it
        # ==============================
        warn "Killing OpenVPN daemon";
        kill 9, $_pid
          or return { error => "Cannot kill OpenVPN with pid " . $_pid };

        # Now check if its dead
        # =====================
        undef $_pid;
        $_pid = $self->_check_running;

        # Return ok if no pid
        # ===================
        return $self->_stop_end_action
          unless $_pid;

        # Try killing the process
        # one last time ...
        # =======================
        kill 9, $_pid
          or return { error => "Cannot kill OpenVPN with pid " . $_pid };
        undef $_pid;
        $_pid = $self->_check_running;
        return { error => "Cannot kill OpenVPN with pid " . $_pid }
          if $_pid;
        return $self->_stop_end_action
          unless $_pid;
    }
    else {
        return { error => "OpenVPN is already stopped" };
    }
}

sub restart {
    my $self = shift;

    $self->stop if $self->_check_running || $self->vpn->{objects};
    sleep 1;
    if ( $self->_check_running ) {
        $self->stop;
        sleep 1;
    }
    my $_ret_val = $self->start;
    return $_ret_val;
}

sub _stop_end_action {
    my $self = shift;
    unlink glob $self->openvpn_tmpdir . 'openvpn_cc_*.tmp';
    $self->_disconnect_vpn;
    return { status => "OpenVPN is stopped" };
}

sub _check_running {
    my $self = shift;
    my $_pid;
    my $openvpn_bin = $self->openvpn_bin;

    if ( -e $self->openvpn_pid ) {
        $_pid = read_file( $self->openvpn_pid )
          or die "Cannot read pidfile '" . $self->openvpn_pid . "': $!";
        chomp $_pid;
    }
    else {
        die "Pidfile does not exists: " . $self->openvpn_pid;
    }

    my $t = Proc::ProcessTable->new;
    foreach my $p ( @{ $t->table } ) {
        if ( $p->cmndline =~ /$openvpn_bin/g && $_pid == $p->pid ) {
            return $p->pid;
        }
    }
    return;
}

1;
