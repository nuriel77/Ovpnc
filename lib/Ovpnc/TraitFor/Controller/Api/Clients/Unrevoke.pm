package Ovpnc::TraitFor::Controller::Api::Clients::Unrevoke;
use warnings;
use strict;
use IPC::Cmd qw( can_run run );
use Expect;
use Tie::File;
use Fcntl 'O_RDWR';
use Moose::Role;
use namespace::autoclean;
use vars qw( $openvpn_dir $tools );
use constant TIMEOUT   => 5;


=head1 NAME

Ovpnc::TraitFor::Controller::Api::Clients::Unrevoke - Ovpnc Controller Trait

=head1 DESCRIPTION

Unrevoke x509 certificates

=head1 METHODS

=cut



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


=head2 unrevoke_certificate

Unrevoke client certificate

=head2 Example format index.txt

Example of how revoked and non-revoked
lines in the L<index.txt> look like

R       141230142646Z   121230221454Z   0E      unknown /C=US/ST=Louisiana/L=East Baton Rouge Parish/O=X-VPS/OU=Development/CN=bart/name=bart1/emailAddress=nuri@de-bar.com
V       131230162907Z           14      unknown /C=BF/ST=Centre-Sud/L=Nahouri Province/O=X-VPS/OU=Development/CN=bart/name=bart01/emailAddress=nuri@de-bar.com

=cut


sub unrevoke_certificate {
    my ( $self, $client, $ssl_config, $ssl_bin, $cert_name, $passwd ) = @_;

    my $_ret_val;

    $openvpn_dir = $self->openvpn_dir;
    $tools       = $self->openvpn_utils;

    # vars script location
    # ====================
    my $vars = $tools . '/vars';

    # OpenVPN index file for crl
    # ==========================
    my $index_file = $tools . '/keys/index.txt';

    # If single certificate is provided
    # only unrevoke this certificate
    # =================================

    if ( -e $index_file and -w $index_file ) {

        my $regex = $cert_name
            ? qr[^R\t\w+.*\/CN=$client\/name=$cert_name\/.*$]
            : qr[^R\t\w+.*\/CN=$client\/name=.*$];

        my $_qchk = 0;

        my $o = tie my @array, 'Tie::File', $index_file, mode => O_RDWR;
        $o->flock;

        # Remove revoked fields
        # =====================
        for (@array){
            if ( /$regex/ ) {
                my @line = split /\t/;
                $line[0] = 'V';
                $line[2] = '';
                $_ = join "\t", @line;
                undef(@line);
                $_qchk++;
            }
        }
        undef $o;
        untie @array;

        # Check exit status
        # =================
        return { errors => ['Un-revocation failure for ' . $client . ': ' . $_ret_val ]}
            if $_qchk == 0;

        # Regenerate the crl.pem
        # ======================
        my $_cmd = $ssl_bin;
        my $_args = [ 'ca', '-gencrl', '-config', $ssl_config, '-out', $tools . '/keys/crl.pem' ];

        unless ( can_run($ssl_bin) ){
            return { errors => [ 'Cannot run ' . $ssl_bin ] };
        }

        if ( $passwd ){
            $Expect::Debug = 0;
            $Expect::Log_Stdout = 0;
            my ($error, $buf);
            my $exp = Expect->new;
            #$exp->log_file('/tmp/exp.txt', 'w');
            $exp->exp_internal( 0 );
            $exp->spawn( $_cmd, @{$_args} ) or die "Cannot spawn command: " . $!;
            $exp->expect(
                2,
                [
                    qr/Enter pass phrase for.*/,
                    sub { $exp->send( $passwd . "\n" ); exp_continue; },
                ],
            );

            $exp->soft_close();
            return { status => [ ( $cert_name ? 'Certificate ' . $cert_name : $client ) . ' unrevoked ok' ] }
        }
        else {
            # Run command
            # ===========
            my ( $success, $error_code, $full_buf ) =
                run( command => [ $_cmd, @{$_args} ], verbose => 0, timeout => TIMEOUT );

            $_ret_val = join( "\n", @{$full_buf} );
            $_ret_val =~ s/\n/;/g;
    
            if ( $success ){
                return { status => [ ( $cert_name ? 'Certificate ' . $cert_name : $client ) . ' unrevoked ok' ] }
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
