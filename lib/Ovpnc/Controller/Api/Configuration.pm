package Ovpnc::Controller::Api::Configuration;
use warnings;
use strict;
use Scalar::Util 'looks_like_number';
use XML::Simple;
use XML::SAX::ParserFactory;
use XML::Validator::Schema;
use XML::LibXML;
use Module::Locate qw(locate);
scalar locate('File::Slurp') ? 0 : do { use File::Slurp; };
scalar locate('File::Copy')  ? 0 : do { use File::Copy; };
use Readonly;
use Moose;
use Moose::Exporter;
use namespace::autoclean;

Readonly::Scalar my $SKIP_LINE => '^[;|#].*|^$';

Moose::Exporter->setup_import_methods(
      as_is     => [ 'get_openvpn_param', 'get_openvpn_config_file' ],
);


BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config( namespace => 'api' );

with 'MooseX::Traits';
has '+_trait_namespace' => (

    # get the correct namespace.
    # To keep traits out of
    # the Controller directory.
    # ==========================
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

Ovpnc::Controller::Api::Config - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller for OVPN Configuration

OpenVPN Config Controller API


=head1 METHODS

=head2 config

For REST action class

=cut

sub configuration : Local : ActionClass('REST') {
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
#        $c->change_session_expires(
#            $c->config->{'api_session_expires'} )
    }

}

=head2 before...

Method modifier

=cut

before [qw(
        configuration_GET
        configuration_POST
    )] => sub {
    my ( $self, $c, $params ) = @_;

    # File::Assets might leave an empty hash
    # so we better delete it, no need in api
    # ======================================
    delete $c->stash->{assets} if ref $c && $c->stash->{assets};

    # Assign config params
    # ====================
    $self->cfg( $c->controller('Api')->assign_params( $c ) )
        if ( ref $c && ! $self->_has_conf );
};



=head2 configuration_GET

Will output the configuration
of openvpn and will run validation
just incase someone makes changes
in the conf file manually

=cut

sub configuration_GET : Local
                      : Args(0)
                      : Does('ACL')
                            AllowedRole('admin')
                            AllowedRole('can_edit')
                            ACLDetachTo('denied')
                      : Sitemap
{
    my ( $self, $c ) = @_;
    $self->status_ok( $c, entity => { status => 'ok' } );
}

=head2 configuration_POST

When user posts data to this controller
this will update the configurtion files
of openvpn and the back-end xml
and run validataions via the xsd schema

=cut

sub configuration_POST : Local
                       : Args(0)
                       : Does('ACL')
                            AllowedRole('admin')
                            AllowedRole('can_edit')
                            ACLDetachTo('denied')
                       : Sitemap
{
    my ( $self, $c ) = @_;

    # Dereference
    # ===========
    my %data = %{ $c->request->params };

    # This will only prepare a
    # data structure which can
    # be converted to XML
    # ========================
    my $xml = $self->_create_xml( \%data );
    if ( not defined $xml ) {
        $c->controller('Api')->detach_error($c,
            'Could not generate XML format from posted parameters' );
        delete $c->stash->{assets} if $c->stash->{assets};
        $c->detach;
    }

    # Create a string
    # from the xml object
    # ===================
    my $xml_string = $self->_perl_to_xml($xml);

    # Validate the xml against the xsd schema
    # Will return a message if any error
    # =======================================
    my $message =
      $self->_validate_xml( $xml_string, $self->cfg->{ovpnc_config_schema} );

    if ($message) {
        $self->status_bad_request( $c, message => $message );
        delete $c->stash->{assets} if $c->stash->{assets};
        $c->detach;
    }
    else {
        my $st_msg      = {};

        # This defines the OpenVPN
        # server config file
        # ========================
        my $config_file = $data{'-1_null_ConfigFile'};

        $config_file = $config_file =~ /^\//
            ? $config_file
            : $self->cfg->{home} . '/' . $config_file;

        # Pretty fatal, but should not happen here
        # because we ran validation earlier on xml format
        # ===============================================
        unless ($config_file) {
            $st_msg->{error} = "Did not receive any configuration file value!";
            $self->_send_error( $c, $st_msg->{error}, 200 );
            $c->detach;
        }

        # Prepare configuration file header
        # =================================
        my $output =
            "#\n# OpenVPN Configuration file\n"
          . "# Generated by "
          . __PACKAGE__ . "\n"
          . "# Created: "
          . scalar localtime() . "\n"
          . "# Do not modify by hand!\n" . "#\n";

        # Cut out the directory name
        # ==========================
        my ($dir) = $config_file =~ /^(.*)\/.*$/g;

        # Now check if directory is valid
        # ===============================
        unless ( -e $dir and -d $dir and -w $dir ) {
            $st_msg->{error} =
              "Error: Directory of configuration file is invalid: $!";
        }

        # Create backup for existing configuration file
        # Also backup the xml configuration file.
        # =============================================
        if ( -e $config_file ) {
            $_ =
              $self->_manage_conf_backup(
                [ $config_file, $self->cfg->{ovpnc_conf} ],
                $c->config->{keep_n_conf_backup} );
            $st_msg->{error} = $_->{error} if $_->{error};
        }

        my $FILE;

        # Open the (new) file for writing
        # ===============================
        unless ( $st_msg->{error} ) {
            open( $FILE, ">", $config_file )
              or $st_msg->{error} =
              "Error: Configuration file '" . $config_file . "' could not be updated: $!";
        }

        # If no errors so far, proceed
        # with outputing key/values to file
        # =================================
        unless ( defined $st_msg->{error} ) {
            $output .= $self->_prepare_conf_file_data( \%data );
            print $FILE $output;
            close $FILE;
            chmod 0600, $config_file;
            if (   -e $self->cfg->{ovpnc_conf}
                && -w $self->cfg->{ovpnc_conf} )
            {
                XMLout(
                    $xml,
                    KeepRoot   => 1,
                    NoSort     => 0,
                    OutputFile => $self->cfg->{ovpnc_conf},
                    XMLDecl    => "<?xml version='1.0' encoding='UTF-8'?>",
                  )
                  or $self->_send_error( $c,
                    "Error generating xml configuration file: " . $!, 200 )
                  && $c->detach;

                chmod 0600, $self->cfg->{ovpnc_conf};
            }
            else {
                $st_msg->{error} =
                    "Cannot write xml configuration file "
                  . $self->cfg->{ovpnc_conf}
                  . ".\r\nEither it does not exists or is not accessible.";
                $self->_send_error( $c, $st_msg->{error}, 200 );
                return;
            }
            $st_msg->{status} = 'Configuration file updated successfully';
        }
        else {
            $self->_send_error( $c, $st_msg->{error}, 200 );
            return;
        }

        # Confirm to client
        # submission okay
        # =================
        $self->status_ok( $c, entity => $st_msg );
    }
}

=head2 configuration_UPDATE

For now all this does is update
the configuration XSD:
renew the Cipher list into the
XSD schema from openvpn

=cut

sub configuration_UPDATE : Local
                         : Args(0)
                         : Does('ACL')
                            AllowedRole('admin')
                            AllowedRole('can_edit')
                            ACLDetachTo('denied')
                         : Sitemap
{
    my ( $self, $c ) = @_;

    # Get action's traits
    # ===================
    $self->_roles(
        $self->new_with_traits(
            traits      => [qw/RenewCiphers/],
            schema_file => $self->cfg->{ovpnc_config_schema},
            openvpn     => $self->cfg->{openvpn_bin}
        )
    );

    # Update the cipher list
    # in the xsd schema file
    # ======================
    my $_ret_val = $self->_roles->update_cipher_list;
    $c->controller('Api')->detach_error($c)
      unless ($_ret_val);
    $c->controller('Api')->detach_error($c, $_ret_val->{error})
      if ( ref $_ret_val && $_ret_val->{error} );
    $self->status_ok( $c, entity => $_ret_val )
      if ( ref $_ret_val && !$_ret_val->{error} );
}

=head2 XML example _create_xml

<Nodes>
  <Node id="1">
    <Name></Name>
    <ConfigFile>/etc/openvpn/server.conf</ConfigFile>
    <Directives>
      <Group id="1">
        <Directive>
          <Name>local</Name>
          <Params>
            <VPN-Server>192.168.1.250</VPN-Server>
          </Params>
        </Directive>
        <Directive>
          <Name>duplicate-cn</Name>
        </Directive>
      </Group>
    </Directives>
  </Node>
</Nodes>

=cut

# Private functions
# =================
sub _send_error : Private {
    my ( $self, $c, $error ) = @_;
    $c->response->status( $error ? $error : 500 );
    delete $c->stash->{assets} if $c->stash->{assets};
    $c->stash( { error => $error } );
    $c->detach;
}

=head2 _prepare_conf_file_data

Will prepare the openvpn
configuration file
will set attributes etc

=cut

sub _prepare_conf_file_data : Private {
    my $self    = shift;
    my %data    = %{ (shift) };
    my $output  = "\n# [ Group id=0 ]\n";
    my $on_hold = {};
    my @existing_keys;
    my $last_group = 0;

    my @_pathtypes = qw/
        ca
        cert
        dh
        key
        chroot
        tls-auth
        ifconfig-pool-persist
        log-append
        status
    /;

  DATA:
    for my $key ( sort keys %data ) {

        # Get any disabled directives
        # ===========================
        my $to_split_key = $key;
        my $disabled = $to_split_key =~ s/_disabled$//;

        # Split the key on underscore
        # ===========================
        my ( $group, $parent, $real, $number ) =
          split( '_', $to_split_key );

        # Skip the two main Directives
        # They have been assigned group 0
        # (config filename and servername)
        # ================================
        next DATA if ( $group == -1 );

        $output .= "\n# [ Group id=" . $group . " ]\n"
          if $group > $last_group;

        if ( $real ~~ @_pathtypes
          && !looks_like_number($data{$key})
          && $data{$key} !~ /via\-[env|file]/
        ){
            $data{$key} = $data{$key} =~ /^\//
                ? $data{$key}
                : $self->cfg->{home} . '/' . $data{$key};
        }

        # If this is second (or more) value
        # we need to hold it until we can
        # append it to its first value(s)
        # =================================
        if ( $number && $real ne 'push' ) {
            if ( $self->_not_exists( \@existing_keys, $real ) ) {
                warn "Added $real to on_hold with value " . $data{$key};
                $on_hold->{$real} = {
                    value  => $data{$key},
                    parent => $parent
                };
                next DATA;
            }
        }

        # If this one has no number defined
        # check if we have pending values
        # to append from the $on_hold hashref
        # ===================================
        if ( !$number && $real ne 'push' ) {
            if ( ref $on_hold eq 'HASH' ) {
                for my $okey ( keys %{$on_hold} ) {
                    if (   $okey eq $real
                        && $on_hold->{$okey}->{parent}
                        && $on_hold->{$okey}->{value} )
                    {
                        $data{$key} .= ' '
                          . $on_hold->{$okey}->{value} . ' ;'
                          . $parent . ' ;'
                          . $on_hold->{$okey}->{parent};
                    }
                }
            }
        }

        # If key name already found,
        # append current value to it
        # ==========================
        if ( $output =~ /\n\b$real\b/g and $real ne 'push' ) {
            my ( $val, $p ) = split( ';', $data{$key} );
            $output =~ s/($real.*) ;(.*)\n/$1 $val ;$2\n/g;
            $output =~ s/($real.*)\n/$1 ;$parent\n/;
        }
        else {
            my $tab = length($real) >= 5 ? "\t" x 6 : "\t" x 7;
            $tab = "\t" x 4 if ( length($real) > 10 );
            if ( defined $data{$key} ) {

                # Create new key/value.
                # output value only if exists
                # otherwise output only the key
                # =============================
                if ( $real eq $data{$key} ) {
                    $output .=
                        ( $disabled ? ';' : '' )
                      . $real . "$tab;"
                      . $parent . "\n";
                }
                else {
                    unless ( $on_hold->{$real}->{parent} ) {
                        $output .=
                            ( $disabled ? ' ;' : '' )
                          . $real . "$tab"
                          . $data{$key} . ' ;'
                          . $parent . "\n";
                    }
                    else {
                        $output .=
                            ( $disabled ? ' ;' : '' )
                          . $real . "$tab"
                          . $data{$key} . "\n";
                    }
                }
                push( @existing_keys, $real );
            }
        }
        $last_group = $group;
    }    # (%DATA)
    $output .= ";END\n";
    return $output;
}

=head2 _create_xml

This function will create
xml file (conditional)
and return xml string

=cut

sub _create_xml : Private {
    my ( $self, $data, $xml_file ) = @_;

    my $xml_obj = XMLin( '<Nodes></Nodes>', ForceArray => [ 'Nodes', 'Node' ] );

    my $i = 0;

    # Create first node id
    # ====================
    $xml_obj->{Nodes}->{Node}->{id} = '0';

    my $last_group = '-1';

  DATA:
    for my $key ( sort keys %{$data} ) {

        # Get any disabled
        # ================
        my $to_split_key = $key;
        my $disabled = $to_split_key =~ s/_disabled$//;

        # We shall increment $i only when group changes
        # we get all elements sorted in this loop
        # =============================================
        my ( $group, $parent, $real, $number ) =
          split( '_', $to_split_key );

        $i = 0 if ( $group > $last_group );

        # Only if group is not '-1' which are directives
        # which do not appear in the conf file itself
        # ==============================================
        $xml_obj->{Nodes}->{Node}->{Directives}->{Group}->[$group]->{id} =
          $group
          unless ( $group eq '-1' );

        # Name and ConfigFile have no
        # parent because they are not
        # part of the config file itself
        # ==============================
        if ( $group eq '-1' ) {
            $xml_obj->{Nodes}->{Node}->{$real} = [ $data->{$key} ];
        }
        else {

            # Create the Name node
            # ====================
            my ( $z, $skip ) = 0;

            if ( $real ne 'push' ) {
              NODES:
                for (
                    @{
                        $xml_obj->{Nodes}->{Node}->{Directives}->{Group}
                          ->[$group]->{Directive}
                    }
                  )
                {

                    unless ( $_->{Name}->[0] ) {
                        $z++;
                        next NODES;
                    }

                    # Check if such a name already exists in the
                    # hash, if yes, append to its node
                    # Otherwise it creates a new parent node
                    # and not append to the previous similar one
                    # ==========================================
                    if ( $real eq $_->{Name}->[0] ) {

                        $xml_obj->{Nodes}->{Node}->{Directives}->{Group}
                          ->[$group]->{Directive}->[$z]->{Params}->[0]
                          ->{$parent} = [ $data->{$key} ];

                        # Give $skip a value for later checks
                        # ===================================
                        $skip++;
                        last NODES;
                    }
                    $z++;
                }
            }

            # If $skip is not assigned this is a new
            # parent node, so create a new one
            # ======================================
            if ( !$skip ) {

                $xml_obj->{Nodes}->{Node}->{Directives}->{Group}->[$group]
                  ->{Directive}->[$i]->{status} = ( $disabled ? 0 : 1 );
                $xml_obj->{Nodes}->{Node}->{Directives}->{Group}->[$group]
                  ->{Directive}->[$i]->{Name} = [$real];

            }

            # Create parameters node only if
            # the parameters exists, that means
            # that they are different than the $parent
            # ========================================
            if ( $real ne $data->{$key} && !$skip ) {

                $xml_obj->{Nodes}->{Node}->{Directives}->{Group}->[$group]
                  ->{Directive}->[$i]->{Params}->[0] =
                  { $parent => [ $data->{$key} ] };
            }

            $i++ if ( !$skip );

        }

        # Save the group for next loop
        # ============================
        $last_group = $group;

    }

    # Note! Returns a PERL data structure
    # we shall XMLout it soon
    # ===================================
    return $xml_obj;
}

=head2 _validate_xml

Validate the xml against a xsd schema
returns the errors if any

=cut

    sub _validate_xml : Private {
        my ( $self, $xml, $schema ) = @_;
        my $validator = XML::Validator::Schema->new( file => $schema );
        my $parser = XML::SAX::ParserFactory->parser( Handler => $validator );
        eval { $parser->parse_string($xml) };
        return "Form validation error: $@" if $@;
    }

=head2 _perl_to_xml

Convert a perl datastructure to xml

=cut

    sub _perl_to_xml : Private {
        return XMLout(
            $_[1],
            KeepRoot => 1,
            NoSort   => 0,
            XMLDecl  => "<?xml version='1.0' encoding='UTF-8'?>",
        ) or die "Cannot generate XML data!";
    }


=head2 _manage_conf_file

Remove old backups
create backup before save

=cut

    sub _manage_conf_backup : Private {
        my ( $self, $config_files, $keep_conf ) = @_;

        return "\$config_files missing data!" unless $config_files;
        return "\$config_files must be an ArrayRef"
            if ref $config_files ne 'ARRAY';

        for my $config_file ( @{$config_files} ) {
            # Backup conf file
            # ================
            copy( $config_file, $config_file . '_' . time() . '_backup' )
              or return {
                error => "Error: Cannot backup existing config file '" . $config_file . "': $!" };

            my ($_dir) = split( /\/[a-z\._\-]*$/i, $config_file );

            # leave n copies (remove old)
            # ===========================
            opendir( my $DIR, $_dir );
            my @_files =
              map { $_ if $_ =~ /^[a-z\.\-_]+_[0-9]+_backup/g } readdir($DIR);
            close $DIR;
            my @_to_remove = splice @{ [ reverse sort @_files ] },
              ( $keep_conf ? $keep_conf : 1 );
            for (@_to_remove) {
                next if $_ eq $_dir . '/';
                unlink $_dir . '/' . $_;
            }
        }
        return;
    }


# Functions
# =========
=head2 _not_exists

Checks if elemnt already exists
in the array, if yes, it returns
false so it will not be put into hold

=cut

    sub _not_exists : Private {
        my ( $self, $keys, $real ) = @_;
        return 1 unless ref $keys eq 'ARRAY';
        if ( $real ~~ @{$keys} ) {
            return 0;
        }
        return 1;
    }


=head2 get_openvpn_[param]

Get parameter(s) from the
Ovpnc xml conf file

=cut

    sub get_openvpn_param : Private {
        my ( $self, $params, $file ) = @_;

        die "Called get_openvpn_param without \$params"
            unless $params;

        $file ||= $self->cfg->{ovpnc_conf};

        my $dom = XML::LibXML->load_xml( location => ( $file ) );
        if ( ref $params eq 'ARRAY' ) {
            my @arr;
            for ( @{$params} ) {
                my $value = $dom->findvalue(
                    '/Nodes/Node/Directives/Group/Directive/Params/' . $_ );
                push( @arr, $value ) if $value;
            }
            return \@arr;
        }
        else {
            my $_ret_val = $dom->findvalue(
                '/Nodes/Node/Directives/Group/Directive/Params/' . $params );
            warn "Param not found: $params"
                unless $_ret_val;
            return $_ret_val;
        }
    }

=head2 get_openvpn_config_file

Returns specifically the ConfigFile

=cut

    sub get_openvpn_config_file : Private {
        my ( $self, $file ) = @_;
        my $xml_obj = XMLin( $file ) or die "Cannot read xml file $file: $!";
        return $xml_obj->{Node}->{ConfigFile};
    }



=head2 end

Last auto-action

=cut

    sub end : Private {
        my ( $self, $c ) = @_;
    
        # Clean up the File::Assets
        # it is set to null but
        # is not needed in JSON output
        delete $c->stash->{assets};

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
