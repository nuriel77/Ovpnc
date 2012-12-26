package Ovpnc::TraitFor::Controller::Api::Clients::Unrevoke;
use warnings;
use strict;
use IPC::Cmd qw( can_run run );
use Moose::Role;
use namespace::autoclean;
use vars qw( $openvpn_dir $tools );
use constant TIMEOUT   => 5;

has openvpn_dir => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has openvpn_utils => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has home => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

sub unrevoke_certificate {
    my ( $self, $client, $ssl_config, $ssl_bin, $cert_name ) = @_;

    my $_ret_val;

    $openvpn_dir = $self->openvpn_dir;
    $tools = $self->openvpn_utils;

    # vars script location
    # ====================
    my $vars = $tools . '/vars';

    # OpenVPN index file for crl
    # ==========================
    my $index_file = $tools . '/keys/index.txt';

    # If single certificate is provided
    # only unrevoke this certificate
    # =================================
    my $command = $cert_name
        ?
"/bin/sed -i 's/^R[[:space:]]*\\([a-zA-Z0-9]*\\)[[:space:]][a-zA-Z0-9]*[[:space:]]\\([0-9]*[[:space:]].*\\/CN=$client\\/name=$cert_name\\/.*\\)/V\\t\\1\\t\\t\\2/g' $index_file"
        : 
"/bin/sed -i 's/^R[[:space:]]*\\([a-zA-Z0-9]*\\)[[:space:]][a-zA-Z0-9]*[[:space:]]\\([0-9]*[[:space:]].*\\/CN=$client\\/.*\\)/V\\t\\1\\t\\t\\2/g' $index_file";

    if ( -e $index_file and -w $index_file ) {

        # Run command
        # ===========
        $_ret_val = `$command`;
        chomp($_ret_val);

        # Check exit status
        # =================
        if ( $? >> 8 != 0 ) {
            return { errors => ['Un-revocation failure for ' . $client . ': ' . $_ret_val ]};
        }

        # Regenerate the crl.pem
        # ======================
        my @_cmd = (
            $ssl_bin,
            'ca',
            '-gencrl',
            '-config',
            $ssl_config,
            '-out',
            $tools . '/keys/crl.pem'
        );

        unless ( can_run($ssl_bin) ){
            return { errors => [ 'Cannot run ' . $ssl_bin ] };
        }

        # Run command
        # ===========
        my ( $success, $error_code, $full_buf ) =
            run( command => [ @_cmd ], verbose => 0, timeout => TIMEOUT );

        $_ret_val = join( "\n", @{$full_buf} );
        $_ret_val =~ s/\n/;/g;

        if ( $success ){
            return { status => [ 'Unrevoked ok' ] }
        }
        else {
            return {
                errors => [
                    'Un-revocation failure: '
                    . ( $error_code ? ': ' . $error_code : '' )
                    . ( $_ret_val ? ', ' . $_ret_val : '' )
                ]
            };
        }
    }
    else {
        return {
            errors => [
                'Un-revocation failure: '
                . ' OpenVPN index file does not exists or is not accessible: '
                . $index_file
            ]
        };
    }
}

1;
