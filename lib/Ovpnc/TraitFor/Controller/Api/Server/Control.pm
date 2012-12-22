package Ovpnc::TraitFor::Controller::Api::Server::Control;
use warnings;
use strict;
use Module::Locate 'locate';
scalar locate('File::Slurp') ? 0 : do { use File::Slurp; };
use String::MkPasswd 'mkpasswd';
use Errno  qw( EADDRINUSE );
use Socket qw( PF_INET SOCK_STREAM SOCK_DGRAM INADDR_ANY sockaddr_in pack_sockaddr_in inet_aton );
use Proc::Simple;
use Proc::ProcessTable;
use File::Touch;
use Moose::Role;
use MooseX::Types::IPv4 'ip4';
use namespace::autoclean;

=head1 NAME

Ovpnc::TraitFor::Controller::Api::Server::Control - Control OpenVPN State

=head1 DESCRIPTION

OpenVPN Server Controller
Controls start/stop/restart

=cut

# VPN mgmt port Connection handle
# ===============================
has vpn => (
    is        => 'ro',
    isa       => 'Object',
    required  => 0,
    predicate => '_has_vpn',
    clearer   => '_disconnect_vpn',
    writer    => '_set_vpn',
);

# Configuration parameters
# ========================
has [qw/app_root app_user/] => (
    is       => 'ro',
    isa      => 'Str',
    required => 1
);

has cfg => (
    is => 'ro', 
    isa => 'HashRef',
    required => 1
);


=head2 start

L<Start> the OpenVPN server

=cut

sub start {
    my ( $self, $vpn ) = @_;

    $self->_set_vpn( $vpn ) if $vpn;

    # Check connected or not to mgmt port
    # ===================================
    my $_pid = $self->_check_running;
    if ( $_pid || ( $self->_has_vpn && $self->vpn->{objects} ) ) {
        $self->_disconnect_vpn;
        return { error => 'Server already started with pid ' . $_pid };
    }
    else {

        # First check if the address/port
        # are free to bind to
        # ===============================
        my $config = Ovpnc::Controller::Api::Configuration
            ->new( cfg => $self->cfg );
        my ( $openvpn_addr, $openvpn_port, $openvpn_proto ) =
             @{( $config->get_openvpn_param(
                [ 'VPNServer', 'ServerPort', 'Protocol' ] ) )};

        undef $config;

        unless (
            $self->_check_port_available(
                $openvpn_addr,
                $openvpn_port,
                $openvpn_proto
            )
        ) {
            return { 
                error => 'Server cannot start. Cannot bind to socket. '
                    . 'Check that the ' . $openvpn_proto . ' address/port '
                    . $openvpn_addr . ':' . $openvpn_port
                    . ' are free and try again.'
            };
        }

        $self->_check_management_password;

        my @cmd = (
            '/usr/bin/sudo',        $self->cfg->{openvpn_bin},
            '--writepid',           $self->cfg->{openvpn_pid},
            '--management',         '127.0.0.1', '7505',
            $self->cfg->{mgmt_passwd_file},
            '--management-log-cache', 2000,
            '--tls-server',
            '--daemon', 'ovpn-server',
            '--setenv',            'PATH', '/bin',
            '--setenv',            'OVPNC_USER', $self->app_user,
            '--script-security',   '2',
            '--client-connect',    'bin/client_connect',
            '--client-disconnect', 'bin/client_disconnect',
            '--tmp-dir',           '/tmp',
            '--ccd-exclusive',
            '--cd',                $self->cfg->{openvpn_dir} . '/',
            '--up',                'bin/up.pl',
            '--up-restart',
            '--config',            $self->app_root . '/' . $self->cfg->{openvpn_config},
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
            # ============
            return { error =>
                  "Server failed to start up! Please check the log files." };
        }
        else {

            # Compare active and file pid numbers
            # ===================================
            if ( -e $self->cfg->{openvpn_pid} and -r $self->cfg->{openvpn_pid} ) {
                undef $_pid;
                $_pid = $self->_check_running;
                my $_file_pid = read_file( $self->cfg->{openvpn_pid}, chomp => 1 );

                if ( $_file_pid == $_pid ) {

                    # Report status ok
                    # ================
                    return { status => 'Server started ok with pid ' . $_pid };
                }
                else {

                    # Report error
                    # ============
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


=head2 stop

L<Stop> the OpenVPN server

=cut

sub stop {
    my ( $self, $vpn ) = @_;

    if ( $vpn ){
        $self->_set_vpn($vpn);
    }

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
        unlink $self->cfg->{openvpn_pid};
        return $self->_stop_end_action
          unless $_pid;

    }

    # If we are here, we should
    # have $_pid not undef
    # =========================
    if ( $_pid ) {

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


=head2 restart

L<Restart> the OpenVPN server

=cut

    sub restart {
        my ( $self, $vpn ) = @_;
    
        $self->_set_vpn($vpn)
            if $vpn;
    
        $self->stop if $self->_check_running || $self->vpn->{objects};
        sleep 1;
        if ( $self->check_running ) {
            $self->stop;
            sleep 1;
        }
        my $_ret_val = $self->start;
        return $_ret_val;
    }

    
=head2 _stop_end_action

Run this final action
when the server stops

=cut

    sub _stop_end_action {
        my $self = shift;
        unlink glob $self->cfg->{openvpn_tmpdir} . 'openvpn_cc_*.tmp';
        $self->_disconnect_vpn;
        return { status => "OpenVPN is stopped" };
    }

=head2 _check_running

Check if the OpenVPN server is running

=cut

    sub _check_running {
        my $self = shift;
        my $_pid;
        my $openvpn_bin = $self->cfg->{openvpn_bin};
    
        if ( -e $self->cfg->{openvpn_pid} and -r $self->cfg->{openvpn_pid} ) {
            $_pid = read_file( $self->cfg->{openvpn_pid}, chomp => 1 );
        }
        else {
            my (undef, undef, undef, $gid) = getpwnam(
                $self->cfg->{openvpn_group} );
            my (undef, undef, $uid) = getpwuid( $< );
            my ($_rundir) = $self->cfg->{openvpn_pid} =~ /^(.*)\/.*$/;
            unless ( -e $_rundir ) {
                mkdir $_rundir;
                chmod 0770, $_rundir;
                chown $uid, $gid, $_rundir;
            }
            touch $self->cfg->{openvpn_pid};
            chmod 0660, $self->cfg->{openvpn_pid};
            chown $uid, $gid, $self->cfg->{openvpn_pid};
        }
    
        my $t = Proc::ProcessTable->new;
        foreach my $p ( @{ $t->table } ) {
            if ( $p->cmndline =~ /$openvpn_bin/g && ( $_pid && $_pid == $p->pid ) ){
                return $p->pid;
            }
        }
        return;
    }

=head2 _check_port_available

Check if OpenVPN port is in user

=cut

    sub _check_port_available {
        my ( $self, $iaddr, $port, $proto ) = @_;

        $proto  ||= 'udp';
        $proto    = getprotobyname($proto)  or die "getprotobyname: $!";
        $port   ||= 1194;
        $iaddr  ||= INADDR_ANY;
        my $type  = $proto eq 'tcp' ? SOCK_STREAM : SOCK_DGRAM;
        my $ipaddr = inet_aton($iaddr);
        socket(my $sock, PF_INET, $type, $proto) or die "socket: $!";
        my $name = sockaddr_in($port,$ipaddr)    or die "sockaddr_in: $!";
        bind($sock, $name)                       and return 1;
        $! == EADDRINUSE                         and return 0;
        die "bind: $!";
    }

=head2 _check_management_password

Will check if password for management
console already exists, if not, it
will create one before starting up.
When using the connector, it will
read from the file so it should
work automatically without having
to manually set the password.

=cut

    sub _check_management_password {
        my $self = shift;

        # If no file or file empty, generate a new password
        # ==================================================
        $self->_write_new_passwd
            if ( ! -e $self->cfg->{mgmt_passwd_file}
                || (stat( $self->cfg->{mgmt_passwd_file} ))[7] == 0
            );
        }

    sub _write_new_passwd{
        my $self = shift;
        open ( my $FH, '>', $self->cfg->{mgmt_passwd_file} )
            or die "Cannot update " . $self->cfg->{mgmt_passwd_file}
                    . ": " . $!;
        print {$FH} $self->_gen_passwd(32, 3, 3, 3, 0);
        close $FH;
        return 1;
    }

    sub _gen_passwd {
        my $self = shift;
        my ($a,$b,$c,$d,$e) = @_;
        return mkpasswd(
                -length     => $a,
                -minnum     => $b,
                -minlower   => $c,
                -minupper   => $d,
                -minspecial => $e,
        );
    }



=head1 AUTHOR

Nuriel Shem-Tov

=cut

1;
