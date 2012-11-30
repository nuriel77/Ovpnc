package Ovpnc::TraitFor::Controller::Api::Certificates::Vars;
use warnings;
use strict;
use Moose::Role;

# will become defined
# for all other traits
has '_cfg' => (
    is => 'ro',
    required => 1,
    isa => 'HashRef',
);

has '_req' => (
    is => 'ro',
    required => 1,
    isa => 'HashRef',
);

sub set_environment_vars
{
    my $self = shift;

    # OpenVPN tools
    # =============
    my $_tools_dir = $self->_cfg->{app_root}
                    . '/' . $self->_cfg->{openvpn_dir}
                    . '/' . $self->_cfg->{utils_dir};

    # OpenSSL config
    # ==============
    my $_openssl_config =
        $self->_cfg->{ssl_config} =~ /^\//
            ? $self->_cfg->{ssl_config}
            : $_tools_dir . '/' . $self->_cfg->{ssl_config};

    # Set openssl environment variables (eq to source ./vars)
    my %_oe = (
        EASY_RSA           => $_tools_dir,
        OPENSSL            => $self->_cfg->{ssl_bin},
        PKCS11TOOL         => $_tools_dir . '/pkcs11-tool',
        GREP               => '/bin/grep',
        KEY_CONFIG         => $_openssl_config,
        KEY_DIR            => $_tools_dir . '/keys',
        PKCS11_MODULE_PATH => 'dummy',
        PKCS11_PIN         => 'dummy',
        KEY_SIZE           => $self->_req->{key_size}       || 2048,
        CA_EXPIRE          => $self->_req->{ca_expire}      || 3650,
        KEY_EXPIRE         => $self->_req->{key_expire}     || 3650,
        KEY_COUNTRY        => $self->_req->{key_country}    || 'NL',
        KEY_PROVINCE       => $self->_req->{key_province}   || 'NH',
        KEY_CITY           => $self->_req->{key_city}       || 'Amsterdam',
        KEY_ORG            => $self->_req->{key_org}        || 'DeBar',
        KEY_EMAIL          => $self->_req->{key_email}      || 'nuri@de-bar.com',
    );

    $ENV{$_} = $_oe{$_} for ( keys %_oe );

    return \%_oe;
}

1;
