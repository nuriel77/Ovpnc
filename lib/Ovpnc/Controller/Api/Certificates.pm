package Ovpnc::Controller::Api::Certificates;
use warnings;
use strict;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config( namespace => 'api' );

with 'MooseX::Traits';
has '+_trait_namespace' => (
    default => sub {
        my ( $P, $SP ) = __PACKAGE__ =~ /^(\w+)::(.*)$/;
        return $P . '::TraitFor::' . $SP;
    }
);

has 'cfg' => (
    is        => 'rw',
    isa       => 'HashRef',
    predicate => '_has_conf'
);

has '_roles' => (
    is  => 'rw',
    isa => 'Object',
);


=head1 NAME

Ovpnc::Controller::Api::Certificates - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 certificates

For REST action class

=cut

sub certificates : Local : Args(0) : ActionClass('REST') {
}


=head2 before...

Method modifier

=cut

before [qw(
        certificates_POST
    )] => sub {
    my ( $self, $c ) = @_;

    # File::Assets might leave an empty hash
    # so we better delete it, no need in api
    # ======================================
    delete $c->stash->{assets} if $c->stash->{assets};

    # Assign config params
    # ====================
    $self->cfg( Ovpnc::Controller::Api->assign_params( $c ) )
        unless $self->_has_conf;
};

=head2 certificates_POST

Certificate actions such as generating
a new CA, server or client certificates
requires user to provide options

=cut

sub certificates_POST : Local
                      : Args(0)
                      : Sitemap
#                      : Does('NeedsLogin')
{
    my ( $self, $c ) = @_;

    my $req = $c->request->params;

    # 'cmd' must always be provided
    # =============================
    unless ( $req->{cmd} ){
        $self->status_bad_request($c, message =>
            "Missing param 'cmd'"
        );
        delete $c->stash->{assets};
        $c->detach;
    }

    # Set roles
    # =========
    $self->_roles(
        $self->new_with_traits(
            traits         => [ qw( Vars BuildDH ) ],
            openvpn_dir    => $c->config->{openvpn_dir},
            openssl_bin    => $c->config->{openssl_bin},
            openssl_conf   => $c->config->{openssl_conf},
            _req           => $c->request->params,
            _cfg           => $self->cfg,
        )
    );

    # Possible options
    # ================
    my $_options = {
        build_dh        => sub { return $self->_build_dh( @_ ) },
        gen_ca          => sub { return $self->_gen_ca( @_ ) },
        gen_server      => sub { return $self->_gen_server( @_ ) },
        gen_client      => sub { return $self->_gen_client( @_ ) }
    };

    # Same as source ./vars
    # =====================
    $self->_roles->set_environment_vars;

    # Match param command against our
    # list of possible commands
    # Execute on match (closure)
    # ===============================
    my ( $_found, $_ret_val );
    for my $_command ( keys %{$_options} ){
        if ( $_command eq $req->{cmd} ){
            $_ret_val = $_options->{$_command}->( $req );
            $_found++;
        }
    }

    # No command match?
    # =================
    unless ( $_found ){
        $self->status_bad_request($c,
            message => 'Unknown option ' . $req->{cmd}
        );
        $c->detach;
    }
    # Process return value
    # ====================
    if ( ref $_ret_val ){
        # Any errors? put in error stash
        if ( $_ret_val->{error} ){
            $self->_send_err($c, $_ret_val->{error});
        }
        # All ok? return what is supposed to
        # be the newely generated filename
        elsif ( $_ret_val->{status} ) {
            $self->status_ok($c, entity => $_ret_val );
            $c->detach;
        }
        else {
           $self->_send_err($c, "Something went wrong with command " . $req->{cmd} );
        }
    }
    else {
        $self->_send_err($c, "Something went wrong with command " . $req->{cmd} );
    }

}


=head2 certificates_GET

Get certificate(s) data

=cut

sub certificates_GET : Local
                     : Args(0)
                     : Sitemap
#                     : Does('NeedsLogin')
{
    my ( $self, $c ) = @_;
    $self->status_ok(
        $c,
        entity => {
            some => 'dsta',
            foo  => 'is real bar-x',
        },
    );
}

=head2 certificates_DELETE

Delete certificate(s)

=cut

sub certificates_DELETE : Local
                        : Args(0)
                        : Sitemap
                        #: Does('NeedsLogin')
{
    my ( $self, $c ) = @_;
    $self->status_ok(
        $c,
        entity => {
            some => 'dsta',
            foo  => 'is real bar-x',
        },
    );
}


=head2 _build_dh

Generate DH secret

=cut

sub _build_dh : Private {
    my ( $self, $req ) = @_;
    return $self->_roles->build_dh;
}

=head2 _send_err

detach with status 500
and the error message

=cut

sub _send_err : Private {
    my ( $self, $c, $msg ) = @_;
    $c->response->status(500);
    delete $c->stash->{assets};
    $c->stash->{error} = $msg ? $msg : 'An unknown error has occured';
    $c->detach;
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
