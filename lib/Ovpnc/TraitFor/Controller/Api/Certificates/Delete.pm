package Ovpnc::TraitFor::Controller::Api::Certificates::Delete;
use warnings;
use strict;
use Try::Tiny;
use Moose::Role;


=head1 NAME

Ovpnc::TraitFor::Controller::Api::Certificates::Delete - Ovpnc Controller Trait

=head1 DESCRIPTION

Ovpnc Certificates - Delete

=head1 METHODS

=cut



=head2 delete_certificates

Delete Certificates

=cut

    sub delete_certificates {
        my $self = shift;
        my @certificates = @{(shift)};

        my $_ret_val;

        # Set openvpn utils dir
        # =====================
        $self->_cfg->{openvpn_utils} = $self->_cfg->{openvpn_utils} =~ /^\//
            ? $self->_cfg->{openvpn_utils}
            : $self->_cfg->{home} . '/' . $self->_cfg->{openvpn_utils};

        # Determine the keys dir
        # ======================
        my $keys_dir = $self->_cfg->{openvpn_utils} . '/keys/';

        for my $cert ( @certificates ){
            my $collector = {
                $cert->name => {
                    warnings => [],
                    errors   => [],
                    status   => []
                }
            };
            my $user = $cert->user;

            # Client certificate has client's
            # username prepended to it
            # ===============================
            my $_dir = $cert->cert_type eq 'client'
                ? $keys_dir . $user->username . '/' . $cert->name . '.*'
                : $keys_dir . $cert->name . '.*';

            # Remove the certificate serial pem
            # =================================
            if ( $cert->cert_type ne 'ca' ){
                my $serial_cert_file = $keys_dir . $cert->key_serial . '.pem';
                if ( -f $serial_cert_file ){
                    unlink $serial_cert_file
                        or push @{$collector->{$cert->name}->{warnings}},
                                'Cannot remove serial certificate file '
                                . $serial_cert_file . ': ' . $!;
                }
                else {
                    push @{$collector->{$cert->name}->{warnings}},
                         'Cannot remove serial certificate file '
                         . $serial_cert_file . ': does not exists';
                         
                }
            }
            # If CA is being remove, remove
            # all files which are not needed
            # ==============================
            elsif ( $cert->cert_type eq 'ca' ){
                for (
                    glob ($keys_dir . 'index.txt*'),
                    glob ($keys_dir . 'crl*'),
                    glob ($keys_dir . 'serial*'),
                    glob ($keys_dir . '*old'),
                ){
                    unlink ($_)
                        or push @{$collector->{$cert->name}->{errors}},
                             'Cannot remove old index, crl and serial: ' . $_;
                }
            }
            
            # Delete all certificates and keys
            # ================================
            unlink ( glob ( $_dir ) )
                or push @{$collector->{$cert->name}->{errors}},
                        'Cannot remove certificate(s): ' . $!;
            
            # Delete certificate from database
            # ================================
            try {
                if ( $cert->delete ) {
                    push @{$collector->{$cert->name}->{messages}},
                         'Certificate removed ok';
                }
            }
            catch {
                push @{$collector->{$cert->name}->{errors}},
                     'Failed to remove certificate from database: '
                     . (split /\n/, $_)[0];
            };

            push @{$_ret_val}, $collector;
        }

        return $_ret_val;

    }


=head1 AUTHOR

Nuriel Shem-Tov

=cut

1;
