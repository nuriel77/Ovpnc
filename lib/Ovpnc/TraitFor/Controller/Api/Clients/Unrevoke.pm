package Ovpnc::TraitFor::Controller::Api::Clients::Unrevoke;
use warnings;
use strict;
use Moose::Role;
use namespace::autoclean;
use vars qw( $openvpn_dir $tools );

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

has app_root => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

sub unrevoke_certificate {
    my ( $self, $client, $ssl_config, $ssl_bin ) = @_;

    my $_ret_val;

    $openvpn_dir =
        $self->openvpn_dir =~ /^\//
      ? $self->openvpn_dir
      : $self->app_root . '/' . $self->openvpn_dir;

    $tools =
        $self->openvpn_utils =~ /^\//
      ? $self->openvpn_utils
      : $openvpn_dir . '/' . $self->openvpn_utils;

    # vars script location
    # ====================
    my $vars = $tools . '/vars';

    # OpenVPN index file for crl
    # ==========================
    my $index_file = $tools . '/keys/index.txt';

    if ( -e $index_file and -w $index_file ) {

        # Change the revocation in the index.txt
        # ======================================
        my $command =
"/bin/sed -i 's/^R[[:space:]]*\\([a-zA-Z0-9]*\\)[[:space:]][a-zA-Z0-9]*[[:space:]]\\([0-9]*[[:space:]].*\\/CN=$client\\/.*\\)/V\\t\\1\\t\\t\\2/g' $index_file";

        # Run command
        # ===========
        $_ret_val = `$command`;
        chomp($_ret_val);

        # Check exit status
        # =================
        if ( $? >> 8 != 0 ) {
            return 'Un-revocation failure for ' . $client . ': ' . $_ret_val;
        }

        my $_openssl_config =
            $ssl_config =~ /^\//
                ? $ssl_config
                : $tools . '/' . $ssl_config;

        # Regenerate the crl.pem
        # ======================
        $command =
            $ssl_bin
          . ' ca -gencrl -config '
          . $_openssl_config
          . ' -out '
          . $tools
          . '/keys/crl.pem';

        # vars script location
        # ====================
        my $vars = $tools . '/vars';

        # Run command
        # TODO: Replace with IPC::Cmd
        # TODO: Get vars from certificates trait
        # ===========
        $_ret_val = `cd $tools && . $vars >/dev/null && $command && cd - 2>&1`;
        chomp($_ret_val);

        # Check exit status
        # =================
        if ( $? >> 8 != 0 ) {
            return
                'Un-revocation failure for '
              . $client
              . ' while regenerating crl.pem: '
              . $_ret_val;
        }
        else {
            return 'Un-revocation success for ' . $client . ': ' . $_ret_val;
        }
    }
    else {
        return
            'Un-revocation failure for '
          . $client
          . ' as index file does not exists or is not accessible: '
          . $index_file;
    }
}

1;
