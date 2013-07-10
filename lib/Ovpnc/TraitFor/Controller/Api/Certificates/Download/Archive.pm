package Ovpnc::TraitFor::Controller::Api::Certificates::Download::Archive;
use warnings;
use strict;
use File::Copy;
use Cwd;
use Try::Tiny;
use Archive::Tar;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Moose::Role;


=head1 NAME

Ovpnc::TraitFor::Controller::Api::Certificates::Download::Archive - Ovpnc Controller Trait

=head1 DESCRIPTION

Archive certificates + keys
of clients and return array
of archive files to be downloaded

=head1 METHODS

=cut

has _cfg => (
    is => 'ro',
    isa => 'HashRef',
);


=head2 archive_certificates

Archive and download
certificates and keys

=cut

    sub archive_certificates {
        my ( $self, $c, $client, $format, $certs ) = @_;

        # Set correct extension 
        # and compression type
        # =====================
        my $compression = '';
        my $extension = 'tar';

        if ( $format eq 'bzip' ){
            $compression = 'COMPRESS_BZIP';
            $extension .= '.bz2';
        }
        elsif ( $format eq 'gzip' ){
            $compression = 'COMPRESS_GZIP';
            $extension .= '.gz';
        }
        elsif ( $format eq 'zip' ){
            $compression = 'SEND_TO_ZIP';
            $extension = 'zip';
        }

        if ( my $error = $self->_run_type_supported_check( $format ) ){
            return $error;
        }

        # Set keys directory
        # ==================
        my $keys_dir = $c->config->{openvpn_dir} =~ /^\//
            ? $self->_cfg->{openvpn_utils} . '/keys'
            : $self->_cfg->{home} . '/' . $self->_cfg->{openvpn_utils} . '/keys';

        my $current_dir = getcwd;

        # If user request 'all' certificates
        # undef certs so the query will result
        # with all the certificates for this client
        # =========================================
        $certs = undef if $certs eq 'all';
        my @cert_names = map { $_ if $_ ne '' } split ',', $certs
            if $certs;

        my $_ret_val = {};

        my $rs = $c->model('DB::Certificate')->search(
                (
                    @cert_names
                        ? { user => $client, name => { in => \@cert_names } }
                        : { user => $client }
                ),
                { select => [ qw/ name key_file cert_file cert_type /] }
        );

        return { resultset => [] }
            if ( $rs == 0 );

        # New Archive object
        # ==================
        my ($tar, $zip);
        unless ( $format eq 'zip' ){
            $tar = Archive::Tar->new;
        }
        else {
            $zip = Archive::Zip->new;
        }
    
        my ( @files, @errors );
        my $client_keys_dir;

        while ( my $cert = $rs->next ){

            if ( -f $cert->key_file and -f $cert->cert_file ){

                # Setup path name, only client type
                # get the client name prepended
                # to the certificate name
                # =================================
                $client_keys_dir = $cert->cert_type =~ /server|ca/
                    ? $keys_dir
                    : $keys_dir . '/' . $client;

                chdir $client_keys_dir
                    or push @errors, $client . ': Cannot enter directory of certificates: ' . $_;

                warn "Start creating archive...\n";
                if ( ( -f $keys_dir . '/ca.crt' && -f $keys_dir . '/ta.key' )
                  and $cert->cert_type !~ /server|ca/
                ){
                    copy ( $keys_dir . '/ca.crt', $client_keys_dir . '/ca.crt' );
                    copy ( $keys_dir . '/ta.key', $client_keys_dir . '/ta.key' );
                }

                # Add the files to the archive
                # ============================
                unless ( $zip ){
                    $tar->add_files( $cert->name . '.crt', $cert->name . '.key', 'ca.crt', 'ta.key' )
                        or push @errors, $client . ': Failed to initialize archive class: '
                                         . $tar->error;
                    warn "Adding " . $cert->name . " to bundle\n";
                    # Write the archive file to disk
                    # ==============================
                    eval {
                        $tar->write( $client_keys_dir . '/' . $cert->name . '.' . $extension, $compression );
                    };
                    if ($@){
                        warn "Cannot write tar file: $@\n";
                        push @errors,
                                 $client . ': Failed to create ' . $extension . ' for '
                                 . $cert->name . ': ' . $tar->error;
                    };

                    # Clear the object
                    # ================
                    $tar->clear;
                }
                else {
                    $zip->addFile( $cert->name . '.crt' );
                    $zip->addFile( $cert->name . '.key' );
                    $zip->addFile( 'ca.crt' ) if -f 'ca.crt';
                    $zip->addFile( 'ta.key' ) if -f 'ta.key'; 
                    unless ( $zip->writeToFileNamed( $client_keys_dir . '/' . $cert->name . '.' . $extension ) == AZ_OK ){
                        push @errors,
                              $client . ': Failed to create ' . $extension . ' for '
                              . $cert->name . ': ' . $tar->error;
                    }
                }

                unlink ( 'ta.key', 'ca.crt' ) unless $cert->cert_type =~ /server|ca/;

                if ( $rs == 1 ){
                     push @files, $cert->name . '.' . $extension
                         if -f $client_keys_dir . '/' . $cert->name . '.' . $extension;
                }
                else {
                    push @files, $cert->name . '.' . $extension;
                }
            }
        }

        # If just one certificate we
        # name the archive file as the
        # certificate's name. If multiple
        # we set the name to the client's
        # ===============================
        if ( @files > 0 ) {
            if ( $format ne 'zip' ){
                $tar->clear;
                $tar = Archive::Tar->new;
                $tar->add_files( @files );
                try {
                    $tar->write( $client_keys_dir . '/' . $client . '.' . $extension, $compression )
                        or push(@errors, $client  . ': Failed to create '
                                        . $extension . ' for all certificates / keys: ' . $tar->error
                           );
                };
            }
            else {
                $zip->addFile( $_ ) for @files;
                unless ( zip->writeToFileNamed('someZip.zip') == AZ_OK ) {
                    push(@errors, $client  . ': Failed to create '
                                   . $extension . ' for all certificates / keys')
                }
            }
            
            # Remove the temporary archivce files
            # ===================================
            unlink(@files);

            # Empty the array
            # ===============
            $#files = -1;

            # Place the new name into the array
            # =================================
            push @files, $client_keys_dir . '/' . $client . '.' . $extension;
        }
        unlink('tmp/') if -d 'tmp/session';
        chdir $current_dir;
        return { resultset => [ @files ], errors => [ @errors ] };
    }


=head2 _run_type_supported_check
;
Check if this type can be used
on this system

=cut

    sub _run_type_supported_check {
        my ( $self, $format ) = @_;

        if ( $format eq 'bzip' ){
            return { error => 'bzip2 support/libraries missing' }
                unless Archive::Tar->has_bzip2_support;
        }
        else {
            return { error => 'zlib support/libraries missing' }
                unless Archive::Tar->has_zlib_support;
        }
        
        return { error => 'Cannot handle compressed files!' }
            unless Archive::Tar->can_handle_compressed_files;

        return undef;
    }


=head1 AUTHOR

Nuriel Shem-Tov

=cut

1;

