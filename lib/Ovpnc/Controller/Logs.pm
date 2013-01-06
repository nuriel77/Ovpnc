package Ovpnc::Controller::Logs;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

around [qw(index)] => sub {
    my ( $orig, $self, $c ) = @_;
    $c->stash->{token} = $c->get_session_id;
    my $ovpnc_conf = $c->config->{ovpnc_conf} =~ /^\//
        ? $c->config->{ovpnc_conf}
        : $c->config->{home} . '/' . $c->config->{ovpnc_conf};
    # Openvpn dir
    # ===========
    $c->config->{openvpn_dir} = $c->config->{openvpn_dir} =~ /^\//
        ? $c->config->{openvpn_dir}
        : $c->config->{home} . '/' . $c->config->{openvpn_dir};
    # Assign config params
    # get also ccd dir
    # ====================
    ( $c->config->{openvpn_user}, $c->config->{openvpn_ccd} ) =
     @{( $c->controller('Api::Configuration')->get_openvpn_param(
        [ 'UserName', 'ClientDir' ], $ovpnc_conf ) )};
    $c->config->{openvpn_ccd} = $c->config->{openvpn_ccd} =~ /^\//
        ? $c->config->{openvpn_ccd}
        : $c->config->{openvpn_dir} . '/' . $c->config->{openvpn_ccd};
    # Sanity check
    # ============
    my $err = Ovpnc::Model::Sanity->action( $c->config );
    if ( $err and ref $err eq 'ARRAY' ) {
        $c->response->status(500);
        $c->response->body( join "<br>", @{$err} );
        $c->forward('end');
        return;
    }
    else {
        return $self->$orig($c);
    }
};


=head1 NAME

Ovpnc::Controller::Logs - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

Main action

=cut

    sub index : Path
              : Does('NeedsLogin')
              : Sitemap
    {
        my ( $self, $c ) = @_;
        $c->stash->{title}     = ucfirst($c->action);
        $c->stash->{this_link} = $c->action;
    }


=head2 end

Attempt to render a view, if needed.

=cut

    sub end : ActionClass('RenderView') {
        my ( $self, $c ) = @_;

        # Add js / css
        # ============
        $c->controller('Root')->include_default_links($c);

        $c->stash->{username} = $c->user->get("username")
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
