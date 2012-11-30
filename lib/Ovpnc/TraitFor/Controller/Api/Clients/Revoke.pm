package Ovpnc::TraitFor::Controller::Api::Clients::Revoke;
use warnings;
use strict;
use IPC::Cmd qw( can_run run );
use Moose::Role;
use namespace::autoclean;
use vars qw( $openvpn_dir $tools $vars );
use constant TIMEOUT    => 5;

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

    # Vars script location
    # ====================
    $vars = $tools . '/vars';

    # Build command
    # =============
    my @_cmd = ( $tools . '/revoke-full', $client );

    # Check if can run
    # ===============
    if ( can_run( $tools . '/revoke-full' ) ){

        # Run command
        # ===========
        my ($success, $error_code, $full_buf, $stdout_buf, $stderr_buf) =
            run( command => [ @_cmd ], verbose => 0, timeout => TIMEOUT );

        $_ret_val = join( "\n", @{$full_buf} );
        $_ret_val =~ s/\n/;/g;

        if ( $success ){
            # Explicit ERROR in output
            # ========================
            if ( $_ret_val =~ /ERROR:(.*)$/g ) {
                return {error => "Revocation failure for '"
                      . $client
                      . ( $1 ? ': ' . $1 : '' )
                };
            }
            # If we match this, certificate
            # has been revoked successfully
            # =============================
            elsif ( $_ret_val =~ /error 23.*certificate revoked/g ) {
                return 'Ok';
            }
            # Anything else is unknown
            # ========================
            else {
                return {error => "Unknown revocation status for '"
                      . $client
                      . ( $_ret_val ? ': ' . $_ret_val : '' )
                };
            }

        }
        # Could be a timeout (if yes, it will
        # appear in the error_code)
        # ===================================
        else {
            return {error => $_ret_val . ';'
                . ( $error_code ? $error_code : '' )
            };
        }
    }
    else {
        die "Error revoking client " . $client
            . ", cannot run " . $tools . '/revoke-full';
    }

    return $_ret_val;
}

1;
