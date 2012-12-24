package Ovpnc::View::JSON;
use warnings;
use strict;
use Moose;
use JSON::XS();

extends 'Catalyst::View::JSON';

has 'encoder' => (
	isa => 'Object',
	lazy => 1,
	is => 'ro',
	default => sub {
		return JSON::XS
				->new
				->utf8
				->pretty(1)
				->indent(1)
				->allow_nonref(1)
				->allow_blessed(1)
				->convert_blessed(1)
	}
);

sub encode_json 
{
	my( $self, $c, $data ) = @_;

    # Remove default assets
    # is only used in HTML view
    # =========================
    delete $c->stash->{assets} if $c->stash->{assets};

    $c->response->headers->header('Content-Type' => 'application/json');

    # Return JSON
    # ===========
	return $self->encoder->encode( $data );
}

sub to_json
{
	my( $self, $c, $data ) = @_;
	return $self->encoder->encode( $data );
}

sub from_json
{
    my( $self, $data ) = @_;
    $self->encoder->decode( $data );
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
