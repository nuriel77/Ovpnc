package Ovpnc::Controller::Login;
use Moose;
use namespace::autoclean;

BEGIN { extends 'CatalystX::SimpleLogin::Controller::Login'; }
	

=head1 NAME

Ovpnc::Controller::Login - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller, override login from CatalystX::SimpleLogin

=head1 METHODS

=cut

=head2 around 'login'

Modify the original 
login parameters
from CatalystX::SimpleLogin

=cut

around 'login' => sub {
	my ( $orig, $self, $c ) = @_;
	
	# Redirect to https if user specified 
	# a port in config under 'redirect_https_port'
	if ( $c->config->{redirect_https_port} && ! $c->req->secure ){
		$c->redirect(
			'https://'
			. $c->req->uri->host
			. ':' 
			. $c->config->{redirect_https_port} 
			. '/' 
			. $c->req->path
		);
	}

	unless ( $c->req->secure ){
		$c->stash->{warning} =
			"Warning: It is recommended to serve this page under HTTPS."
		  .	" Check the configuration manual on how to set this up.";
	}

	# Will load any js or css
    Ovpnc::Controller::Root->include_default_links($c);

	# Only sets the name in this cookie.
	if ( defined $c->request->params->{username} ){
		$c->response->cookies->{Ovpnc_C} = {
			value 	=> $c->request->params->{username},
			domain 	=> $c->request->uri->host,
			path 	=> '/',
		}
	} else {
		$self->remove_cookies( $c, [ qw( Ovpnc_C ovpnc_session Ovpnc_User_Settings ) ] );
	}

    return $self->$orig($c);

};

sub remove_cookies : Private {
	my ($self, $c, $cookies) = @_;

	for ( @{$cookies} ){
		$c->log->debug("Removing cookie $_");
		$c->response->cookies->{$_} = {
	        value   => '',
	        expires => '-1d',
	    } if $c->request->cookies->{$_};
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
