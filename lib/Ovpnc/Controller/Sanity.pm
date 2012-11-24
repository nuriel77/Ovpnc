package Ovpnc::Controller::Sanity;
use Moose;
use Fcntl ':mode';
use vars qw/$errors/;
use namespace::autoclean;

has 'ovpnc_user' => (
    isa     => 'Str',
    is      => 'rw',
    default => 'ovpnc',
);

has 'openvpn_user' => (
    isa     => 'Str',
    is      => 'rw',
    default => 'openvpn',
);

has 'dist' => (
    isa     => 'Str',
    is      => 'rw',
    default => '/etc/debian_version',
);

has 'os' => (
    isa     => 'Str',
    is      => 'rw',
    default => 'linux',
);

sub action {
    my ( $self, $config ) = @_;

	# remove trailing /
	$config->{openvpn_dir} =~ s/\/$//;
	
    my $checks = {
        os            => sub { return $self->check_os },
        openvpn_user  => sub { return $self->check_openvpn_user },
        app_user      => sub { return $self->check_app_user },
        distro        => sub { return $self->check_dist },
        ovpnc_user    => sub { return $self->check_ovpnc_user },
        configuration => sub { return $self->check_config($config) if $config },
		check_scripts => sub { return $self->check_openvpn_scripts($config) if $config },
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
        return ( $^O eq $self->os
            ? 0
            : 'Not a ' . $self->os . ' operating system: ' . $^O );
    }

    sub check_dist {
        my $self = shift;
        return ( -e $self->dist ? 0 : 'Not a ' . $self->dist . ' distro' );
    }

    sub check_openvpn_user {
        my $self = shift;

        # Check if user exists
        if (
            my ( undef, $st, undef, undef, undef, undef, undef, undef, $home ) =
            getpwnam $self->openvpn_user )
        {

            # Check if user is diabled
            return "User " . $self->openvpn_user . " is disabled"
              if ( $st ne 'x' );

            # Make sure user does not have a login shell
            return
"User has a login shell, please disable it by changing the shell entry of this user in the /etc/passwd to /sbin/nologin"
              if ( $home !~ /\/sbin\/nologin|\/bin\/false/ )

        }
        else {
            return
                "User "
              . $self->openvpn_user
              . " not found, please add the user by issusing the command: sudo adduser "
              . $self->openvpn_user;
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
            = getpwnam $self->ovpnc_user
          )
        {

            # Check if user is diabled
            return "User " . $self->ovpnc_user . " is disabled"
              if ( $st ne 'x' );

# Make sure user does not have a login shell
#return "User has a login shell, please disable it by changing the shell entry of this user in the /etc/passwd to /sbin/nologin"
#	if ( $home !~ /\/sbin\/nologin|\/bin\/false/ )

            # Check if openvpn user is in the group of ovpnc
            return (
                ( getgrgid($group_id) )[3] !~ /$self->{openvpn_user}/
                ? "You need to add user openvpn to the group "
                  . $self->ovpnc_user
                  . ": sudo adduser openvpn "
                  . $self->ovpnc_user
                : 0
            );

        }
        else {
            return
                "User "
              . $self->ovpnc_user
              . " not found, please add the user by issusing the command: sudo adduser "
              . $self->ovpnc_user;
        }
    }

    sub check_app_user {
        return ( $< == 0
            ? "This application should not be run under root user!"
            : 0 );
    }

    sub check_config {
        my ( $self, $config ) = @_;

        if (!-e $config->{ovpnc_conf}
            || !-r $config->{ovpnc_conf}
            || !-w $config->{ovpnc_conf} )
        {
            return $config->{ovpnc_conf}
              . " not found or not readable or not writable (should be both)";
        }

		# Get the openvpn conf
		# File from the xml
		$config->{openvpn_conf} =
			Ovpnc::Controller::Api::Config->get_openvpn_config_file( $config->{ovpnc_conf} );

        # Check binary
        if ( !-e $config->{openvpn_bin} ) {
            return $config->{openvpn_bin} . " is not found";
        }
        elsif ( !-x $config->{openvpn_bin} ) {
            return
                $config->{openvpn_bin}
              . " is not executable by current user: "
              . $self->ovpnc_user;
        }

        # check openvpn dir
        elsif (!-e $config->{openvpn_dir}
            || !-d $config->{openvpn_dir}
            || !-r $config->{openvpn_dir} )
        {
            return $config->{openvpn_dir} . " not found or not readable";
        }
	
		# check openvpn tmpdir
		 elsif (!-e $config->{openvpn_dir} . '/tmp'
            || !-d $config->{openvpn_dir} . '/tmp'
            || !-w $config->{openvpn_dir} . '/tmp' )
        {
            return $config->{openvpn_tmpdir} . " not found or not readable";
        }

		# check openssl conf
		elsif ( !-e $config->{openssl_conf} || !-r $config->{openssl_conf} ) {
            return $config->{openssl_conf} . " not found or not readable";
        }

		# check application root dir
		elsif ( !-e $config->{application_root} || !-d $config->{application_root} ) {
            return $config->{application_root} . " not found or not readable";
        }

        # check openvpn conf
        elsif ( !-e $config->{openvpn_conf} || !-r $config->{openvpn_conf} ) {
            return $config->{openvpn_conf} . " not found or not readable";
        }
        elsif (!-e $config->{ovpnc_config_schema}
            || !-r $config->{ovpnc_config_schema} )
        {
            return $config->{ovpnc_config_schema}
              . " not found or not readable or not writable (should be both)";
        }

    }

	sub check_openvpn_scripts {

        my ( $self, $config ) = @_;

		# Add a trailing / to dir 
		# it was removed earier
		$config->{openvpn_dir} .= '/';
		
		# check openvpn scripts
		for ( qw/
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
			/ )
		{
			if ( !-r $config->{openvpn_dir} . $_ ){
	            return "'" . $config->{openvpn_dir}. $_ . "' not found or not readable";
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

no Moose;

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
