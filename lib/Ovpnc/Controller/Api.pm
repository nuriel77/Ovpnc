package Ovpnc::Controller::Api;
use Moose;
use vars qw/$status/;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller::REST'; }

=head1 NAME

Ovpnc::Controller::Api - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller

OpenVPN Controller API


=head1 METHODS

=head2 base

For chain to login page

=cut

sub base : Chained('/base') PathPrefix CaptureArgs(0) {}


=head2 index

For REST action class

=cut

sub index :Chained('/') PathPart('api/') Args(0) :ActionClass('REST') { }


=head2 begin

Begin method

=cut

#sub begin :Private
#{
#	my ( $self, $c ) = @_;
#}

#sub index_GET
#{
#	my ( $self, $c, $r ) = @_;
#
#}

sub sanity : Chained('base') PathPart('sanity') Args(0)
{

	my ($self, $c) = @_;
	my $sanity = Ovpnc::Controller::Sanity->new(
			ovpnc_user 		=> $c->config->{ovpnc_user} || 'ovpnc',
			os		   		=> $c->config->{os} || 'linux',
			dist	   		=> $c->config->{dist} || '/etc/debian_version',
			openvpn_user 	=> $c->config->{openvpn_user} || 'openvpn',
	);

	my $ret_val = $sanity->action( $c->config );

	if (ref $ret_val eq 'ARRAY'){
		$c->response->status(500);
        $c->stash( { status => $ret_val } );
        return $ret_val;
	}

	$c->stash( { status => 'Sanity check successful' } )
		if ($c->request->path =~ /sanity/);
}


sub default :Private
{
	my ($self, $c) = @_;

#	$c->response->body( 'Page not found xxx' );
#	$c->response->status(404);

#	unless ($c->request->method eq 'POST'){
#            $c->response->body( 'Not a POST method: ' . $c->request->method );
#            $c->response->status(500);
#            return;
#    }

#	if ($c->req->param('username') && $c->req->param('password')){
	
#	$c->authenticate({}, "ovpnc");
#	}
 #   $c->response->body( 'No username or password' );
 #   $c->response->status(403);
    return;
}

sub end :Private
{
	my ($self, $c) = @_;

	# Debug if requested
	die "forced debug" if $c->req->params->{dump_info}; 

	# Forward to JSON view
#	$c->forward("View::JSON");
	$c->forward( $c->view('JSON') );
}

=head1 AUTHOR

Nuriel Shem-Tov

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


__PACKAGE__->meta->make_immutable;

1;
