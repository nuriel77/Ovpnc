package Ovpnc::TraitFor::Controller::Api::Certificates::Archive;
use warnings;
use strict;
use Cwd;
use Try::Tiny;
use Archive::Tar;
use Moose::Role;


=head1 NAME

Ovpnc::TraitFor::Controller::Api::Certificates::Archive - Ovpnc Controller Trait

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

        my $compression;
        $compression = 'COMPRESS_BZIP' if $format eq 'bzip';
        $compression = 'COMPRESS_GZIP' if $format eq 'gzip';

        if ( my $error = $self->_run_type_supported_check($format) ){
            return $error;
        }

        my $keys_dir = $c->config->{openvpn_dir} =~ /^\//
            ? $self->_cfg->{openvpn_utils} . '/keys'
            : $self->_cfg->{home} . '/' . $self->_cfg->{openvpn_utils} . '/keys';

        my $current_dir = getcwd;

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

        if ( $rs == 0 ) {
            return { resultset => [] };
        }

        my $tar = Archive::Tar->new;
        my ( @files, @errors );
        my $client_keys_dir;
        while ( my $cert = $rs->next ){

            if ( -f $cert->key_file and -f $cert->cert_file ){

                $client_keys_dir = $cert->cert_type =~ /server|ca/
                    ? $keys_dir
                    : $keys_dir . '/' . $client;

                chdir $client_keys_dir
                    or push @errors, $client . ': Cannot enter directory of client certificates: ' . $_;

                $tar->add_files( $cert->name . '.crt', $cert->name . '.key' )
                    or push @errors, $client . ': Failed to initialize archive class: '
                                     . $tar->error;

                try {
                    $tar->write( $client_keys_dir . '/' . $cert->name . '.' . $format, $compression )
                        or push @errors,
                                 $client . ': Failed to create ' . $format . ' for '
                                . $cert->name . ': ' . $tar->error;
                };

                if ( $rs == 1 ){
                     push @files, $client_keys_dir . '/' . $cert->name . '.' . $format
                         if -f $client_keys_dir . '/' . $cert->name . '.' . $format;
                }
                else {
                    push @files, $cert->name . '.' . $format;
                }
            }
        }

        if ( $rs > 1 ) {
            $tar->add_files( \@files );
            try {
                $tar->write( $client_keys_dir . '/' . $client . '.' . $format, $compression )
                    or push(@errors, $client  . ': Failed to create '
                                    . $format . ' for all certificates / keys: ' . $tar->error
                       );

                unlink(@files);
                $#files = -1;
                push @files, $client_keys_dir . '/' . $client . '.' . $format;
            };
        }
        unlink('tmp/') if -d 'tmp/session';
        chdir $current_dir;
        return { resultset => [ @files ], errors => [ @errors ] };
    }


=head2 _run_type_supported_check

Check if this type can be used
on this system

=cut

    sub _run_type_supported_check {
        my ( $self, $format ) = @_;

        if ( $format eq 'bzip' ){
            return { error => 'zlib support/libraries missing' }
                unless Archive::Tar->has_bzip_support;
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

