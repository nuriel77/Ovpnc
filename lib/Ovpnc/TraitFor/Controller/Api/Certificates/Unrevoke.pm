package Ovpnc::TraitFor::Controller::Api::Certificates::Unrevoke;
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

Ovpnc::TraitFor::Controller::Api::Certificates::Unrevoke - Ovpnc Controller Trait

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
        my ( $self, $args ) = @_;

        my $client      = $args->{client}       || die "No client?";
        my $ssl_config  = $args->{ssl_config}   || die "No ssl_config?";
        my $ssl_bin     = $args->{ssl_bin}      || die "No ssl_bin?";
        my $cert_name   = $args->{certificate}  if $args->{certificate};
        my $serial      = $args->{serial}       if $args->{serial};
        my $passwd      = $args->{ca_password}  if $args->{ca_password};
    
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
                ? qr[^R.*$serial.*\/C.*\/CN=$client\/name=$cert_name\/.*$]
                : qr[^R\t\w+.*\/CN=$client\/name=.*$];
    
            my $_qchk = 0;
    
            my $o = tie my @array, 'Tie::File', $index_file, mode => O_RDWR;
            $o->flock;
    
            # Remove revoked fields
            # =====================
			my $rb_revoke = [];
            for (@array){
                if ( /$regex/ ) {
                    my @line = split /\t/;
                    $line[0] = 'V';
                   	$rb_revoke->[$_qchk] = $line[2];
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
            return { warnings => [ 'Could not find a revoked entry in the index file' ]}
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
                $buf = $exp->before();
    			if ( $buf =~ /(unable to load CA private key)/ ){
    				$regex = $cert_name
                		? qr[^V.*$serial.*\/C.*\/CN=$client\/name=$cert_name\/.*$]
                		: qr[^V\t\w+.*\/CN=$client\/name=.*$];
    				my $err = $1;
					my $rb_o = tie my @rb_array, 'Tie::File', $index_file, mode => O_RDWR;
	           		$rb_o->flock;
	           		my $_chk = 0;
            		for (@rb_array){
		                if ( /$regex/ ) {
		                    my @line = split /\t/;
		                    $line[0] = 'R';
		                    $line[2] = shift @{$rb_revoke};
		                    $_ = join "\t", @line;
		                    undef(@line);
		                    $_chk++;
		                }
            		}
            		undef $rb_o;
            		untie @rb_array;
					$err .= $regex . '... index.txt did not roll-back.' if $_chk == 0;
                	$exp->soft_close;
                	return { errors => [ 'Error! Wrong password for CA private key: ' . $err ] };
                }
               
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

=head1 AUTHOR

Nuriel Shem-Tov

=cut
    
1;
