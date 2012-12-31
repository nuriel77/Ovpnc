package Ovpnc::TraitFor::Controller::Api::Clients::Revoke;
use warnings;
use strict;
use File::Basename;
use IPC::Cmd qw( can_run run );
use Moose::Role;
use namespace::autoclean;
use vars qw( $openvpn_dir $tools $vars $_ret_val );
use constant TIMEOUT    => 5;



=head1 NAME

Ovpnc::TraitFor::Controller::Api::Clients::Revoke - Ovpnc Controller Trait

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
        my ( $self, $clients, $cert_names ) = @_;

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
                $self->rval->{$clients->[$i]} =
                    {
                        errors => [],
                        warnings => [],
                        status => []
                    };

                for my $cert ( glob $tools . '/keys/' . $clients->[$i] . '/*.crt' ){
                    $_chk++;
                    $cert =~ s{\.[^.]+$}{};
                    $self->_revoke_certificate( $tools, $cert, $clients->[$i] );
                }

                push (@{$self->rval->{$clients->[$i]}->{warnings}}, 'Has no certificates')
                    unless ($_chk);
            }
            else {
                $self->rval->{$cert_names->[$i]} =
                    {
                        errors => [],
                        warnings => [],
                        status => []
                    };
                $self->_revoke_certificate( $tools, $cert_names->[$i], $clients->[$i] );
            }
    
        }

        return $self->rval;
    }


=head2 _revoke_certificate

Revoke a certificate - private

=cut

    sub _revoke_certificate {
        my ( $self, $revoke_tool, $cert, $client ) = @_;

        # Build command
        # =============
        my @_cmd = ( $revoke_tool, $cert );

        # Run command
        # ===========
        my ($success, $error_code, $full_buf, $stdout_buf, $stderr_buf) =
            run( command => [ @_cmd ], verbose => 0, timeout => TIMEOUT );

        my $_check_ret_val = join( "\n", @{$full_buf} );
        $_check_ret_val =~ s/\n/;/g;

        if ( $success ){
            # Already in revoke list
            # ======================
            if ( $_check_ret_val =~ /already revoked/gi ){
                push @{$self->rval->{$client}->{warnings}},
                        "Revocation failure, certificate "
                       . basename($cert) . ": Already revoked";
            }
            # Didn't find certificate
            # =======================
            elsif ( $_check_ret_val =~ /No such file or directory/gi ){
                push @{$self->rval->{$client}->{errors}},
                    "Revocation failure, certificate ". basename($cert) . ": "
                      . "No such certificates";
            }
            # ERROR in output
            # ===============
            elsif ( $_check_ret_val =~ /ERROR:(.*)/gi ) {
                push @{$self->rval->{$client}->{errors}},
                       "Revocation failure, certificate " . basename($cert) . ": "
                      . ( $1 ? '\': ' . $1 : '\'' ) .';';
            }
            # If we match this, certificate
            # has been revoked successfully
            # =============================
            elsif ( $_check_ret_val =~ /error 23.*certificate revoked/g ) {
                push @{$self->rval->{$client}->{status}},
                    'Certificate ' . basename($cert) . ' revoked ok';
            }
            # Anything else is unknown
            # ========================
            else {
                push @{$self->rval->{$client}->{warnings}},
                    'Certificate ' . basename($cert) . ' unknown status: '
                    . ( $_check_ret_val ? ': ' . $_check_ret_val : '' ).';';
            }
    
        }
        # Could be a timeout (if yes, it will
        # appear in the error_code)
        # ===================================
        else {
            push @{$self->rval->{$client}->{errors}},
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
