package Ovpnc::Plugins::ChainCA;
use strict;
use warnings;
use utf8;
use MIME::Base64;
use POSIX;
use Crypt::OpenSSL::CA;
use Crypt::OpenSSL::Bignum;
use Crypt::OpenSSL::Random;
use Crypt::OpenSSL::RSA;
use Crypt::OpenSSL::PKCS10 qw( :const );
use Crypt::Rijndael;
use Data::Entropy qw(with_entropy_source entropy_source);
use Data::Entropy::Algorithms qw( rand_bits rand_int );
use Data::Entropy::RawSource::CryptCounter;
use Data::Entropy::RawSource::Local;
use Data::Entropy::Source;
use File::Slurp;
use Moose;
use vars qw/$time_format/;
use namespace::autoclean;

use constant ONE_YEAR   => 31536000;
use constant ONE_MONTH  => ONE_YEAR / 12; #2628000
$time_format = "%Y%m%d%H%M%SZ";

has _ca_privkey_as_text => (
    is  => 'ro',
    isa => 'Str',
    writer => '_set_priv',
    predicate => '_has_priv',
    clearer => '_clear_priv'
);

has _ca_cert_as_text => (
    is  => 'ro',
    isa => 'Str',
    writer => '_set_cert',
    predicate => '_has_cert',
    clearer => '_clear_cert'
);

has serial => (
    is  => 'ro',
    isa => 'Str',
);

=head1 NAME

Generates RSA X509 certificate chain

=head1 DESCRIPTION

This plugin will provide Ovpnc
the ability to manage certificates

=cut


=head2 gen_private_key

Create Private Key

=cut

sub gen_private_key {
    my ( $self, $params ) = @_;

    $params->{key_size} //= 1024;
    $params->{key_file} //= 'ovpnc.key';
    die "Cannot seed" unless $self->_set_random_seed;
    my $rsa = Crypt::OpenSSL::RSA->generate_key( $ENV{KEY_SIZE} || 1024 );
    $self->_set_priv( $rsa->get_private_key_string() );
    return $self->_ca_privkey_as_text;
}


=head2 gen_ca_certificate

The CA certificate is filled out field after field,
starting with the RSA public key.

From OpenVPN Documentation:

    Build your server certificates with specific key usage and
    extended key usage. The RFC3280 determine that the following
    attributes should be provided for TLS connections:

    Mode      Key usage                          Extended key usage
    ---------------------------------------------------------------------------
    Client    digitalSignature                   TLS Web Client Authentication
              keyAgreement
              digitalSignature, keyAgreement

    Server    digitalSignature, keyEncipherment  TLS Web Server Authentication
              digitalSignature, keyAgreement


=cut

sub gen_ca_certificate {
    my ( $self, $key, $params ) = @_;

    $key ||= $self->_ca_privkey_as_text;

    # Import private key
    # ==================
    my $ca_privkey = Crypt::OpenSSL::CA::PrivateKey->
        parse( $key );

    # Extract public key
    # ==================
    my $ca_pubkey = $ca_privkey->get_public_key;

    # x509 object
    # ===========
    my $ca_cert = Crypt::OpenSSL::CA::X509->new( $ca_pubkey );

    # Set random seed,
    # Get 16 bytes random data
    # ========================
    my $_random_bytes = $self->_set_random_seed;

    # Convert to hex and set as serial
    # ================================
    $ca_cert->set_serial( '0x' . unpack('H*', $_random_bytes) );

    # Set validaty range
    # ==================
    my $_time_now = strftime( $time_format, gmtime(time()) );
    my $_time_yr = strftime( $time_format, gmtime(time() + (
        ONE_YEAR * ( $params->{expires} ? $params->{expires} : 1 ) )
    ));
    $ca_cert->set_notBefore( $_time_now );
    $ca_cert->set_notAfter( $_time_yr );
#    $ca_cert->set_notBefore("20080204101500Z");
#    $ca_cert->set_notAfter("22080204101500Z");

    my $ca_dn = Crypt::OpenSSL::CA::X509_NAME->new(
        C               => $params->{C}             || 'NL',
        ST              => $params->{ST}            || 'NH',
        L               => $params->{L}             || 'Amsterdam',
        O               => $params->{O}             || 'Ovpnc',
        OU              => $params->{OU}            || 'Development',
        CN              => $params->{CN}            || 'Ovpnc CA',
        name            => $params->{name}          || 'SSL Server CA',
        emailAddress    => $params->{emailAddress}  || 'nuri@de-bar.com'
    );

    $ca_cert->set_issuer_DN($ca_dn);
    $ca_cert->set_subject_DN($ca_dn);

    # v3 extention data
    # =================
    $ca_cert->set_extension("basicConstraints", "CA:TRUE", -critical => 0);

    my $ca_keyid = $ca_pubkey->get_openssl_keyid;
    $ca_cert->set_extension("subjectKeyIdentifier", $ca_keyid);
    $ca_cert->set_extension("authorityKeyIdentifier" =>
        {
			keyid => $ca_keyid,
			issuer => $ca_dn,
			serial => $ca_cert->get_serial()
        }
    );

    $self->_set_cert( $ca_cert->sign($ca_privkey, 'sha256') );
    return $self->_ca_cert_as_text;

}

=head1 USER CERTIFICATE SIGNING REQUEST

  openssl req -nodes -batch -newkey rsa:1024 -keyout userkey.pem -out user.p10

=cut

sub gen_key_and_csr {
    my ( $self, $params, $cfg ) = @_;

    # Check that we don't already
    # have some client with this name
    # ================================
    if ( -e $cfg->{openvpn_utils} . '/keys/'
            . $params->{name} . '.csr'
        || -e $cfg->{openvpn_utils} . '/keys/'
            . $params->{name} . '.key'
    ) {
        if ( ! $params->{overwrite} ){
            return { error => 'Client certificate for '
                        . $params->{name} . ' already exists' }
        }
        else {
            rename $cfg->{openvpn_utils} . '/keys/'
            . $params->{name} . '.csr', $cfg->{openvpn_utils} . '/keys/'
            . $params->{name} . '.csr.old';
            rename $cfg->{openvpn_utils} . '/keys/'
            . $params->{name} . '.key', $cfg->{openvpn_utils} . '/keys/'
            . $params->{name} . '.key.old';
        }
    }

    # Generate a new key
    # ==================
    my $rsa = Crypt::OpenSSL::RSA->generate_key(
        $params->{key_size} // $ENV{KEY_SIZE} // 1024
    );

    # Generate a new request
    # ======================
    my $req = Crypt::OpenSSL::PKCS10->new_from_rsa( $rsa );

    my ( undef, $ca_cert ) = $self->_get_ca_key_and_cert( $cfg );

    # Save DN / KeyID
    # ===============
    my $_ca_dn = $ca_cert->get_subject_DN();
    my $_ca_keyid = $ca_cert->get_subject_keyid;
    my $_ca_serial = $ca_cert->get_serial();
    $req->set_subject( $_ca_dn->to_string() );
    $req->add_ext_final();
    $req->sign();

    # Write to file
    # =============
    $req->write_pem_req(
        $cfg->{openvpn_utils} . '/keys/'
            . $params->{name} . '.csr' );
    $req->write_pem_pk(
        $cfg->{openvpn_utils} . '/keys/'
            . $params->{name} . '.key' );

    return [ $_ca_dn, $_ca_keyid, $_ca_serial ];
}

sub sign_new_csr {
    my ( $self, $req, $params, $cfg ) = @_;

    my ( $ca_privkey, $ca_cert ) = $self->_get_ca_key_and_cert( $cfg );

    # Extract public key
    # ==================
#    my $ca_pubkey = $ca_privkey->get_public_key;

    # x509 object
    # ===========
#    my $ca_cert = Crypt::OpenSSL::CA::X509->new( $ca_pubkey );

    my $_req = read_file(
        $cfg->{openvpn_utils} . '/keys/' . $params->{name} . '.csr',
        chomp => 1
    ) or die "Cannot read CSR file: "
        . $cfg->{openvpn_utils} . '/keys/'
        . $params->{name} . '.csr' . ": " . $!;


    # Extract public key from
    # the newely created csr
    # =======================
    my $user_pubkey = Crypt::OpenSSL::CA::PublicKey->
        validate_PKCS10( $_req );
#        validate_PKCS10(  $req->get_pem_req() );

    my $user_dn = Crypt::OpenSSL::CA::X509_NAME->new_utf8(
        C => $params->{C}                           || 'NL',
        ST => $params->{ST}                         || 'NH',
        L => $params->{L}                           || 'Amsterdam',
        O => $params->{O}                           || 'Ovpnc',
        OU => $params->{OU}                         || 'Development',
        CN => $params->{CN}                         || 'ovpncadmin',
        name => $params->{name}                     || 'Ovpnc VPN Server',
        emailAddress => $params->{emailAddress}     || 'nuri@de-bar.com',
    );
    #/C=NL/ST=NH/L=Amsterdam/O=XVPS/OU=XVPS_SERVER/CN=server/name=XVPS_SERVER/emailAddress=nuri@de-bar.com

    my $user_cert = Crypt::OpenSSL::CA::X509->new( $user_pubkey );
    my $subject_keyid = $user_pubkey->get_openssl_keyid;
    $user_cert->set_issuer_DN( $req->[0] );
    $user_cert->set_subject_DN( $user_dn );

    my $_current_serial;
    if ( -e $cfg->{openvpn_utils} . '/keys/serial'
        && -f $cfg->{openvpn_utils} . '/keys/serial'
    ) {
        $_current_serial = read_file(
            $cfg->{openvpn_utils} . '/keys/serial', chomp => 1
        ) or die "Cannot read serial file: "
                 . $cfg->{openvpn_utils} . '/keys/serial';
    } else {
        open ( my $SF, '>', $cfg->{openvpn_utils} . '/keys/serial' )
            or die "Cannot create new serial file: " . $!;
        print $SF "01\n";
        close $SF;
    }

    my $_serial = $_current_serial
        ? sprintf('%02X', hex( $_current_serial ) + 1 )
        : '01';

    $user_cert->set_serial( '0x' . $_serial );

    # Set validaty range
    # ==================
    my $_time_now = strftime($time_format, gmtime(time()));
    my $_time_yr = strftime($time_format, gmtime(time() +
        ONE_YEAR * ( $params->{expires} ? $params->{expires} : 1 ) )
    );
    $user_cert->set_notBefore( $_time_now );
    $user_cert->set_notAfter( $_time_yr );

    $user_cert->set_extension( "basicConstraints", "CA:FALSE");
    $user_cert->set_extension( "nsCertType", $params->{cert_type});
    $user_cert->set_extension( "nsComment", "Ovpnc - Crypt::OpenSSL::CA Generated Server Certificate");
    $user_cert->set_extension( "extendedKeyUsage", "TLS Web " . ucfirst($params->{cert_type}) . " Authentication" );
    $user_cert->set_extension( "keyUsage", "Digital Signature, Key Encipherment" );
    $user_cert->set_extension( subjectKeyIdentifier => $subject_keyid );
    $user_cert->set_extension( authorityKeyIdentifier =>
        {
            keyid => $req->[1],
            issuer => $req->[0],
            serial => $req->[2],
        },
        -critical => 0); # As per RFC3280 section 4.2.1.1

    $user_cert->set_extension
      (subjectAltName => 'email:nuri@de-bar.com,email:ovpnc@x-vps.com');

    my $user_cert_as_text = $user_cert->sign($ca_privkey, 'sha256');

    my $new_user_cert = Crypt::OpenSSL::CA::X509->parse( $user_cert_as_text );

    my @_files = (
        $cfg->{openvpn_utils} . '/keys/crl.pem',
        $cfg->{openvpn_utils} . '/keys/' . $params->{name} .'.crt',
        $cfg->{openvpn_utils} . '/keys/' . $params->{name} .'.pem',
    );

    # Prepare CRL file
    # ================
    if ( $params->{cert_type} eq 'server' ){
        my $_crl = Crypt::OpenSSL::CA::X509_CRL->new;
        die 'Could not create a CRLv2 object'
            unless $_crl->is_crlv2();
        $_crl->set_issuer_DN( $ca_cert->get_issuer_DN() );

        # Set validaty range
        # ==================
        $_time_now = strftime($time_format, gmtime(time()) );
        my $_time_month = strftime($time_format, gmtime(time() + ONE_MONTH ));
        $_crl->set_lastUpdate( $_time_now );
        $_crl->set_nextUpdate( $_time_month );
        my $_crl_data = $_crl->sign( $ca_privkey, 'sha256' );
        open (my $FH, '>', $cfg->{openvpn_utils} . '/keys/crl.pem')
            or die "Cannot open certificate file 'crl.pem' for writing: " . $!;
        print {$FH} $_crl_data;
        close $FH;
    }

    # Write to file
    # =============
    open (my $FH, '>', $cfg->{openvpn_utils} . '/keys/' . $params->{name} .'.crt')
        or die "Cannot open certificate file '" . $params->{name} . ".crt' for writing: " . $!;
    print {$FH} $user_cert_as_text;
    close $FH;

    open ($FH, '>', $cfg->{openvpn_utils} . '/keys/' . $_serial . '.pem')
        or die "Cannot open certificate file '" . $_serial . ".pem' for writing: " . $!;
    print {$FH} $new_user_cert->dump();
    close $FH;

    # All ok, update serial
    # =====================
    open ( $FH, '>', $cfg->{openvpn_utils} . '/keys/serial' )
        or die "Cannot update serial file: " . $!;
    print $FH $_serial . "\n";
    close $FH;

    # Update index.txt
    # ================
    open ( $FH, '>>', $cfg->{openvpn_utils} . '/keys/index.txt' )
        or die "Cannot update index.txt file: " . $!;
    my $_tmp_time_format = "%y%m%d%H%M%SZ";
    $_time_now = strftime( $_tmp_time_format, gmtime(time() + ( 10 * ONE_YEAR ) ) );
    my $_index_str = "V\t" . $_time_now . "\t\t" . $_serial . "\tunknown\t"
                    . $new_user_cert->get_subject_DN()->to_string();

    print $FH $_index_str . "\n";
    close $FH;

    return \@_files;
}

sub _get_ca_key_and_cert {
    my ( $self, $cfg ) = @_;

    # Get the filename of the CA cert
    # ===============================
    my $ca_cert_file = Ovpnc::Controller::Api::Configuration->get_openvpn_param(
        $cfg->{ovpnc_conf}, 'Ca' );

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

    # Get the Root CA key
    # ===================
    my $_ca_key = read_file ( $ca_key_file, chomp => 1 )
        or die "Cannot read CA key, make sure it has been created.";
    my $ca_privkey = Crypt::OpenSSL::CA::PrivateKey->
        parse( $_ca_key );

    # Get the Root CA certificate
    # ===========================
    my $_ca_cert = read_file ( $ca_cert_file, chomp => 1 )
        or die "Cannot read CA certificate, make sure it has been created.";
    my $ca_cert = Crypt::OpenSSL::CA::X509->
        parse( $_ca_cert );

    return ( $ca_privkey, $ca_cert );
}


sub get_supported_digests {
    my @digests = Crypt::OpenSSL::CA::X509_CRL->supported_digests();
    return ( wantarray() ? @digests : join "\n", @digests );
}

sub _read_random_entropy {
    my ( $self, $really_secure ) = @_;

    open ( my $rand, '<', $really_secure ? '/dev/random' : '/dev/urandom' )
        or die "Unable to read from random";
    binmode $rand;
    my $entropy;
    read $rand, $entropy, ( 1024 / 4 ), 0;
    return $entropy;
}


sub _set_random_seed_fast {
    my $self = shift;

    Crypt::OpenSSL::Random::random_seed(
        $self->_read_random_entropy()
    ) unless -f '/dev/urandom';

    Crypt::OpenSSL::RSA->import_random_seed()
        or die "Unable to seed the (u)random number generator";

    return 1 if Crypt::OpenSSL::Random::random_status();
}

sub _set_random_seed {
    my ( $self, $really_secure ) = @_;

    with_entropy_source(
        Data::Entropy::Source->new(
            Data::Entropy::RawSource::Local->new(
                $really_secure ? "/dev/random" : "/dev/urandom"
            ), "sysread"
        ), sub {
            $main::prng = Data::Entropy::Source->new(
                Data::Entropy::RawSource::CryptCounter->new(
                    Crypt::Rijndael->new(entropy_source->get_bits(128))
                ), "sysread"
            );
        }
    );

    with_entropy_source $main::prng, sub {
        return rand_bits(128);
    };
}



1;
