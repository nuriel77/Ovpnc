package Ovpnc::TraitFor::Controller::Api::Certificates::Vars;
use warnings;
use strict;
use Moose::Role;

# will become defined
# for all other traits
# ====================
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
    my $_tools_dir = $self->_cfg->{openvpn_utils};

    # OpenSSL config
    # ==============
    my $_openssl_config =
        $self->_cfg->{ssl_config} =~ /^\//
            ? $self->_cfg->{ssl_config}
            : $_tools_dir . '/' . $self->_cfg->{ssl_config};
use Data::Dumper::Concise;
die Dumper $self->_req;
    # Set openssl environment
    # variables (eq to source ./vars)
    # At the moment we don't do duplicate
    # client certifiates, so each client
    # gets same CN as the client's name
    # ===================================
    my %_oe = (
        KEY_CN             => $self->_req->{KEY_CN}         || 'server',
        KEY_NAME           => $self->_req->{KEY_NAME}       || 'Ovpnc',
        EASY_RSA           => $_tools_dir,
        OPENSSL            => $self->_cfg->{ssl_bin},
        PKCS11TOOL         => $_tools_dir . '/pkcs11-tool',
        GREP               => '/bin/grep',
        KEY_CONFIG         => $_openssl_config,
        KEY_DIR            => $_tools_dir . '/keys',
        PKCS11_MODULE_PATH => 'dummy',
        PKCS11_PIN         => 'dummy',
        KEY_SIZE           => $self->_req->{KEY_SIZE}       // 2048,
        CA_EXPIRE          => $self->_req->{CA_EXPIRE}      // 3650,
        KEY_EXPIRE         => $self->_req->{KEY_EXPIRE}     // 3650,
        KEY_COUNTRY        => $self->_req->{KEY_COUNTRY}    || 'NL',
        KEY_PROVINCE       => $self->_req->{KEY_PROVINCE}   || 'NH',
        KEY_CITY           => $self->_req->{KEY_CITY}       || 'Amsterdam',
        KEY_ORG            => $self->_req->{KEY_ORG}        || 'DeBar',
        KEY_OU             => $self->_req->{KEY_OU}         || 'DeBar',
        KEY_EMAIL          => $self->_req->{KEY_EMAIL}      || 'nuri@de-bar.com',
    );

    $ENV{$_} = $_oe{$_} for ( keys %_oe );

    return \%_oe;
}

1;
