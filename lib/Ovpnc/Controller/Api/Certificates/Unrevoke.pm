package Ovpnc::Controller::Api::Certificates::Unrevoke;
use warnings;
use strict;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config( namespace => 'api/certificates' );

=head1 NAME

Ovpnc::Controller::Api::Certificates::Unrevoke - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller. Unrevoke client certificates

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

    sub unrevoke : Local : Args(0) : ActionClass('REST') {
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
            $c->change_session_expires(
                $c->config->{'api_session_expires'} )
        }

    }



=head2 certificates_UNREVOKE

Un-Revoke certificate(s)
sends to clients/unrevoke

=cut

   sub unrevoke_POST : Local
                     : Args(0)
                     : Does('ACL')
                         AllowedRole('admin')
                         AllowedRole('can_edit')
                         ACLDetachTo('denied')
                     : Sitemap
    {
        my ( $self, $c ) = @_;
        $c->detach('/api/clients/unrevoke');
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


=head1 AUTHOR

Nuriel Shem-Tov

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
