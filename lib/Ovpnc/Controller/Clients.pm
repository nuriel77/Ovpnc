package Ovpnc::Controller::Clients;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

Ovpnc::Controller::Clients - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 Method modifier

Will run sanity check
before any of the listed
methods execute

=cut

around [qw(index)] => sub {
    my ( $orig, $self, $c ) = @_;

	$c->config->{openvpn_user} =
        Ovpnc::Controller::Api::Configuration->get_openvpn_param(
            $c->config->{ovpnc_conf}, 'UserName' );

    # Sanity check
	my $err = Ovpnc::Plugins::Sanity->action( $c->config );
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

=cut

sub index :Path :Args(0) : Does('NeedsLogin') : Sitemap {
    my ( $self, $c ) = @_;

	# Get all killed clients
#    my $kc = Ovpnc::Controller::Root->list_revoked_clients($c);
#    $c->stash->{killed_clients} = $kc
#        if ( $kc and ref $kc );

	$c->stash->{title} = 'Clients';
    $c->stash->{this_link} = 'clients';
    $c->stash->{logged_in} = 1;
}


=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {
	my ($self, $c) = @_;
	# Will load any js or css
	Ovpnc::Controller::Root->include_default_links($c);

	$c->stash->{username} = $c->request->cookies->{Ovpnc_C}->value
        if $c->request->cookies->{Ovpnc_C};

}

=head1 AUTHOR

Nuriel Shem-Tov

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
