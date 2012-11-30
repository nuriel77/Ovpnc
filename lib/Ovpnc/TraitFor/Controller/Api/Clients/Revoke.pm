package Ovpnc::TraitFor::Controller::Api::Clients::Revoke;
use warnings;
use strict;
use Moose::Role;
use namespace::autoclean;
use vars qw( $openvpn_dir $tools $vars );

has openvpn_dir => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has openvpn_utils => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has app_root => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

sub revoke_certificate {
    my ( $self, $client ) = @_;

    my $_ret_val;

    $openvpn_dir =
        $self->openvpn_dir =~ /^\//
      ? $self->openvpn_dir
      : $self->app_root . '/' . $self->openvpn_dir;

    $tools =
        $self->openvpn_utils =~ /^\//
      ? $self->openvpn_utils
      : $openvpn_dir . '/' . $self->openvpn_utils;

    # TODO: Get vars from certificates trait
    # Use IPC::Cmd

    # Vars script location
    # ====================
    $vars = $tools . '/vars';

    # Build command
    # =============
    my $command = $tools . '/revoke-full';

    # Check if can run
    # ===============
    if ( -e $vars and -e $command and -x $command ) {

        # Run command
        # ===========
        $_ret_val = `cd $tools && . $vars > /dev/null && $command $client 2>&1`;

        # Check exit status
        # =================
        if ( $? >> 8 != 0 or $_ret_val =~ /Error opening/g ) {
            return {error => "Revocation failure for '"
                  . $client . "': "
                  . $_ret_val };
        }

        if ( $_ret_val =~ /ERROR:Already revoked/g ) {
            return {error => "Revocation failure for '"
                  . $client
                  . "': Already revoked" };
        }

        if ( $_ret_val =~ /error 23.*certificate revoked\n/g ) {
            $_ret_val = 'Ok';
        }
    }
    else {
        die "Error revoking client " . $client;
    }

    return $_ret_val;
}

1;
