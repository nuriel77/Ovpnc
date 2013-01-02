package Ovpnc::Controller::Api::Certificates::Download;
use warnings;
use strict;
use HTTP::Date;
use File::stat;
use Try::Tiny;
use Moose;
use utf8;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

__PACKAGE__->config( namespace => 'api/certificates' );


with 'MooseX::Traits';
has '+_trait_namespace' => (
    default => sub {
        my ( $P, $SP ) = __PACKAGE__ =~ /^(\w+)::(.*)$/;
        return $P . '::TraitFor::' . $SP;
    }
);

has 'cfg' => (
    is        => 'rw',
    isa       => 'HashRef',
    predicate => '_has_conf'
);

has '_roles' => (
    is  => 'rw',
    isa => 'Object',
);

=head1 NAME

Ovpnc::Controller::Api::Certificates::Download - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 before...

Method modifier

=cut

before ['download'] => sub {
    my ( $self, $c ) = @_;

    # File::Assets might leave an empty hash
    # so we better delete it, no need in api
    # ======================================
    delete $c->stash->{assets} if $c->stash->{assets};

    # Assign config params
    # ====================
    $self->cfg( $c->controller('Api')->assign_params( $c ) )
        unless $self->_has_conf;
};


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


=head2 download

Get (download) certificates
and keys, first archive
Expects one client name
and 'all' or any cert names.
if 'all' is specified, then all
of the client's certs will be
archived for download.

=cut

    sub download : Local
                 : Args(2)
                 : Does('ACL')
                     AllowedRole('admin')
                     AllowedRole('client')
                     ACLDetachTo('denied')
                 : Sitemap
    {

        my ( $self, $c, $client, $certs ) = @_;

        my $format = $c->req->params->{format} ||= 'tar';
        my @formats = qw[ tar gzip bzip zip ];

        $c->detach if !$client or !$certs;

        # Validate format type
        # ====================
        unless ( grep $format ~~ $_, @formats ){
            $c->res->status(400);
            $c->res->body(
                'Unknown format: ' . $format
                . '. Supported formats: '
                . join ', ', @formats
            );
            $c->detach;
        }

        # Set roles
        # =========
        $self->_roles(
            $self->new_with_traits(
                traits => [ 'Archive' ],
                _cfg   => $self->cfg,
            )
        );

        # Get request 'get_cert'
        # will download the certificate + key
        # ===================================
        if ( $client ){
            my $_ret_val =
                $self->_roles->archive_certificates(
                    $c,
                    $client,
                    $format,
                    ( $certs ? $certs : undef )
                );

            if (     $_ret_val and !$c->stash->{error}
              and ( defined $_ret_val->{resultset}->[0] && -f $_ret_val->{resultset}->[0] )
            ){
                my ($filename) = $_ret_val->{resultset}->[0] =~ /^.*\/(.*)$/;
                my $stat = stat($_ret_val->{resultset}->[0]);
                $c->res->header('Content-Disposition' => qq[attachment; filename="$filename"] );
                $c->res->headers->content_length( $stat->size );
                $c->res->headers->last_modified( $stat->mtime );
                $c->res->headers->expires( time() );
                $c->res->headers->header( 'Pragma' => 'no-cache' );
                $c->res->headers->header( 'Cache-Control' => 'no-cache' );
                $c->response->header('Content-Description' => 'Certificate bundle');
                $c->serve_static_file($_ret_val->{resultset}->[0]);
                $c->stash->{content_transfer} = 'application/octet-stream';
            }
        }
        else {
            $self->status_bad_request($c,
                message => 'No certificate name(s) provided' );
            $c->detach;
        }

    }

=head1 AUTHOR

Nuriel Shem-Tov

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
