package Ovpnc::Plugin::PEM;
use strict;
use warnings;
use Convert::PEM;
use Crypt::OpenSSL::RSA;
use MIME::Base64;
use Moose;
use Moose::Exporter;
use namespace::autoclean;

#
# Exported method
#
Moose::Exporter->setup_import_methods(
    as_is   => [ 'lock_key', 'unlock_key', 'encode64', 'decode64' ]
);

=head1 NAME

Ovpnc::Plugin::PEM - Convert PEM format

=head1 DESCRIPTION

Mainly used to lock and unlock
pem keys with a passphrase

head1 METHODS

=cut

=head lock_key

Use Convert::PEM (ASN format)
to lock the key with a passphrase

=cut

    sub lock_key {
        my ( $keyfile, $password ) = @_;

        my $pem = Convert::PEM->new(
           Name => 'RSA PRIVATE KEY',
           ASN  => qq(
                  RSAPrivateKey SEQUENCE {
                      version INTEGER,
                      n INTEGER,
                      e INTEGER,
                      d INTEGER,
                      p INTEGER,
                      q INTEGER,
                      dp INTEGER,
                      dq INTEGER,
                      iqmp INTEGER
                  }
             )
        );

        my $pkey = $pem->read( Filename => $keyfile );

        $pem->write(
           Content  => $pkey,
           Password => $password,
           Filename => $keyfile
        );
        
        my $unlocked = unlock_key( $keyfile, $password );
        return undef unless $unlocked;
        Crypt::OpenSSL::RSA->new_private_key($unlocked)
            or die $!;
        return 1;
    }


=head2 unlock_key

Unlock a key

=cut

    sub unlock_key {
        my ( $keyfile, $password ) = @_;

        my $pem = Convert::PEM->new(
           Name => 'RSA PRIVATE KEY',
           ASN  => qq(
                  RSAPrivateKey SEQUENCE {
                      version INTEGER,
                      n INTEGER,
                      e INTEGER,
                      d INTEGER,
                      p INTEGER,
                      q INTEGER,
                      dp INTEGER,
                      dq INTEGER,
                      iqmp INTEGER
                  }
             )
        );

        my $pkey = $pem->read( Filename => $keyfile, Password => $password );
        return $pem->encode( Content => $pkey );
    }


=head2 encode64

Encode to base64

=cut

    sub encode64 { return encode_base64(shift) }


=head2 decode64

Decode from base64

=cut

    sub decode64 { return decode_base64(shift) }


=head1 AUTHOR

Nuriel Shem-Tov

=cut

1;
