package Ovpnc::Controller::Api::Server;
use strict;
use warnings;
use Moose;
use Net::OpenVPN::Manage;
use File::Slurp;

use vars qw/
  $regex
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

__PACKAGE__->config( namespace => 'api/server' );

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

has 'host' => (
    isa     => 'Str',
    is      => 'rw',
    default => '127.0.0.1'
);

has 'port' => (
    isa     => 'Str',
    is      => 'rw',
    default => '7505'
);

has 'password' => (
    isa => 'Str',
    is  => 'rw'
);

has 'timeout' => (
    isa     => 'Int',
    is      => 'rw',
    default => 5
);

has 'vpn' => (
    isa       => 'Object',
    is        => 'rw',
    predicate => '_has_vpn',
    clearer   => '_disconnect_vpn'
);

# Define global regex(s)
$regex = {
    client_list => 'CLIENT_LIST,(.*?),(.*?),(.*?),([0-9]+),([0-9]+),(.*?),([0-9]+)$',
    log_line  => '^([0-9]+),(.*)\n',
    verb_line => '^SUCCESS: verb=(\d+)\n',
	client_crl => 'R\s*\w+\s*(\w+).*\/C.*\/CN=(.*)\/name=.*',
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

=head2 kill and unkill

Kill or unkill a client
will also revoke/unrevoke CRL
One argument (client identification)

=head2 index

For REST action class

=cut

sub index : Chained('/') PathPart('api/server') Args(0) : ActionClass('REST') {
}

=head2 begin

On start assign
params to globals

=cut
sub begin : Private {
	my ( $self, $c ) = @_;

	# Establish connection to management port
    $self->vpn(
        $self->mgt_connect(
            {
                host     => $c->config->{host}     || '127.0.0.1',
                port     => $c->config->{port}     || '7505',
                timeout  => $c->config->{timeout}  || 5,
                password => $c->config->{password} || '',
            }
        )
    );

	# Remove trailing /
	$c->config->{openvpn_dir} =~ s/\/$//;
	$c->config->{application_root} =~ s/\/$//;

	# Assing to global variables
	$app_root	 = $c->config->{application_root} or die "No application root?!";

	# Set openvpn tmp dir
	$tmp_dir = $c->config->{application_root} . '/openvpn/tmp/';

	# Pid file, if only a dir part has been given, prepand
	# the application root to it (for example ovpnc/somedir/..., will prepand to it)
    $pid_file =
		$c->config->{openvpn_pid}
			|| $c->config->{application_root} . '/openpvpn/var/run/openvpn.server.pid';

	$pid_file =
		$c->config->{application_root} . '/' . $pid_file if ( $pid_file !~ /^\// );

	# OpenVPN main binary
    $openvpn_bin =
		$c->config->{openvpn_bin} || '/usr/sbin/openvpn';

	# OpenVPN main config
    $openvpn_config =
		Ovpnc::Controller::Api::Config->get_openvpn_config_file(
	        $c->config->{ovpnc_conf} ) 
		|| $c->config->{application_root} . '/openvpn/conf/openvpn.ovpnc.conf';

	# OpenVPN dir
    $vpn_dir 
		= $c->config->{openvpn_dir} || $c->config->{application_root} . '/openvpn';

	# OpenVPN Utilities dir
    $utils_dir = $c->config->{openvpn_utils} || 'conf/2.0';

	# OpenSSL config file
	$ssl_config = $c->config->{openssl_conf};

	return 1;
}

=head2 before ...

Establish connection
before accessing any 
of these actions

=cut

before [qw/status control_vpn set_verb/] => sub {
    my ( $self, $c ) = @_;

    # Establish connection to management port
    $self->vpn(
        $self->mgt_connect(
            {
                host     => $c->config->{host}     || '127.0.0.1',
                port     => $c->config->{port}     || '7505',
                timeout  => $c->config->{timeout}  || 5,
                password => $c->config->{password} || '',
            }
        )
    );

	return 1;
};


# Main actions
{

	sub status : Path('status') : Args(0) #Does('NeedsLogin')
    {
        my ( $self, $c ) = @_;

        # Check connection to mgmt port
        unless ( $self->vpn->connect ) {
            $c->stash( { status => 'Server offline' } );
			$c->detach;
        }

  		# Trait names should match action name
	    # (class names in ucfirst)
		my ($fn) = (caller(0))[3] =~ /::(\w+)$/;
    	my $role = $self->new_with_traits(
	        traits  => [ ucfirst( $fn ) ],
			vpn 	=> $self->vpn,
			regex	=> $regex
	    ) or die "Could not get role '" . ucfirst( $fn ) . "': $!";

		# Check connection to mgmt port
        if ( my $status = $role->get_status ) {
	        $c->stash( $status );
        } else {
            $c->stash( { error => 'Did not get status data from management port' } );
		}
    }

    sub set_verb : Path('set_verb') Args(0) #Does('NeedsLogin')
	{
        my ( $self, $c, $level ) = @_;

        unless ( $self->vpn->connect ) {
            $c->stash( { status => 'Server offline' } );
			$c->detach;
            return;
        }

        # Set the verbosity level
        $c->stash(
            {
                    status => $self->set_verbosity( $level ? $level : 4 )
                  . ' Now at level: '
                  . $self->get_verbosity()
            }
        );
    }

    sub view_log : Chained('base') PathPart('log') Args(0) {
        my ( $self, $c ) = @_;

        # Request params
        my $req = $c->request;

        # Check connected with mgmt port
        unless ( $self->vpn->connect ) {
            $c->stash( { status => 'Server offline' } );
			$c->detach;
            return;
        }

        # Get all or (n) lines of log
        my $_log = $self->vpn->log( $req->params->{lines} || 'all' );

        my $log_object;

        # Check if any log is returned (should be array_ref)
        if ( ref $_log eq 'ARRAY' ) {

            # Read line by line
            for my $line ( @{$_log} ) {

                # Get time and data
                my ( $_time, $_data ) = $line =~ /$regex->{log_line}/;

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

Revoke's client certificate
using crl.pem
Appends .disabled to client's 
file in ccd 

=cut

    sub kill_client : Path('kill') : Args(1) #Does('NeedsLogin')
	{
        my ( $self, $c, $client ) = @_;

        unless ($client) {
            $c->stash( { error => 'No client specified at kill_client' } );
			$c->detach;
        }

        # Check connection to mgmt port
        unless ( $self->vpn->connect ) {
            $c->stash( { status => 'Server offline' } );
			$c->detach;
        }

        # Revoke client's certificate
        my $ret_val;
        $ret_val = $self->revoke_certificate($client)
          unless ( $c->request->params->{no_revoke} );

        # Kill the connection (just incase client is currently connected)
        if ( my $str = $self->kill_connection($client) ) {
            $ret_val .= ';' . $str;
        }
        else {
            $ret_val .= ';Client ' . $client . ' not found online';
        }
        $c->stash( { status => $ret_val } );
    }

=head2

Unrevoke a client's certificate
and remove the appended
.disabled from the file
in ccd

=cut

    sub unkill_client : Path('unkill') Args(1) Does('NeedsLogin') {
        my ( $self, $c, $client ) = @_;

        # Unrevoke a revoked client's certificate
        my $ret_val = $self->unrevoke_certificate($client);
        $c->stash( { status => $ret_val } );
    }

=head2

VPN control commands

=cut

    sub control_vpn : Path('control') Args(1) Does('NeedsLogin') {
        my ( $self, $c, $command ) = @_;

        # Dict of possible commands
        my $cmds = {
            start   => sub { $self->start_vpn; },
            stop    => sub { $self->stop_vpn },
            restart => sub { $self->restart_vpn },
        };

        my ( $found_command, $ret_val );

        # Run the matched command (closure)
        for my $cmd ( keys %{$cmds} ) {
            if ( $cmd eq $command ) {
                $ret_val       = $cmds->{$cmd}->();
                $found_command = 1;
            }
        }

        # If no command was matched
        unless ($found_command) {
            $c->stash( { status => $command . ' is unrecognized' } );
            return;
        }

        # If return val is not a ref, stash for output
        unless ( ref $ret_val ) {
            $c->stash( { status => $ret_val } );
        }
    }

	sub get_killed : Path('get_killed') : Args(0) Does('NeedsLogin')
	{
		my ( $self, $c ) = @_;

		my $crl_index = $c->config->{openvpn_dir} . '/keys/index.txt';

		unless ( -r $crl_index ){
			$c->stash( { error => 'Cannot read ' . $crl_index . ', file does not exists or is not readable' } );
            $c->detach;
		}

		my $revoked_clients = $self->read_crl_index_file( $crl_index );

		if ( $revoked_clients and ref $revoked_clients eq 'ARRAY' and @{$revoked_clients} > 0 ){
			$c->stash( { status => $revoked_clients } );
		}
		else {
			$c->stash( { status => 'none' } );
		}
	}

}

# Private methods
# ===============
{

	sub read_crl_index_file : Private
	{
		my ( $self, $crl_index ) = @_;
		my ($Y,$M,$D,$h,$m,$s);
		my $obj = [];
	
		open ( FH, "<", $crl_index )
			or die "Cannot read $crl_index: $!";
	
		while (my $line = <FH>){
			my ($revoke_time, $name) = $line =~ /$regex->{client_crl}/g;
			if ($revoke_time and $name){ 
				($Y,$M,$D,$h,$m,$s) = $revoke_time =~ /(..)/g;
				my $kill_time =  $D.'-'.$M.'-'.($Y+2000) . ' ' . $h.':'.$m.':'.$s;
				push ( @{$obj}, { name => $name, kill_time => $kill_time } );
			}
		}
	
		close FH;
		return $obj;
	}

    sub mgt_connect : Private {
        my $c = shift;
        return Net::OpenVPN::Manage->new(
            {
                host     => $c->{host},
                port     => $c->{port},
                password => $c->{password},
                timeout  => $c->{timeout},
            }
        );
    }

    sub get_verbosity : Private {
        my $self = shift;

        # Get verb level
        my $verb = $self->vpn->verb();

        # Parse the verb level
        $verb =~ s/$regex->{verb_line}/$1/;
        return $verb;
    }

    sub set_verbosity : Private {
        my ( $self, $level ) = @_;
        my $verb = $self->vpn->verb($level);
        return $verb;
    }

    sub kill_connection : Private {
        my ( $self, $connection ) = @_;
        my $ret_val = $self->vpn->kill($connection);
        return $ret_val;
    }

    sub revoke_certificate : Private {
        my ( $self, $client ) = @_;
        my $ret_val;

        # vars script location
        my $vars = $vpn_dir . '/vars';

        # build command
        my $command = $vpn_dir . '/revoke-full';

        # Check if can run
        if ( -e $vpn_dir . '/vars' and -e $command and -x $command ) {

            # Run command
            $ret_val =
              `cd $vpn_dir && . $vars > /dev/null && $command $client 2>&1`;

            # Check exit status
            if ( $? >> 8 != 0 or $ret_val =~ /Error opening/g ) {
                return 'Revocation failure for ' . $client . ': ' . $ret_val;
            }
            if ( $ret_val =~ /ERROR:Already revoked/g ) {
                return 'Revocation failure for ' . $client
                  . ': Already revoked';
            }
            if ( $ret_val =~ /error 23.*certificate revoked\n/g ) {
                $ret_val = 'ok';
            }
        }
        else {
            die "Error revoking";
        }

        return $ret_val;
    }

    sub unrevoke_certificate : Private {
        my ( $self, $client ) = @_;
        my $ret_val;

		my $tools = $vpn_dir . '/' . $utils_dir;
        my $index_file = $tools . '/keys/index.txt';

        if ( -e $index_file and -w $index_file ) {

            # Change the revocation in the index.txt
            # ======================================
            my $command =
"/bin/sed -i 's/^R[[:space:]]*\\([a-zA-Z0-9]*\\)[[:space:]][a-zA-Z0-9]*[[:space:]]\\([0-9]*[[:space:]].*\\/CN=$client\\/.*\\)/V\\t\\1\\t\\t\\2/g' $index_file";

            # Run command
            my $ret_val = `$command`;

            # Check exit status
            if ( $? >> 8 != 0 ) {
                return 'Un-revocation failure for ' . $client . ': ' . $ret_val;
            }

            # Regenerate the crl.pem
            # ======================
            $command =
				'/usr/bin/openssl ca -gencrl -config ' . $ssl_config 
			  . ' -out ' . $tools . '/keys/crl.pem';

            # vars script location
            my $vars = $tools . '/vars';

			warn "EXECUTING:  cd $vpn_dir && . $vars >/dev/null && $command 2>&1";
            # Run command
            $ret_val = `cd $tools && . $vars >/dev/null && $command 2>&1`;

            # Check exit status
            if ( $? >> 8 != 0 ) {
                return
                    'Un-revocation failure for ' 
                  . $client
                  . ' while regenerating crl.pem: '
                  . $ret_val;
            }
            else {
                return 'Un-revocation success for ' . $client . ': ' . $ret_val;
            }
        }
        else {
            return 'Un-revocation success for ' . $client
              . ' as index file does not exists or is unaccessible';
        }
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

sub default : Private {
    my ( $self, $c ) = @_;
    $c->stash( { status => 'Control action not found' } );
    $c->response->status(404);
}

sub end : Private {
    my ( $self, $c ) = @_;

    # Close connection to management port
    $self->_disconnect_vpn;

    # Debug if requested
    die "forced debug" if $c->req->params->{dump_info};

    # Forward to JSON view
    $c->forward(
        ( $c->request->params->{xml} ? 'View::XML::Simple' : 'View::JSON' ) );
}

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
