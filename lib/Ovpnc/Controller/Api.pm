package Ovpnc::Controller::Api;
use warnings;
use strict;
use Ovpnc::Plugins::Connector;
use Moose;
use File::Slurp;
use Cwd;
use vars qw/$status/;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config( namespace => 'api' );

=head1 NAME

Ovpnc::Controller::Api - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller

OpenVPN Controller API


=head1 METHODS

=head2 base

For chain to login page

=cut

sub base : Chained('/base') PathPrefix CaptureArgs(0) {
}

=head2 index

For REST action class

=cut

sub index : Chained('/') PathPart('api/') Args(0) : ActionClass('REST') {
}


=head2 sanity

A sanity check

=cut

sub sanity : Chained('base') : PathPart('sanity') : Args(0) : Does('NeedsLogin')
{

    my ( $self, $c ) = @_;
    my $sanity = Ovpnc::Controller::Sanity->new(
        ovpnc_user   => $c->config->{ovpnc_user}   || 'ovpnc',
        os           => $c->config->{os}           || 'linux',
        dist         => $c->config->{dist}         || '/etc/debian_version',
        openvpn_user => $c->config->{openvpn_user} || 'openvpn',
    );

    my $ret_val = $sanity->action( $c->config );

    if ( ref $ret_val eq 'ARRAY' ) {
        $c->response->status(500);
        $c->stash( { status => $ret_val } );
        return $ret_val;
    }

    $c->stash( { status => 'Sanity check successful' } )
      if ( $c->request->path =~ /sanity/ );
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
        $cfg->{app_root},
        $cfg->{openvpn_ccd},
        $cfg->{openvpn_utils},
    ){ s/\/$// if $_ }

    # Assing configurations params
    # be made accessible via
    # private methods as well
    # ============================

    # OpenVPN pid file
    # ================
    $cfg->{openvpn_pid} ||= $cfg->{app_root}
        . '/openpvpn/var/run/openvpn.server.pid';

    $cfg->{openvpn_pid} = $cfg->{app_root} . '/' . $cfg->{openvpn_pid}
        if (  $cfg->{openvpn_pid} !~ /^\// );

    return {

        # Paths beginning with '/'
        # will be considered full-paths
        # =============================

        # User and Group name
        # ===================
        openvpn_group => Ovpnc::Controller::Api::Configuration->get_openvpn_param(
                $c->config->{ovpnc_conf}, 'GroupName'
        ),

        openvpn_user => Ovpnc::Controller::Api::Configuration->get_openvpn_param(
                $c->config->{ovpnc_conf}, 'UserName'
        ),

        # The ovpnc application root
        # ==========================
        app_root => $cfg->{app_root} // getcwd,

        # Ovpnc temporary directory
        # =========================
        tmp_dir     => $cfg->{app_root}
                        . '/' . $cfg->{openvpn_utils} . '/tmp/',

        # OpenVPN pid file
        # ================
        openvpn_pid => $cfg->{openvpn_pid},

        # OpenVPN client's dir
        # ====================
        openvpn_ccd => ( $cfg->{openvpn_ccd} =~ /^\//
            ? $cfg->{openvpn_ccd}
            : $cfg->{openvpn_dir} . '/' . $cfg->{openvpn_ccd}
        ),

        # OpenVPN Binary
        # ==============
        openvpn_bin => $cfg->{openvpn_bin} // '/usr/sbin/openvpn',

        # OpenVPN config
        # ==============
        openvpn_config =>
          Ovpnc::Controller::Api::Configuration->get_openvpn_config_file(
            $cfg->{ovpnc_conf}
          ) // $cfg->{app_root}
          . '/openvpn/conf/openvpn.ovpnc.conf',

        # OpenVPN main directory
        # ======================
        openvpn_dir => ( $c->config->{openvpn_dir} =~ /^\//
            ? $cfg->{openvpn_dir}
            : $cfg->{app_root} . '/' . $cfg->{openvpn_dir}
        ),

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
            : $cfg->{openvpn_dir} . '/'
                . $cfg->{openvpn_utils} . '/' . $cfg->{openssl_conf}
        ),

        # OpenSSL binary
        # ==============
        ssl_bin => $cfg->{openssl_bin},

        # OpenVPN Management console
        # ==========================
        mgmt_params => {
            host    => $cfg->{mgmt_host}    // '127.0.0.1',
            port    => $cfg->{mgmt_port}    // '7505',
            timeout => $cfg->{mgmt_timeout} // 5,
            password => read_file( $cfg->{mgmt_passwd_file}, chomp => 1 )
              // '',
        }
    };
}

sub end : Private {
    my ( $self, $c ) = @_;

    # Debug if requested
    die "forced debug" if $c->req->params->{dump_info};

    # Clean up the File::Assets
    # it is set to null but
    # is not needed in JSON output
    delete $c->stash->{assets};

    # Forward to JSON view or XML
    $c->forward(
        ( $c->request->params->{xml} ? 'View::XML::Simple' : 'View::JSON' ) );
}

=head1 AUTHOR

Nuriel Shem-Tov

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
