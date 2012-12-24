package Ovpnc::Controller::Login;
use Ovpnc::Controller::Root 'include_default_links';
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
        # Prepend the user's salt to the password
        # =======================================
        my $salt = $self->_get_saved_salt($c, $user) || '';

        # Authenticate the user
        # =====================
        if ( 
             $c->authenticate(
                    {
                        username => $user,
                        password => $salt.$password
                    },
                    ( $c->req->params->{realm} || 'users' )
              )
        ) {
            $c->stash->{logged_in} = 1;
        }
    }

    return $self->$orig($c);
};


=head2 expire_cookies

Expire a list of cookies

=cut

    sub expire_cookies : Private {
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


=head2 _get_saved_salt

Get a salt for a user
to be prepended to password

=cut

    sub _get_saved_salt : Private {
        my ( $self, $c, $username ) = @_;
        my $user = $c->model('DB::User')
            ->search(
                { username => $username },
                { select   => 'salt' },
            );
        return $user->next->salt;
    }


=head2 end

Last auto action

=cut

    sub end : Private {
        my ( $self, $c ) = @_;

        if ( $c->user_exists ){

            # Generate a new session
            # ======================
            $c->config->{'Plugin::Session'}->{expires} = $c->config->{web_session_expires};
            my $new_sid = $c->change_session_id;
            $c->change_session_expires( $c->config->{web_session_expires} );
            $c->session->{logged_in} = 1;

            # Check if there is a last location/page
            # stored in a cookie, if yes, redirect.
            # ======================================
            if ( my $cookie = $c->request->cookies->{'Ovpnc_User_Settings'} ){
                my $cookie_data = $c->view('JSON')->from_json($cookie->value);
                if ( $cookie_data
                  && $cookie_data->{last_page} ne '/'
                ){
                    $c->log->debug("Got cookie last visited page, redirecting to: "
                        . $cookie_data->{last_page});
                    $c->redirect( $c->uri_for( $cookie_data->{last_page} ));
                    return;
                }
            }

            $c->res->redirect('/') if $c->check_user_roles('client');
        }

        $c->response->headers->header('Content-Type', 'text/html');
        include_default_links($self, $c);
        $c->forward('View::HTML');
    }    

=head1 AUTHOR

Nuriel Shem-Tov

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
