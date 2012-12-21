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

    # Verify the request headers
    # some controllers will end
    # up here when user requested XML
    # ===============================
    if ( $c->req->headers->{'accept'} !~ /json/gi ){
        if ( $c->req->headers->{'accept'} =~ /html/gi ){
            $c->response->headers->header('Content-Type' => 'text/html' );
            Ovpnc::Controller::Root->include_default_links( $c );
            $c->forward('View::HTML');
        }
        elsif ( $c->req->headers->{'accept'} =~ /[text|application]\/xml/gi ){
            $c->response->headers->header('Content-Type' => $c->req->headers->{'accept'} );
            $c->forward('View::XML::Simple');
        }
        $c->detach;
        return;
    }

    $c->response->headers->header('Content-Type' => 'application/json');

    # Return JSON
    # ===========
	$self->encoder->encode( $data );
}

sub to_json
{
	my( $self, $c, $data ) = @_;
	$self->encoder->encode( $data );
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
