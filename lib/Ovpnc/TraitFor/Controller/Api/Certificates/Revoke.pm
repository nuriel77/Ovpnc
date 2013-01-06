package Ovpnc::TraitFor::Controller::Api::Certificates::Revoke;
use warnings;
use strict;
use File::Basename;
use Expect;
use IPC::Cmd qw( can_run run );
use Moose::Role;
use namespace::autoclean;
use vars qw( $openvpn_dir $tools $vars $_ret_val );
use constant TIMEOUT    => 5;



=head1 NAME

Ovpnc::TraitFor::Controller::Api::Certificates::Revoke - Ovpnc Controller Trait

=head1 DESCRIPTION

Revoke x509 certificates

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

has rval => (
    is       => 'rw',
    isa      => 'HashRef',
);

=head2 revoke_certificate

Revoke certificate(s)

=cut

    sub revoke_certificate {
        my ( $self, $clients, $cert_names, $serials, $passwd ) = @_;

        $openvpn_dir = $self->_set_openvpn_dir;
        $tools = $self->_set_openvpn_utils;

        # Vars script location
        # ====================
        $vars = $tools . '/vars';

        # Check can run tool
        # ==================
        unless ( can_run( $tools . '/revoke-full' ) ){
            return { error => "Error revoking certificate(s), cannot run "
                             . $tools . '/revoke-full' };
        }

        $tools .= '/revoke-full';

        $self->rval({});

        for my $i ( 0 .. $#{$clients} ){

            # Revoke certificates - when $cert_names
            # has been provided revoke only these
            # certificates, otherwise all certificates
            # belonging to the client (found in his dir)
            # ==========================================
            unless ( $cert_names ){ 

                my $_chk = 0;

                # Prepare a return object
                # for client status/errors
                # ========================
                for my $cert ( glob $self->_set_openvpn_utils . '/keys/' . $clients->[$i] . '/*.crt' ){
                    $_chk++;
                    $cert =~ s{\.[^.]+$}{};
                    $self->_revoke_certificate( 'all', $tools, $cert, $clients->[$i], $serials->[$i], $passwd );
                }

                push (@{$self->rval->{$clients->[$i]}->{warnings}}, 'Has no certificates')
                    unless ($_chk);
            }
            else {
                $self->_revoke_certificate( 'single', $tools, $cert_names->[$i], $clients->[$i], $serials->[$i], $passwd );
            }
    
        }
        return $self->rval;
    }


=head2 _revoke_certificate

Revoke a certificate - private

=cut

    sub _revoke_certificate {
        my ( $self, $action, $revoke_tool, $cert, $client, $serial, $passwd ) = @_;

        die "No cert?" unless $cert;

        # Build command
        # =============
        my $_cmd = $revoke_tool;
        my $_args = [ $cert ];
        my ($success, $error_code, $full_buf, $stdout_buf, $stderr_buf, $_check_ret_val );
		#my $e_obj = $action eq 'all' ? $client : basename($cert);
		my $e_obj = $client;

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
                [
                    qr/ERROR:Already revoked.*/,
                    sub {
                            push @{$self->rval->{$e_obj}->{errors}},
                                 'Certificate ' . basename($cert) . ' is already revoked';
                            exp_continue;
                        },
                ],
                [
                	qr/No such file or directory|Error opening certificate file.*/,
                	sub {
                            push @{$self->rval->{$e_obj}->{errors}},
                                 'Certificate ' . basename($cert) . ' is not found or corrupt'
                                 unless grep 'Certificate ' . basename($cert) . ' is not found or corrupt', 
                                 			@{$self->rval->{$e_obj}->{errors}};
                            exp_continue;
                        },
                ],
            );

            $buf = $exp->before();
    		if  ( $buf =~ /(unable to load CA private key)/gi ){
				push @{$self->rval->{$e_obj}->{errors}},
                   		'Error! Wrong password for CA private key: ' . $1
                   unless grep 'Error! Wrong password for CA private key: ' . $1,
                                 			@{$self->rval->{$e_obj}->{errors}};
                $exp->soft_close;
                return;
    		}
    		elsif ( $buf =~ /ERROR:Already revoked.*/gi ){
				push @{$self->rval->{$e_obj}->{errors}},
	               		'Certificate ' . basename($cert) . ' is already revoked';  			
    		}
    		
            $exp->soft_close();

            if ( $self->rval->{$e_obj}->{errors}
              && ref $self->rval->{$e_obj}->{errors} eq 'ARRAY'
              && @{$self->rval->{$e_obj}->{errors}} > 0
            ){
                return;
            }
            else {
                push @{$self->rval->{$e_obj}->{status}},
                     'Certificate ' . basename($cert) . ' revoked ok';
            }
            return 1;
        }
        else {
            # Run command
            # ===========
            ($success, $error_code, $full_buf, $stdout_buf, $stderr_buf) =
                run(
                    command => [ $_cmd, @{$_args} ],
                    verbose => 0,
                    timeout => TIMEOUT
                );

            $_check_ret_val = join( "\n", @{$full_buf} );
            $_check_ret_val =~ s/\n/;/g;
        }

        if ( $success ){
            # Already in revoke list
            # ======================
            if ( $_check_ret_val =~ /already revoked/gi ){
                push @{$self->rval->{$e_obj}->{warnings}},
                        "Revocation failure, certificate "
                       . basename($cert) . ": Already revoked";
            }
            # Didn't find certificate
            # =======================
            elsif ( $_check_ret_val =~ /No such file or directory/gi ){
                push @{$self->rval->{$e_obj}->{errors}},
                    "Revocation failure, certificate ". basename($cert) . ": "
                      . "No such certificates";
            }
            # ERROR in output
            # ===============
            elsif ( $_check_ret_val =~ /ERROR:(.*)/gi ) {
                push @{$self->rval->{$e_obj}->{errors}},
                       "Revocation failure, certificate " . basename($cert) . ": "
                      . ( $1 ? '\': ' . $1 : '\'' ) .';';
            }
            # If we match this, certificate
            # has been revoked successfully
            # =============================
            elsif ( $_check_ret_val =~ /error 23.*certificate revoked/g ) {
                push @{$self->rval->{$e_obj}->{status}},
                    'Certificate ' . basename($cert) . ' revoked ok';
            }
            # Anything else is unknown
            # ========================
            else {
                push @{$self->rval->{$e_obj}->{warnings}},
                    'Certificate ' . basename($cert) . ' unknown status: '
                    . ( $_check_ret_val ? ': ' . $_check_ret_val : '' ).';';
            }
    
        }
        # Could be a timeout (if yes, it will
        # appear in the error_code)
        # ===================================
        else {
            push @{$self->rval->{$e_obj}->{errors}},
                basename($cert) . ' got timeout out error(?): ' . $_check_ret_val . ';'
                . ( $error_code ? $error_code : '' ).';';
        }

    }


=head2 _set_openvpn_utils

Set the openvpn_utils path

=cut

    sub _set_openvpn_dir{
        my $self = shift;
        return ( $self->openvpn_dir =~ /^\//
                  ? $self->openvpn_dir
                  : $self->home . '/' . $self->openvpn_dir );
    }


=head2 _set_openvpn_utils

Set the openvpn_utils path

=cut

    sub _set_openvpn_utils {
        my $self = shift;
          return ( $self->openvpn_utils =~ /^\//
                    ? $self->openvpn_utils
                    : $openvpn_dir . '/' . $self->openvpn_utils );
    }


=head1 AUTHOR

Nuriel Shem-Tov

=cut

1;
