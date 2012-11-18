package Ovpnc::Controller::Static;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

Ovpnc::Controller::Static - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Ovpnc::Controller::Static in Static.');
}

=head2 Default Method

Server static on /static path

=cut

sub default : Path('/static') {
    my ( $self, $c ) = @_;

    # Optional, allow the browser to cache the content
    $c->res->headers->header( 'Cache-Control' => 'max-age=86400' );

    if ( $c->req->path =~ /css$/i ) {
        $c->serve_static("text/css");
    }
    else {
        $c->serve_static;
    }
}

# also handle requests for /favicon.ico
sub favicon : Path('/favicon.ico') {
    my ( $self, $c ) = @_;
    $c->res->content_type("image/x-icon");
    $c->serve_static("image/x-icon");
}

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
