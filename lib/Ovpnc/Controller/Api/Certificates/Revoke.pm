package Ovpnc::Controller::Api::Certificates::Revoke;
use warnings;
use strict;
use Try::Tiny;
use Moose;
use utf8;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config( namespace => 'api/certificates' );

has 'cfg' => (
    is        => 'rw',
    isa       => 'HashRef',
    predicate => '_has_conf'
);


=head1 NAME

Ovpnc::Controller::Api::Certificates::Revoke - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

Both Revoke and Unrevoke are handled by clients controllers
because this involves relation to user database and status.
Therefore the forwarding to client controllers after
parameters have been configured and / or verified
in this controller.
The traits used by the clients controllers to revoke/unrevoke
are of the certificates controllers (traits), because actions
on certificates relate to certificates, the status thereof
becomes appended to the status of the clients in the 
clients controller.


=head1 METHODS

=cut


=head2 certificates

For REST action class

=cut

    sub revoke : Local : Args(0) : ActionClass('REST') {
    }



=head2 begin

Automatic first
action to run

=cut

    sub begin : Private {
        my ( $self, $c ) = @_;

        # Log user in if login params are provided
        # =======================================
        $c->controller('Api')->auth_user( $c )
            unless $c->user_exists();

        # Set the expiration time
        # if user is logged in okay
        # =========================
        if ( $c->user_exists() && !$c->req->params->{_} ){
            $c->log->info('Setting session expire to '
                . $c->config->{'api_session_expires'});
#            $c->change_session_expires(
#                $c->config->{'api_session_expires'} )
        }

    }


=head2 certificates_REVOKE

Revoke certificate(s)
sends to _DELETE with no_delete param

=cut

   sub revoke_POST : Local
                   : Args(0)
                   : Does('ACL')
                       AllowedRole('admin')
                       AllowedRole('can_edit')
                       ACLDetachTo('denied')
                   : Sitemap
    {
        my ( $self, $c ) = @_;

        $c->req->params->{no_delete} = 1;

        if (  ! $c->req->params->{certificates}
          and ! $c->req->params->{clients}
          and ! $c->req->params->{serials}
        ){
            $self->status_bad_request($c, message =>
                'Certificate name(s), serial(s) and client name(s) should be provided (min 1)'
            );
            $c->detach;
        }
        my @certificates = split ',', $c->req->params->{certificates};
        my @clients      = split ',', $c->req->params->{clients};
        my @serials      = split ',', $c->req->params->{serials};

        # Check if such a certificate exists
        # ==================================
        # just to make sure:
        $c->req->params->{no_delete} ||= 1;
        $c->req->method('DELETE');
        my $chk_revoke = $c->forward('/api/certificates');
#            $c,
#            $c->req->params->{clients},
#            $c->req->params->{certificates},
#            $c->req->params->{serials}
#        );

		# Check the return values to find
		# successful ones and update the
		# database with the revoke time
		# ===============================
        if ( $chk_revoke and ref $chk_revoke ){
            for my $i ( 0 .. $#certificates ){
				my $e_obj;
                if ( $chk_revoke->{$clients[$i]}->{status} ){
                	$e_obj = $clients[$i];
                }
                elsif ( $chk_revoke->{$certificates[$i]}->{status} ){  
                	$e_obj = $certificates[$i];    
                }
                else {
                	$e_obj = $certificates[$i];
                }
               
                if ( ref $chk_revoke->{$e_obj}->{status} eq 'ARRAY' ){
                    for my $cert_status ( @{$chk_revoke->{$e_obj}->{status}} ){
                        my ($cert_name) = $cert_status =~ /Certificate.(.*).revoked ok/;
                        if ( $cert_name and $cert_name eq $certificates[$i] ){
                            try {
                                $c->model('DB::Certificate')->search({
                                    name => $cert_name,
                                    user => $clients[$i]
                                })->update({ revoked => DateTime->now });
                            }
                            catch {
                                $c->log->error('DB Error: ' . $_);
                                push @{$c->stash->{$e_obj}->{errors}},
                                    "Failed to update database for '$cert_name': " . $_
                                    . " user: '$clients[$i]'";
                            };
                            try {
                                my $check_total_revoked =
                                    $c->model('DB::Certificate')->search({
                                        user    => $clients[$i],
                                        revoked => { in => [ '0000-00-00 00:00:00' ] }                                
                                    })->count;
                                if ( $check_total_revoked == 0 ){
                                    $c->log->debug('Updating user, setting to revoked because all certificates are revoked.');
                                    $c->model('DB::User')->search({
                                        username => $clients[$i]
                                    })->update({ revoked => 1 });
                                }
                            }
                            catch {
                                $c->log->error('DB Error: ' . $_);
                                push @{$c->stash->{$e_obj}->{errors}},
                                    "Failed to update database for user status: " . $_
                                    . " user: '$clients[$i]'";
                            };
                        }
                    }
                }
                elsif ( $chk_revoke->{$e_obj}->{warnings} ){
                    $c->stash->{rest}->{$e_obj}->{errors} =
                        $chk_revoke->{$e_obj}->{warnings};
                }
                elsif ( $chk_revoke->{$e_obj}->{errors} ){
                    $c->stash->{$e_obj}->{errors} =
                        $chk_revoke->{$e_obj}->{errors};
                }
                else {
                    push @{$c->stash->{$e_obj}->{errors}},
                        "Failed to get status for '$certificates[$i]', user: '$clients[$i]'";
                }
                #$chk_revoke->{$certificates[$i]} = $chk_revoke->{$clients[$i]};
                #delete $chk_revoke->{$clients[$i]};
            }
            $self->status_ok($c, entity => { resultset => $chk_revoke } );
        }
    }






=head2 denied

Unauthorized access
no match for role

=cut

    sub denied : Private {
        my ( $self, $c ) = @_;
        $self->status_forbidden( $c, message => "Access denied" );
        $c->detach;
    }


=head2 end

Last action of this controller

=cut

    sub end : Private {
        my ( $self, $c ) = @_;
    
        # Debug if requested
        # ==================
        die "forced debug" if $c->req->params->{dump_info};

        # Clean up the File::Assets
        # it is set to null but
        # is not needed in JSON output
        # ============================
        delete $c->stash->{assets};

        # Forward to JSON view
        # ====================
        $c->forward(
            ( $c->request->params->{xml} ? 'View::XML::Simple' : 'View::JSON' ) );
    }
    

=head1 AUTHOR

Nuriel Shem-Tov

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
