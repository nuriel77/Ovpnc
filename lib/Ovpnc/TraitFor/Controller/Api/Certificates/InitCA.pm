package Ovpnc::TraitFor::Controller::Api::Certificates::InitCA;
use warnings;
use strict;
use File::Copy;
use Digest::MD5::File 'file_md5_hex';
use Ovpnc::Plugins::ChainCA;
use Moose::Role;

=head1 NAME

Ovpnc::TraitFor::Controller::Api::Certificates::InitCA - Ovpnc Controller Trait

=head1 DESCRIPTION

Ovpnc Certificates Root CA

=head1 METHODS

=cut

=head2 init_ca

Generate new key,
generate new certificate

=cut

sub init_ca {
    my $self = shift;
    my $ca = Ovpnc::Plugins::ChainCA->new;
    my $priv_key = $ca->gen_private_key;
    my $cert = $ca->gen_certificate( $priv_key );

    # Get the filename of the CA cert
    # ===============================
    my $ca_cert_file = Ovpnc::Controller::Api::Configuration->get_openvpn_param(
        $self->_cfg->{ovpnc_conf}, 'Ca' );

    # Auto-append key for the key filename
    # ====================================
    my $ca_key_file = $ca_cert_file;
    if ( $ca_key_file =~ /cert|crt/i ){
        $ca_key_file =~ s/cert|crt/key/gi
    } else {
        $ca_key_file .= '.key';
    }

    # Determine the keys dir according
    # to the extracted path from the cert
    # ===================================
    my ($_keys_dir) = $ca_cert_file =~ /^(.*)\/.*$/;

    # Get the group/user
    # ==================
    my (undef, undef, undef, $gid) = getpwnam( $self->_cfg->{openvpn_group} );
    my (undef, undef, $uid) = getpwuid( $< );

    # Generate new serial file and index.txt
    # ======================================
    unless ( $self->_write_to_file({
        serial => {
            data => "01\n",
            file => $_keys_dir . '/serial',
            mode => 0660,
            backup => 1,
            group => $gid,
            user => $uid,
        },
        indexer => {
            data => '',
            file => $_keys_dir . '/index.txt',
            mode => 0660,
            backup => 1,
            group => $gid,
            user => $uid,
        }
    })){
        return { error => 'Could not create new serial and index.txt!' };
    }

    # Write the key/cert to file
    # ==========================
    return $self->_write_to_file({
        certificate => {
            data => $cert,
            file => $ca_cert_file,
            mode => 0440,
            backup => 1,
            group => $gid,
            user => $uid,
        },
        key => {
            data => $priv_key,
            file => $ca_key_file,
            mode => 0400,
            backup => 1,
            group => $gid,
            user => $uid,
        }
    });
}

sub _write_to_file {
    my ( $self, $params ) = @_;

    # Lock to this class
    # ==================
    {
        my $caller = (caller(1))[3];
        my $me  = (caller(0))[3];
        $caller =~ s/^(.*)::.*$/$1/;
        $me =~ s/^(.*)::.*$/$1/;
        die "Private method" if $caller ne $me;
    }

    return { error => 'No file data or details provided' }
        unless $params;

    my $_digests = [];
    for my $item ( keys %{$params} ){
        # Incase we need to overwrite,
        # backup the old file.
        # ============================
        if ( $params->{$item}->{backup}
            && -e $params->{$item}->{file}
            && -f $params->{$item}->{file}
        ) {
            rename ( $params->{$item}->{file}, $params->{$item}->{file} . '.old' )
                or return {error=> "Cannot backup "
                . $params->{$item}->{file} . ": " .  $!};
        }

        # Write data to file
        # ==================
        open ( my $FH, ">", $params->{$item}->{file} )
            or return {error=> "Cannot open "
            . $params->{$item}->{file} . ": " .  $!};
        local $| = 1;
        print {$FH} $params->{$item}->{data};
        close $FH;

        # Chown/Chmod
        # ===========
        my $user = $params->{$item}->{user};
        my $group = $params->{$item}->{group};

        if ( $params->{$item}->{user} && $params->{$item}->{group} ) {
            chown $params->{$item}->{user}, $params->{$item}->{group},
                $params->{$item}->{file}
                    or warn "Warning!! Cannot chown "
                        . $params->{$item}->{file} . ": " . $!;
        }

        if ( $params->{$item}->{mode} ){
            chmod $params->{$item}->{mode}, $params->{$item}->{file}
                or warn "Warning!! Cannot chmod "
                    . $params->{$item}->{file} . ": " . $!;
        }

        push (@{$_digests}, {
            file    => $params->{$item}->{file},
            digest  => file_md5_hex( $params->{$item}->{file} ) || 'null',
        });
    }

    return (
        $_digests && @{$_digests} > 0
            ? $_digests
            : undef
    );

}


sub _get_ca_file_name {




}

1;

