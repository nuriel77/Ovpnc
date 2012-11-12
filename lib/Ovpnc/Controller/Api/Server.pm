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
	$vpn_dir
/;


=head2 begin

default method, will start connection to mgmt port


=head2 status

get openvpn server status


=head2 view_log

get openvpn log


=head2 restart

restart openvpn

=head2 index

For REST action class

=cut


BEGIN { extends 'Catalyst::Controller::REST'; }

sub index :Chained('/') PathPart('api/server/') Args(0) :ActionClass('REST') { }

has 'host' => (
	isa => 'Str',
	is => 'rw',
	default => '127.0.0.1'
);

has 'port' => (
	isa => 'Str',
	is => 'rw',
	default => '7505'
);

has 'password' => (
	isa => 'Str',
	is => 'rw'
);

has 'timeout' => (
	isa => 'Int',
	is => 'rw',
	default => 5
);

has 'vpn' => (
	isa => 'Object',
	is => 'rw',
	predicate => '_has_vpn',
	clearer => '_disconnect_vpn',
);

$regex = {
	client_list => 'CLIENT_LIST,(.*?),(.*?),(.*?),([0-9]+),([0-9]+),(.*?),([0-9]+)$',
	log_line => '^([0-9]+),(.*)\n',
	verb_line => '^SUCCESS: verb=(\d+)\n',
};

sub begin :Private
{
    my ( $self, $c ) = @_;
	
	# Establish connection to management port
	$self->vpn(
		$self->mgt_connect({
			host => $c->config->{host} || '127.0.0.1',
			port => $c->config->{port} || '7505',
			timeout => $c->config->{timeout} || 5,
			password => $c->config->{password} || '',
		})
	);

	# Assign from config file
	$pid_file 		= $c->config->{openvpn_pid} 	|| '/var/run/openvpn.server.pid';
	$openvpn_bin 	= $c->config->{openvpn_bin} 	|| '/usr/sbin/openvpn';
	$openvpn_config = Ovpnc::Controller::Api::Config->get_openvpn_config_file( $c->config->{ovpnc_conf} ) || '/etc/openvpn/server.conf';
	$vpn_dir 		= $c->config->{openvpn_dir} 	|| '/var/www/vpn/2.0/';
}

{
	sub get_status :Path('status') Args(0)
	{	
		my ( $self, $c ) = @_;

		# Sanity check
		return if $c->forward('/api/sanity');
	
		# Check connection to mgmt port
		unless ( $self->vpn->connect ){
			$c->stash( { status => 'Server seems down' } );
			return;
		}
	
		# Get the current status table in version 2 format from the process.
		my $status = $self->vpn->status(2);
		
#		$c->log->debug(join ", ", @{$self->vpn->state()});	
	
		# If method returned false, return error message.
		unless ( $status ) {
			$c->stash ( { status => $self->vpn->{error_msg} } );
			return;
		}
	
		# Start assigning data for stashing 
		my $data = { clients => [] };
		$data->{verbosity} = $self->get_verbosity;
		$data->{title} = $self->vpn->version();

		# Parse the status output
		for my $line (@$status){
			chomp($line);
			if ($line =~ /$regex->{client_list}/){
				push ( @{$data->{clients}}, {
					name => $1 || 'anon',
					virtual_ip => $3 || 'unassigned',
					remote_port => (( split ':', $2 )[-1]) || 'unknown',
					remote_ip => (( split ':', $2 )[0]) || 'unknown',
					bytes_recv => $4 || 0,
					bytes_sent => $5 || 0,
					conn_since => $6 || '',
					epoc_since => $7 || ''
				});
			}
		}
		
		$c->stash( $data );
	}
	
	sub set_verb :Path('verb') Args(1)
	{
		my ( $self, $c, $level ) = @_;

		# Sanity check
		return if $c->forward('/api/sanity');

		unless ( $self->vpn->connect ){
			$c->stash( { status => 'Server seems down' } );
			return;
		}
		# Set the verbosity level
		$c->stash( { status => $self->set_verbosity($level) . ' Now at level: ' . $self->get_verbosity() } );
	}

	sub view_log :Path('log') Args(0)
	{
		my ( $self, $c ) = @_;
	
		# Sanity check
		return if $c->forward('/api/sanity');

		# Request params
		my $req = $c->request;

		# Check connected with mgmt port
		unless ( $self->vpn->connect ){
			$c->stash( { status => 'Server seems down' } );
			return;
		}
	
		# Get all or (n) lines of log
		my $_log = $self->vpn->log( $req->params->{lines} || 'all' );

		my $log_object;
		# Check if any log is returned (should be array_ref)
		if ( ref $_log eq 'ARRAY' ){
			# Read line by line
			for my $line ( @{$_log} ){
				# Get time and data
				my ($_time, $_data) = $line =~ /$regex->{log_line}/;
	
				# Convert epoc time to human if requested
				$_time = scalar localtime($_time)
					if ( $req->params->{time} );
	
				# Add log data to new array_ref
				push ( @{$log_object}, { $_time => $_data } );
			}
		}

		$c->stash( log => $log_object );
	}
	
	sub kill_client :Path('kill') Args(1)
	{
		my ( $self, $c, $client ) = @_;

		# Sanity check
		return if $c->forward('/api/sanity');

		# Check connection to mgmt port
		unless ( $self->vpn->connect ){
			$c->stash( { status => 'Server seems down' } );
			return;
		}
		
		# Revoke client's certificate
		my $ret_val = $self->revoke_certificate($client);

		# Kill the connection (just incase client is currently connected)
		if ( my $str = $self->kill_connection($client) ){
			$ret_val .= ';' . $str;
		}
		else {
			$ret_val .= ';Client ' . $client . ' not found online';
		}
		$c->stash( { status => $ret_val } );
	}
	
	sub unkill_client :Path('unkill') Args(1)
	{
		my ( $self, $c, $client ) = @_;

		# Sanity check	
		return if $c->forward('/api/sanity');

		# Unrevoke a revoked client's certificate
		my $ret_val = $self->unrevoke_certificate($client);
		$c->stash( { status => $ret_val } );
	}

	sub control_vpn :Path('control') Args(1)
	{
	    my ( $self, $c, $command ) = @_;

		# Sanity check	
		return if $c->forward('/api/sanity');
		
		# Dict of possible commands
		my $cmds = {
			start => sub { $self->start_vpn; },
			stop => sub { $self->stop_vpn },
			restart => sub { $self->restart_vpn },
		};
	
		my ($found_command, $ret_val);
		
		# Run the matched command (closure)
		for my $cmd (keys %{$cmds}){
			if ($cmd eq $command){
				$ret_val = $cmds->{$cmd}->();
				$found_command = 1;
			}
		}
	
		# If no command was matched
		unless ($found_command){
			$c->stash( { status => $command . ' is unrecognized' } );
			return;
		}
	
		# If return val is not a ref, stash for output
		unless ( ref $ret_val ){
			$c->stash( { status => $ret_val } );
		}
	}

}

# Private methods
# ===============
{

	sub mgt_connect :Private
	{
		my $c = shift;
		return Net::OpenVPN::Manage->new({ 
		         host => $c->{host},
		         port => $c->{port},
		         password => $c->{password},
		         timeout => $c->{timeout},
		});
	}

	sub get_verbosity :Private
	{
		my $self = shift;

		# Get verb level
		my $verb = $self->vpn->verb();

		# Parse the verb level
		$verb =~ s/$regex->{verb_line}/$1/;
		return $verb;
	}

	sub set_verbosity :Private
	{
		my ( $self, $level ) = @_;
		my $verb = $self->vpn->verb($level);
		return $verb;
	}

	sub kill_connection :Private
	{
		my ( $self, $connection ) = @_;
		my $ret_val = $self->vpn->kill($connection);
		return $ret_val;
	}

	sub revoke_certificate :Private
	{
		my ( $self, $client ) = @_;
		my $ret_val;

		# vars script location
		my $vars = $vpn_dir . 'vars';

		# build command
		my $command = $vpn_dir . 'revoke-full';

		# Check if can run
		if (-e $vpn_dir.'vars' and -e $command and -x $command){

			# Run command
			$ret_val = `cd $vpn_dir && . $vars > /dev/null && $command $client 2>&1`;

			# Check exit status
			if ( $? >> 8 != 0 or $ret_val =~ /Error opening/g ){
				return 'Revocation failure for ' . $client . ': ' . $ret_val;
			}
			if ( $ret_val =~ /ERROR:Already revoked/g){
				return 'Revocation failure for ' . $client . ': Already revoked';
			}
			if ( $ret_val =~ /error 23.*certificate revoked\n/g){
				$ret_val = 'ok';
			}
		}
		else {
			die "Error revoking";
		}

		return $ret_val;
	}

	sub unrevoke_certificate :Private
	{
		my ( $self, $client ) = @_;
		my $ret_val;
		my $index_file = $vpn_dir . 'keys/index.txt';
		if ( -e $index_file and -w $index_file ){

			# Change the revocation in the index.txt
			# ======================================
			my $command = "/bin/sed -i 's/^R[[:space:]]*\\([a-zA-Z0-9]*\\)[[:space:]][a-zA-Z0-9]*[[:space:]]\\([0-9]*[[:space:]].*\\/CN=$client\\/.*\\)/V\\t\\1\\t\\t\\2/g' $index_file";

			# Run command
			my $ret_val = `$command`;

			# Check exit status
			if ( $? >> 8 != 0 ){
		       return 'Un-revocation failure for ' . $client . ': ' . $ret_val;
		    }

			# Regenerate the crl.pem
			# ======================
			$command = '/usr/bin/openssl ca -gencrl -config openssl.cnf -out keys/crl.pem';
			# vars script location
			my $vars = $vpn_dir . 'vars';

			# Run command
			$ret_val = `cd $vpn_dir && . $vars >/dev/null && $command 2>&1`;

			# Check exit status
			if ( $? >> 8 != 0 ){
                return 'Un-revocation failure for ' . $client . ' while regenerating crl.pem: ' . $ret_val;
            }
            else {
                return 'Un-revocation success for ' . $client . ': ' . $ret_val;
            }
		}
		else {
			return 'Un-revocation success for ' . $client . ' as index file does not exists or is unaccessible';
		}
	}
}

{
	sub stop_vpn :Private
	{
		my $self = shift;
	
		if ( $self->vpn and $self->vpn->connect() ){
			# send SIGINT signal to daemon
			$self->vpn->signal('SIGINT');

			# If can still connect try killing
		    if ( $self->vpn->connect() ){
				# Get openvpn last pid
	            my $pid = read_file $pid_file;
	            chomp($pid);
				# Try to kill
				kill 9, $pid or return "Cannot kill OpenVPN with pid " . $pid;;
				if ( $self->vpn->connect() ){
			    	return "OpenVPN did not turn off with pid " . $pid;
				}
		    }
			else {
				return "OpenVPN is stopped";
			}
		}
		else {
			return "OpenVPN is already stopped";
		}
	}
	
	sub start_vpn :Private
	{
		my $self = shift;
	
		# Check connected or not to mgmt port
		if ( $self->vpn and $self->vpn->connect() ){
			return 'Server already started';
		}
		else {
			# Build command
			my $command = 'sudo ' . $openvpn_bin
		        . ' --writepid ' . $pid_file
		        . ' --daemon ovpn-server'
				. ' --script-security 2'
		        . ' --cd /etc/openvpn'
		        . ' --config ' . $openvpn_config;
		
			# Run command
		    my $output = `$command`;
		
			# Check exit staatus
		    if ( $? >> 8 != 0 ){
		        return "An error occured starting server with code " . ( $? >> 8 ) . ": " . $output;
		    }
		    else {
				# Get pid number
		        if ( -e $pid_file and -r $pid_file ){
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
		
	sub restart_vpn :Private
	{
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

sub default :Private
{
    my ($self, $c) = @_;
    $c->stash( { status => 'Control action not found' } );
    $c->response->status(404);
}

sub end :Private
{
    my ($self, $c) = @_;

    # Close connection to management port
    $self->_disconnect_vpn;

    # Debug if requested
    die "forced debug" if $c->req->params->{dump_info};

    # Forward to JSON view
	$c->forward( ( $c->request->params->{xml} ? 'View::XML::Simple' : 'View::JSON' ) );
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
