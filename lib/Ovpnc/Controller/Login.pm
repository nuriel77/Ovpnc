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

    # Authenticate user if
    # username/password
    # have been provided
    # ====================
    if ( my $user        = $c->req->params->{username}
        and my $password = $c->req->params->{password}
        and ! $c->user_exists
        and ! $c->req->params->{_}
    ){
        if ( $c->authenticate( { username => $user,
                                 password => $password }, 'users' )
        ) {
            $c->stash->{logged_in} = 1;
            $c->change_session_id;
            $c->change_session_expires( $c->config->{web_session_expires} )
                if $c->user_exists;
        } else {
            $c->stash->{logged_in} = 0;
        }
    }
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
