package Ovpnc::TraitFor::Controller::Api::Certificates::BuildTA;
use warnings;
use strict;
use IPC::Cmd qw( can_run run );
use Digest::MD5::File 'file_md5_hex';
use Moose::Role;

=head1 NAME

Ovpnc::TraitFor::Controller::Api::Certificates::BuildTA - Ovpnc Controller Trait

=head1 DESCRIPTION

Ovpnc Certificates BuildTA ta.key Trait

=head1 METHODS

=cut

=head2 build_ta

Generate a new ta.key file

=cut


sub build_ta
{
    my $self = shift;

    my $ovpnc_conf = $self->_cfg->{ovpnc_conf} =~ /^\//
        ? $self->_cfg->{ovpnc_conf}
        : $self->_cfg->{home} . '/' . $self->_cfg->{ovpnc_conf};

    # OpenVPN tools directory
    # =======================
    my $_tools_dir = $self->_cfg->{openvpn_utils};

    # The DH file to process
    # ======================
    my $_ta_key =
        Ovpnc::Controller::Api::Configuration
            ->get_openvpn_param( 'TlsKey', $ovpnc_conf );

    $_ta_key = $self->_cfg->{home} . '/' . $_ta_key
        unless $_ta_key =~ /^\//;

    # Confirm writable if exists
    # ===========================
    if ( -e $_ta_key && ! -w $_ta_key ) {
        return { error => $_ta_key . ' is not writable' };
    }

    # Get current digest if file exists
    # =================================
    my $_digest = $self->_verify_new( $_ta_key );

    # Verify the openssl binary
    # =========================
    my ( $_bin, $_cfg_bin );

    return { error => 'Cannot run openvpn binary!' }
       unless ( $_bin = can_run( $self->_cfg->{openvpn_bin} ) );

    # Prepare command
    # ===============
    my $_cmd = [
        $self->_cfg->{openvpn_bin},
        '--genkey',
        '--secret',
        $_ta_key,
    ];

    # Run command
    # ===========
    my ($success, $error_code, $full_buf, $stdout_buf, $stderr_buf) =
        run( command => $_cmd, verbose => 0, timeout => 4 );

    my $_out = join( "\n", @{$full_buf} );

    if ( $success ){
        # Check if a new file has
        # been created, compare to older
        # digest if any was existing.
        # ==============================
        my $_new_digest = $self->_verify_created(
            $_ta_key, ($_digest ? $_digest : undef)
        );
        # Not ok?
        # =======
        return { error => $_ta_key . ' was not created: ' . $_out }
            unless $_new_digest;

        # Chown & Chmod
        # =============
        chown $<, $<, $_ta_key
            or $_out .= ';Warning! Could not chown ' . $< . ':' . $< . ' ' . $_ta_key . ': ' . $!;

        chmod 0400, $_ta_key
            or $_out .= ';Warning! Could not chmod 0640 ' . $_ta_key . ': ' . $!;

        # Ok
        # ==
        return  {
            status => {
                file     => $_ta_key,
                digest   => $_new_digest,
            }
        }
    }
    else {
        return { error => $_out . ';'
            . ( $error_code ? $error_code : '' )
        };
    }

}


1;
