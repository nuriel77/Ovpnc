package Ovpnc::Controller::Clients;
use File::Touch;
use Try::Tiny;
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

    # Force submit param
    # ==================
    $c->req->params->{'submit'} ||= 'Submit';

    my $form = $c->stash->{form};

    # Verify all fields have been submitted
    # FixMe: FormFu doesn't like ajax, check why
    # ->submitted doesn't work (although forced
    # submit param at start of this action)
    # ==========================================
    my @_keys = sort keys %{$c->req->params} if scalar keys %{$c->req->params} > 1; 
    my @_columns = qw[address email fullname password password2 phone submit username];

    # Form submitted okay
    # ===================
    if ( @_keys && @_columns ~~ @_keys ) {

        $form->process;

        # Check if any errors in form
        # FormFu handles this automatically
        # =================================
        if ( $form->has_errors ) {
            $form->process;
            $c->forward('View::HTML');
        }

        if ( $form->submitted_and_valid ) {

            # If submitted we go "JSON"
            # =========================
            $c->response->headers->header('Content-Type' => 'application/json');
            delete $c->stash->{$_} for ( qw/assets form token/ );
            delete $c->req->params->{submit};
            # New resultset
            # =============
            my $_client = $c->model('DB::User')
                ->new_result({});

            # update dbic row with
            # submitted values from form
            # ==========================
            try   { $form->model->update( $_client ) }
            catch { 
                my $error_clean = $_;
                my $error = $_;
                $self->_db_error($c, $error_clean, $error, $form);
                $c->forward('View::JSON');
                $c->detach;
            }; 
    
            my $_client_role_id = $c->model('DB::Role')
                ->search(
                    { name => 'client' },
                    { select   => 'id' },   
                );
            try {
                $c->model('DB::UserRole')
                    ->create(
                        {
                            user_id => $_client->id,
                            role_id => $_client_role_id->next->id,
                        }
                    );
            } catch {
                my $error_clean = $_;
                my $error = $_;
                $self->_db_error($c, $error_clean, $error, $form);
                $c->forward('View::JSON');
                $c->detach;
            };

            # Create client configuration file
            # ================================
            if ( ! -w $c->config->{openvpn_ccd} ){
                $self->_error($c,
                    "Cannot create ccd file for " . $_client->username
                    . ": directory '" . $c->config->{openvpn_ccd}
                    . "' does not exists or is not writable!" );
            }

            my $_file = $c->config->{openvpn_ccd} . '/' . $_client->username;

            touch $_file
                or $self->_error($c, "Cannot create ccd file for "
                    . $_client->username . ': ' . $!);
    
            # Set permissions and ownership
            # =============================
            my ( $uid, $gid ) = $self->_get_user_group_id( $c );
            chown $uid, $gid, $_file
                or $self->_error($c, " chmod error '" . $_file . "': " . $!);

            chmod 0640, $c->config->{openvpn_ccd} . '/' . $_client->username
                or $self->_error($c, " chown error '" . $_file . "': " . $!);
    
            if ( $c->stash->{error} ) {
                $_client->delete;
            }
            else {
                $c->stash->{status} = "'" . $_client->username . "' created successfully";
            }


            $c->forward('View::JSON');
        }
    }
    else {
        $c->response->headers->header('Content-Type' => 'text/html');
        Ovpnc::Controller::Root->include_default_links( $c );
    }

}

=head2 _db_error

Handle Database error

=cut

sub _db_error : Private {
    my ( $self, $c, $error_clean, $error, $form ) = @_;

    $c->response->status(500);    

    if ( $error_clean =~ /duplicate entry '(.*)' for key '(.*)' /i ){
        push @{$c->stash->{error}}, $2 if $2;
        $form->get_field( $2 )
            ->get_constraint({ type => 'Callback' })
            ->force_errors(1);
        $form->process;
    }
# TODO: use for return ajax handle error to do something with this error field
#            elsif ( $_ =~ /(execute failed: Column) '(.*)' (.*) \[/g ) {
#                push @{$c->stash->{error}}, $2 if $2;
#                my ($_err) = $error =~ /(execute failed: .*) \[/g;
#                push @{$c->stash->{error}}, "MySQL error: " . $_err if $_err;
#            }
    elsif ( $_ =~ /(execute failed:.*) \[/g ) {
        push @{$c->stash->{error}}, "Error: " . $1;
    }
    else { 
        push @{$c->stash->{error}}, "Error: " . $error_clean;
    }
}

=head2 _error

Handle General error

=cut

sub _error : Private {
    my ( $self, $c, $error ) = @_;
    $c->response->status(500);
    push @{$c->stash->{error}}, $error;
}

=head2 _get_user_group_id

Get user and group id

=cut

sub _get_user_group_id : Private {

    my ( $self, $c )= @_;

    # Get the group/user
    # ==================
    my (undef, undef, undef, $gid) = getpwnam(
        $c->config->{openvpn_user} );

    my (undef, undef, $uid) = getpwuid( $< );

    return ( $uid, $gid );
}

=head2 denied

Denied action

=cut

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
