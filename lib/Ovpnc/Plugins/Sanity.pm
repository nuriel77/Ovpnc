package Ovpnc::Plugins::Sanity;
use warnings;
use strict;
use Fcntl ':mode';
use vars qw/$errors $openvpn_user $os $distro/;

sub cfg {
    my $self = shift;
    $self->{_cfg} = shift if @_;
    return $self->{_cfg};
}

sub action {
    my ( $inv, $config ) = @_;
    my $class = ref($inv) || $inv;
    my $self = {};
    bless $self, $class;

    return unless $config;

    # remove trailing /
    # =================
    $config->{openvpn_dir} =~ s/\/$//;

    $openvpn_user = $config->{openvpn_user};
    $distro       = '/etc/debian_version';
    $os           = 'linux';

    # Set in accessor
    # ===============
    $self->cfg($config);

    # Prepare hash with
    # list of all checks
    # ==================
    my $checks = {
        os            => sub { return $self->check_os },
        openvpn_user  => sub { return $self->check_openvpn_user },
        app_user      => sub { return $self->check_app_user },
        distro        => sub { return $self->check_dist },
        ovpnc_user    => sub { return $self->check_ovpnc_user },
        configuration => sub { return $self->check_config if $config },
        check_scripts => sub { return $self->check_openvpn_scripts if $config },
        check_tmp_dirs => sub {
            return $self->check_temp_directories(
                [
                    (
                        (
                            $config->{"Plugin::Cache"}->{backend}
                              ->{cache_root} =~ /^(.*)\/.*$/
                        )
                    ),
                    $config->{"Plugin::Cache"}->{backend}->{cache_root},
                    $config->{"Plugin::Session"}->{storage},
                ]
            );
        },
    };

    # Loop the hash to execute checks
    # ===============================
    for my $check ( keys %{$checks} ) {
        if ( my $ret_val = $checks->{$check}->() ) {
            push( @{$errors}, 'Check error - ' . $check . ': ' . $ret_val );
        }
    }
    return $errors if ref $errors eq 'ARRAY';
}

{

    sub check_os {
        my $self = shift;
        return (
            $^O eq $os
            ? 0
            : 'Not a ' . $os . ' operating system: ' . $^O
        );
    }

    sub check_dist {
        my $self = shift;
        return ( -e $distro ? 0 : 'Not a ' . $distro . ' distro' );
    }

    sub check_openvpn_user {
        my $self = shift;

        # Check if user exists
        if (
            my ( undef, $st, undef, undef, undef, undef, undef, undef, $home ) =
            getpwnam $self->cfg->{openvpn_user} )
        {

            # Check if user is diabled
            return "User " . $self->cfg->{openvpn_user} . " is disabled"
              if ( $st ne 'x' );

            # Make sure user does not have a login shell
            return
"User has a login shell, please disable it by changing the shell entry of this user in the /etc/passwd to /sbin/nologin"
              if ( $home !~ /\/sbin\/nologin|\/bin\/false/ )

        }
        else {
            return
                "User "
              . $self->cfg->{openvpn_user}
              . " not found, please add the user by issusing the command: sudo adduser "
              . $self->cfg->{openvpn_user};
        }
    }

    sub check_ovpnc_user {
        my $self = shift;

        #Example: ovpnc:x:1011:1012::/home/ovpnc:/bin/sh
        # Check if user exists
        if (
            my (
                undef, $st,   $user_id, $group_id, undef,
                undef, undef, undef,    $home
            )
            = getpwnam $self->cfg->{ovpnc_user}
          )
        {

            # Check if user is diabled
            return "User " . $self->cfg->{ovpnc_user} . " is disabled"
              if ( $st ne 'x' );

# Make sure user does not have a login shell
#return "User has a login shell, please disable it by changing the shell entry of this user in the /etc/passwd to /sbin/nologin"
#	if ( $home !~ /\/sbin\/nologin|\/bin\/false/ )

            # Check if openvpn user is in the group of ovpnc
            return (
                ( getgrgid($group_id) )[3] !~ /$openvpn_user/
                ? "You need to add user openvpn to the group "
                  . $self->cfg->{ovpnc_user}
                  . ": sudo adduser openvpn "
                  . $self->cfg->{ovpnc_user}
                : 0
            );

        }
        else {
            return
                "User "
              . $self->cfg->{ovpnc_user}
              . " not found, please add the user by issusing the command: sudo adduser "
              . $self->cfg->{ovpnc_user};
        }
    }

    sub check_app_user {
        return (
            $< == 0
            ? "This application should not be run under root user!"
            : 0
        );
    }

    sub check_config {
        my $self = shift;

        if (   !-e $self->cfg->{ovpnc_conf}
            || !-r $self->cfg->{ovpnc_conf}
            || !-w $self->cfg->{ovpnc_conf} )
        {
            return $self->cfg->{ovpnc_conf}
              . " not found or not readable or not writable (should be both)";
        }

        # Get the openvpn conf
        # File from the xml
        # ====================
        $self->cfg->{openvpn_conf} =
          Ovpnc::Controller::Api::Configuration->get_openvpn_config_file(
            $self->cfg->{ovpnc_conf} );

        # Check binary
        # ============
        if ( !-e $self->cfg->{openvpn_bin} ) {
            return $self->cfg->{openvpn_bin} . " is not found";
        }
        elsif ( !-x $self->cfg->{openvpn_bin} ) {
            return
                $self->cfg->{openvpn_bin}
              . " is not executable by current user: "
              . $self->cfg->{ovpnc_user};
        }

        # Check openvpn dir
        # =================
        elsif (!-e $self->cfg->{openvpn_dir}
            || !-d $self->cfg->{openvpn_dir}
            || !-r $self->cfg->{openvpn_dir} )
        {
            return $self->cfg->{openvpn_dir}
              . " not found or not readable(openvpn_dir)";
        }

        # check openvpn tmpdir
        # ====================
        elsif (!-e $self->cfg->{openvpn_dir} . '/tmp'
            || !-d $self->cfg->{openvpn_dir} . '/tmp'
            || !-w $self->cfg->{openvpn_dir} . '/tmp' )
        {
            return $self->cfg->{openvpn_dir}
              . "/tmp not found or not readable(openvpn_tmpdir)";
        }

        # check openssl conf
        # ==================
        elsif (!-e $self->cfg->{openssl_conf}
            || !-r $self->cfg->{openssl_conf} )
        {
            return $self->cfg->{openssl_conf}
              . " not found or not readable(openssl.conf)";
        }

        # check application root dir
        # ==========================
        elsif (!-e $self->cfg->{app_root}
            || !-d $self->cfg->{app_root} )
        {
            return $self->cfg->{app_root}
              . " not found or not readable";
        }

        # check openvpn conf
        # ==================
        elsif (!-e $self->cfg->{openvpn_conf}
            || !-r $self->cfg->{openvpn_conf} )
        {
            return $self->cfg->{openvpn_conf}
              . " not found or not readable(openvpn_conf)";
        }
        elsif (!-e $self->cfg->{ovpnc_config_schema}
            || !-r $self->cfg->{ovpnc_config_schema} )
        {
            return $self->cfg->{ovpnc_config_schema}
              . " not found or not readable or not writable (should be both)";
        }

    }

    sub check_openvpn_scripts {

        my $self = shift;

        # Add a trailing / to dir
        # and append the util dir
        # it was removed earier
        # =====================
        my $conf_dir =
            $self->cfg->{openvpn_utils} =~ /^\//
            ? $self->cfg->{openvpn_utils}
            : $self->cfg->{openvpn_dir} . '/' . $self->cfg->{openvpn_utils} . '/';

        # check openvpn scripts
        for (
            qw[
            vars
            whichopensslcnf
            pkitool
            sign-req
            clean-all
            build-req-pass
            build-req
            build-key-server
            build-key-pkcs12
            build-key-pass
            build-key
            build-ca
            build-dh
            build-inter
            revoke-full
            build-key-automatic
            keys/index.txt
            ]
          )
        {

            if ( !-r $conf_dir . $_ ) {
                return "'" . $conf_dir . $_ . "' not found or not readable";
            }
        }
    }

    sub check_temp_directories {
        my ( $self, $dirs ) = @_;

        return unless $dirs or ref $dirs ne 'ARRAY';

        for my $dir ( @{$dirs} ) {
            return "Directory '$dir' does not exists"     if ( !-e $dir );
            return "Directory '$dir' is not a directory?" if ( !-d $dir );
            return "Directory '$dir' is not writable"     if ( !-w $dir );
            my $mode = sprintf "%04o", S_IMODE( ( stat($dir) )[2] );
            return "Directory '$dir' should not be world accessibe ($mode)!"
              if $mode eq '0777';
        }

    }

}

1;
