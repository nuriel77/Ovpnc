package Ovpnc::TraitFor::Controller::Api::Certificates::Generate;
use warnings;
use strict;
use Ovpnc::Controller::Api::Configuration 'get_openvpn_param';
use File::Copy;
use File::Touch;
use File::Slurp;
use Digest::MD5::File 'file_md5_hex';
use Ovpnc::Plugin::ChainCA;
use Moose::Role;
use utf8;
use vars qw/$ca/;

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

has serial => (
    is => 'rw',
    isa => 'Str',
);

has _ca => (
    is => 'rw',
    isa => 'Object',
    default => sub { return Ovpnc::Plugin::ChainCA->new; }
);

has _keys_dir => (
    is => 'rw',
    isa => 'Str',
);

=head2 init_ca

This function will create a new Root CA
(key + cert) with which other certificates
can be signed with. It would be best to
place the key elsewhere after creation,
or else chown it as root and leave it
on mode 0400 to be secure.
This function will also remove
all files existing in the keys
directory.

=cut

    sub init_ca {
        my ( $self, $params ) = @_;

        my $ovpnc_conf = $self->_cfg->{ovpnc_conf} =~ /^\//
            ? $self->_cfg->{ovpnc_conf}
            : $self->_cfg->{home} . '/' . $self->_cfg->{ovpnc_conf};

        # Get the filename of the CA cert
        # ===============================
        my $ca_cert_file = get_openvpn_param( $self, 'Ca', $ovpnc_conf );
    
        $ca_cert_file = $ca_cert_file =~ /^\//
    	? $ca_cert_file
    	: $self->_cfg->{home} . '/' . $ca_cert_file;

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
        my ( $_keys_dir ) = $ca_cert_file =~ /^(.*)\/.*$/;
        $self->_keys_dir( $_keys_dir );

        if ( ! -e $self->_keys_dir ) {
            mkdir $self->_keys_dir, 0770
        }
        else {
            # Generate new serial file and index.txt
            # ======================================
            if ( my @_to_remove = glob($_keys_dir . '/*') ){
                unlink ( @_to_remove )
                    or die "Cannot clean " . $_keys_dir . '/* :' . $!;
            }
        }

        my ( $uid, $gid ) = $self->get_user_group_id;
    
        # Override Perl's Crypt::OpenSSL::CA
        # ==================================
        unless ( $self->_cfg->{ssl_via_perl} ){
        
            my $_rv = $self->_ca->gen_via_pkitool( $params, $self->_cfg );
            if ( $_rv && ref $_rv eq 'HASH' && $_rv->{status} ){

                # Generate index.txt and serial
                # =============================
                unless ( $self->_write_to_file({
                    serial => {
                        data => "01\n",
                        file => $self->_keys_dir . '/serial',
                        mode => 0660,
                        backup => 0,
                        group => $gid,
                        user => $uid,
                    },
                    indexer => {
                        data => '',
                        file => $self->_keys_dir . '/index.txt',
                        mode => 0660,
                        backup => 0,
                        group => $gid,
                        user => $uid,
                    },
                })){
                    return { error => 'Could not create new serial and/or index.txt!' };
                }
                # Return output from ca creation
                # ==============================
                my $_digest->{crt} = file_md5_hex( $ca_cert_file );
                $_digest->{key} = file_md5_hex( $ca_key_file );
                return [
                    {
                        file   => $ca_cert_file,
                        digest => $_digest->{crt}
                    },
                    {
                        file   => $ca_key_file,
                        digest => $_digest->{key}
                    }
                ];
            }
    
            return $_rv
                if ( $_rv && ref $_rv eq 'HASH' && $_rv->{error} );
            return { error =>
                'Something went wrong while creating root CA' };
        }

        # Via Perl's Crypt::OpenSSL
        # =========================
        my $priv_key = $self->_ca->gen_private_key;
        my $cert = $self->_ca->gen_ca_certificate( $priv_key, $params );

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


=head2 gen_ca_signed_certificate

Create a new key / csr and then
have it signed by the root CA.
User can choose cert_type server
or client, which is mandatory.
'server' is always expected to
be created before any client
is created. There are some additional
files being created which are
necessary for functionality.

=cut

    sub gen_ca_signed_certificate {
        my ( $self, $params ) = @_;

        return { error => 'No parameters supplied at gen_ca_signed_certificate' }
            unless $params;

        # Generate a new key and csr
        # ==========================
        my $_new_csr = $self->_ca->gen_certificate( $params, $self->_cfg );
        if ( $_new_csr and ref $_new_csr ){
            return $_new_csr if ( $_new_csr->{error} );

            # Get file digests
            # ================
            my @_digests;
            if ( $_new_csr->{resultset} ) {
                for ( @{$_new_csr->{resultset}} ){
                    push @_digests, {
                        file    => $_,
                        digest  => file_md5_hex( $_ ) || 'null',
                    };
                }

            }

            # Sign the new CSR
            # ================
            if ( my $_ret_val = $self->_ca->gen_crl( $params, $self->_cfg ) ) { 
                if ( ! -e $self->_cfg->{openvpn_ccd} . '/' . $params->{KEY_CN}
                  and $params->{cert_type} !~ /server|ca/
                ){
                    touch $self->_cfg->{openvpn_ccd} . '/' . $params->{KEY_CN}
                        or warn "Did not create client ccd file: " . $!;
                }
                return { status => 'ok', resultset => \@_digests };
            }
        } else {
            return { error => 'Did not create new certificate(s) for ' . $params->{name} };
        }

    }


=head2 get_user_group_id

Get user's group id

=cut

    sub get_user_group_id {
        my $self = shift;

        # Get the group/user
        # ==================
        my (undef, undef, undef, $gid) = getpwnam(
            $self->_cfg->{openvpn_group} );
        my (undef, undef, $uid) = getpwuid( $< );

        return ( $uid, $gid );
    }


=head2 set_chown_chmod

Set chown and chmod on file(s)

=cut

    sub set_chown_chmod {
        my ( $self, $file, $mode, $user, $group ) = @_;

        die "No filename supplied"
            unless $file;

        if ( $user and $group ) {
            chown $user, $group, $file
                or warn "Warning!! Cannot chown "
                        . $file . ": " . $!;
        }

        if ( $mode ) {
            chmod $mode, $file
                or warn "Warning!! Cannot chmod "
                    . $file . ": " . $!;
        }

        return 1;
    }


=head2 _write_to_file

Write certificate/key data to file

=cut

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
            $self->set_chown_chmod(
                $params->{$item}->{file},
                $params->{$item}->{mode},
                $params->{$item}->{user},
                $params->{$item}->{group}
            );

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


=head1 AUTHOR

Nuriel Shem-Tov

=cut

1;

