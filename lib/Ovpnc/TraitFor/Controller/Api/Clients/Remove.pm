package Ovpnc::TraitFor::Controller::Api::Clients::Remove;
use warnings;
use strict;
use Try::Tiny;
use Moose::Role;
use namespace::autoclean;



=head1 NAME

Ovpnc::TraitFor::Controller::Api::Clients::Remove - Ovpnc Controller Trait

=head1 DESCRIPTION

Remove a client

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

    
=head2 remove_clients

Remove a list of clients

=cut

    sub remove_clients {
        my ( $self, $c, $client_list, $ccd_dir ) = @_;

        my @clients = map { $_ if $_ ne '' } split ',', $client_list;
        my ( @_delete_ok , @_not_ok , @_errors );

    CLIENT:
        for my $client (@clients){
            # Find client in database
            # =======================
            my $_res;
            try {
                 $_res = $c->model('DB::User')->find({ username => $client });
            }
            catch {
                push @_errors, $_;
            };

            if ( $_res ){
                # Deny removal of default
                # administrator user
                # =======================
                if ( $_res->id == 1 ){
                    push @_not_ok, $client;
                    push @_errors,
                        $client . ": Denied. Cannot delete the default administrator!";
                    next CLIENT;
                }
                else {
                    # Delete entry
                    # ============
                    if ( $_res->delete ) {
                        push (@_delete_ok, $client);
                    }
                    else {
                        push (@_not_ok, $client);
                    }
                    # Remove any ccd file
                    # ===================
                    if ( -e $ccd_dir . '/' . $client and -d $ccd_dir . '/' . $client){
                        unlink $ccd_dir . '/' . $client
                            or push (@_not_ok, $client);
                    }
                }
            }
        }

        return \@_delete_ok, \@_not_ok, \@_errors;

    }



=head1 AUTHOR

Nuriel Shem-Tov

=cut

1;
