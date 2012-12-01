package Ovpnc::Plugins::ChainCA;
use strict;
use warnings;
use utf8;
use Crypt::OpenSSL::CA;
use Crypt::OpenSSL::Bignum;
use Crypt::OpenSSL::Random;
use Crypt::OpenSSL::RSA;
use Data::Dumper::Concise;
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

    my $rsa = Crypt::OpenSSL::RSA->generate_key(1024);
    $self->_set_priv( $rsa->get_private_key_string() );
    return $self->_ca_privkey_as_text;
}


=head2 gen_certificate

The CA certificate is filled out field after field,
starting with the RSA public key.

=cut

sub gen_certificate {

    my ( $self, $key ) = @_;
    $key ||= $self->_ca_privkey_as_text;
    my $ca_privkey = Crypt::OpenSSL::CA::PrivateKey->
        parse( $key );

    my $ca_pubkey = $ca_privkey->get_public_key;
    my $ca_cert = Crypt::OpenSSL::CA::X509->new( $ca_pubkey );
    my $ca_serial = "0x1";
    $ca_cert->set_serial($ca_serial);
    $ca_cert->set_notBefore("20080204101500Z");
    $ca_cert->set_notAfter("22080204101500Z");

    my $ca_dn = Crypt::OpenSSL::CA::X509_NAME->new(
        C               => 'NL',
        ST              => 'NH',
        L               => 'Amsterdam',
        O               => 'Ovpnc',
        OU              => 'Development',
        CN              => 'Ovpnc CA',
        name            => 'server',
        emailAddress    => 'nuri@de-bar.com'
    );
    #/C=NL/ST=NH/L=Amsterdam/O=XVPS/OU=Private/CN=x-vps.com/name=server/emailAddress=nuri@de-bar.com

    $ca_cert->set_issuer_DN($ca_dn);
    $ca_cert->set_subject_DN($ca_dn);

    $ca_cert->set_extension("basicConstraints", "CA:TRUE", -critical => 1);

    my $ca_keyid = $ca_pubkey->get_openssl_keyid;
    $ca_cert->set_extension("subjectKeyIdentifier", $ca_keyid);
    $ca_cert->set_extension("authorityKeyIdentifier" =>
        {
			keyid => $ca_keyid,
			issuer => $ca_dn,
			serial => $ca_serial
        }
    );

=pod

Sign it, and the certificate is ready!

=cut

  $self->_set_cert( $ca_cert->sign($ca_privkey, "sha1") );
  return $self->_ca_cert_as_text;

}

=head1 USER CERTIFICATE SIGNING REQUEST

  openssl req -nodes -batch -newkey rsa:1024 -keyout userkey.pem -out user.p10

=cut

sub _gen_user_certificate {
    my $self = shift;

  my $user_csr = <<_PKCS10_;
-----BEGIN CERTIFICATE REQUEST-----
MIIBhDCB7gIBADBFMQswCQYDVQQGEwJBVTETMBEGA1UECBMKU29tZS1TdGF0ZTEh
MB8GA1UEChMYSW50ZXJuZXQgV2lkZ2l0cyBQdHkgTHRkMIGfMA0GCSqGSIb3DQEB
AQUAA4GNADCBiQKBgQCwoel30tZE9ItO0wfQWx3jGFpMLo41iFhFrqlweTJ7iacM
bq58tmpDjEONxhqLkNzm05nb2pylskWzKwLQ9NXvchkzK31HKyp89thiVL7ILClV
YRYMz4QLeB75W+xl6q2pcClQ3NrN7CrR9czvmVFOXNWKWxyQXYi2Ad0qVvNF+wID
AQABoAAwDQYJKoZIhvcNAQEFBQADgYEAFL1txli+LGSS4V1sVSRdMh054QVk9TKY
50HTKYR44aCax3fDcnp4H7jR5QEHX0TeHCC5cr8cDDWLEYmCb0UBXr70czrap3n2
Du3EgKJUHSURsNbkSHSBKupLrw9Ygmipl4vvHRAX59Bqbz4LGEhALnx0eiwK1TtQ
mk7h7g7cYc8=
-----END CERTIFICATE REQUEST-----
_PKCS10_

  my $user_pubkey = Crypt::OpenSSL::CA::PublicKey->validate_PKCS10($user_csr);

=head1 USER CERTIFICATE CREATION

=cut

  my $ca_cert = Crypt::OpenSSL::CA::X509->
    parse(our $ca_cert_as_text);
  my $ca_privkey = Crypt::OpenSSL::CA::PrivateKey->
    parse(our $ca_privkey_as_text, -password => "secret");


  my $ca_dn = $ca_cert->get_subject_DN();
  my $ca_keyid = $ca_cert->get_subject_keyid;

=head2 Certificate Fields and Extensions

=cut

  my $user_cert = Crypt::OpenSSL::CA::X509->new($user_pubkey);

  my $user_dn = Crypt::OpenSSL::CA::X509_NAME->new_utf8
    (C => "fr", O => "zoinxé",
     OU => "☮☺⌨", # Peace, joy, coding :-)
     CN => "test user cert");

  $user_cert->set_issuer_DN($ca_dn);
  $user_cert->set_subject_DN($user_dn);

  $user_cert->set_serial("0x1234567890abcdef1234567890ABCDEF");

  $user_cert->set_notBefore("20080204114600Z");
  $user_cert->set_notAfter("21060108000000Z");
  $user_cert->set_extension("basicConstraints", "CA:FALSE",
                         -critical => 1);

  $user_cert->set_extension("authorityKeyIdentifier",
                       { keyid => $ca_keyid },
                       -critical => 0); # As per RFC3280 section 4.2.1.1
  $user_cert->set_extension( subjectKeyIdentifier =>
                        "00:DE:AD:BE:EF"); # Hey, why not?

  $user_cert->set_extension(certificatePolicies =>
                       'ia5org,1.2.3.4,1.5.6.7.8,@polsect',
                       -critical => 0,
                       polsect => {
                            policyIdentifier => '1.3.5.8',
                            "CPS.1"        => 'http://my.host.name/',
                            "CPS.2"        => 'http://my.your.name/',
                            "userNotice.1" => '@notice',
                         },
                         notice => {
                            explicitText  => "Explicit Text Here",
                            organization  => "Organisation Name",
                            noticeNumbers => '1,2,3,4',
                         });

  $user_cert->set_extension
    (subjectAltName => 'email:johndoe@example.com,email:johndoe@example.net');

  my $fancy_digest_alg = "sha256";  # I'd use "sha256" myself, but
  # some old builds of OpenSSL don't have it.
  warn "And here is a certificate using $fancy_digest_alg as the digest!\n";

  our $user_cert_as_text = $user_cert->sign($ca_privkey, $fancy_digest_alg);
  print $user_cert_as_text;
}

1;
