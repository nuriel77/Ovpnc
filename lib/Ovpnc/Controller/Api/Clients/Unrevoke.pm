package Ovpnc::Controller::Api::Clients::Unrevoke;
use warnings;
use strict;
use Try::Tiny;
use Tie::File;
use Fcntl 'O_RDONLY';
use Moose;
use namespace::autoclean;
use vars qw( $REGEX );

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config( namespace => 'api/clients' );


=head1 NAME

Ovpnc::Controller::Api::Clients::Unrevoke - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller for Clients Unrevoke

=head1 METHODS

=cut

with 'MooseX::Traits';
has '+_trait_namespace' => (

    # get the correct namespace.
    # To keep traits out of
    # the Controller directory.
    default => sub {
        my ( $P, $SP ) = __PACKAGE__ =~ /^(\w+)::(.*)::\w+$/;
        $SP =~ s/Clients/Certificates/;
        return $P . '::TraitFor::' . $SP;
    }
);

has openvpn_dir => (
    is        => 'rw',
    isa       => 'Str',
    required  => 0,
    predicate => '_has_vpn_dir'
);

has openvpn_utils => (
    is        => 'rw',
    isa       => 'Str',
    required  => 0,
    predicate => '_has_utils_dir'
);

has '_roles' => (
    is        => 'rw',
    isa       => 'Object',
    predicate => '_has_roles',
);

has 'cfg' => (
    is        => 'rw',
    isa       => 'HashRef',
    predicate => '_has_conf'
);

$REGEX = {
    client => {
        list =>
          'CLIENT_LIST,(.*?),(.*?),(.*?),([0-9]+),([0-9]+),(.*?),([0-9]+)$',
        crl => '\/CN=(.*)\/name=(.*)\/',
    }
};


=head2 Method Modifiers

Run before other actions
or after, or around...

=cut

    around 'unrevoke_POST' => sub {
        my ( $orig, $self, $c, $params ) = @_;

        # Assign global config params
        # ===========================
        $self->cfg( $c->controller('Api')->assign_params( $c ) )
          unless $self->_has_conf;

        # File::Assets might leave an empty hash
        # so we better delete it, no need in api
        # ======================================
        delete $c->stash->{assets} if $c->stash->{assets};
    
        return $self->$orig( $c, $params );

    };

   

=head2 begin

Automatic first
action to run

=cut

    sub begin : Private {
        my ( $self, $c ) = @_;

        # Test database connection
        # ========================
        $c->controller('Root')->auto( $c );

        # Log user in if login params are provided
        # =======================================
        $c->controller('Api')->auth_user( $c )
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


=head2 clients

For REST action class

=cut

    sub unrevoke : Local : ActionClass('REST') {
    }



=head2 unrevoke_POST

Unrevoke a client's certificate
and remove the appended
.disabled from the file
in ccd

=cut

    sub unrevoke_POST	 : Local
                         : Args(0)
                         : Does('ACL')
                           AllowedRole('admin')
                           AllowedRole('can_edit')
                           ACLDetachTo('denied')
                         : Sitemap
    {
        my ( $self, $c, $client_list, $cert_list, $serials ) = @_;

        # Verify that a client name was provided
        # ======================================
        $c->controller('Api::Clients')->client_error(400)
          if ( ! $client_list and !$c->request->params->{clients} and !$c->request->params->{serials} );
    
        # Override anything in the path by setting
        # params from post if they exists
        # ========================================
        $client_list = $c->request->params->{clients}
            if $c->request->params->{clients};
        my @clients = map { $_ if $_ ne '' } split ',', $client_list;
        $cert_list = $c->request->params->{certificates}
            if $c->request->params->{certificates};
        my @certificates = map { $_ if $_ ne '' } split ',', $cert_list
            if $c->request->params->{certificates};
        $serials = $c->req->params->{serials}
            if $c->req->params->{serials};
        my @serials = map { $_ if $_ ne '' } split ',', $serials
            if $c->request->params->{serials};

        # Trait names should match request method
        # =======================================
        $self->_roles (
            $self->_get_roles(
                'Unrevoke',
                'Vars'
            )
        );
    
        # Same as source ./vars
        # =====================
        $self->_roles->set_environment_vars;
    
        # Check if client's certificate is revoked
        # ========================================
        $c->req->params->{no_detach} = 1; 
		$c->req->method('GET');
		my $revoked = $c->forward('/api/clients/revoke');

        my $_ret_val;

      CLIENT:
        for my $i ( 0 .. $#clients ){

            # Unrevoke client certificate(s)
            # ==============================
            # TODO: move ssl_[config|bin] to the trait's instantiation.
            my $_unrevoke_status = 
                $self->_roles->unrevoke_certificate({
                    client       => $clients[$i],
                    ssl_config   => $self->cfg->{ssl_config},
                    ssl_bin      => $c->config->{openssl_bin},
                    certificate  =>( @certificates ? $certificates[$i] : $c->req->params->{cert_name} ),
                    serial       => $serials[$i],
                    ca_password  => $c->req->params->{ca_password}
                });

			if ( grep { /errors/ } keys %{$_unrevoke_status} ){	
	            if (@certificates){
	                for ( keys %{$_unrevoke_status} ){
	                    push @{ $_ret_val->{$certificates[$i]}->{$_} },
	                        $_unrevoke_status->{$_};          
	                }
	            }
	            else {
	                for ( keys %{$_unrevoke_status} ){
	                    push @{ $_ret_val->{$clients[$i]}->{$_} },
	                        $_unrevoke_status->{$_};          
	                }
	            }
	            
	            # Done processing client(s)
        		# =========================
        		$self->status_ok( $c, entity => { resultset => $_ret_val } );
        		delete $c->stash->{status} if $c->stash->{status};
				$c->detach('View::JSON');
			}
			
            # Update database, two possibilities:
            # a. No certificates provided: this means
            #    that all the client's certificates
            #    will be processed (unrevoked)
            # b. Certificate names are provided, we
            #    therefore make a specific query
            # =======================================
            unless ( @certificates ){
                try {
                    $c->model('DB::Certificate')->search({
                        user        => $clients[$i]
                    })->update({ revoked => '0000-00-00 00:00:00' });
                }
                catch {
                    push @{$c->stash->{$clients[$i]}->{errors}},
                        "Failed to update database for '$clients[$i]': " . $_;
                };
            }
            else {
                try {
                    $c->model('DB::Certificate')->search({
                        user       => $clients[$i],
                        name       => $certificates[$i],
                        key_serial => $serials[$i],
                    })->update({ revoked => '0000-00-00 00:00:00' });
                }
                catch {
                    push @{$c->stash->{$clients[$i]}->{errors}},
                        "Failed to update database for '$clients[$i]': " . $_;
                }; 
            }
            
            # Since we unrevoked all or one
            # certificate we do not consider
            # the user to be revoked anymore
            # ==============================
            try {
                $c->model('DB::User')->find({ username => $clients[$i] })
                    ->update({ revoked => 0 });
            }
            catch {
                push @{$_ret_val->{$clients[$i]}->{errors}},
                    "DB query failed: " . $_;
            };

            #if (@certificates){
            #    for ( keys %{$_unrevoke_status} ){
            #       push @{ $_ret_val->{$certificates[$i]}->{$_} },
            #           $_unrevoke_status->{$_};          
            #   }
            #}
            #else {
                for ( keys %{$_unrevoke_status} ){
                    push @{ $_ret_val->{$clients[$i]}->{$_} },
                        $_unrevoke_status->{$_};          
                }
           # }
        }


        # Done processing client(s)
        # =========================
        $self->status_ok( $c, entity => { resultset => $_ret_val } );
        delete $c->stash->{status} if $c->stash->{status};
    }


=head2 _read_crl_index_file

This file generated by
OpenVPN lists the certificates
and provides us information
who is revoked

=cut

    sub _read_crl_index_file : Private {
        my ( $self, $crl_index ) = @_;

        my ( $Y, $M, $D, $h, $m, $s );
        my $obj = [];

        my $o = tie my @array, "Tie::File", $crl_index;
        $o->flock;

        for my $line ( @array ){
            my ( $Y, $M, $D, $h, $m, $s );
            if ( $line =~ /^R.*$/ ){
                my (undef, $created, $revoke_time, $serial, undef, $subject )
                    = split /\t/, $line;
                my ( $CN, $name ) = $subject =~ /$REGEX->{client}->{crl}/;
                ( $Y, $M, $D, $h, $m, $s ) = $revoke_time =~ /(..)/g;
                my $kill_time =
                        $D . '-'
                      . $M . '-'
                      . ( $Y + 2000 ) . ' '
                      . $h . ':'
                      . $m . ':'
                      . $s;
                push( @{$obj}, { serial => $serial, CN => $CN, cert_name => $name, kill_time => $kill_time } );
            }
        }

        undef $o;
        untie @array;
        return $obj;
    }


=head2 _match_revoked

Will compare the current
client to the list of revoked
to see if he is there

=cut

    sub _match_revoked : Private {
        my ( $self, $revoked, $client, $cert_name, $serial ) = @_;

        if ( $revoked and ref $revoked eq 'ARRAY' ) {
            for ( @{$revoked} ) {
                if (
                       $cert_name
                    && $_->{CN} eq $client
                    && $_->{cert_name} eq $cert_name
                    && $_->{serial} eq $serial
                ){
                    return 1
                }
                else {
                    return 1
                        if $_->{CN} eq $client
                        and $_->{serial} eq $serial;
                }
            }
        }
        return 0;
    }


=head2 _get_roles

Based on the method name we wish
to load the corresponding trait(s)
Notice we ucfirst format the name
and also sent extra params

=cut

    sub _get_roles : Private {
        my $self = shift;
    
        return $self->new_with_traits(
            traits    => [ ucfirst( lc(shift) ), @_ ],
            openvpn_dir     => $self->cfg->{openvpn_dir},
            openvpn_utils   => $self->cfg->{openvpn_utils},
            home            => $self->cfg->{home},
            openssl_conf    => $self->cfg->{openssl_conf},
            _req            => {},
            _cfg            => $self->cfg,
        );
    
    }

    
=head2 client_error

Detach not before stashing
the error message
and disconnect the mgmt port

=cut

    sub client_error : Private {
        my ( $self, $c, $status, $msg ) = @_;
        
        $status ||= 400;

        if ( $status == 204 ){
            $self->status_no_content( $c );
        }
        elsif ( $status == 400 ){
            $self->status_bad_request(
                $c,
                message => 'Invalid request: ' . ( $msg ? $msg : '' )
            );
        }
        $c->detach('View::JSON');
    }


=head2 denied

Unauthorized access
no match for role

=cut

    sub denied : Private {
        my ( $self, $c ) = @_;
        $self->status_forbidden( $c, message => "Access denied" );
        $c->detach;
    }


=head2 end

Last auto-action
of this controller
Disconnect the mgmt port
and forward to the view

=cut

    sub end : Private {
        my ( $self, $c ) = @_;

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
