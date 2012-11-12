package Ovpnc::View::JSON;

use strict;
use Moose;
use JSON::XS();

extends 'Catalyst::View::JSON';

my $encoder = JSON::XS->new->utf8->pretty( 1 )->indent( 1 )->allow_nonref( 1 );

sub encode_json 
{
	my( $self, $c, $data ) = @_;
	$encoder->encode( $data );
}

sub to_json
{
	my( $self, $c, $data ) = @_;
	$encoder->encode( $data );
}

=head1 NAME 

Ovpnc::View::JSON - Catalyst JSON View

=head1 SYNOPSIS

See L<Ovpnc>

=head1 DESCRIPTION

Catalyst JSON View.

=head1 AUTHOR

Nuriel Shem-Tov

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
