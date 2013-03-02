package Ovpnc::Controller::Clients;
use Ovpnc::Model::ChainCA 'read_random_entropy';
use Ovpnc::Model::Sanity;
use Try::Tiny;
use Digest::MD5 'md5_hex';
use utf8;
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


=head2 add

Add a client

=cut

    sub add : Path('add')
            : Args(0)
            : FormConfig
            : Does('ACL')
                AllowedRole('admin')
                AllowedRole('can_edit')
                ACLDetachTo('denied')
            : Does('NeedsLogin')
            : Sitemap
    {
        my ( $self, $c ) = @_;

        $c->stash->{title}     = 'Clients: Add a new client';
        my $form = $c->stash->{form};

		# Adds a class near field labels
		# to style and add '*' on required
		# ================================
        $form->auto_constraint_class( 'constraint_%t' );
        
        # Prepand a random salt to the password
        # =====================================
        #my $form_elem_password = $form->get_field( 'password' );
        #$form_elem_password->filter({
        #    type     => 'Callback',
        #    callback => \&_get_random_salt
        #});
    
        # Form process 
        # =============
        $form->process;
    
    	my @fields = qw (
    		email
    		fullname
    		password
    		password2
    		username	
    	);
    
        my $phone = $c->req->params->{phone};
        my $address = $c->req->params->{address};
        delete $c->req->params->{phone} if $c->req->params->{phone} or $c->req->params->{phone} eq '';
        delete $c->req->params->{address} if $c->req->params->{address} or $c->req->params->{address} eq '';
    	my @keys = sort keys %{$c->req->params};

        # Form submitted and valid
        # ========================
        #if ( $form->submitted_and_valid ) {
        if ( @keys ~~ @fields ){
        	for (@keys){
				if (! $c->req->params->{$_} or $c->req->params->{$_} eq '' ){
					push @{$c->stash->{errors}}, "Missing parameter: " . $_;	
				}
			}
			if (
				$c->stash->{errors}
			 && ref $c->stash->{errors} eq 'ARRAY'
			 && @{$c->stash->{errors}} > 0
			){
				$c->res->status(400);
				$c->detach('View::JSON');
				return;
			}
        	$c->req->params->{phone} = $phone || undef;
        	$c->req->params->{address} = $address || undef;
        	
            my ($username, $email);
            try     {
                        $username = 
                            $c->model('DB::User')->search(
                                { username  => $c->req->params->{username}  },
                            )->count;
                        $email    =
                            $c->model('DB::User')->search(
                                { email     => $c->req->params->{email}     }
                            )->count;
            }
            catch   { push @{$c->stash->{errors}}, (split(/\n/,$_))[0]; };
            if ( $username and $username > 0 ) {
                push @{$c->stash->{errors}}, 'Failed to create new user. Username already exists.';
                $form->process;

                $c->res->headers->header('Content-Type' => 'application/json');
                $c->detach('View::JSON');
                return;
            }
            if ( $email and $email > 0 ){       
                push @{$c->stash->{errors}}, 'Failed to create new user. Email already exists.';
                $form->process;
                $c->res->headers->header('Content-Type' => 'application/json');
                $c->detach('View::JSON');
                return;
            }

			if ( $c->req->params->{password} ne $c->req->params->{password2} ){
				push @{$c->stash->{errors}}, 'Failed to create new user: password fields do not match.';
                $form->process;
                $c->res->headers->header('Content-Type' => 'application/json');
                $c->detach('View::JSON');
                return;
			}
			
            if ( !$email and !$username ) {
             	
                # Generate a random salt
                # ======================
             	$c->req->params->{salt} = $self->_get_random_salt($c);

             	delete $c->req->params->{password2};
             	
                # New resultset
                # =============
                my $_client;
                #try     { $_client = $c->model('DB::User')->new_result({}); }
                #catch   { push @{$c->stash->{errors}}, $_; };

                # update dbic row with
                # submitted values from form
                # ==========================
                #try   { $form->model->update( $_client ) }
                try { 
                	$_client = $c->model('DB::User')->create({
                		email		=> $c->req->params->{email},
    					fullname	=> $c->req->params->{fullname},
    					password	=> $c->req->params->{password}.$c->req->params->{salt},
    					username	=> $c->req->params->{username},
    					address		=> $c->req->params->{address} || '',
    					phone		=> $c->req->params->{phone} || '',
    					enabled		=> 0,
    					revoked		=> 0,
    					salt		=> $c->req->params->{salt}	
                	})
                }
                catch { $self->_db_error($c, $_, $_, $form) }; 
            
                my ( $_client_role_id, $error_clean, $error );
                try {
                   $_client_role_id = $c->model('DB::Role')
                        ->search(
                            { name => 'client' },
                            { select   => 'id' },   
                        );
                }
                catch { push @{$c->stash->{errors}}, $_; };
        
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
                    $self->_error($c,
                        "Cannot create ccd file for " . $_client->username
                        . ": directory '" . $c->config->{openvpn_ccd}
                        . "' does not exists or is not writable!" );
                }
        
                my $_file = $c->config->{openvpn_ccd} . '/' . $_client->username;
                open (my $FILE, '>', $_file)
                    or $self->_error($c, "Cannot create ccd file for "
                        . $_client->username . ': ' . $! );
                print {$FILE} '#'.md5_hex( $c->req->params->{username} . "\n" . $c->req->params->{password} . "\n");
        
                ## For Debug: -- remove
                print $FILE "\n"
                            . 'Generated from:'
                            . "\n"
                            .'#'. $c->req->params->{username}
                            . "\n"
                            . '#'
                            . $c->req->params->{password}
                            . "\n";
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
                if ($c->stash->{errors}){
                	$_client->delete;
                }
    			else {
    				$c->res->status(201);
                	$c->stash->{resultset} =
                    	"Client " . $_client->username . " added successfully.";
    			}
				$c->detach('View::JSON');
                return;
            }
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
                    push @{$c->stash->{fields_error}} , $_->name;
                    push @{$c->stash->{errors}},
                        "Error in field: '" . $_->name . "' - " . $_->message
                        . " - " . $_->type
                        . ( $_->constraint->message ? ' - ' . $_->constraint->message : '' )
                        . ( $_->constraint->regex ? ", '" . $_->constraint->regex . "'" : '' );
                }
                catch {
                     push @{$c->stash->{errors}}, $_;
                };
            }

            $c->res->headers->header('Content-Type' => 'application/json');
            $c->detach('View::JSON');    
            return;
        }
    }

    
=head2 _db_error

Handle Database error

=cut

    sub _db_error : Private {
        my ( $self, $c, $error_clean, $error, $form ) = @_;

        if ( $error_clean =~ /duplicate entry '(.*)' for key '(.*)' /i ){
            push @{$c->stash->{errors}}, $2 if $2;
            $form->get_field( $2 )
                ->get_constraint({ type => 'Callback' })
                ->force_errors(1);
            $form->process;
        }
        elsif ( $_ =~ /(execute failed: Column) '(.*)' (.*) \[/g ) {
            push @{$c->stash->{errors}}, $2 if $2;
            my ($_err) = $error =~ /(execute failed: .*) \[/g;
            push @{$c->stash->{errors}}, "MySQL error: " . $_err if $_err;
        }
        elsif ( $_ =~ /(execute failed:.*) \[/g ) {
            push @{$c->stash->{errors}}, "Error: " . $1;
        }
        else { 
            push @{$c->stash->{errors}}, "Error: " . $error_clean;
        }
    }
    
=head2 _error

Handle General error

=cut

    sub _error : Private {
        my ( $self, $c, $error ) = @_;
        push @{$c->stash->{errors}}, $error;
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
        $c->controller('Root')->include_default_links($c);
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

        my $accept = $c->req->header('accept') || '';
        $c->req->headers->header('accept' => 'application/xhtml+xml'); 
        my $content_type = $c->req->header('content-type');
        if($accept =~ /html/){ 
            $c->res->headers->header('Content-Type' => 'text/html');
            # Add js / css
            # ============
            $c->controller('Root')->include_default_links($c);
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


=head2 _get_random_salt

Get a random salt to be prepended
to the new password

=cut

	sub _get_random_salt{
		my ($self, $c) = @_;
    
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
        #$form->add_valid( 'salt', $salt );    

        # Return salt+password
        # ====================
        return $salt;
	} 

=head1 AUTHOR

Nuriel Shem-Tov

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
