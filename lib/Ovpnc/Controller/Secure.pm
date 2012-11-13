package Ovpnc::Controller::Secure;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller::REST'; }

sub setup : Chained('/login/required') PathPart('') CaptureArgs(1) {
	my ( $self, $c, $id ) = @_;
    
	# setup actions for authenticated-user-only access
    $c->stash->{id} = $id;
}

sub something_secure : Chained('setup') PathPart Args(0) {
    my ( $self, $c ) = @_;
    # only authenticated users will have access to this action
}

sub open_to_all : Chained('/login/not_required') PathPart Args(0) {
    my ( $self, $c ) = @_;
    # this is available to everyone
}

1;
