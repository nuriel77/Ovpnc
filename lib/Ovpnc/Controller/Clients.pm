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

    # Assign config params
    # ====================
    $c->config->{openvpn_user} =
      Ovpnc::Controller::Api::Configuration->get_openvpn_param(
        $c->config->{ovpnc_conf}, 'UserName' );

    # Sanity check
    # ============
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

sub index : Path : Args(0) : Does('NeedsLogin') : Sitemap {
    my ( $self, $c ) = @_;
    $c->stash->{title}     = 'Clients';
    $c->stash->{this_link} = 'clients';

}

sub denied : Private {
    my ( $self, $c ) = @_;

    # Add js / css
    Ovpnc::Controller::Root->include_default_links($c);
    $c->stash->{this_link}     = 'clients';
    $c->stash->{title}         = ucfirst( $c->stash->{this_link} );
    $c->stash->{error_message} = "Access denied";
    $c->stash->{no_self}       = 1;
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {
    my ( $self, $c ) = @_;

    # Add js / css
    Ovpnc::Controller::Root->include_default_links($c);

    $c->stash->{username} = $c->user->get("username")
      if ( $c->user_exists );
}

=head1 AUTHOR

Nuriel Shem-Tov

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
