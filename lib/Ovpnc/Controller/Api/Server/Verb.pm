package Ovpnc::Controller::Api::Server::Verb;
use warnings;
use Scalar::Util qw( looks_like_number );
use strict;
use Moose;
use namespace::autoclean;

use vars qw/
  $REGEX
  /;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config( namespace => 'api/server' );

=head1 NAME

Ovpnc::Controller::Api::Server::Verb - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller for OpenVPN server
Set/Get verbosity level

=cut

has 'vpn' => (
    isa       => 'Object',
    is        => 'rw',
    predicate => '_has_vpn',
    clearer   => '_disconnect_vpn'
);

has 'cfg' => (
    is        => 'rw',
    isa       => 'HashRef',
    predicate => '_has_conf'
);

$REGEX = { verb_line => '^SUCCESS: verb=(\d+)\n' };

around [qw(verb_GET verb_POST)] => sub {
    my $orig = shift;
    my $self = shift;
    my $c    = shift;

    $self->cfg( $c->controller('Api')->assign_params($c) )
      unless $self->_has_conf;

    return $self->$orig( $c, @_ )
      if $self->_has_vpn;

    # Instantiate connector
    # =====================
    $self->vpn( $c->model('VpnConnector')->new( $self->cfg->{mgmt_params} ) );

    return $self->$orig( $c, @_ );
};

=head2 after modifier

Makes sure to disconnect
and release the mgmt port

=cut

after [qw(verb_GET verb_POST)] => sub { shift->_disconnect_vpn; };

=head2 server

For REST action class

=cut

sub verb : Local : ActionClass('REST') {
}

=head2 begin

Automatic first
action to run

=cut

    sub begin : Private {
        my ( $self, $c ) = @_;

        # Test database connection
        # ========================
        $c->controller('Root')->auto( $c );

        # Log user in if login params are provided
        # =======================================
        $c->controller('Api')->auth_user( $c )
            unless $c->user_exists();

        # Set the expiration time
        # if user is logged in okay
        # Ignore if ajax call
        # =========================
        if ( $c->user_exists() && !$c->req->params->{_} ){
            $c->log->info('Setting session expire to '
                . $c->config->{'api_session_expires'});
#            $c->change_session_expires(
#                $c->config->{'api_session_expires'} );
        }

    }      

=head2 verb_POST

Sets the verbosity level live
When requesting can provide
both on path or as parameter
'level'.

For example: 

/api/server/verb/4

=cut

sub verb_POST : Local
              : Args(0)
              : Does('ACL')
                    AllowedRole('admin')
                    AllowedRole('can_edit')
                    ACLDetachTo('denied')
              : Sitemap
{
    my ( $self, $c, $level ) = @_;

    # Verify content not empty
    # ========================
    do {
        $self->status_bad_request( $c, message => 'Missing parameters for verb_POST' );
        $self->_disconnect_vpn;
        $c->detach;
    } unless defined( $level // $c->request->params->{level} );

    # Assign from post params if exists
    # This will override anything in the path
    # =======================================
    $level = $c->request->params->{level} if $c->request->params->{level};

    # level range [0-9] check
    # =======================
    if ( !looks_like_number($level) or $level > 9 or $level < 0 ) {
        $self->status_bad_request( $c,
            message => 'Invalid range. Verbosity range is 0 to 9' );
        $self->_disconnect_vpn;
        $c->detach;
    }

    # Verify can run
    # ==============
    my $_server = Ovpnc::Controller::Api::Server->new( vpn => $self->vpn );
    undef $_server if $_server->sanity($c);

    # Set the verbosity level
    # =======================
    $self->status_accepted(
        $c,
        entity => {
                status => $self->_set_verbosity( $level ? $level : 4 )
              . ' Now at level: '
              . $self->get_verbosity
        }
    );

    $self->_disconnect_vpn;
}

=head2 verb

Gets the verbosity level

=cut

sub verb_GET : Local
             : Args(0)
             : Does('ACL')
                AllowedRole('admin')
                AllowedRole('can_edit')
                ACLDetachTo('denied')
             : Sitemap
{
    my ( $self, $c ) = @_;

    # Verify can run
    # ==============
    my $_server = $c->controller('Api::Server')->new( vpn => $self->vpn );
    $_server->sanity($c);
    $self->status_ok( $c, entity => { verbosity => $self->get_verbosity } );
}

# Private methods
# ===============
{

    sub get_verbosity : Private {
        my $self = shift;

        # Get verb level
        my $verb = $self->vpn->verb();

        # Parse the verb level
        $verb =~ s/$REGEX->{verb_line}/$1/;
        return $verb;
    }

    sub _set_verbosity : Private {
        my ( $self, $level ) = @_;
        my $verb = $self->vpn->verb($level);
        return $verb;
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


    sub end : Private {
        my ( $self, $c ) = @_;

        # Clean up the File::Assets
        # it is set to null but
        # is not needed in JSON output
        delete $c->stash->{assets};

        # Debug if requested
        die "forced debug" if $c->req->params->{dump_info};

        # Forward to JSON view
        $c->forward(
            ( $c->request->params->{xml} ? 'View::XML::Simple' : 'View::JSON' )
        );
    }
}

=head1 AUTHOR

Nuriel Shem-Tov

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
