package Ovpnc::TraitFor::Controller::Api::Clients::Delete;
use warnings;
use strict;
use Try::Tiny;
use Moose::Role;
use namespace::autoclean;


=head1 NAME

Ovpnc::TraitFor::Controller::Api::Clients::Delete - Ovpnc Controller Trait

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
    
=head2 remove_clients

Remove a list of clients

=cut

    sub remove_clients {
        my ( $self, $c, $client_list, $ccd_dir, $keys_dir ) = @_;

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
                    # Remove certificates
                    # ===================
					my $rs;
                    try {
                        $rs = $c->model('DB::Certificate')->search(
                            { user   => $client },
                            { select => [ 'name', 'key_serial' ] }
                        );
                    }
                    catch {
                        push @_errors, $_;
                    };
					if ( $rs && $rs > 0 ){
                        $c->req->params->{clients} = '';
                        while ( $_ = $rs->next ){
                            $c->req->params->{certificates} .= $_->name.',';
                            $c->req->params->{clients} 		.= $client.',';
                            $c->req->params->{serials} 		.= $_->key_serial.',';
                        }
                        $c->req->params->{no_detach} = 1;
                        my $chk_revoke = $c->forward('certificates_DELETE');

                        if ( $chk_revoke && $chk_revoke->{$client} ){
                            if ( $chk_revoke->{$client}->{status}->[0] ){
                                warn "[ @@@@@ ] Revoke for delete status returns: "
                                     . ( join ", ", @{$chk_revoke->{$client}->{status}} );
                                push @_delete_ok, $client;
                            }
                            if ( $chk_revoke->{$client}->{errors}->[0] ){
                                warn "[ @@@@@ ] Revoke for delete status returns: "
                                     . ( join ", ", @{$chk_revoke->{$client}->{errors}} );
                                push @_errors, $client . ': Did not revoke one or more certificates: '
                                			 . $chk_revoke->{$client}->{errors}->[0];
                            }
                        }
                    }
 					else {
 						push @_delete_ok, $client;
 					}
 					
                    # Delete entry
                    # ============
                    if ( !@_errors or @_errors == 0 ) {
						try {
	                    	unless ( $_res->delete ){
                        		die $client;
	                    	}
						}	
						catch {
							push @_not_ok, $_;
						};
                    
	                    # Remove any ccd file
	                    # ===================
	                    if ( -e $ccd_dir . '/' . $client and -d $ccd_dir . '/' . $client){
	                        unlink $ccd_dir . '/' . $client
	                            or push (@_not_ok, $client);
	                    }
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
