package Ovpnc::Controller::Api::Certificates;
use warnings;
use strict;
use Try::Tiny;
use Moose;
use utf8;
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
        certificates_DELETE
        get_cert
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
        my ( $self, $c, $form ) = @_;
    
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

        # Switch between common_name and name
        # This is because we want multiple 
        # certificate names per client name.
        # for OpenVPN checks the CN has to be
        # the same as the client's username
        # ===================================
        my $temp_cn = $c->req->params->{KEY_CN};
        my $temp_name = $c->req->params->{name};
        $c->req->params->{KEY_CN} = $temp_name;
        $c->req->params->{name} = $temp_cn;

        $c->stash->{cert_name} = $c->req->params->{name};
        $c->stash->{name} = $c->req->params->{KEY_CN};

        # Check if current user's name has
        # been submitted, force add it.
        # ================================
        $req->{ca_username} = $c->user->get("name")
            unless $req->{ca_username};

        # Check if such a certificate exists
        # ==================================
        my $check_not_exists = $self->certificates_GET(
            $c, $c->stash->{cert_name}, $c->stash->{name} );
        
        if ( $check_not_exists
                and ref $check_not_exists
                and $check_not_exists->{error}
        ){
            return $check_not_exists;
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
            if ( $form ){
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
                if ( $form ){
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
                if ( $_ret_val->{resultset} and $form ){

                    my $_chk =
                        $self->_update_db_certificate(
                            $c,
                            [@{$_ret_val->{resultset}}],
                            $req,
                            ( $form ? $form : undef )
                        );
                    # If errors, "rollback"
                    # =====================
                    if ( $_chk->{error} ){
                        my ($_dir) = $_ret_val->{resultset}->[0]->{file} =~ /^(.*)\/.*$/;
                        unlink $_dir if $c->req->params->{cert_type} eq 'client';
                        return $_chk;
                    }
                }
                elsif ( $_ret_val->{status}
                    and ref $_ret_val->{status} eq 'ARRAY'
                ) {

                    my $files;
                    push @{$files}, @{$_ret_val->{status}}[0,1];

                    my $_chk = $self->_update_db_certificate(
                                    $c,
                                    [@{$files}],
                                    $req,
                                    ( $form ? $form : undef ) );
                    # If errors, "rollback"
                    # =====================
                    if ( $_chk->{error} ){
                        my ($_dir) = $files->[0] =~ /^(.*)\/.*$/;
                        unlink $_dir if $c->req->params->{cert_type} eq 'client';
                        return $_chk;
                    }
                }

                if ( $form ){
                    return $_ret_val;
                }
                else {
                    $self->status_ok($c, entity => $_ret_val );
                    $c->detach('View::JSON');
                }
            }
            else {
                if ( $form ){
                    return { error => "Something went wrong with command " . $req->{cmd} };
                }
                else {
                    $self->_send_err($c, "Something went wrong with command " . $req->{cmd} );
                }
            }
        }
        else {
            if ( $form ){
                return { error => "Something went wrong with command " . $req->{cmd} };
            }
            else {
                $self->_send_err($c, "Something went wrong with command " . $req->{cmd} );
            }
        }
    
    }


=head2 certificates_GET

Get certificate(s) data
Options:

L<One>      Get a specific certificate by name/match user
            Used by the certificate/add to check no 
            duplicates when create a new certificate
L<Two>      Get a specific certificate by field
L<Three>    Get all certificates - sorted results by field
L<Four>     Archive and download certificate + key

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
        my ( $self, $c, $cert_name_int, $name_int ) = @_;

        # get column names
        # ================
        my $cert_rs = $c->model('DB::Certificate')->search;
        my $columns = [$cert_rs->result_source->columns];

        my $field          = $c->req->params->{field};

        # Check if requested field exists
        # ===============================
        if ($field){
            unless ( $field ~~ @{$columns} ) {
                if ( ! $cert_name_int ){ 
                    $self->status_not_found($c,
                        message => "Unknown field name: '" . $field . "'",
                    );
                    $c->detach;
                }
                else {
                    return { error => "Unknown field name: '" . $field . "'" };
                }
            };
        }

        # Assign the flexgrid request params
        # ==================================
        my ( $page, $search_by, $search_text, $rows, $sort_by, $sort_order ) =
          @{ $c->req->params }{qw/page qtype query rp sortname sortorder/};

        $sort_by ||= 'name';

        # Searching for a single certificate
        # Used mainly by the certificates
        # add form in order to prevent user
        # from using an existing certificate
        # ==================================


        $c->req->params->{cert_name}     = $cert_name_int if $cert_name_int;
        $c->req->params->{name}         = $name_int     if $name_int;
        $c->req->params->{cert_type}    = $c->req->params->{type} if $c->req->params->{type};

        if (
                my $cert_name    = $c->req->params->{cert_name}
            and my $username    = $c->req->params->{name}
        ){

            $username .= '/';
            my $username_mem = $username;
            $username = '' if $c->req->params->{cert_type} =~ /ca|server/;
            if (
                (
                        -d $self->cfg->{openvpn_utils} . '/keys/' . $username
                    and -e $self->cfg->{openvpn_utils} . '/keys/' . $username
                            . $cert_name . '.crt'
                )
                 or
                (
                    $self->_check_cert_name_db(
                        $c,
                        $cert_name,
                        ( $username eq '' ? $username_mem : $username )
                    )
                )
            ){
                if ( ! $cert_name_int ){ 
                    $self->status_bad_request($c, message => 'Certificate exists');
                    $c->detach('View::JSON');
                }
                else {
                    return { error => 'Certificate exists' };
                }
            }
            $self->status_ok($c, entity => { status => 'ok' } );
        }
        # Search for a specific field
        # ===========================
        elsif (
                my $search         = $c->req->params->{search}
                and $field
        ){

            my $certificates =
                $self->_get_searched_field($c, $field, $search);
        }
        # Get all certificates
        # ====================
        else {
            my $rs = $cert_rs->search(
                {},
                {
                    order_by => ( $sort_by && $sort_order )
                        ? "$sort_by $sort_order"
                        : "name ASC",
                    select => $columns
                }
            );

            unless ($rs){
                $self->status_not_found($c, message => 'No certifictes');
                $c->detach('View::JSON');
            }
        
            $rs = $rs->search_literal("lower($search_by) LIKE ?", lc($search_text) .'%' )
                if $search_by && $search_text;

            my $paged_rs = $rs->search({}, {
                page => $page,
                rows => $rows,
            });
 
            # Skipping Root CA...
            my @column_names = @{$columns};
            my $certificates;
            while ( my $cert = $paged_rs->next ) {
                my $modified = $cert->modified;
                my $created = $cert->created;
                my $revoked = $cert->revoked || '-';
                push @{$certificates},
                    {
                        map { # Avoid having 'null' in JSON output by using double quotes
                            $_ => (
                                $_ eq 'modified' ? "$modified"
                              : $_ eq 'created'  ? "$created"
                              : $_ eq 'revoked'  ? "$revoked"
                              : $_ eq 'user'     ? $cert->user->username
                              : $cert->$_ 
                            )
                        } @column_names
                    };
            }

            unless ( $certificates ){
                $self->status_ok($c, entity =>
                   { resultset => [ 'No certificates' ] });
                $c->detach('View::JSON');
            }

            # Make sure the sorting is as requested
            # =====================================
            my @_sorted = sort {
                    ( $$a{$sort_by} ? $$a{$sort_by} : 0 )
                cmp
                    ( $$b{$sort_by} ? $$b{$sort_by} : 0 )
            } @{$certificates};
            @_sorted = lc($sort_order) eq 'asc' ? @_sorted : reverse @_sorted;
            
            $self->status_ok($c, entity => {
                total     => $rs->count,
                page      => $page,
                rows      => \@_sorted
            });
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

        my $req = $c->req->params;

        # client and certificate name
        # must be provided (min 1)
        # ===========================
        my $certificates;
        my ($certs, $clients);
        if ( ! $req->{clients} or ! $req->{certificates} ){
            $self->status_bad_request($c, message =>
                "Missing params. Both clients and certificates must be provided (min 1)."
            );
            delete $c->stash->{assets};
            $c->detach('View::JSON');
        }
        # Check if same number of
        # client names as certificates
        # ============================
        else {
            @{$certs}   = split ",", $req->{certificates};
            @{$clients} = split ",", $req->{clients}; 
            if ( scalar @{$certs} != scalar @{$clients} ){
                $self->status_bad_request($c, message =>
                    "Certificates number does not match to clients number: "
                    . "[ " . scalar @{$certs} . ' - ' . scalar @{$clients} . " ]."
                );
                delete $c->stash->{assets};
                $c->detach('View::JSON');
            }
        }

        # Make a hash using certnames
        # as keys as clients as values
        # ============================
        #$certificates = $self->_map_certs_clients(\@certs, \@clients);

        # Get the certificates data
        # =========================
        my @rs = $c->model('DB::Certificate')->search(
                {
                    name => { in => $certs },
                    user => { in => $clients }
                }
            )->all;

        unless ( @rs > 0 ){
            $self->status_bad_request($c, message =>
                'Certificate(s) not found in database!'
            );
            delete $c->stash->{assets};
            $c->detach('View::JSON');        
        }

        # Run verifications that this is
        # not a 'CA' or 'server' type being
        # deleted while other certificates
        # still exists. Remove from array if so.
        # ======================================
        my ( $rs, $path_certs );
        ($certs, $clients, $rs)              = $self->_check_not_ca( $c, $certs, $clients, \@rs );
        ($certs, $clients, $rs, $path_certs) = $self->_check_not_server( $c, $certs, $clients, $rs );

        # [- debug - ]
        #$c->controller('Api')->detach_error( $c,
        #   "     Paths:     " . ( join ", ", @{$path_certs} )
        #  .".    Certs:     " . ( join ", ", @{$certs} )
        #  .".    Clients:   " . ( join ", ", @{$clients} )
        #);

        unless ( @{$certs} ){
            $self->status_bad_request($c, message =>
                'No certificates left for removal.'
            );
            delete $c->stash->{assets};
            $c->detach('View::JSON');
        }

        # Set roles
        # =========
        $self->_roles(
            $self->new_with_traits(
                traits         => [
                  qw/
                     Vars
                     Delete
                     +Ovpnc::TraitFor::Controller::Api::Clients::Revoke
                  /
                ],
                openvpn_dir    => $c->config->{openvpn_dir},
                openssl_bin    => $c->config->{openssl_bin},
                openssl_conf   => $c->config->{openssl_conf},
                openvpn_utils  => $self->cfg->{openvpn_utils},
                home           => $self->cfg->{home},
                _req           => $c->request->params,
                _cfg           => $self->cfg,
            )
        );

        # Same as source ./vars
        # =====================
        $self->_roles->set_environment_vars;

        # Revoke certificates
        # ===================
        my $_chk_revoke = $self->_roles->revoke_certificate(
            $clients, $path_certs ); 

        unless ( $_chk_revoke ){
            $c->controller('Api')->detach_error( $c,
                'No reply from backend!');
            return;
        }

        # Delete from DB and files
        # ========================
        my $_ret_val = $self->_roles->delete_certificates( $rs )
            unless $req->{no_delete};

        if ( $req->{no_delete} ){
            return $_chk_revoke;
        } 
        else {
            $self->status_ok($c,
                entity => {
                    resultset => $_ret_val,
                    errors => $c->stash->{error}
                },
            );
        }
    }



=head2 certificates_UNREVOKE

Un-Revoke certificate(s)
sends to clients_UNREVOKE

=cut

   sub certificates_UNREVOKE : Local
                             : Args(0)
                             : Does('ACL')
                                AllowedRole('admin')
                                AllowedRole('can_edit')
                                ACLDetachTo('denied')
                             : Does('NeedsLogin')
                             : Sitemap
    {
        my ( $self, $c ) = @_;
        $c->detach('/api/clients_UNREVOKE');
    }



=head2 certificates_REVOKE

Revoke certificate(s)
sends to _DELETE with no_delete param

=cut

   sub certificates_REVOKE : Local
                           : Args(0)
                           : Does('ACL')
                               AllowedRole('admin')
                               AllowedRole('can_edit')
                               ACLDetachTo('denied')
                           : Does('NeedsLogin')
                           : Sitemap
    {
        my ( $self, $c ) = @_;


        $c->req->params->{no_delete} = 1;

        my @certificates = split ',', $c->req->params->{certificates};
        my @clients      = split ',', $c->req->params->{clients};

        # Check if such a certificate exists
        # ==================================
        # just to make sure:
        $c->req->params->{no_delete} ||= 1;
        my $chk_revoke = $self->certificates_DELETE(
            $c, $c->req->params->{clients}, $c->req->params->{certificates} );

        if ( $chk_revoke ){
            for my $i ( 0 .. $#certificates ){
                if (     $chk_revoke->{$clients[$i]}
                     and $chk_revoke->{$clients[$i]}->{status}
                     and my @status = @{$chk_revoke->{$clients[$i]}->{status}}
                ) {

                    for my $cert_status ( @status ){
                        my ($cert_name) = $cert_status =~ /Certificate.(.*).revoked ok/;
                        if ( $cert_name and $cert_name eq $certificates[$i] ){
                            try {
                                $c->model('DB::Certificate')->search({
                                    name => $cert_name,
                                    user => $clients[$i]
                                })->update({ revoked => DateTime->now });
                            }
                            catch {
                                $c->log->error('DB Error: ' . $_);
                                push @{$c->stash->{$cert_name}->{errors}},
                                    "Failed to update database for '$cert_name': " . $_
                                    . " user: '$clients[$i]'";
                            };
                            try {
                                my $check_total_revoked =
                                    $c->model('DB::Certificate')->search({
                                        user    => $clients[$i],
                                        revoked => { in => [ '0000-00-00 00:00:00' ] }                                
                                    })->count;
                                if ( $check_total_revoked == 0 ){
                                    $c->log->debug('Updating user, setting to revoked because all certificates are revoked.');
                                    $c->model('DB::User')->search({
                                        username => $clients[$i]
                                    })->update({ revoked => 1 });
                                }
                            }
                            catch {
                                $c->log->error('DB Error: ' . $_);
                                push @{$c->stash->{$cert_name}->{errors}},
                                    "Failed to update database for user status: " . $_
                                    . " user: '$clients[$i]'";
                            };
                        }
                    }
                }
                elsif (
                    $chk_revoke->{$clients[$i]}
                    and $chk_revoke->{$clients[$i]}->{warnings}
                ){
                    $c->stash->{rest}->{$certificates[$i]}->{errors} =
                        $chk_revoke->{$clients[$i]}->{warnings};
                }
                elsif (
                    $chk_revoke->{$clients[$i]}
                    and $chk_revoke->{$clients[$i]}->{errors}
                ){
                    $c->stash->{$certificates[$i]}->{errors} =
                        $chk_revoke->{$clients[$i]}->{errors};
                }
                else {
                    push @{$c->stash->{$certificates[$i]}->{errors}},
                        "Failed to get status for '$certificates[$i]', user: '$clients[$i]'";
                }
                #$chk_revoke->{$certificates[$i]} = $chk_revoke->{$clients[$i]};
                #delete $chk_revoke->{$clients[$i]};
            }
            $self->status_ok($c, entity => { resultset => $chk_revoke } );
        }
    }


=head2 get_cert

Get (download) certificates
and keys, first archive
Expects one client name
and 'all' or any cert names.
if 'all' is specified, then all
of the client's certs will be
archived for download.

=cut

    sub get_cert : Path('certificates/get_cert')
                 : Args(2)
                 : Does('ACL')
                     AllowedRole('admin')
                     AllowedRole('can_edit')
                     ACLDetachTo('denied')
                 : Does('NeedsLogin')
                 : Sitemap
    {

        my ( $self, $c, $client, $certs ) = @_;

        my $format = $c->req->params->{format} ||= 'tar';
        my @formats = qw[ tar gzip bzip ];

        unless ( grep $format ~~ $_, @formats ){
            $self->status_bad_request($c,
                message => 'Unknown format: ' . $format
                            . '. Supported formats: '
                            . join ', ', @formats
            ); 
            $c->detach;
        }
     
        # Set roles
        # =========
        $self->_roles(
            $self->new_with_traits(
                traits => [ 'Archive' ],
                _cfg   => $self->cfg,
            )
        );

        # Get request 'get_cert'
        # will download the certificate + key
        # ===================================
        if ( $client ){
            my $_ret_val =
                $self->_roles->archive_certificates(
                    $c,
                    $client,
                    $format,
                    ( $certs ? $certs : undef )
                );

            if ( $_ret_val and ! $c->stash->{error} ){
                $self->status_ok($c, entity => $_ret_val);
                $c->detach;
            }
        }
        else {
            $self->status_bad_request($c,
                message => 'No certificate name(s) provided' );
            $c->detach;
        }

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
                        $_ret_val->{status}->{file} ? $_ret_val->{status}->{file} : undef,
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


=head2 _gen_cert

Generate a signed certificate
Needs a root CA

=cut

    sub _gen_cert : Private {

        my $_ret_val = shift->_roles->gen_ca_signed_certificate( @_ );
        if ( defined $_ret_val && ref $_ret_val ){
            return $_ret_val;
        }
        return undef;

    }


=head2 _update_db_certificate

Update the database with
the new certificate/key details

=cut

    sub _update_db_certificate : Private {
        my ( $self, $c, $resultset, $req, $form ) = @_;

            my $_ret_val = {};

            my ($cert_file) = shift @{$resultset};
            my ($key_file) = shift @{$resultset};

            # For client type we check valid
            # usernames, for serve and ca
            # any common name can be provided.
            # We therefore use the ca_username
            # hidden field to write to database
            # which user has created the ca/server
            # ====================================
            my $user = $c->find_user({
                username => (
                    $req->{cert_type} =~ /server|ca/
                        ? $req->{ca_username}
                        : $req->{KEY_CN}
                )
            });
            unless ( $user ){
                return { error => 'Choose an existing user.' };
            }

            # When certificate type is ca
            # it always gets the name ca.{crt,key,csr}...
            # ===========================================
            $req->{name} = 'ca' if $req->{cert_type} eq 'ca';
            $req->{name} = $req->{cert_name} if $req->{cert_type} eq 'server';

            my $start_date = $form->param_value('start_date');
            $start_date =~ s/([0-9]+)\-([0-9]+)\-([0-9]+)/$3-$2-$1/;

            my $serial = @{$resultset}[-1];
            
            # update dbic row with
            # submitted values from form
            # ==========================
            try     {
                $c->model('DB::Certificate')->update_or_create({
                    user_id         => $user->id,
                    user            => $user->username,
                    name            => $req->{cert_name},
                    created_by      => $req->{ca_username},
                    created         => $start_date,
                    key_cn          => $req->{KEY_CN},
                    key_expire      => $req->{KEY_EXPIRE},
                    key_size        => $req->{KEY_SIZE},
                    cert_type       => $req->{cert_type},
                    key_country     => $req->{KEY_COUNTRY},
                    key_province    => $req->{KEY_PROVINCE},
                    key_city        => $req->{KEY_CITY},
                    key_email       => $req->{KEY_EMAIL},
                    key_serial      => $serial->{serial} || '0',
                    key_org         => $req->{KEY_ORG},
                    key_ou          => $req->{KEY_OU},
                    key_file        => $key_file->{file},
                    key_digest      => $key_file->{digest},
                    cert_file       => $cert_file->{file},
                    cert_digest     => $cert_file->{digest}
                });
            }
            catch   {
                $c->log->error( $_ );
                push @{$_ret_val->{error}}, $_;
            };

            $_ret_val->{status} = 1;

            return $_ret_val->{error}
                ? { error => join ";", @{$_ret_val->{error}} }
                : $_ret_val;
    }


=head2 _check_cert_name_db

Check if name/user combination 
of certificate exists in DB

=cut

    sub _check_cert_name_db : Private {
        my ( $self, $c, $cert_name, $username ) = @_;

        $username =~ s/\///g;

        my $rs;

        if ( $cert_name eq 'check_any' ) {
             try {
                $rs = $c->model('DB::Certificate')->search(
                    { cert_type => 'server' },
                    { select => 'id' }
                )->single;
            }
            catch {
                $c->log->error('Database error: ' . $_);
                    push @{$c->{stash}->{error}},
                        'Database error detected: ' . $_;
                return;
            };
        }
        else {
            try {
                $rs = $c->model('DB::Certificate')->search(
                    { key_cn => $username, name      => $cert_name },
                    { select => 'id' }
                )->single;
            }
            catch {
            $c->log->error('Database error: ' . $_);
                push @{$c->{stash}->{error}},
                    'Database error detected: ' . $_;
                return;
            };
        }
        return $rs ? 1 : undef;

    }


=head2 _get_searched_field

Get sorted results from DB

=cut

    sub _get_searched_field : Private {
        my ( $self, $c, $field, $search ) = @_;

        my $_result = $c->model('DB::Certificate')->search(
                { $field => { -like => $search . "%" } },
                { select => $field }
            )->single;

        if ( defined $_result ){
            $self->status_ok($c,
                entity => { resultset => $_result->$field }
            );
            $c->detach;
            return;
        }
        else {
            my $_complete_result = [ $c->model('DB::Certificate')->search({},{select=>$field})->all ];
            $self->status_ok($c,
                entity => { resultset => [ map { $_->$field } @{$_complete_result} ] }
            );
            $c->detach;
        }

    }


=head2 _check_not_ca

Make sure user is not trying
to delete the Root CA while
other certificates exists

=cut

    sub _check_not_ca : Private {
        my $self = shift;
        my $c = shift;
        my @certs = @{(shift)};
        my @clients = @{(shift)};
        my @rs = @{(shift)};

        # Count non-CA certificates
        # =========================
        my $non_ca_count;
        try {
            $non_ca_count =
                $c->model('DB::Certificate')->search({
                    cert_type => { 'not in' => [ 'ca' ] }
                 })->count;
        }
        catch {
            $self->status_bad_request($c, message =>
                    'Database query error: '
                    . (split(/\n/, $_))[0]
            );
            delete $c->stash->{assets};
            $c->detach('View::JSON');        
        };
        
        # Check this is not a Root CA
        # being deleted. We first check
        # how many non-CA certificate
        # types there are, only if none
        # allow the Root CA to be deleted
        # ===============================
        my $rs_index = 0;
     CERTS:
        for my $cert ( @rs ){
            if ( $cert->cert_type eq 'ca' ){
                # Loop cert names
                # ===============
                for my $i ( 0 .. @certs ){
                    # Find the "offending" one
                    # ========================
                    if ( $certs[$i] eq $cert->name ){
                        if ( $non_ca_count and $non_ca_count > 0 ){
                            $c->log->debug('Ignoring CA certificate ' . $cert->name );
                            # Remove from arrays
                            # ==================
                            splice ( @certs, $i ,1 );
                            splice ( @clients, $i ,1 );
                            splice ( @rs, $rs_index, 1);
                            # Compensate on removal
                            # =====================
                            $i--;

                            push @{$c->{stash}->{error}},
                                 $cert->name . 
                                 ': Denied. Cannot delete Root CA while other certificates exists.';

                            next CERTS;
                        }
                    }
                }
            }
            $rs_index++;
        }
        return (\@certs, \@clients, \@rs);
     }


=head2 _check_not_server

Make sure user is not trying
to delete server certificate
other client certificates exists
Here we also determine the path
for each certificate, since 'ca'
and 'server' remain in main keys
directory and client's get own
directory, so we need to append.

=cut

    sub _check_not_server : Private {
        my $self = shift;
        my $c = shift;
        my @certs = @{(shift)};
        my @clients = @{(shift)};
        my @rs = @{(shift)};
        
        my @path_certs;
        my $non_server_count;

        # Count non-CA or non server
        # ==========================
        try {
            $non_server_count =
                $c->model('DB::Certificate')->search({
                    cert_type => { 'not in' => [ 'server', 'ca' ] }
                })->count;
        }
        catch {
            $self->status_bad_request($c, message =>
                    'Database query error: '
                    . (split(/\n/, $_))[0]
            );
            delete $c->stash->{assets};
            $c->detach('View::JSON');        
        };

        # Check this is not a 'server'
        # being deleted. First check
        # how many non-CA and 'server'
        # types there are, only if none
        # allow to delete the 'server' cert
        # =================================
        my $rs_index = 0;
        CERTS:
        for my $cert ( @rs ){
            if ( $cert->cert_type eq 'server' ){
                # Loop cert names
                # ===============
                for my $i ( 0 .. @certs ){
                    # Find the "offending" one
                    # ========================
                    if ( $certs[$i] eq $cert->name ){
                        if ( $non_server_count and $non_server_count > 0 ){
                            $c->log->debug('Ignoring server certificate ' . $cert->name );

                            # remove from arrays
                            # ==================
                            splice ( @certs, $i, 1 );
                            splice ( @clients, $i, 1 );
                            splice ( @rs, $rs_index, 1 );

                            # Compensate for the missing element
                            # ==================================
                            $i--;
                            push @{$c->{stash}->{error}},
                                 $cert->name .
                                 ': Denied. Cannot delete type server while other certificates exists.';
                            next CERTS;
                        }
                        else {
                            # Define server cert-dir path
                            # ===========================
                            push @path_certs, $certs[$i];
                        }
                    }
                }
            }
            elsif ( $cert->cert_type eq 'client' ) {
                # Define client cert-dir path
                # ===========================
                push @path_certs, $clients[$rs_index] . '/' . $certs[$rs_index];
            }
            else {
                push @path_certs, $certs[$rs_index];
            }
            $rs_index++;
        }

        return (\@certs, \@clients, \@rs, \@path_certs);
     }


=head2 _map_certs_clients

In action _DELETE map
certificate names to
the client names

=cut

    sub _map_certs_clients : Private {
        my ( $self, $certs, $clients ) = @_;
        my $certificates;
        for my $i ( 0 .. @{$clients} ){
            next unless $certs->[$i] or $clients->[$i];
            $certificates->{$certs->[$i]}->{username} = $clients->[$i];
        }
        return $certificates;
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
