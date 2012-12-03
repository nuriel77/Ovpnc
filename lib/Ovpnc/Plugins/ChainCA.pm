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
use File::Slurp;
use Moose;
use namespace::autoclean;

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
    my ( $self, $key ) = @_;

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

    # Set random seed
    # ===============
    die "Cannot seed" unless $self->_set_random_seed;

    # Get 16 bytes random data
    # ========================
    my $_random_bytes = Crypt::OpenSSL::Random::random_bytes(16);

    # Convert to hex and set as serial
    # ================================
    $ca_cert->set_serial( '0x' . unpack('H*', $_random_bytes) );

    # Set validaty range
    # ==================
    my $_time_t = "%Y%m%d%H%M%SZ";
    my $_time_now = strftime($_time_t, gmtime(time()));
    my $_time_5yr = strftime($_time_t, gmtime(time()+157680000));
    $ca_cert->set_notBefore( $_time_now );
    $ca_cert->set_notAfter( $_time_5yr );
#    $ca_cert->set_notBefore("20080204101500Z");
#    $ca_cert->set_notAfter("22080204101500Z");

    my $ca_dn = Crypt::OpenSSL::CA::X509_NAME->new(
        C               => 'NL',
        ST              => 'NH',
        L               => 'Amsterdam',
        O               => 'Ovpnc',
        OU              => 'Development',
        CN              => 'Ovpnc CA',
        name            => 'SSL Server CA',
        emailAddress    => 'nuri@de-bar.com'
    );

    $ca_cert->set_issuer_DN($ca_dn);
    $ca_cert->set_subject_DN($ca_dn);

    # v3 extention data
    # =================
    $ca_cert->set_extension("basicConstraints", "CA:FALSE", -critical => 1);

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

sub gen_user_certificate {
    my ( $self, $params, $cfg ) = @_;

#    my $_crl = Crypt::OpenSSL::CA::X509_CRL->new;
#    die 'Could not create a CRLv2 object'
#        unless $_crl->is_crlv2();
#     die $_crl->dump;


    # Generate a new key
    # ==================
    my $rsa = Crypt::OpenSSL::RSA->generate_key(
        $params->{key_size} // $ENV{KEY_SIZE} // 1024
    );

    # Generate a new request
    # ======================
    my $req = Crypt::OpenSSL::PKCS10->new_from_rsa( $rsa );

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
#    my $_ca_key = read_file ( $cfg->{openvpn_utils} . '/keys/ca.key', chomp => 1 )
    my $_ca_key = read_file ( $ca_key_file, chomp => 1 )
        or die "Cannot read CA key, make sure it has been created.";
    my $ca_privkey = Crypt::OpenSSL::CA::PrivateKey->
        parse( $_ca_key );

    # Get the Root CA certificate
    # ===========================
#    my $_ca_cert = read_file ( $cfg->{openvpn_utils} . '/keys/ca.crt', chomp => 1 )
    my $_ca_cert = read_file ( $ca_cert_file, chomp => 1 )
        or die "Cannot read CA certificate, make sure it has been created.";
    my $ca_cert = Crypt::OpenSSL::CA::X509->
        parse( $_ca_cert );

    # Save DN / KeyID
    # ===============
    my $ca_dn = $ca_cert->get_subject_DN();
    my $ca_keyid = $ca_cert->get_subject_keyid;
    my $ca_serial = $ca_cert->get_serial();
    $req->set_subject( $ca_dn->to_string() );
    $req->add_ext_final();
    $req->sign();

    # Write to file
    # =============
    $req->write_pem_req( $cfg->{openvpn_utils} . '/keys/' . $params->{name} . '.csr' );
    $req->write_pem_pk(  $cfg->{openvpn_utils} . '/keys/' . $params->{name} . '.key' );

    # Extract public key from
    # the newely created csr
    # =======================
    my $user_pubkey = Crypt::OpenSSL::CA::PublicKey->
        validate_PKCS10(  $req->get_pem_req() );

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
    $user_cert->set_issuer_DN( $ca_dn );
    $user_cert->set_subject_DN( $user_dn);

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
    my $_time_t = "%Y%m%d%H%M%SZ";
    my $_time_now = strftime($_time_t, gmtime(time()));
    my $_time_5yr = strftime($_time_t, gmtime(time()+157680000));
    $user_cert->set_notBefore( $_time_now );
    $user_cert->set_notAfter( $_time_5yr );

    $user_cert->set_extension( "basicConstraints", "CA:FALSE");
    $user_cert->set_extension( "nsCertType", $params->{cert_type});
    $user_cert->set_extension( "nsComment", "Ovpnc - Crypt::OpenSSL::CA Generated Server Certificate");
    $user_cert->set_extension( "extendedKeyUsage", "TLS Web Server Authentication" );
    $user_cert->set_extension( "keyUsage", "Digital Signature, Key Encipherment" );
    $user_cert->set_extension( subjectKeyIdentifier => $subject_keyid );
    $user_cert->set_extension( authorityKeyIdentifier =>
        {
            keyid => $ca_keyid,
            issuer => $ca_dn,
            serial => $ca_serial,
        },
        -critical => 0); # As per RFC3280 section 4.2.1.1

    $user_cert->set_extension
      (subjectAltName => 'email:nuri@de-bar.com,email:ovpnc@x-vps.com');

    my $user_cert_as_text = $user_cert->sign($ca_privkey, 'sha256');

    my $new_user_cert = Crypt::OpenSSL::CA::X509->parse( $user_cert_as_text );

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
    my $_index_str = "V\t" . $_time_now . "\t\t" . $_serial . "\tunknown " . $new_user_cert->get_subject_DN()->to_string();
    #V       221106113229Z           01      unknown /C=NL/ST=NH/L=Amsterdam/O=XVPS/OU=XVPS_SERVER/CN=www.x-vps.com/name=Server/emailAddress=nuri@de-bar.com
    print $FH $_index_str . "\n\n";
    close $FH;

    return 1;
}

sub get_supported_digests {
    my @digests = Crypt::OpenSSL::CA::X509_CRL->supported_digests();
    return ( wantarray() ? @digests : join "\n", @digests );
}

sub _read_random_entropy {
    open ( my $rand, '<', '/dev/urandom' )
        or die "unable to open random";
    binmode $rand;
    my $entropy;
    read $rand, $entropy, 1024, 0;
    return $entropy;
}


sub _set_random_seed {
    my $self = shift;

    Crypt::OpenSSL::Random::random_seed(
        $self->_read_random_entropy()
    ) unless -f '/dev/random';

    Crypt::OpenSSL::RSA->import_random_seed()
        or die "Unable to seed the random number generator";

    return 1 if Crypt::OpenSSL::Random::random_status();
}

1;
