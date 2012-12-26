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


=head2 before...

Method modifier

=cut

before [qw(
        certificates_GET
        certificates_POST
    )] => sub {
    my ( $self, $c ) = @_;

    # File::Assets might leave an empty hash
    # so we better delete it, no need in api
    # ======================================
    delete $c->stash->{assets} if $c->stash->{assets};

    # Assign config params
    # ====================
    $self->cfg( $c->controller('Api')->assign_params( $c ) )
        unless $self->_has_conf;
};


=head2 certificates

For REST action class

=cut

    sub certificates : Local : Args(0) : ActionClass('REST') {
    }



=head2 begin

Automatic first
action to run

=cut

    sub begin : Private {
        my ( $self, $c ) = @_;

        # Log user in if login params are provided
        # =======================================
        $c->controller->('Api')->auth_user( $c )
            unless $c->user_exists();

        # Set the expiration time
        # if user is logged in okay
        # =========================
        if ( $c->user_exists() && !$c->req->params->{_} ){
            $c->log->info('Setting session expire to '
                . $c->config->{'api_session_expires'});
            $c->change_session_expires(
                $c->config->{'api_session_expires'} )
        }

    }



=head2 certificates_POST

Certificate actions such as generating
a new CA, server or client certificates
requires user to provide options

=cut

    sub certificates_POST : Local
                          : Args(0)
                          : Does('ACL')
                                AllowedRole('admin')
                                AllowedRole('can_edit')
                                ACLDetachTo('denied')
                          : Does('NeedsLogin')
                          : Sitemap
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
            $c->detach('View::JSON');
        }
    
        # Set roles
        # =========
        $self->_roles(
            $self->new_with_traits(
                traits         => [ qw( Vars BuildDH BuildTA Generate ) ],
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
            build_ta        => sub { return $self->_build_ta( @_ ) },
            init_ca         => sub { return $self->_gen_ca( @_ ) },
            gen_cert        => sub { return $self->_gen_cert( @_ ) },
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
            if ( $c->req->params->{from_form} ){
                return { error => 'Unknown option ' . $req->{cmd} };
            }
            else {
                $self->status_bad_request($c,
                    message => 'Unknown option ' . $req->{cmd}
                );
                $c->detach('View::JSON');
            }
        }
        # Process return value
        # ====================
        if ( ref $_ret_val ){
            # Any errors? put in error stash
            # ==============================
            if ( $_ret_val->{error} ){
                if ( $c->req->params->{from_form} ){
                    return $_ret_val;
                }
                else {
                    $self->_send_err($c, $_ret_val->{error});
                }
            }
            # All ok? return what is supposed to
            # be the newely generated filename(s)
            # ===================================
            elsif ( ref $_ret_val eq 'HASH' ){
                if ( $c->req->params->{from_form} ){
                    return $_ret_val;
                }
                else {
                    $self->status_ok($c, entity => $_ret_val );
                    $c->detach('View::JSON');
                }
            }
            else {
                if ( $c->req->params->{from_form} ){
                    return { error => "Something went wrong with command " . $req->{cmd} };
                }
                else {
                    $self->_send_err($c, "Something went wrong with command " . $req->{cmd} );
                }
            }
        }
        else {
            if ( $c->req->params->{from_form} ){
                return { error => "Something went wrong with command " . $req->{cmd} };
            }
            else {
                $self->_send_err($c, "Something went wrong with command " . $req->{cmd} );
            }
        }
    
    }


=head2 certificates_GET

Get certificate(s) data

=cut

    sub certificates_GET : Local
                     : Args(0)
                     : Does('ACL')
                        AllowedRole('admin')
                        AllowedRole('can_edit')
                        ACLDetachTo('denied')
                     : Does('NeedsLogin')
                     : Sitemap
    {
        my ( $self, $c ) = @_;

        if (
                my $certname    = $c->req->params->{certname}
            and my $username    = $c->req->params->{name}
        ){
            $c->log->debug('Checking dir: ' . $self->cfg->{openvpn_utils} . '/keys/' . $username);
            $c->log->debug('Checking file: ' .$self->cfg->{openvpn_utils} . '/keys/' . $username
                        . '/' . $username . '.crt.' . $certname );
            if (
                    -d $self->cfg->{openvpn_utils} . '/keys/' . $username
                and -e $self->cfg->{openvpn_utils} . '/keys/' . $username
                        . '/' . $username . '.crt.' . $certname
            ){
                $self->status_bad_request($c, message => 'Certificate exists');
                $c->detach('View::JSON');
            }
            $self->status_ok($c, entity => { status => 'ok' } );
        }
    }


=head2 certificates_DELETE

Delete certificate(s)

=cut

sub certificates_DELETE : Local
                        : Args(0)
                        : Does('ACL')
                            AllowedRole('admin')
                            AllowedRole('can_edit')
                            ACLDetachTo('denied')
                        : Does('NeedsLogin')
                        : Sitemap
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
        my $self = shift;
        if ( my $_ret_val = $self->_roles->build_dh ){
            if ( ref $_ret_val eq 'HASH' ){
                return $_ret_val->{status} ? $_ret_val->{status} : $_ret_val;
            }
            else {
                return { error => $_ret_val };
            }
        }
    }


=head2 _build_ta

Generate ta.key secret

=cut

    sub _build_ta : Private {
        my $self = shift;

        if ( my $_ret_val = $self->_roles->build_ta ) {
            if ( ref $_ret_val eq 'HASH' ){
    	    return $_ret_val if $_ret_val->{error};
                warn "Did not chown 0400 new tls file!"
                    unless $self->_roles->set_chown_chmod(
                        $_ret_val->{status}->{filename} ? $_ret_val->{status}->{filename} : undef,
                        0400
                    );
                return $_ret_val->{status} ? $_ret_val->{status} : $_ret_val;
            }
            else {
                return { error => $_ret_val };
            }
        }
    
        return { error =>  "Build ta.key failed!" };
    }


=head2 _gen_ca

Create Root CA
Self signed

=cut

    sub _gen_ca : Private{
        my $self = shift;

        # Create a new CA + key
        # Setup the keys dir
        # =====================
        my $_ret_val = $self->_roles->init_ca( @_ );

        if ( defined $_ret_val && ref $_ret_val eq 'HASH' && $_ret_val->{error} ){
    	return $_ret_val;
        }

        if ( defined $_ret_val && ref $_ret_val ){

            # Build DH params
            # ===============
            push @{$_ret_val} , $self->_build_dh();

            # Build ta.key
            # ============
            push @{$_ret_val} , $self->_build_ta();

            return (
                ref $_ret_val eq 'ARRAY'
                    ? { status => $_ret_val }
                    : $_ret_val
            );
        }

        return undef;
    }


=head2

Generate a signed certificate
Needs a root CA

=cut

    sub _gen_cert : Private {

        my $_ret_val = shift->_roles->gen_ca_signed_certificate( @_ );
        if ( defined $_ret_val && ref $_ret_val ){
            return (
                ref $_ret_val eq 'ARRAY'
                    ? { status => $_ret_val }
                    : $_ret_val
            );
        }

        return undef;

    }


=head2 _send_err

detach with status 400
and the error message

=cut

    sub _send_err : Private {
        my ( $self, $c, $msg ) = @_;

        delete $c->stash->{assets};
        $c->stash->{error} = $msg ? $msg : 'An unknown error has occured';
        $self->status_bad_request($c, message =>
                ( $msg ? $msg : 'An unknown error has occured' )
            );
        $c->detach('View::JSON');

    }


=head2 end

Last action of this controller

=cut

    sub end : Private {
        my ( $self, $c ) = @_;
    
        # Debug if requested
        # ==================
        die "forced debug" if $c->req->params->{dump_info};

        # Clean up the File::Assets
        # it is set to null but
        # is not needed in JSON output
        # ============================
        delete $c->stash->{assets};
    
        # Forward to JSON view
        # ====================
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
