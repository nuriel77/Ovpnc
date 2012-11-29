package Ovpnc::Controller::Api::Server::Status;
use strict;
use warnings;
use Ovpnc::Plugins::Connector;
use Moose;
use namespace::autoclean;

use vars qw/
  $REGEX
/;


BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config( namespace => 'api/server' );


=head1 NAME

Ovpnc::Controller::Api::Server::Status - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller for OpenVPN Server Status

=cut


with 'MooseX::Traits';
has '+_trait_namespace' => (
    # get the correct namespace.
    # Wanted to keep traits out of
    # the Controller directory
    default => sub {
        my ($P, $SP) = __PACKAGE__ =~ /^(\w+)::(.*)::\w+$/;
        return $P . '::TraitFor::' . $SP;
    }
);

has 'vpn' => (
    isa       => 'Object',
    is        => 'rw',
    predicate => '_has_vpn',
    clearer   => '_disconnect_vpn'
);

has 'cfg' => (
    is => 'rw',
    isa => 'HashRef',
    predicate => '_has_conf'
);

$REGEX = {
    client_list => 'CLIENT_LIST,(.*?),(.*?),(.*?),([0-9]+),([0-9]+),(.*?),([0-9]+)$',
    log_line    => '^([0-9]+),(.*)\n',
    verb_line   => '^SUCCESS: verb=(\d+)\n',
};

=head2 around modifier

Make sure to establish
connection

=cut

around status_GET => sub {
    my $orig = shift;
    my $self = shift;
    my $c = shift;

	$self->cfg( Ovpnc::Controller::Api->assign_params( $c ) )
      unless $self->_has_conf;

    return $self->$orig($c, @_)
        if $self->_has_vpn;

    # Establish connection to management port
    $self->vpn( Ovpnc::Plugins::Connector->new($self->cfg->{mgmt_params}) );

    return $self->$orig($c, @_);
};


=head2 after modifier

Makes sure to disconnect
and release the mgmt port

=cut

after 'status_GET' => sub { shift->_disconnect_vpn; };


=head2 server

For REST action class

=cut

sub status : Local : ActionClass('REST') { }

=head2 status_GET

Gets status from OpenVPN
such as clients, verbosity
and title (version)

=cut

sub status_GET : Local
			   : Args(0)
			   : Sitemap #Does('NeedsLogin')
{
    my ( $self, $c ) = @_;

    # Verify can run
    my $_server = Ovpnc::Controller::Api::Server->new( vpn => $self->vpn );
	undef $_server if $_server->sanity( $c );

    # Trait names should match action name
	# Ovpnc::TraitFor::Controller::Api::Server::Status
    my ($_fn) = (caller(0))[3] =~ /::(\w+)::\w+_.*$/;
    my $_role = $self->new_with_traits(
        traits  => [ $_fn ],
        vpn     => $self->vpn,
        regex   => $REGEX
    ) or die "Could not get role '" . ucfirst( $_fn ) . "': $!";

 	# Check connection to mgmt port
    if ( my $_status = $_role->get_status ) {
        $self->_disconnect_vpn;
        $self->status_ok( $c, entity => $_status );
        return $_status;
    } else {
        $self->_disconnect_vpn;
        $self->gone( $c, message =>  'Did not get status data from management port, might be down');
        return undef;
    }
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
