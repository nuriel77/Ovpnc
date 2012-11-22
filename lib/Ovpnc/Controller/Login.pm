package Ovpnc::Controller::Login;
use Moose;
use namespace::autoclean;

BEGIN { extends 'CatalystX::SimpleLogin::Controller::Login'; }

=head1 NAME

Ovpnc::Controller::Login - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller, override login from CatalystX::SimpleLogin

=head1 METHODS

=cut

=head2 around 'login'

Modify the original 
login parameters
from CatalystX::SimpleLogin

=cut

around 'login' => sub {
	my ( $orig, $self, $c ) = @_;
	
	# Will load any js or css
    Ovpnc::Controller::Root->include_default_links($c);

    return $self->$orig($c);

};



=head1 AUTHOR

Nuriel Shem-Tov

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
