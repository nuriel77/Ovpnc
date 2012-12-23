package Ovpnc::Controller::Clients;
use Ovpnc::Controller::Root 'include_default_links'; 
use Ovpnc::Plugins::ChainCA 'read_random_entropy';
use Try::Tiny;
use Digest::MD5 'md5_hex';
use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::HTML::FormFu'; }

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
    # get also ccd dir
    # ====================
    ( $c->config->{openvpn_user}, $c->config->{openvpn_ccd} ) =
     @{( Ovpnc::Controller::Api::Configuration->get_openvpn_param(
        [ 'UserName', 'ClientDir' ], $ovpnc_conf ) )};

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

Main action

=cut

sub index : Path
          : Args(0)
          : Does('NeedsLogin')
          : Does('ACL')
            AllowedRole('admin')
            AllowedRole('client')
            ACLDetachTo('denied')
          : Sitemap
{
    my ( $self, $c ) = @_;
    $c->stash->{title}     = ucfirst($c->action);
    $c->stash->{this_link} = $c->action;
}

=head2 add

Add a client

=cut

sub add : Path('add')
        : Args(0)
        : FormConfig
        : Sitemap
        : Does('ACL') AllowedRole('admin') AllowedRole('can_edit') ACLDetachTo('denied')
        : Does('NeedsLogin')
{
    my ( $self, $c ) = @_;

    $c->stash->{title}     = 'Clients: Add a new client';
    my $form = $c->stash->{form};

    # Prepand a random salt to the password
    # =====================================
    my $form_elem_password = $form->get_field( 'password' );
    $form_elem_password->filter({
        type     => 'Callback',
        callback => sub {
            # Get a random salt
            # =================
            my $random_data = read_random_entropy( 64,
                $c->config->{really_secure_passwords}  # /dev/random and if true: /dev/urandom
            ); 

            # "Hexify" data
            # =============
            my $salt = unpack("H*", $random_data);

            # Set the salt field
            # ==================
            $form->add_valid( 'salt', $salt );

            # Return salt+password
            # ====================
            return $salt.shift;
        }
    });

    # Form process 
    # =============
    $form->process;

    # Form submitted and valid
    # ========================
    if ( $form->submitted_and_valid ) {

        #die $c->req->params->{password};
        use Data::Dumper::Concise;

        # New resultset
        # =============
        my $_client;
        try     { $_client = $c->model('DB::User')->new_result({}); }
        catch   { push @{$c->stash->{error}}, $_; };

        # update dbic row with
        # submitted values from form
        # ==========================
        try   { $form->model->update( $_client ) }
        catch { $self->_db_error($c, $_, $_, $form) }; 
    
        my ( $_client_role_id, $error_clean, $error );
        try {
           $_client_role_id = $c->model('DB::Role')
                ->search(
                    { name => 'client' },
                    { select   => 'id' },   
                );
            }
            catch { push @{$c->stash->{error}}, $_; };

            try {
                $c->model('DB::UserRole')
                    ->create(
                        {
                            user_id => $_client->id,
                            role_id => $_client_role_id->next->id,
                        }
                    );
            } catch {
                $error_clean = $_;
                $error = $_;
            };

            # Create client configuration file
            # ================================
            if ( ! -e $c->config->{openvpn_ccd} || ! -w $c->config->{openvpn_ccd} ){
                #$self->_error($c,
                #    "Cannot create ccd file for " . $_client->username
                #    . ": directory '" . $c->config->{openvpn_ccd}
                #    . "' does not exists or is not writable!" );
            }

            my $_file = $c->config->{openvpn_ccd} . '/' . $_client->username;

            open (my $FILE, '>', $_file);
                #or $self->_error($c, "Cannot create ccd file for "
                #    . $_client->username . ': ' . $!);
            print {$FILE} '#'.md5_hex( $c->req->params->{username} . "\n" . $c->req->params->{password} . "\n");

            ## For Debug: -- remove
            print $FILE "\n#Generated from:\n" . $c->req->params->{username} . "\n" . $c->req->params->{password} . "\n";

            close $FILE;
            # Set permissions and ownership
            # =============================
            my ( $uid, $gid ) = $self->_get_user_group_id( $c );
            chown $uid, $gid, $_file
                or $self->_error($c, " chmod error '" . $_file . "': " . $!);

            chmod 0640, $c->config->{openvpn_ccd} . '/' . $_client->username
                or $self->_error($c, " chown error '" . $_file . "': " . $!);
                
            # Rollback on errors
            # ==================
            $_client->delete  if $c->stash->{error};

            push (@{$c->flash->{success_messages}},
                "Client \\'" . $_client->username . "\\' added successfully.");

            $c->response->redirect( $c->uri_for('add') );
            return;
        }

        # Check if any errors in form
        # FormFu handles this automatically
        # but we are using ajax for this
        # call, so we need to override
        # FormFu and send the errors back
        # ================================
        if ( $form->has_errors ) {
            for ( @{$form->get_errors} ){
                try  { 
                    #push @{$c->stash->{fields_error}} , $_->name;
                    #push @{$c->stash->{error}},
                    #    "Error in field: '" . $_->name . "': " . $_->message
                    #    . " - " . $_->type
                    #    . ( $_->constraint->message ? ' - ' . $_->constraint->message : '' )
                    #    . ( $_->constraint->regex ? ", '" . $_->constraint->regex . "'" : '' );
                }
                catch {
                     #push @{$c->stash->{error}}, $_;
                };
            }

            $c->res->headers->header('Content-Type' => 'text/html');
            # Add js / css
            # ============
            include_default_links( $self, $c );
            $c->forward('View::HTML');    
            return;
        }
}

=head2 _db_error

Handle Database error

=cut

sub _db_error : Private {
    my ( $self, $c, $error_clean, $error, $form ) = @_;

    #$c->response->status(500);    

    if ( $error_clean =~ /duplicate entry '(.*)' for key '(.*)' /i ){
        push @{$c->stash->{error}}, $2 if $2;
        $form->get_field( $2 )
            ->get_constraint({ type => 'Callback' })
            ->force_errors(1);
        $form->process;
    }
    elsif ( $_ =~ /(execute failed: Column) '(.*)' (.*) \[/g ) {
        push @{$c->stash->{error}}, $2 if $2;
        my ($_err) = $error =~ /(execute failed: .*) \[/g;
        push @{$c->stash->{error}}, "MySQL error: " . $_err if $_err;
    }
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
    include_default_links( $self, $c );
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

    $c->stash->{username} = $c->user->get("username")
      if ( $c->user_exists );

    my $accept = $c->req->header('accept');
    $c->req->headers->header('accept' => 'application/xhtml+xml'); 
    my $content_type = $c->req->header('content-type');
    if($accept =~ /html/){ 
        $c->res->headers->header('Content-Type' => 'text/html');
        # Add js / css
        # ============
        include_default_links( $self, $c );
    } 
    elsif ( $accept =~ /xml/){ 
        $c->res->headers->header('Accept' => 'text/xml'); 
        $c->forward('View::XML::Simple');
    } 
    elsif ( $accept =~ /json/ ){
        $c->res->headers->header('Accept' => 'application/json'); 
        $c->forward('View::JSON');
    }

}


=head1 AUTHOR

Nuriel Shem-Tov

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
