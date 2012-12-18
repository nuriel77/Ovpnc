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
    # Redirect to https if user specified
    # a port in config under 'redirect_https_port'
    # ============================================
    if ( $c->config->{redirect_https_port} && !$c->req->secure ) {
        $c->redirect( 'https://'
              . $c->req->uri->host . ':'
              . $c->config->{redirect_https_port} . '/'
              . $c->req->path );
    }

    # Display warning if user is not
    # forcing https on login page
    # ==============================
    unless ( $c->req->secure ) {
        $c->stash->{warning} =
            "Warning: It is recommended to serve this page under HTTPS."
          . " Check the configuration manual on how to set this up.";
    }

    $c->stash->{logged_in} = $c->user_exists ? 1 : 0;
    $c->response->headers->header('Content-Type', 'text/html');
    Ovpnc::Controller::Root->include_default_links($c);
    $c->forward('View::HTML');
    return $self->$orig($c);
};

sub remove_cookies : Private {
    my ( $self, $c, $cookies ) = @_;

    for ( @{$cookies} ) {
        $c->log->debug("Removing cookie $_");
        $c->response->cookies->{$_} = {
            value   => '',
            expires => '-1d',
          }
          if $c->request->cookies->{$_};
    }
}

=head1 AUTHOR

Nuriel Shem-Tov

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
