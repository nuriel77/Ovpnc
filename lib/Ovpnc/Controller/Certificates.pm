package Ovpnc::Controller::Certificates;
use Module::Locate qw(locate);
scalar locate('File::Slurp') ? 0 : do { use File::Slurp; };
scalar locate('JSON::XS')    ? 0 : do { use JSON::XS; };

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

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

around [qw(index)] => sub {
    my ( $orig, $self, $c ) = @_;

    # Sanity check
    my $err = $c->forward('/api/sanity');
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

sub index : Path : Args(0) : Does('NeedsLogin') {
    my ( $self, $c ) = @_;

    # Get the country list (for certificates signing)
    my @clist = @{ $self->get_country_list( $c->config->{country_list} ) };

    $c->stash->{title}     = 'Certificates';
    $c->stash->{this_link} = 'certificates';
    $c->stash->{logged_in} = 1;

    # Get geo username
    $c->stash->{geo_username} = $c->config->{geo_username};

    # stash country list
    $c->stash->{countries} = [ sort { $a cmp $b } @clist ];
}

=head2 get_country_list

Get country list from the json data

=cut

sub get_country_list : Private {
    my ( $self, $file ) = @_;

    die "No file specified" unless $file;
    my $_list = read_file($file) or die "Cannot read '$file': $!";
    my $json  = JSON::XS->new->ascii->allow_nonref;
    my @clist = map {
        {
            $_->{countryName} => {
                code => $_->{countryCode},
                id   => $_->{geonameId},
              }
        }
    } @{ ( $json->decode($_list) ) };
    return \@clist;
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {
    my ( $self, $c ) = @_;

    # Will load any js or css
    Ovpnc::Controller::Root->include_default_links($c);

    # stash username
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
