package Ovpnc::Controller::Api::Clients;
use Ovpnc::Plugins::Connector;
use Moose;
use namespace::autoclean;

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

around [ qw(
		clients_REVOKE
		clients_REMOVE
		kill_connection
	)] => sub {
		my ( $orig, $self, $c, $params ) = @_;

		# Do not process twice
		if ( ref $c && ! $self->_has_vpn_dir ){
			# Remove trailing /
		   	$c->config->{openvpn_dir} =~ s/\/$//;
		   	$c->config->{application_root} =~ s/\/$//;
			# Assign OpenVPN dir
		    $self->vpn_dir ((
				$c->config->{openvpn_dir} || $c->config->{application_root} . '/openvpn'
			));
			$self->utils_dir( $self->vpn_dir . '/' . $c->config->{openvpn_utils} );
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

sub clients_GET : Local : Args(0) #Does('NeedsLogin') 
{
	my ( $self, $c ) = @_;

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

	# Verify that client name was provided
    unless ($client) {
        $c->stash( { error => 'No client specified at clients_REVOKE' } );
		$self->_disconnect_vpn if $self->_has_vpn;
        $c->detach;
    }

	# Trait names should match request method
	# (class names in ucfirst)
	my $role = $self->new_with_traits(
		traits	=> [ ucfirst( lc($c->request->method) ) ],
		vpn_dir => $self->vpn_dir,
		utils_dir => $self->utils_dir
	);

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


sub kill_connection : Private {
    my ( $self, $connection ) = @_;
	die "No connection?!" unless $self->_has_vpn;
    my $ret_val = $self->vpn->kill( $connection );
    return $ret_val;
}


=head2 default

Default action, not found

=cut

sub default : Private {
    my ( $self, $c ) = @_;
    $c->stash( { status => 'Control action not found' } );
    $c->response->status(404);
}

sub end : Private {
    my ( $self, $c ) = @_;

    # Debug if requested
    die "forced debug" if $c->req->params->{dump_info};

	# Disconnect if established
	$self->_disconnect_vpn if $self->_has_vpn;

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
