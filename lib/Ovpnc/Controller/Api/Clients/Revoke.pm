package Ovpnc::Controller::Api::Clients::Revoke;
use warnings;
use strict;
use Try::Tiny;
use Scalar::Util 'looks_like_number';
use Tie::File;
use Fcntl 'O_RDONLY';
use Moose;
use namespace::autoclean;
use vars qw( $REGEX );

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config( namespace => 'api/clients' );


=head1 NAME

Ovpnc::Controller::Api::Clients::Revoke - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller for Clients.

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

# For methods requiring
# management port connection
# ==========================
has vpn => (
    is        => 'rw',
    isa       => 'Object',
    predicate => '_has_vpn',
    clearer   => '_disconnect_vpn',
    required  => 0
);


=head2 Method Modifiers

Run before other actions
or after, or around...

=cut

    around [
        qw(
          revoke_POST
          revoke_GET
          )
      ] => sub {
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

    around [
        qw(
          revoke_POST
          )
      ] => sub {
        my ( $orig, $self, $c, $params ) = @_;
    
        # File::Assets might leave an empty hash
        # so we better delete it, no need in api
        # ======================================
        delete $c->stash->{assets} if ref $c && $c->stash->{assets};
    
        # Do not process twice
        # ====================
        if ( ref $c && !$self->_has_vpn_dir ) {
            $self->cfg( $c->controller('Api')->assign_params( $c ) );
        }
    
        # Get global configurations
        # if not assigned yet
        # =========================
        $self->cfg( $c->controller('Api')->assign_params( $c ) )
          unless $self->_has_conf;
    
        # Also here, don't process twice
        # ==============================
        return $self->$orig( $c, $params )
          if $self->_has_vpn;
    
        # Instantiate connector
        # =====================
        $self->vpn( $c->model('VpnConnector')->new( $self->cfg->{mgmt_params} ) );
    
        # Check connection to mgmt port
        # =============================
        unless ( $self->vpn->connect ) {
            $c->stash( { status => 'Server offline' } );
            $self->_disconnect_vpn if $self->_has_vpn;
        }
    
        return $self->$orig( $c, $params );
    };


=head2 after modifier

Makes sure to disconnect
and release the mgmt port

=cut

    after [
        qw/
          revoke_POST
          kill_connection
          /
    ] => sub {
        my $self = shift;
        $self->_disconnect_vpn if $self->_has_vpn;
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

    sub revoke : Local : ActionClass('REST') {
    }


=head2 revoke_GET

Gets all clients / users
which have been revoked

=cut

    sub revoke_GET  : Local
                    : Args(0)
                    : Does('ACL')
                      AllowedRole('admin')
                      AllowedRole('client')
                      ACLDetachTo('denied')
                    : Sitemap
    {
        my ( $self, $c ) = @_;
    
        my $_ret_val;

        my $openvpn_dir = $self->cfg->{openvpn_dir} =~ /^\//
            ? $self->cfg->{openvpn_dir}
            :  $self->cfg->{home} . '/' . $self->cfg->{openvpn_dir};
    
        # The crl index file from OpenVPN
        # ===============================
        my $crl_index = $self->cfg->{openvpn_utils} =~ /^\//
            ? $self->cfg->{openvpn_utils} . '/keys/index.txt'
            : $openvpn_dir . '/'
                . $self->cfg->{openvpn_utils}
                . '/keys/index.txt';
    
        # Check readable
        # ==============
        unless ( -r $crl_index ) {
            push @{$_ret_val->{'General Fault'}->{errors}},
                'Cannot read ' . $crl_index . ', file does not exists or is not readable';
            $self->status_ok($c, entity => { resultset => $_ret_val });
            $self->_disconnect_vpn if $self->_has_vpn;
            $c->detach;
        }
    
        my $revoked_clients = $self->_read_crl_index_file($crl_index);

        if (    $revoked_clients
            and ref $revoked_clients eq 'ARRAY'
            and @{$revoked_clients} > 0 )
        {
            # Keep data also in stash->{status}
            # It is being used by other controllers
            # =====================================
            return $revoked_clients
                if $c->req->params->{no_detach};
            $self->status_ok( $c, entity => $revoked_clients );
        }
        else {
            return { status => 'No revoked clients' }
                if $c->req->params->{no_detach};
            $self->status_not_found( $c, message => 'No revoked clients' );
        }

    }
        

=head2 clients_REVOKE

Revoke client(s) certificates
using crl.pem. Try to disconnect
if client is online and server
is running

=cut

    sub revoke_POST : Local
                    : Args(0)
                    : Does('ACL')
                        AllowedRole('admin')
                        AllowedRole('can_edit')
                        ACLDetachTo('denied')
                    : Sitemap
    {

        my ( $self, $c, $client_list, $cert_list, $serial_list ) = @_;

        # Verify that a client name was provided
        # ======================================
        $self->client_error( $c )
          if ( ! $client_list and ! $c->request->params->{clients} );

        # Override anything in the path by setting
        # params from post if they exists
        # ========================================
        $client_list = $c->request->params->{clients}
            if $c->request->params->{clients};

        $cert_list = $c->request->params->{certificates}
            if $c->request->params->{certificates};


        $serial_list = $c->request->params->{serials}
            if $c->request->params->{serials};

        my @cert_names = map { $_ if $_ ne '' } split ',', $cert_list
            if $cert_list;
        my @clients    = map { $_ if $_ ne '' } split ',', $client_list;
        my @serials    = map { $_ if $_ ne '' } split ',', $serial_list;

        # Trait names should match request method
        # =======================================
		my $action = $c->action;
		my $namespace = $c->namespace;
		$action =~ s/$namespace\///;
        $self->_roles(
            $self->_get_roles(
                'Revoke',
                'Vars',
            )
        );
    
        # Same as source ./vars
        # =====================
        $self->_roles->set_environment_vars;
    
        # HashRef Will contain after return:
        # {warnings}, {errors}, {status}
        # ==================================
        my $_ret_val;
    
        # Revoke client's certificate
        # ===========================
        unless ( $c->request->params->{no_revoke} ) {
            $_ret_val = $self->_roles->revoke_certificate(
                \@clients,
                ( @cert_names ? \@cert_names : undef ),
                \@serials,
                $c->req->params->{ca_password}
            );
        }

        unless ( $_ret_val ){
            $self->_disconnect_vpn if $self->_has_vpn;
            $c->controller('Api')->detach_error( $c,
                { errors => [ 'No reply from backend!' ] } );
            return;
        }
       
        # Proceed with disconnecting
        # the client if online and
        # update the status in DB
        # ==========================
        my $_disconnect_client_ok;
        $_disconnect_client_ok = 1 if $self->_has_vpn;
        for my $i ( 0 .. $#clients ){

            # See if vpn is currently on,
            # if yes, try to diconnect the
            # client (might not be online)
            # ============================
            if ( $_disconnect_client_ok ){
                if ( my $str = $self->kill_connection( $clients[$i] ) ) {
                    push @{$_ret_val->{$clients[$i]}->{status}},
                        'Disconnect from VPN status: ' . $str;
                }
                else {
                    push @{$_ret_val->{$clients[$i]}->{info}},
                        'Disconnect from VPN status: not found online';
                }
            }
            # Update database
            # ===============
            try {
                $c->model('DB::User')->find({ username => $clients[$i] })
                    ->update({ revoked => 1 });
            }
            catch {
                push @{$c->stash->{$clients[$i]}->{errors}},
                    "Failed to update database for user '$clients[$i]': " . $_;
            };
            if ( @cert_names ){
                try {
                    $c->model('DB::Certificate')->search({ user => $clients[$i], name => $cert_names[$i] })
                        ->update({ revoked => DateTime->now });
                }
                catch {
                    push @{$c->stash->{$clients[$i]}->{errors}},
                        "Failed to update database for '$clients[$i]': " . $_;
                };
            }
            else {
                try {
                    $c->model('DB::Certificate')->search({ user => $clients[$i] })
                        ->update({ revoked => DateTime->now });
                }
                catch {
                    push @{$c->stash->{$clients[$i]}->{errors}},
                        "Failed to update database for '$clients[$i]': " . $_;
                };
            }
        }

        # Done processing client(s)
        # =========================
        $self->status_ok( $c, entity => { resultset => $_ret_val } );
        $self->_disconnect_vpn if $self->_has_vpn;
    }
    
    
# Private methods
# ===============

=head2 Kill_connection

Kill a connection of a
given client/ip:port

=cut

    sub kill_connection : Private {
        my ( $self, $connection, $client ) = @_;
        $connection = $client if ref $connection;
        die "No connection?!" unless $self->_has_vpn;
        my $ret_val = $self->vpn->kill($connection);
        return $ret_val;
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
        $self->_disconnect_vpn if $self->_has_vpn;
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


=head2 default

Default action, not found

=cut

    sub default : Private {
        my ( $self, $c ) = @_;
        $c->stash( { status => 'Control action not found' } );
        $c->response->status(404);
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

        # disconnect if exists
        # ====================
        $self->_disconnect_vpn if $self->_has_vpn;

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
