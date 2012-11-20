package Ovpnc::Controller::Root;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config( namespace => '' );

=head1 NAME

Ovpnc::Controller::Root - Root Controller for Ovpnc

=head1 DESCRIPTION

OpenVPN Controller Application

=head1 METHODS

=head2 base

Chain actions to login page

=cut

sub base : Chained('/login/required') PathPart('') CaptureArgs(0) {
}

=head2 Method modifier

Will run sanity check
before any of the listed
methods execute

=cut

around [qw(ovpnc_config index)] => sub {
    my ( $orig, $self, $c ) = @_;

    # Sanity check
    my $err = $c->forward('/api/sanity');
    if ( $err and ref $err eq 'ARRAY' ) {
        $c->response->status(500);
        $c->forward('View::JSON');
        return;
    }
    else {
        return $self->$orig($c);
    }
};

=head2 index

Default main page

=cut

sub index : Chained('/base') Path : Args(0) Does('NeedsLogin') {
    my ( $self, $c ) = @_;

	# Get all killed clients
	my $obj = $c->forward('/api/server/get_killed');
	die $c->{error} if ( $c->{error} );

	if ( ref $obj eq 'HASH' ){
		if ( $obj->{status} and ref $obj->{status} eq 'ARRAY'){
			$c->stash->{killed_clients} = $obj->{status};
		}
		else {
			warn map { $_ . " - " . $obj->{$_} } keys %{$obj};
		}
	}
	else {
		die "Killed clients read error?!";
	}

	$c->stash->{geo_username} = $c->config->{geo_username};
	$c->stash->{this_link} = 'root';
    $c->stash->{logged_in} = 1;
}

=head2 default

Standard 404 error page

=cut

sub default : Path {
    my ( $self, $c ) = @_;
    $c->response->body('Page not found');
    $c->response->status(404);
}

=head2 ovpnc_config

Configuration Page

=cut

sub ovpnc_config : Chained('/base') PathPart("config") Args(0) {
    my ( $self, $c ) = @_;

    my $req = $c->request;
    $c->stash->{xml} = $c->config->{ovpnc_conf}
      || '/home/ovpnc/Ovpnc/root/xslt/ovpn.xml';
    $c->stash->{title} = 'Ovpnc Configuration';
    $c->forward('Ovpnc::View::XSLT');
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {
}

=head1 AUTHOR

Nuriel Shem-Tov

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
