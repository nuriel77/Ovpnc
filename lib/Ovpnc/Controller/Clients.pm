package Ovpnc::Controller::Clients;
use File::Touch;
use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::HTML::FormFu'; }
#use base 'Catalyst::Controller::HTML::FormFu';
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

around [qw(index add)] => sub {
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
    # ====================
    $c->config->{openvpn_user} =
      Ovpnc::Controller::Api::Configuration->get_openvpn_param(
        $ovpnc_conf, 'UserName' );

    # Openvpn ccd dir
    # ===============
    $c->config->{openvpn_ccd} = 
        Ovpnc::Controller::Api::Configuration->get_openvpn_param(
        $ovpnc_conf, 'ClientDir' );

    $c->config->{openvpn_ccd} = $c->config->{openvpn_ccd} =~ /^\//
        ? $c->config->{openvpn_ccd}
        : $c->config->{openvpn_dir} . '/' . $c->config->{openvpn_ccd};

    # Sanity check
    # ============
    my $err = Ovpnc::Plugins::Sanity->action( $c->config );
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

=head2 index

=cut

sub index : Path
          : Args(0)
          : Sitemap
          : Does('NeedsLogin')
{
    my ( $self, $c ) = @_;
    $c->stash->{title}     = 'Clients';
    $c->stash->{this_link} = 'clients';

}

=head2 add

Add a client

=cut

sub add : Path('add')
        : Args(0)
        : FormConfig
        : Sitemap
        : Does('NeedsLogin')
{
    my ( $self, $c ) = @_;

    $c->response->headers->header('Content-Type' => 'text/html');
    Ovpnc::Controller::Root->include_default_links( $c );

    my $form = $c->stash->{form};

    if ( $form->has_errors ) {
        $c->forward('View::HTML');
        $c->detach;
    }

    if ( $form->submitted_and_valid ) {
        my $_client = $c->model('DB::User')
            ->new_result({});
 
        # update dbic row with
        # submitted values from form
        # ==========================
        try {
            $form->model->update( $_client );
        }
        catch {
            $c->stash->{errors} = $_;
            warn "MySQL Error: " . $_;
            $c->detach;
        }; 

        my $_cid = $_client->{_column_data}->{id};
        my $_client_role_id = $c->model('DB::Role')
            ->search(
                { name => 'client' },
                { select   => 'id' },   
            );
        $c->model('DB::UserRole')
            ->create(
                {
                    user_id => $_cid,
                    role_id => $_client_role_id->next->id,
                }
            );
        touch $c->config->{openvpn_ccd} . '/' . $_client->{_column_data}->{username};
        $c->response->redirect( $c->uri_for('/clients') );
        return;
    }

}

sub denied : Private {
    my ( $self, $c ) = @_;

    # Add js / css
    # ============
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
