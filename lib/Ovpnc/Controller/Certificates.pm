package Ovpnc::Controller::Certificates;
use Module::Locate qw(locate);
use Ovpnc::Plugin::ChainCA 'read_random_entropy';
scalar locate('File::Slurp') ? 0 : do { use File::Slurp; };
scalar locate('JSON::XS')    ? 0 : do { use JSON::XS; };
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller::HTML::FormFu'; }

has 'json' => (
    is => 'ro',
    isa => 'Object',
    default => sub { return JSON::XS->new->ascii->allow_nonref  },
);

=head1 NAME

Ovpnc::Controller::Certificates - Catalyst Controller

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

    $c->config->{ovpnc_conf} = $c->config->{ovpnc_conf} =~ /^\//
        ? $c->config->{ovpnc_conf}
        : $c->config->{home} . '/' . $c->config->{ovpnc_conf};

    $c->config->{openvpn_user} =
      $c->controller('Api::Configuration')->get_openvpn_param(
        'UserName', $c->config->{ovpnc_conf} );

    # Sanity check
    # ============
    my $err = Ovpnc::Plugin::Sanity->action( $c->config );
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


=head2 begin

Before any action

=cut

    sub begin : Private {
        my ( $self, $c ) = @_;
        $c->stash->{title}     = ucfirst($c->action);
        $c->stash->{this_link} = $c->action;
    }



=head2 index

Main certificates page

=cut

    sub index : Path
              : Args(0)
              : Does('ACL')
                AllowedRole('admin')
                AllowedRole('can_edit')
                ACLDetachTo('denied')
              : Does('NeedsLogin')
              : Sitemap
    {
        my ( $self, $c ) = @_;
        $c->stash->{content} = 'This will be certificates management main index page';
    }


=head2 add

Add a new certificate

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
    
        $c->stash->{title}     = 'Certificates: Add a new certificate';
    
        my $form = $c->stash->{form};


        # HTML view
        # =========
        $c->controller('Root')->include_default_links($c);

        # Get the country list (for certificates signing)
        # ===============================================
        $c->config->{country_list} = $c->config->{country_list} =~ /^\//
            ? $c->config->{country_list}
            : $c->config->{home} . '/' . $c->config->{country_list};

        my @clist = @{ $self->get_country_list( $c->config->{country_list} ) };

        # Get geo username
        # ================
        $c->stash->{geo_username} = $c->config->{geo_username};

        # stash country list
        # ==================
        $c->stash->{countries} = [ sort { $a cmp $b } @clist ];

=comment Countries datastructure
    
[
  {
    Andorra => {
      code => "AD",
      id => 3041565
    }
  },
]

=cut

        my $form_elem_country = $form->get_field({name => 'C'});

        # Set default value for country
        # if it exists in the cookie
        # =============================
        my $cookie  = $c->request->cookie("Ovpnc_addCeritifcate_Form_Settings");
        my $last_country = $cookie ? $self->json->decode( $cookie->value ) : undef;

        # Populate the options
        # state and city will
        # be done by ajax/js
        # ====================
        my @_formatted_countries;
        my $_country_got_selected;
        C: for ( @{$c->stash->{countries}} ){
            # We should not have such
            # a situation with two keys
            next C if scalar keys %{$_} > 1;
            my $key = (keys %{$_})[0];
            my $data = {
                value       => $_->{$key}->{id},
                label       => $_->{$key}->{code} . ' - ' . $key
            };

            if ( defined $last_country
                 and $last_country->{country} == $_->{$key}->{id}
            ){
                $data->{attributes} =
                    { style => 'highlighted', selected => 'selected' };
                $_country_got_selected = 1;
            }

            push @_formatted_countries, $data;
        }
    
        unshift (@_formatted_countries, {
            value => '0',
            label => '-',
            attributes => {
                style => 'highlighted',
                selected => 'selected'
            } 
        }) unless $_country_got_selected;

        $form_elem_country->options( \@_formatted_countries )
            if @_formatted_countries;

    
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
    
        $form->process;

        # Form submitted okay
        # ===================
        if ( $form->submitted_and_valid ) {    

            $c->response->redirect( $c->uri_for('add') );
            return;
       
        }
   
        # Check if any errors in form
        # FormFu handles this automatically
        # =================================
        if ( $form->has_errors ) {
             # Add js / css
            # ============
            $c->controller('Root')->include_default_links( $self, $c );
            $c->forward('View::HTML');    
            return;
        }

    }
 
    

=head2 get_country_list

Get country list from the json data

=cut

sub get_country_list : Private {
    my ( $self, $file ) = @_;

    die "No file specified" unless $file;
    my $_list = read_file( $file )
        or die "Cannot read '$file': $!";

    my @clist = map {
        {
            $_->{countryName} => {
                code => $_->{countryCode},
                id   => $_->{geonameId},
              }
        }
    } @{ ( $self->json->decode($_list) ) };
    return \@clist;
}

=head2 denied

Unauthorized access
no match for role

=cut

sub denied : Private {
    my ( $self, $c ) = @_;

    # Add js / css
    # ============
    $c->controller('Root')->include_default_links($c);
    $c->stash->{this_link}     = $c->req->path;
    $c->stash->{title}         = ucfirst( $c->req->path );
    $c->stash->{error_message} = "Access denied";
    $c->stash->{no_self}       = 1;
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

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;

