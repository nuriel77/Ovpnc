package Ovpnc::Plugin::ChainCA;
use strict;
use warnings;
use utf8;
use POSIX;
use File::Basename;
use IPC::Cmd qw( can_run run );
use Convert::PEM;
use Crypt::OpenSSL::CA;
use Crypt::OpenSSL::Bignum;
use Crypt::OpenSSL::Random;
use Crypt::OpenSSL::RSA;
use Crypt::Rijndael;
use Data::Entropy qw(with_entropy_source entropy_source);
use Data::Entropy::Algorithms qw( rand_bits rand_int );
use Data::Entropy::RawSource::CryptCounter;
use Data::Entropy::RawSource::Local;
use Data::Entropy::Source;
use File::Copy;
use File::Slurp;
use Expect;
use Readonly;
use Moose;
use Moose::Exporter;
use namespace::autoclean;

Readonly::Scalar    my $ONE_YEAR    => 31536000;
Readonly::Scalar    my $ONE_MONTH   => $ONE_YEAR / 12;
Readonly::Scalar    my $ONE_DAY     => 86400;
Readonly::Scalar    my $TIMEOUT     => 60;
Readonly::Scalar    my $time_format => "%Y%m%d%H%M%SZ";

#
# Exported method
#
Moose::Exporter->setup_import_methods(
    as_is   => [ 'read_random_entropy' ]
);

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

Ovpnc::Plugin::ChainCA - Chain CA Creator

=head1 DESCRIPTION

Generates RSA X509 certificates chain
This plugin will provide Ovpnc
the ability to manage certificates
Also uses OpenVPN easy-rsa scripts

head1 METHODS

=cut

=head2 gen_private_key

Create Private Key

=cut

    sub gen_private_key {
        my ( $self, $params ) = @_;
        $ENV{KEY_SIZE} //= 1024;
        $params->{key_size} ||= $ENV{KEY_SIZE};
        $params->{key_file} //= 'ovpnc.key';
        die "Cannot seed" unless $self->get_random_bits(128);
        my $rsa = Crypt::OpenSSL::RSA->generate_key( $params->{key_size} );
        $self->_set_priv( $rsa->get_private_key_string() );
        return $self->_ca_privkey_as_text;
    }

    
=head2 gen_via_pitool

Generate Root CA certificate
using the openvpn pkitool

=cut

    sub gen_via_pkitool {
        my ( $self,	$params, $cfg ) = @_;

        # In openssl by default these are commented.
        # To make sure this works, will add it to the
        # end of the file, we will create a temp.
        # ==========================================
        my $_openssl_conf = $cfg->{ssl_config} . '.working';
        copy ( $cfg->{ssl_config}, $_openssl_conf )
            or die "Cannot create a working copy of "
                    . $_openssl_conf . ": " . $!;
    
        # Assign env for openssl.cnf (temporary)
        # ======================================
        $ENV{KEY_CONFIG} = $_openssl_conf;

        # Run the sed command to modify
        # values of the temp openssl.conf
        # ===============================
        my $_sed_cmd = $self->_get_sed_cmd($_openssl_conf);
        my $_ret_val = `$_sed_cmd`;
        return { error => 'Could not update temporary working ' . $_openssl_conf }
            if ( $? >> 8 != 0 );   

        my @_cmd = (
            $cfg->{openvpn_utils} . '/pkitool',
            '--initca'
        );

        unless ( can_run( $cfg->{openvpn_utils} . '/pkitool' ) ){
            unlink $_openssl_conf;
            return { error => 'Cannot run pkitool! ' . $! };
        }

        # Run command
        # ===========
        my ( $success, $error_code, $full_buf ) =
            run( command => [ @_cmd ], verbose => 0, timeout => $TIMEOUT );
    
        unless ( $success ){
            my $err = join( "\n", @{$full_buf} );
            $err =~ /([fault|error].*)$/gi;
            my $fnd = $1;
            $fnd =~ s/'/\\\\\\'/g if $fnd;  
            return {
                error => 'Failed to create Root CA: '
                . ( $fnd ? $fnd : $err )
                . ( $error_code ? ", " . $error_code : '' )
            };
        }
        else {
            return { status => join( "\n", @{$full_buf} ) };
        }
    
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
        my $ca_cert = Crypt::OpenSSL::CA::X509
            ->new( $ca_pubkey );
    
        # Set random seed,
        # Get 16 bytes random data
        # ========================
        my $_random_bytes = $self->get_random_bits(128);
    
        # Convert to hex and set as serial
        # ================================
        $ca_cert->set_serial( '0x' . unpack('H*', $_random_bytes) );
    
        # Set validaty range
        # ==================
        my $_time_now = strftime( $time_format, gmtime(time()) );
        my $_time_yr = strftime( $time_format, gmtime(time() + (
            $ONE_DAY * ( $params->{ca_expire} || $ENV{CA_EXPIRE} || 365 ) )
        ));
        $ca_cert->set_notBefore( $_time_now );
        $ca_cert->set_notAfter( $_time_yr );

        my $ca_dn = Crypt::OpenSSL::CA::X509_NAME->new(
            C               => $params->{KEY_COUNTRY}             || 'NL',
            ST              => $params->{KEY_PROVINCE}            || 'NH',
            L               => $params->{KEY_CITY}                || 'Amsterdam',
            O               => $params->{KEY_ORG}                 || 'Ovpnc',
            OU              => $params->{KEY_OU}                  || 'Development',
            CN              => $params->{KEY_CN}                  || 'Ovpnc CA',
            name            => $params->{name}                    || 'SSL Server CA',
            emailAddress    => $params->{KEY_EMAIL}               || 'nuri@de-bar.com'
        );
    
        $ca_cert->set_issuer_DN($ca_dn);
        $ca_cert->set_subject_DN($ca_dn);
    
        # v3 extention data
        # =================
        $ca_cert->set_extension( basicConstraints => "CA:TRUE", -critical => 0);
    
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

    
=head1 gen_certificate 

USER CERTIFICATE SIGNING REQUEST
Example:
  openssl req -nodes -batch -newkey rsa:1024 -keyout userkey.pem -out user.p10

=cut

    sub gen_certificate {
        my ( $self, $params, $cfg ) = @_;

        # Check that we don't already
        # have some client with this name
        # ================================
        if ( -e $cfg->{openvpn_utils} . '/keys/'
                . $params->{KEY_CN} . '/'
                . $params->{cert_name} . '.crt'
        ) {
            if ( ! $params->{overwrite} ){
                return { error => 'Certificate name \\\''
                        . $params->{cert_name} . '\\\''
                        . ' - already exists' }
            }
        }

        # The Crypt::OpenSSL::PKCS10 does not install
        # nicely on some systems I have tested. To
        # make sure things will work, will use the
        # pkitool over here.
        # ===========================================

        # In openssl by default these are commented.
        # To make sure this works, will add it to the
        # end of the file, we will create a temp.
        # ==========================================
        my $_openssl_conf = $cfg->{ssl_config} . '.working';
        copy ( $cfg->{ssl_config}, $_openssl_conf )
            or die "Cannot create a working copy of "
                    . $_openssl_conf . ": " . $!;

        $ENV{KEY_CONFIG} = $_openssl_conf;

        my $_sed_cmd = $self->_get_sed_cmd($_openssl_conf);
        my $_ret_val = `$_sed_cmd`;
        return { error => 'Could not update temporary working ' . $_openssl_conf }
            if ( $? >> 8 != 0 );

        # Incase cert_type is server
        # ==========================
        if ( $params->{cert_type} eq 'server'){
            if ( my $_gen_server = $self->_generate_server_certificate(
                                   $cfg, $params, $_openssl_conf )
            ){
                # Not undef, then error
                return $_gen_server;
            }
        }
        # Certificate type client
        # =======================
        else {
            if ( my $_gen_client =  $self->_generate_client_certificate(
                                    $cfg, $params, $_openssl_conf )
            ){
                # Not undef, then error
                return $_gen_client;
            }
        }

        # Process the created certificates
        # Check md5 sum, get serial,
        # check if any errors and move
        # client certificates to own dir
        # ================================
        my $_chk_created = $self->_process_created_certifictes(
            $cfg, $params);
        if ( $_chk_created and ref $_chk_created ){
            return $_chk_created;
        }
        else {
            return { error => 'Something went wrong while processing created certificates' };
        }

    }


=head2 gen_crl

Generate CRL - Certificate Revocation List

=cut

    sub gen_crl {
        my ( $self, $params, $cfg ) = @_;
        my ( $ca_privkey, $ca_cert ) = $self->_get_ca_key_and_cert( $cfg );

        # Prepare CRL file
        # ================
        if ( $params->{cert_type} eq 'server' ){
            my $_crl = Crypt::OpenSSL::CA::X509_CRL->new;
            return { error => 'Could not create a CRLv2 object' }
                unless $_crl->is_crlv2();
            $_crl->set_issuer_DN( $ca_cert->get_issuer_DN() );
    
            # Set validaty range
            # ==================
            my $_time_now = strftime($time_format, gmtime(time()) );
            my $_time_month = strftime($time_format, gmtime(time() + $ONE_MONTH ));
            $_crl->set_lastUpdate( $_time_now );
            $_crl->set_nextUpdate( $_time_month );
            my $_crl_data = $_crl->sign( $ca_privkey, 'sha256' );
            open (my $FH, '>', $cfg->{openvpn_utils} . '/keys/crl.pem')
                or die "Cannot open certificate file 'crl.pem' for writing: " . $!;
            print {$FH} $_crl_data;
            close $FH;
        }
        return 1;
    }


=head2 _get_ca_key_and_cert

Read and return the ca.key
and the ca.cert or any other
configured names

=cut

    sub _get_ca_key_and_cert {
        my ( $self, $cfg ) = @_;

        # Get the filename of the CA cert
        # ===============================
        my $ca_cert_file =
            Ovpnc::Controller::Api::Configuration
                ->get_openvpn_param( 'Ca', $cfg->{ovpnc_conf} );

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

        $_keys_dir = $_keys_dir =~ /^\//
    	? $_keys_dir
    	: $cfg->{home} . '/' . $_keys_dir;

        # Get the Root CA key
        # ===================
        my $_ca_key = read_file ( $cfg->{home} . '/' . $ca_key_file, chomp => 1 )
            or return { error =>
                "Cannot read CA key, make sure it has been created." };
        my $ca_privkey = Crypt::OpenSSL::CA::PrivateKey->
            parse( $_ca_key );

        # Get the Root CA certificate
        # ===========================
        my $_ca_cert = read_file ( $cfg->{home} . '/' . $ca_cert_file, chomp => 1 )
            or return { error =>
                "Cannot read CA certificate, make sure it has been created." };
        my $ca_cert = Crypt::OpenSSL::CA::X509->
            parse( $_ca_cert );

        return ( $ca_privkey, $ca_cert );
    }


=head2 get_supported_digests

Get Crypt::OpenSSL supported digests list

=cut

    sub get_supported_digests {
        my @digests = Crypt::OpenSSL::CA::X509_CRL->supported_digests();
        return ( wantarray() ? @digests : join "\n", @digests );
    }



=head2 read_random_entropy

Read random data
Set $really_secure to true
to read from /dev/urandom (slow)

=cut

    sub read_random_entropy {
        my ( $size, $really_secure ) = @_;
        $size ||= 256;
        $really_secure ||= 0;
        open ( my $rand, '<', $really_secure ? '/dev/random' : '/dev/urandom' )
            or die "Unable to read from random";
        binmode $rand;
        my $entropy;
        read $rand, $entropy, ( $size ), 0;
        return $entropy;
}


=head2 set_random_seed

Set OpenSSL random seed source
Set the $really_secure to true
to read from /dev/urandom (slow)

=cut

    sub set_random_seed {
        my ( $self, $size, $really_secure ) = @_;
        $size ||= 256;
        $really_secure ||= 0;
        Crypt::OpenSSL::Random::random_seed(
            read_random_entropy($size, $really_secure)
        ) unless -f '/dev/urandom';

        Crypt::OpenSSL::RSA->import_random_seed()
            or die "Unable to seed the (u)random number generator";

        return 1 if Crypt::OpenSSL::Random::random_status();
    }


=head2 get_random_bits

Get n random bits
Set $really_secure to read
from /dev/urandom which is
much slower, depending on
how much entropy the system has
collected

=cut

    sub get_random_bits {
        my ( $self, $bits, $really_secure ) = @_;

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
            return rand_bits($bits);
        };
    }


=head2 _get_sed_cmd

Accessor to return the sed commands
which modify the temporary openssl.cnf
being used to process certificates

=cut

    sub _get_sed_cmd {
        my ( $self, $openssl_conf ) = @_;
        return <<_OO_;
sed -i 's/^#\\(organizationalUnitName_default = \$ENV::KEY_OU\\)/\\1/' $openssl_conf ;
sed -i 's/^#\\(commonName_default = \$ENV::KEY_CN\\)/\\1/' $openssl_conf ;
sed -i 's/^#\\(name_default = \$ENV::KEY_NAME\\)/\\1/' $openssl_conf ;
sed -i 's/string_mask = nombstr/string_mask = utf8only/' $openssl_conf ;
sed -i -e '/string_mask = utf8only/ a\\utf8        = yes' $openssl_conf ;
_OO_

    }


=head2 _check_cert_errors

Check output buffer of openssl
to check if any errors

=cut

    sub _check_cert_errors{
        my ( $self, $_buf ) = @_;

        if ($_buf =~ /TXT_DB error number 2/g){
            return
                    'Failed to create certificate,' 
                    . ' serial numbers might be in conflict.' 
                    . ' Check the index.txt, serial, serial.old and [%X].pem files';
        }
        elsif ( $_buf =~ /(wrong.*)/ig || $_buf =~ /(error.*)/ig ){
            my $fnd = $1;
            $fnd =~ s/'/\\\\\\'/g if $fnd;
            warn "[error] OpenSSL ERROR: " . $_buf;
            return
                    'Failed to create certificate.' 
                    . ' Index file might be corrupt.'
                    . ( $fnd ? ' Got error: ' . $fnd : '' );
        }
        elsif ( $_buf =~ /.*(Write out database with . new entries.*)[\r\n]*(Data Base Updated.*)/gi ){
            return undef;
        }
    }


=head2 _generate_client_certificate

Generate client certificate via pkitool

=cut

    sub _generate_client_certificate {
        my ( $self, $cfg, $params, $_openssl_conf ) = @_;

        my $_cmd = $cfg->{openvpn_utils} . '/pkitool';
        my $_args = [
            ( $params->{password} ? '--pass' : '' ),
            $params->{cert_name},
        ];

        # If user requested password
        # we use Expect to enter it
        # ==========================
        if ( $params->{password} ) {
            my $exp = Expect->spawn( $_cmd, @{$_args} )
                or die "Cannot spawn command: " . $!;
            $Expect::Debug = 0;
            $Expect::Log_Stdout = 0;
            $exp->expect(2, "Enter PEM pass phrase:");
            $exp->send( $params->{password} . "\n" );
            $exp->expect(2, "","Verifying - Enter PEM pass phrase:");
            $exp->send( $params->{password} . "\n" );
            $exp->soft_close();
        }
        # No password? Run without pass arg
        # =================================
        else {
            my ( $success, $error_code, $full_buf ) =
                run(
                    command => [ $_cmd, @{$_args} ],
                    verbose => 0,
                    timeout => $TIMEOUT
                );
 
            # Remove temporary
            # openssl.conf
            # ================
            unlink $_openssl_conf;

            # Format output buffer
            # ====================
            my $_buf = $self->_format_output( $full_buf );


            # Glob created certificates
            # used to delete in case of
            # need to rollback
            # =========================
            my @_cert_files =
                glob $cfg->{openvpn_utils}
                    . '/keys/' . $params->{cert_name}
                    . '.*';

            # Check for errors
            # ================
            if ( my $_chk_cert = $self->_check_cert_errors($_buf) ){
                warn "[error] $_chk_cert";
                unlink (@_cert_files);
                return { error => $_chk_cert . '; '
                        . ( split /\n/, $_buf )[0] };
            }

            if ( ! $success ) {
                unlink (@_cert_files);
                return { error => ( split /\n/, $_buf )[0] };
            }
        }
    }


=head2 _generate_server_certificate

Generate server certificate via pkitool

=cut

    sub _generate_server_certificate {
        my ( $self, $cfg, $params, $_openssl_conf ) = @_;

        my @_cmd = (
            $cfg->{openvpn_utils} . '/pkitool',
            '--server',
            $params->{cert_name}
        );

        # Check can run
        # =============
        unless ( can_run( $cfg->{ssl_bin} ) ){
            unlink $_openssl_conf;
            return { error => 'Cannot run openssl! ' . $! };
        }
        # Run command
        # ===========
        my ( $success, $error_code, $full_buf ) =
            run( command => [ @_cmd ], verbose => 0, timeout => $TIMEOUT );

        # Remove temporary
        # openssl.conf
        # ================
        unlink $_openssl_conf;

        # Rearrange output data
        # =====================
        my $_buf = $self->_format_output( $full_buf );

        if ( !$success
             or $_buf =~ /(wrong.*)/ig
             or $_buf =~ /(error.*)/ig
        ){
            my $fnd = $1;
            warn "[error] OpenSSL ERROR: " . $_buf;
            $fnd =~ s/'/\\\\\\\\'/g if $fnd; 

            if ( $fnd and $fnd =~ /error|wrong/gi ){
                return {
                    error =>
                        'Failed to create certificate.' 
                        . ' Index file might be corrupt.'
                        . ' Got error: ' . $fnd
                };
            }

            return { error => 'Failed to create csr and key for server: '
                . ( $fnd ? $fnd : $_buf )
                . ( $error_code ? ", " . $error_code : '' )
            };
        }
        return undef;
    }


=head2 _process_created_certifictes

Process server or client certificates
which have just been created,
check md5, move to client dir
and return the details or errors

=cut

    sub _process_created_certifictes{
        my ( $self, $cfg, $params ) = @_;


        # Check that all files
        # have been created,
        # first glob for them
        # =====================
        my @_cert_files =
            glob $cfg->{openvpn_utils}
                 . '/keys/'
                 . $params->{cert_name}
                 . '.*';
        
        # Get the new serial
        # ==================

        my $_serial_cmd = "tail -1 " . $cfg->{openvpn_utils}
                        . "/keys/index.txt | awk {'print \$3'}";
        my $serial = `$_serial_cmd`;
        return { error => 'Could not read serial number from index.txt!' }
            if ( $? >> 8 != 0 );
        chomp($serial);

        # Check if the serial matches
        # a newely created certificate
        # ============================
        unless ( -f $cfg->{openvpn_utils} . '/keys/'
                    . $serial . '.pem'
        ){
            return { error => 'Last serial in index.txt is ' . 
                          $serial . ' but the file '
                          . $serial . '.pem was not created.'
            };
        }

        # Assign client directory
        # =======================
        my $client_cert_dir =
            $cfg->{openvpn_utils}
            . '/keys/'
            . $params->{KEY_CN};

        # Process new certificates
        # ========================
        if ( @_cert_files ){
            
            # Only create a client dir
            # if cert_type is not server
            # ==========================
            if ( $params->{cert_type} ne 'server' 
              && ! -d $client_cert_dir
            ){
                # Create client cert dir
                # ======================
                mkdir $client_cert_dir, 0700
                    or return { error => 'Cannot create certificate directory: ' . $! };
            }

            # Move cert files to
            # client's cert dir.
            # Then check their file
            # size indicates not empty
            # ========================
            my @_certs_ok;
            for ( @_cert_files ){

                # If one of the certs
                # is empty return error
                # =====================
                if ( -s $_ == 0 ){
                    unlink (@_cert_files);
                    return { error => 'Certificate creation failed for ' . $_ };
                }

                # Type client move to
                # client keys directory
                # =====================
                if ( $params->{cert_type} eq 'client' ){

                    move $_,
                         $client_cert_dir . '/' . basename($_)
                            or return { error =>
                                   "Cannot move file '" . $_ . "'"
                                   . ' to ' . $client_cert_dir . '/' . basename($_)
                                   . ': ' . $! }; 

                    push @_certs_ok, $client_cert_dir
                                     . '/' . basename($_)
                        if $_ =~ /\.crt|\.key$/;

                }

                # Type server leave
                # in main keys dir
                # =================
                else {
                    push @_certs_ok, $_
                        if $_ =~ /\.crt|\.key$/;
                }
            }
            if ( @_certs_ok > 0 ){
                push @_certs_ok, { serial => $serial };
                return { resultset => \@_certs_ok };
            }
            else {
                return { error => 'Something went wrong while creating certificates' };
            }
        }
    }


=head2 _format_output

Format output buffer

=cut

    sub _format_output{
        return join( "\n", @{$_[1]} );
    }


=head1 AUTHOR

Nuriel Shem-Tov

=cut

1;
