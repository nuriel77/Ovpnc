package Ovpnc::Controller::Api::Clients;
use Ovpnc::Plugins::Connector;
use Moose;
use namespace::autoclean;
use vars qw( $REGEX );

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config( namespace => 'api' );

with 'MooseX::Traits';
has '+_trait_namespace' => (
	# get the correct namespace.
	# To keep traits out of
	# the Controller directory.
	default => sub {
		my ($P, $SP) = __PACKAGE__ =~ /^(\w+)::(.*)$/;
		return $P . '::TraitFor::' . $SP;
	}
);

has vpn_dir => (
	is => 'rw',
	isa => 'Str',
	required => 0,
	predicate => '_has_vpn_dir'
);

has utils_dir => (
	is => 'rw',
	isa => 'Str',
	required => 0,
	predicate => '_has_utils_dir'
);

$REGEX = {
    client => {
		list => 'CLIENT_LIST,(.*?),(.*?),(.*?),([0-9]+),([0-9]+),(.*?),([0-9]+)$',
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
	is => 'rw',
	isa => 'Object',
	predicate => '_has_vpn',
	clearer => '_disconnect_vpn',
	required => 0
);

around [ qw( clients_UNREVOKE ) ] => sub {
	my ( $orig, $self, $c, $params ) = @_;
	$self->set_controller_params( $c );
	return $self->$orig($c, $params);
};

around [ qw(
		clients_REVOKE
		clients_REMOVE
		kill_connection
	)] => sub {
		my ( $orig, $self, $c, $params ) = @_;

		# Do not process twice
		if ( ref $c && ! $self->_has_vpn_dir ){
			$self->set_controller_params( $c );
		}

		# Also here, don't process twice
		return $self->$orig($c, $params)
			if $self->_has_vpn;

		# Instantiate connector
		$self->vpn (
			Ovpnc::Plugins::Connector->new({
				host     => $c->config->{host}     || '127.0.0.1',
	            port     => $c->config->{port}     || '7505',
	            timeout  => $c->config->{timeout}  || 5,
	            password => $c->config->{password} || '',
			})
		);

	    # Check connection to mgmt port
	    unless ( $self->vpn->connect ) {
	        $c->stash( { status => 'Server offline' } );
			$self->_disconnect_vpn if $self->_has_vpn;
	        $c->detach;
		}
		
		return $self->$orig($c, $params);
};


=head1 NAME

Ovpnc::Controller::Api::Clients - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 clients

For REST action class

=cut

sub clients : Local : ActionClass('REST') { }



=head2 get_clients

Gets all clients / users
of Ovpnc/OpenVPN

=cut

sub clients_GET : Local : Args(1) #Does('NeedsLogin') 
{
	my ( $self, $c, $cmd ) = @_;

	$self->status_ok(
        $c,
        entity => {
            foo  => 'is real bar-y',
        },
    );
}

=head2 clients_POST

Add new client(s)

=cut

sub clients_POST : Local : Args(0) Does('NeedsLogin') {
	my ( $self, $c ) = @_;
}

=head2 clients_UPDATE

Update client(s) data

=cut

sub clients_UPDATE : Local : Args(0) Does('NeedsLogin') {
	my ( $self, $c ) = @_;
}

=head2 clients_REMOVE

Delete client(s)

=cut

sub clients_REMOVE : Local : Args(0) Does('NeedsLogin') {
	my ( $self, $c ) = @_;
}

=head2

Revoke's client certificate
using crl.pem
Appends .disabled to client's
file in ccd

=cut

sub clients_REVOKE : Local  : Args(1) #Does('NeedsLogin')
{
    my ( $self, $c, $client ) = @_;

	# Verify that a client name was provided
	$self->_client_error($c) unless ( $client );

	# Trait names should match request method
	# (class names in ucfirst)
	my $role = $self->_get_roles( $c->request->method );

	my $_ret_val;

    # Revoke client's certificate
 	unless ( $c->request->params->{no_revoke} ){
		$_ret_val = $role->revoke_certificate( $client );
	}

	# If error from above don't proceed.
	if ( ! $_ret_val || ( ref $_ret_val && $_ret_val->{error} )){
		$c->stash( $_ret_val );
		$self->_disconnect_vpn if $self->_has_vpn;
		$c->detach;
	}

    # Kill the connection (just incase client is currently connected)
    if ( my $str = $self->kill_connection( $client ) ) {
		$_ret_val .= ';' . $str;
    } else {
        $_ret_val .= ';Client ' . $client . ' not found online';
    }

    $c->stash( { status => $_ret_val } );
	$self->_disconnect_vpn if $self->_has_vpn;
}


=head2

Unrevoke a client's certificate
and remove the appended
.disabled from the file
in ccd

=cut

sub clients_UNREVOKE : Path('unkill') Args(1) #Does('NeedsLogin') 
{
    my ( $self, $c, $client ) = @_;

	# Verify that a client name was provided
	$self->_client_error($c) unless ( $client );

	# Check if not aleady revoked
	my $revoked = $c->forward('list_revoked');
	unless ( $self->_match_revoked( $revoked, $client ) ){
		delete $c->stash->{status};
		delete $c->stash->{assets};
		$c->stash({ error => "Unrevoke faild: client is not the revoked list" });
	    $self->_disconnect_vpn if $self->_has_vpn;
	    $c->detach;
	}

	# Trait names should match request method
	my $role = $self->_get_roles( $c->request->method );

    # Unrevoke a revoked client's certificate
    my $_ret_val = $role->unrevoke_certificate(
		$client,
		$c->config->{openssl_conf},
		$c->config->{openssl_bin}
	);
    $c->stash( { status => $_ret_val } );
	$self->_disconnect_vpn if $self->_has_vpn;
}

=head2

Get revoked client list

=cut

sub list_revoked : Path('clients/list_revoked') : Args(0) #Does('NeedsLogin')
{
    my ( $self, $c ) = @_;

    my $crl_index = $c->config->{openvpn_dir} . '/'
					. $c->config->{openvpn_utils} . '/keys/index.txt';

    unless ( -r $crl_index ){
        $c->stash({
			error => 'Cannot read ' . $crl_index
			. ', file does not exists or is not readable' 
		});
		$self->_disconnect_vpn if $self->_has_vpn;
        $c->detach;
    }

    my $revoked_clients = $self->read_crl_index_file( $crl_index );

    if ( $revoked_clients and ref $revoked_clients eq 'ARRAY' and @{$revoked_clients} > 0 ){
        $c->stash( { status => $revoked_clients } );
    } else {
        $c->stash( { status => 'none' } );
    }
}


# Private methods
# ===============

=head2 Kill_connection

Kill a connection of a
given client/ip:port

=cut

sub kill_connection : Private 
{
    my ( $self, $connection ) = @_;
	die "No connection?!" unless $self->_has_vpn;
    my $ret_val = $self->vpn->kill( $connection );
    return $ret_val;
}


=head2 read_crl_index_file

This file generated by 
OpenVPN lists the certificates
and provides us information
who is revoked

=cut

sub read_crl_index_file : Private
{
    my ( $self, $crl_index ) = @_;
    my ($Y,$M,$D,$h,$m,$s);
    my $obj = [];

    open ( FH, "<", $crl_index )
        or die "Cannot read $crl_index: $!";

    while (my $line = <FH>){
        my ($revoke_time, $name) = $line =~ /$REGEX->{client}->{crl}/g;
        if ($revoke_time and $name){
            ($Y,$M,$D,$h,$m,$s) = $revoke_time =~ /(..)/g;
            my $kill_time =  $D.'-'.$M.'-'.($Y+2000) . ' ' . $h.':'.$m.':'.$s;
            push ( @{$obj}, { name => $name, kill_time => $kill_time } );
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
	if ( ref $revoked && $revoked->{status}
		&& $revoked->{status} ne 'none'
	){
		for ( @{$revoked->{status}} ){
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
		traits	=> [ ucfirst( lc(shift) ), @_ ],
		vpn_dir => $self->vpn_dir,
		utils_dir => $self->utils_dir
	);
}

=head2 _client_error

Detach not before stashing
the error message
and disconnect the mgmt port

=cut

sub _client_error : Private {
    my ( $self, $c ) = @_;
	$c->stash( { error => 'No client specified at clients_' . $c->request->method } );
	$self->_disconnect_vpn if $self->_has_vpn;
    $c->detach;
}


=head2 set_controller_params

Sets parameters
from config file
to be used in this controller

=cut

sub set_controller_params : Private {
	my ( $self, $c ) = @_;

	# Remove trailing /
   	$c->config->{openvpn_dir} =~ s/\/$//;
   	$c->config->{application_root} =~ s/\/$//;

	# Assign OpenVPN dir
    $self->vpn_dir ((
		$c->config->{openvpn_dir} || $c->config->{application_root} . '/openvpn'
	));
	$self->utils_dir( $self->vpn_dir . '/' . $c->config->{openvpn_utils} );
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

	# Disconnect if established
	$self->_disconnect_vpn if $self->_has_vpn;

	# Clean up the File::Assets
	# it is set to null but 
	# is not needed in JSON output
	delete $c->stash->{assets};

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
