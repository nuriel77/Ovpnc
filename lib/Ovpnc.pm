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
  Assets
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
  Redirect
  +CatalystX::SimpleLogin
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

    name         => 'Ovpnc',
    default_view => 'HTML',

    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,
    enable_catalyst_header                      => 1,   # Send X-Catalyst header
                                                        #
                                                        # ConfigLoader
                                                        #
    'Plugin::ConfigLoader' => { config_local_suffix => 'local' },

    #
    # Cache
    'Plugin::Cache' => {
        backend => {
            class      => "Cache::File",
            cache_root => 'tmp/cache',
            store      => "Minimal",
        }
      }

);

#
# Static::Simple
__PACKAGE__->config(
    'Static::Simple' => {	
		static => {
			expires => 86400, # Default expire value (24hrs)
			ignore_extensions => [ qw/xhtml shtml phtml tmpl tt2 tt asp php/ ],
	        dirs => [
	            'static',
	            qr/^(images|css|js)/,
	        ],
			mime_types => {
				js  => 'application/javascript',
				json => 'application/json',
				css => 'text/css',
				xml => 'text/xml',
                jpg => 'image/jpg',
                png => 'image/png',
                ico => 'image/x-icon',
            },
	    }
	}
);

#
# XSLT View
__PACKAGE__->config(
    'View::XSLT' => {

        # relative paths to the directories with templates
        INCLUDE_PATH       => [ Ovpnc->path_to( 'root', 'xslt' ), ],
        TEMPLATE_EXTENSION => '.xsl'
        , # default extension when getting template name from the current action
        FORCE_TRANSFORM => 1,
        DUMP_CONFIG     => 0
        , # use for Debug. Will dump the final (merged) configuration for XSLT view
        LibXSLT => {    # XML::LibXSLT specific parameters
            register_function => [
                {
                    uri    => 'urn:ovpnc',
                    name   => 'Param',
                    subref => sub { return $_[0] },
                }
            ]
        }
    }
);

#
# HTML View
__PACKAGE__->config(
    'View::HTML' => {
        TEMPLATE_EXTENSION => '.tt2',
        INCLUDE_PATH       => [ Ovpnc->path_to( 'root', 'src' ), ],

        # Set to 1 for detailed timer stats in your HTML as comments
        TIMER => 0,

        # This is your wrapper template located in the 'root/src'
        WRAPPER    => 'wrapper.tt2',
        ENCODING   => 'utf-8',
        render_die => 1,
    }
);

#
# Assets Plugin

__PACKAGE__->config(    
    'Plugin::Assets' => {
            path => "/static",
            output_path => "built/",
            minify => 0,
            stash_var => "assets", # This is the default setting
        },
);

#
# Login controller config
__PACKAGE__->config(
    'Controller::Login' => {

        # Force clear session on logout
        clear_session_on_logout => 1,

        # Redirect to login page after logout
        redirect_after_logout_uri => '/login',

        login_form_args => { authenticate_args => { active => 'Y' }, },

        traits => [ 'Logout', 'WithRedirect', '-RenderAsTTTemplate' ],

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
        storage        => 'tmp/session'
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
