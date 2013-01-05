package Ovpnc::Controller::Certificates;
use Ovpnc::Model::ChainCA 'read_random_entropy';
use POSIX 'mktime';
use Try::Tiny;
use URI::Escape;
use Date::Calc qw(Delta_Days);
use DateTime::Format::Strptime;
use Module::Locate qw(locate);
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

    # Get geo username
    # ================
    $c->stash->{geo_username} = $c->config->{geo_username};

    $c->stash->{token} = $c->get_session_id;

    $c->config->{ovpnc_conf} = $c->config->{ovpnc_conf} =~ /^\//
        ? $c->config->{ovpnc_conf}
        : $c->config->{home} . '/' . $c->config->{ovpnc_conf};

    $c->config->{openvpn_user} =
      $c->controller('Api::Configuration')->get_openvpn_param(
        'UserName', $c->config->{ovpnc_conf} );

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
    
        # Get the form object
        # ===================
        my $form = $c->stash->{form};
        $form->auto_constraint_class( 'constraint_%t' );

        # Get the username for current
        # logged in user id, set in 
        # form as ca_username
        # ============================
        my $ca_username_element =
            $form->get_field({ name => 'ca_username' });
        my $rs =
            $c->model('DB::User')
                ->search(
                    { id => $c->session->{__user}->{id} },
                    { select => 'username' })
                ->single;
        $ca_username_element->value( $rs->username );

        # Check if a root and/or
        # server certificate exist
        # Add to stash to display
        # ========================

        if ( $c->req->params->{cert_type}
          && $c->req->params->{cert_type} eq 'server'
        ){
            if ( my $_chk_certs = $self->_chk_main_certs( $c ) ){ 
                push @{$c->flash->{error}}, $_chk_certs;
            }
        }

        # Process FormFu
        # ==============    
        $form->process;

        # Form submitted okay
        # ===================
        if ( $form->submitted_and_valid ) {    

            # Calculate the days between
            # the two given dates for expiration
            # ==================================
            $c->req->params->{KEY_EXPIRE} =
                $self->_calculate_delta_days(
                    $c->req->params->{start_date},
                    $c->req->params->{KEY_EXPIRE},
                );

            # Organize other fields
            # =====================
            delete $c->req->params->{$_} for qw/submit start_date/;
            $c->req->params->{KEY_COUNTRY} = $c->req->params->{KEY_COUNTRY_TEXT}
                && delete $c->req->params->{KEY_COUNTRY_TEXT};
            $c->req->params->{KEY_PROVINCE} = $c->req->params->{KEY_STATE_TEXT}
                && delete $c->req->params->{KEY_STATE_TEXT};
            $c->req->params->{KEY_CITY} = $c->req->params->{KEY_CITY_TEXT}
                && delete $c->req->params->{KEY_CITY_TEXT};
    
            # For server and client certificates
            # ==================================
            if ( $c->req->params->{cert_type} =~ /client|server/ ){
                $c->req->params->{cmd} = 'gen_cert';
            }
            # For generating Root CA certificate 
            # ==================================
            elsif ( $c->req->params->{cert_type} eq 'ca' ){
                $c->req->params->{cmd} = 'init_ca';                
            }
    
            # Run action on api controller
            # ============================
            my $result = $c->controller('Api::Certificates')
                ->certificates_POST( $c, $form );
    
            # Handle results
            # ==============
            if ( $result and $result->{status} ){
                if ( ref $result->{status} eq 'HASH' or ! ref $result->{status} ) {
                    $c->flash->{resultset} =
                        "Certificate add process returned: " . $result->{status};
                }
                elsif ( ref $result->{status} eq 'ARRAY' ) {
                    if ( scalar @{$result->{status}} == 4 ){
                        $c->flash->{resultset} =
                            "Root certificate, key, DH permissions, and TA key file created successfully."
                    }
                }
            }
            elsif ( $result and $result->{error} ){
                my ($_escp) = ( split /\n/, $result->{error} )[0];
                $c->flash->{error} = "Error: " . uri_escape( $_escp );
            }
            else {
                $c->flash->{error} = "Error: Status unknown";
            }

            $c->response->redirect( $c->uri_for('add') );
            return;       
        }
   
        # Check if any errors in form
        # FormFu handles this automatically
        # =================================
        if ( $form->has_errors ) {
        }

        # Get the country list (for certificates signing)
        # ===============================================
        $c->config->{country_list} = $c->config->{country_list} =~ /^\//
            ? $c->config->{country_list}
            : $c->config->{home} . '/' . $c->config->{country_list};

        my @clist = @{ $self->get_country_list( $c->config->{country_list} ) };

        # stash country list
        # ==================
        $c->stash->{countries} = [ sort { $a cmp $b } @clist ];

=head2 Countries Datastructure Example

[
  {
    Andorra => {
      code => "AD",
      id => 3041565
    }
  },
]

=cut

        my $form_elem_country = $form->get_field({name => 'KEY_COUNTRY'});

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

    }


=head2 _calculate_delta_days

Calculate the days between
two given date formats

=cut 
    
    sub _calculate_delta_days : Private {
        my ( $self, $start_date, $key_expire ) = @_;

        my $parser = DateTime::Format::Strptime
            ->new( pattern => '%d-%m-%Y' );

        $start_date = $parser->parse_datetime( $start_date );
        $key_expire = $parser->parse_datetime( $key_expire );

        my @start_date = (localtime($start_date->epoch))[5,4,3];
        my @key_expire = (localtime($key_expire->epoch))[5,4,3];
        $start_date[0] += 1900 and $start_date[1]++;
        $key_expire[0] += 1900 and $key_expire[1]++;
        return Delta_Days(@start_date, @key_expire);

    }

=head2 _chk_main_certs

Check if Root CA or server
certificate have already
been created

=cut

    sub _chk_main_certs : Private {
        my ( $self, $c ) = @_;

        my $_main_certs;
        try {
            $_main_certs = $c->model('DB::Certificate')->search(
                { cert_type => [ 'ca', 'server' ] },
                { select => 'cert_type' }
            );
        }
        catch {
            push @{$c->flash->{error}}, $_;
            return undef;
        };
        my ( $have_server, $have_ca );
        while ( my $t = $_main_certs->next ){            
            $have_server = 1 if $t->cert_type eq 'server';
            $have_ca     = 1 if $t->cert_type eq 'ca';
        }

        if ( not $have_ca and not $have_server ){
            return
                'You must have a Root CA, only then server and client certificates can be generated.';
        }
        if ( ( $have_ca and not $have_server )
              and $c->req->params->{cert_type} ne 'server'
        ){
            return 
                'You must have a serve certificate before you can generate client certificates.';
        }

        return undef;

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

        $c->res->status(403);
        
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

