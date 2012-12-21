package Ovpnc::Controller::Certificates;
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

    $c->stash->{token} = $c->get_session_id;

    $c->config->{ovpnc_conf} = $c->config->{ovpnc_conf} =~ /^\//
        ? $c->config->{ovpnc_conf}
        : $c->config->{home} . '/' . $c->config->{ovpnc_conf};

    $c->config->{openvpn_user} =
      Ovpnc::Controller::Api::Configuration->get_openvpn_param(
        $c->config->{ovpnc_conf}, 'UserName' );

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

    # Force submit param
    # ==================
    $c->req->params->{'submit'} ||= 'Submit';

    $c->stash->{title}     = 'Clients: Add a new client';

    my $form = $c->stash->{form};
    
    # Verify all fields have been submitted
    # FixMe: FormFu doesn't like ajax, check why
    # ->submitted doesn't work (although forced
    # submit param at start of this action)
    # ==========================================
    my @_keys = sort keys %{$c->req->params} if scalar keys %{$c->req->params} > 1;
    my @_columns = qw[C ST L O OU CN key_size password password2 submit name emailAdress expires type user_id ];

    # Form submitted okay
    # ===================
    if ( @_keys && @_columns ~~ @_keys ) {

        $form->process;

        # Check if any errors in form
        # FormFu handles this automatically
        # but we are using ajax for this
        # call, so we need to override
        # FormFu and send the errors back
        # =================================
        if ( $form->has_errors ) {
            for ( @{$form->get_errors} ){
                try  {
                    push @{$c->stash->{fields_error}} , $_->name;
                    push @{$c->stash->{error}},
                        "Error in field: '" . $_->name . "': " . $_->message
                        . " - " . $_->type
                        . ( $_->constraint->message ? ' - ' . $_->constraint->message : '' )
                        . ( $_->constraint->regex ? ", '" . $_->constraint->regex . "'" : '' );
                    delete $c->stash->{$_} for ( qw/assets form token/ );
                    delete $c->req->params->{submit};
                }
                catch {
                     push @{$c->stash->{error}}, $_;
                };
            }
            $c->response->status(400);
            $c->forward('View::JSON');
            $c->detach;
        }

        if ( $form->submitted_and_valid ) {

            # If submitted we go "JSON"
            # =========================
            delete $c->stash->{$_} for ( qw/assets form token/ );
            delete $c->req->params->{submit};
            # New resultset
            # =============

            my $_client;
            try {
                $_client = $c->model('DB::User')->new_result({});
            }
            catch {
                push @{$c->stash->{error}}, $_;
            };

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
        }
    }
    else {
        # HTML view
        # =========
        $c->response->headers->header('Content-Type' => 'text/html');
        Ovpnc::Controller::Root->include_default_links( $c );

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
    Ovpnc::Controller::Root->include_default_links($c);
    $c->stash->{this_link}     = 'certificates';
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
    # ============
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
