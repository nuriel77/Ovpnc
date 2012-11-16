package Ovpnc;
use Moose;
use namespace::autoclean;

use Catalyst::Runtime 5.80;

# Set flags and add plugins for the application.
#
# Note that ORDERING IS IMPORTANT here as plugins are initialized in order,
# therefore you almost certainly want to keep ConfigLoader at the head of the
# list if you're using it.
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

use Catalyst qw/
	-Debug
    ConfigLoader
    Static::Simple
	Compress::Gzip
	Compress::Deflate
	Cache
	Session
    Session::Store::File
    Session::State::Cookie
	Authentication
	Authentication::Store::Minimal
	Authorization::Roles
	+CatalystX::SimpleLogin
	StackTrace
/;

extends 'Catalyst';

our $VERSION = '0.01';

# Configure the application.
#
# Note that settings in ovpnc.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with an external configuration file acting as an override for
# local deployment.

__PACKAGE__->config(
    name => 'Ovpnc',
	default_view => 'HTML',
    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,
    enable_catalyst_header => 1, # Send X-Catalyst header
	#
	# ConfigLoader
	#
	'Plugin::ConfigLoader' => {
		config_local_suffix => 'local'
	},
	#
	# Cache
	#
	'Plugin::Cache' =>
	{
		backend => 
		{
			class => "Cache::File",
			cache_root => 'tmp/cache',
			store => "Minimal",
		}
	}

);

#
# Login controller config 
__PACKAGE__->config(
	'Controller::Login' => {
		login_form_args => {
           authenticate_args => { active => 'Y' },
        },
        traits => [qw( Logout WithRedirect RenderAsTTTemplate )],
#		actions => {
#			required => {
#				Does => ['ACL'],
#				AllowedRole => ['ovpncadmin', 'ovpnc', 'nuriel'], # ANY of these
#				RequiresRole => ['nuriel'], # ALL of these
#				ACLDetachTo => 'login',
#			},
#		},
	},
);



#
# Session config
__PACKAGE__->config(
    'Plugin::Session' => {
        flash_to_stash => 1,
		storage => 'tmp/session'
    },
);

#
# Start the application
__PACKAGE__->setup();


=head1 AUTHOR

Nuriel Shem-Tov 2012

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
