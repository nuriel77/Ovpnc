package Ovpnc::Controller::Api::Certificates;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config( namespace => 'api/certificates' );

=head1 NAME

Ovpnc::Controller::Api::Certificates - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 base

For chain to login page

=cut

sub base : Chained('/base') PathPrefix CaptureArgs(0) {
}

=head2 index

For REST action class

=cut

sub certificates : Chained('/') PathPart('api/certificates') Args(0) :
  ActionClass('REST') {
}

=head2 get_cert

=cut

sub certificates_POST : Path('certificates') : Args(0) Does('NeedsLogin') {
    my ( $self, $c ) = @_;

    # Set openssl environment variables (eq to source ./vars)
    my $oe = {
        EASY_RSA           => $c->config->{openvpn_dir},
        OPENSSL            => $c->config->{openvpn_bin},
        PKCS11TOOL         => $c->config->{openvpn_dir} . 'pkcs11-tool',
        GREP               => '/bin/grep',
        KEY_CONFIG         => $c->config->{openssl_conf},
        KEY_DIR            => $c->config->{openvpn_dir} . 'keys',
        PKCS11_MODULE_PATH => 'dummy',
        PKCS11_PIN         => 'dummy',
        KEY_SIZE           => $c->req->params->{key_size} || 1024,
        CA_EXPIRE          => $c->req->params->{ca_expire} || 3650,
        KEY_EXPIRE         => $c->req->params->{key_expire} || 3650,
        KEY_COUNTRY        => $c->req->params->{key_country} || 'NL',
        KEY_PROVINCE       => $c->req->params->{key_province} || 'NH',
        KEY_CITY           => $c->req->params->{key_city} || 'Amsterdam',
        KEY_ORG            => $c->req->params->{key_org} || 'DeBar',
        KEY_EMAIL          => $c->req->params->{key_email} || 'nuri@de-bar.com',
    };

    $ENV{$_} = $oe->{$_} for ( keys %{$oe} );

    # 	$self->status_ok(
    #       $c,
    #        entity => { test => 'just a test' },
    # 	);

}

=head2 certificates_GET

Get certificate(s) data

=cut

sub certificates_GET : Path('certificates') : Args(0) Does('NeedsLogin') {
    my ( $self, $c ) = @_;
    $self->status_ok(
        $c,
        entity => {
            some => 'dsta',
            foo  => 'is real bar-x',
        },
    );
}

=head2 certificates_GET

Delete certificate(s)

=cut

sub certificates_DELETE : Path('certificates') : Args(0) Does('NeedsLogin') {
    my ( $self, $c ) = @_;
    $self->status_ok(
        $c,
        entity => {
            some => 'dsta',
            foo  => 'is real bar-x',
        },
    );
}

sub default : Private {
    my ( $self, $c ) = @_;
    $c->stash( { status => 'Control action not found' } );
    $c->response->status(404);
}

sub end : Private {
    my ( $self, $c ) = @_;

    # Debug if requested
    die "forced debug" if $c->req->params->{dump_info};

    # Clean up the File::Assets
    # it is set to null but
    # is not needed in JSON output
    delete $c->stash->{assets};

    # Forward to JSON view
    $c->forward(
        ( $c->request->params->{xml} ? 'View::XML::Simple' : 'View::JSON' ) );
}

=head1 AUTHOR

Nuriel Shem-Tov

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
