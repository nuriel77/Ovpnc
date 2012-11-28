package Ovpnc::Controller::Root;
use warnings;
use strict;
use Ovpnc::Plugins::Sanity;
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

	$c->config->{openvpn_user} = 
		Ovpnc::Controller::Api::Configuration->get_openvpn_param(
			$c->config->{ovpnc_conf}, 'UserName' );

    # Sanity check
	# ============
    my $err = Ovpnc::Plugins::Sanity->action( $c->config );

    if ( $err and ref $err eq 'ARRAY' ) {
        $c->response->status(500);
        $c->forward('View::JSON');
		$c->detach;
    }
    else {
        return $self->$orig($c);
    }
};

=head2 index

Default main page

=cut

sub index : Chained('/base') 
		  : Path 
		  : Args(0) 
		  : Sitemap 
{
    my ( $self, $c ) = @_;

    # Get username for geoname api service
    $c->stash->{geo_username} = $c->config->{geo_username};

    # todo: check how to get current link in .tt2
    $c->stash->{this_link} = 'root';

    # todo: login name from CxSL?
    $c->stash->{logged_in} = 1;

}

=head2 include_default_links

Include static files, dynamically

=cut

sub include_default_links : Private {
    my ( $self, $c ) = @_;

    # Stash version
	# =============
    $c->stash->{version} = $c->get_version;

    # Include defaults
	# ================
    $c->assets->include($_)
      for (
        qw|css/normalize.css
        css/main.css
        css/slider.css
        js/Flexigrid/css/flexigrid.css
        js/jquery-latest.js
        js/Flexigrid/js/flexigrid.js
        js/jquery.cookie.js
        js/jquery.validate.js
        js/main.js
        js/slider.js|
      );

    # Optional :
    #js/jquery-ui/css/smoothness/jquery-ui-1.9.1.custom.min.css
    #js/jquery-ui/js/jquery-ui-1.9.1.custom.min.js

	return 1 if $c->stash->{no_self};

    # Include according to pathname
	# =============================
    my $c_name = $c->req->path || return;
    $c_name =~ s/\/$//;

    for my $type (qw/ css js /) {
        if ( -e 'root/static/' . $type . '/' . $c_name . '.' . $type ) {

            # example: 'css/certificates.css'
            $c->log->debug(
                "Including: " . $type . '/' . $c_name . '.' . $type );
            $c->assets->include( $type . '/' . $c_name . '.' . $type );
        }
    }

}

sub sitemap : Path('/sitemap') {
    my ( $self, $c ) = @_;
	$c->response->headers->header( 'Content-Type' => 'application/xml' );
	$c->stash( current_view => 'View::XML::Simple' );
    $c->response->body( $c->sitemap_as_xml );
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
    my ( $self, $c ) = @_;

	# Include JS/CSS
    $self->include_default_links($c);

	$c->stash->{username} = $c->user->get("name")
		if ( $c->user_exists );
}

=head1 AUTHOR

Nuriel Shem-Tov

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
