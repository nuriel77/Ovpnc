package Ovpnc::Controller::Api;
use warnings;
use strict;
use Ovpnc::Plugins::Connector;
use Moose;
use Linux::Distribution;
use Cwd;
use vars qw( $ovpnc_conf $mgmt_passwd_file );
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config( namespace => '' );

=head1 NAME

Ovpnc::Controller::Api - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller

OpenVPN Controller API


has cfg => (
    is => 'rw',
    isa => 'HashRef',
    predicate => '_has_cfg',
);

before 'api' => sub {
    my ( $self, $c ) = @_;

    # Authenticate user if
    # password/username exists
    # ========================
    $self->auth_user( $c )
        unless $c->user_exists();
};

=head1 METHODS


=head2 api

For REST action class

=cut

sub api : Local : Args(0) : ActionClass('REST') {
}

=head2 api_GET

Api Usage

=cut

sub api_GET : Local
            : Args(0)
            : Sitemap
            : Does('ACL') AllowedRole('admin') AllowedRole('client') ACLDetachTo('denied')
            : Does('NeedsLogin')
{
    my ( $self, $c ) = @_;

    $self->status_ok($c, entity =>
        { status => 'Here usage information for the API will be displayed' }
    );

    delete $c->stash->{assets} if $c->stash->{assets};
    $c->forward('View::JSON');

}

=head2 api_POST

General api commands

=cut

sub api_POST : Local
             : Args(0)
             : Sitemap
             : Does('ACL') AllowedRole('admin') AllowedRole('client') ACLDetachTo('denied')
             : Does('NeedsLogin')
{
    my ( $self, $c, $cmd ) = @_;
    my $_check = 0;

    $_check++ && $self->status_ok($c, entity => { status => 'Session ended' })
        if $c->req->params->{end_session} or $cmd eq 'end_session';

    $self->status_bad_request($c, message => "Unknown command"
        . ( $cmd ? " '" . $cmd . "'" : '' ) )
            if $_check == 0;

    delete $c->stash->{assets} if $c->stash->{assets};
    $c->response->headers->header('Content-Type' => 'application/json');
    $c->forward('View::JSON');
}


=head2 sanity

A sanity check

=cut

sub sanity : Path('api/sanity')
           : Args(0)
           : Sitemap
           : Does('NeedsLogin')
{

    my ( $self, $c ) = @_;

    $c->response->headers->header(
        'Content-Type' => 'application/json' );

    if ( !$self->_has_cfg ){
        $self->assign_params( $c );
    }

    # Sanity plugin action
    # ====================
    my $_ret_val = Ovpnc::Plugins::Sanity->action( $c->config );

    # Not ok?
    # =======
    if ( $_ret_val && ref $_ret_val eq 'ARRAY' ) {
        $c->response->status(500);
        delete $c->stash->{assets} if $c->stash->{assets};
        $c->response->body( $_ret_val );
        $c->detach;
        return $_ret_val;
    }

    # Ok
    # ==
    if ( $c->request->path =~ /sanity/ ){
        delete $c->stash->{assets} if $c->stash->{assets};
        $c->response->status(200);
        $c->stash->{status} = 'Sanity check successful';
    }

    $c->forward('View::JSON');

}

=head2 detach_error

End action chain
and return error
message to user

=cut

sub detach_error : Private {
    my ( $self, $c, $err_msg ) = @_;
    $c->response->status(500);
    delete $c->stash->{assets};
    $c->stash->{rest} =
      { error => $err_msg ? $err_msg : "An unknown error has occurred" };
    $c->detach;
}

=head2 assign_params

Assign config params
and return as hashref

=cut

sub assign_params : Private {
    my ( $self, $c ) = @_;

    my $cfg = $c->config;

    # Remove trailing / if any
    # ========================
    for (
        $cfg->{openvpn_dir},
        $cfg->{home},
        $cfg->{openvpn_ccd},
        $cfg->{openvpn_utils},
    ){ s/\/$// if $_ }

    # Assing configurations params
    # be made accessible via
    # private methods as well
    # ============================

    # Openvpn management passwd file
    # ==============================
    $mgmt_passwd_file = $c->config->{mgmt_passwd_file} =~ /^\//
        ? $c->config->{mgmt_passwd_file}
        : $c->config->{home} . '/' . $c->config->{mgmt_passwd_file};

    # Check build if ovpnc_conf
    # =========================
    $ovpnc_conf = $c->config->{ovpnc_conf} =~ /^\//
        ? $c->config->{ovpnc_conf}
        : $c->config->{home} . '/' . $c->config->{ovpnc_conf};

    # OpenVPN Dir
    # ===========
    $cfg->{openvpn_dir} = $cfg->{home} . '/' . $cfg->{openvpn_dir}
        if $cfg->{openvpn_dir} !~ /^\//;

    # OpenVPN pid file
    # ================
    $cfg->{openvpn_pid} = $cfg->{openvpn_dir} . '/' . $cfg->{openvpn_pid}
        if (  $cfg->{openvpn_pid} !~ /^\// );

    # Get OpenVPN username
    # ====================
    my ($_openvpn_user, $_openvpn_group ) = @{(
        Ovpnc::Controller::Api::Configuration->get_openvpn_param(
            $ovpnc_conf, [ 'UserName', 'GroupName' ]
        )
    )};
    $c->config->{openvpn_user} = $_openvpn_user;

    my $_cfg = {

        # Paths beginning with '/'
        # will be considered full-paths
        # =============================

        # User and Group name
        # ===================
        openvpn_group => $_openvpn_group,
        openvpn_user => $_openvpn_user,

        # The ovpnc application root
        # ==========================
        home => $cfg->{home} // getcwd,

        # Ovpnc temporary directory
        # =========================
        tmp_dir     => $cfg->{openvpn_dir} . '/tmp/',

        # OpenVPN pid file
        # ================
        openvpn_pid => $cfg->{openvpn_pid},

        # OpenVPN client's dir
        # ====================
        openvpn_ccd => ( $cfg->{openvpn_ccd} =~ /^\//
            ? $cfg->{openvpn_ccd}
            : $cfg->{openvpn_dir} . '/' . $cfg->{openvpn_ccd}
        ),

        # OpenVPN config dir
        # ==================
        openvpn_conf_dir => ( $cfg->{openvpn_conf_dir} =~ /^\//
            ? $cfg->{openvpn_conf_dir}
            : $cfg->{openvpn_dir} . '/conf'
        ),

        # OpenVPN Binary
        # ==============
        openvpn_bin => $cfg->{openvpn_bin} // '/usr/sbin/openvpn',

        # OpenVPN config
        # ==============
        openvpn_config =>
            Ovpnc::Controller::Api::Configuration->get_openvpn_config_file(
            $ovpnc_conf
        ),

        # OpenVPN main directory
        # ======================
        openvpn_dir => $cfg->{openvpn_dir},

        # OpenVPN tools/utilities directory
        # (scripts for CA, Certificates etc)
        # ==================================
        openvpn_utils => ( $cfg->{openvpn_utils} =~ /^\//
            ? $cfg->{openvpn_utils}
            : $cfg->{openvpn_dir}
              . '/' . $cfg->{openvpn_utils}
        ),

        # OpenSSL config
        # ==============
        ssl_config => ( $cfg->{openssl_conf} =~ /^\//
            ? $cfg->{openssl_conf}
            : $cfg->{openvpn_dir} . '/' . $cfg->{openssl_conf}
        ),

        # Ovpnc Schema XSD
        # ================
        ovpnc_config_schema => ( $c->config->{ovpnc_config_schema} =~ /^\//
            ? $c->config->{ovpnc_config_schema}
            : $cfg->{home} . '/' . $c->config->{ovpnc_config_schema}
        ),

        # OpenSSL binary
        # ==============
        ssl_bin => $cfg->{openssl_bin},

        # Ovpnc XML OpenVPN conf file
        # ===========================
        ovpnc_conf => $ovpnc_conf,

        # OpenVPN Management password
        # ===========================
        mgmt_passwd_file => $cfg->{mgmt_passwd_file} =~ /^\//
            ? $cfg->{mgmt_passwd_file}
            : $cfg->{home} . '/' . $cfg->{mgmt_passwd_file},

        # OpenVPN Management console
        # ==========================
        mgmt_params => {
            host    => $cfg->{mgmt_host}    // '127.0.0.1',
            port    => $cfg->{mgmt_port}    // 7505,
            timeout => $cfg->{mgmt_timeout} // 5,
            password => $mgmt_passwd_file   // '',
        }
    };

    return $_cfg;
}


=head2 auth_user

API Authentication

=cut

sub auth_user : Private
{
    my ( $self, $c ) = @_;

    if ( my $user        = $c->req->params->{username}
        and my $password = $c->req->params->{password}
        and ! $c->user_exists
    ){
        if ( $c->authenticate( { username => $user,
                                 password => $password }, 'users' )
        ) {
            delete $c->req->params->{$_} for qw/username password/;
            $c->stash->{expires} = $c->session_expires;
            $c->session->{$user} = $c->session_expires;
        }
        else {
            $c->stash->{error} = 'Invalid username / password combination' ;
        }
    }
    $c->stash->{error} = 'Session expired' if $c->request->params->{_} && !$c->user_exists;
}

=head2 end

Auto end action

=cut 

sub end : Private {
    my ( $self, $c ) = @_;

    # Clean up the File::Assets
    # it is set to null but
    # is not needed in JSON output
    # ============================
    delete $c->stash->{assets};

    # Forward to JSON view or XML
    # ===========================
    $c->forward(
        ( $c->request->params->{xml} ?
        'View::XML::Simple' : 'View::JSON' )
    );
}

=head1 AUTHOR

Nuriel Shem-Tov

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
