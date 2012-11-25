package Ovpnc::TraitFor::Controller::Api::Server::Control;
use Moose::Role;
use namespace::autoclean;

has vpn => (
	is => 'ro',
	isa => 'Object',
	required => 1,
    predicate => '_has_vpn',
    clearer   => '_disconnect_vpn',
);

sub test_server {
	die @_;
	return "This is role test";
}

1;
