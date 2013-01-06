package Ovpnc;
use Moose;
use Cwd;
use namespace::autoclean;
use Catalyst::Runtime 5.80;
use v5.10.1;
use utf8;

=head1 NAME

Ovpnc - OpenVPN Controller

=head1 SYNOPSIS

See L<Ovpnc>

=head1 DESCRIPTION

L<Ovpnc>
GUI and API Controller for OpenVPN

=head2 VERSION v0.01

v0.01

=cut

our $VERSION = '0.01';

use Catalyst qw/
  -Debug
  ConfigLoader
  Assets
  Alarm
  Static::Simple
  Compress::Gzip
  Compress::Deflate
  Cache
  Cache::Memcached
  SecureCookies
  Session
  Session::Store::File
  Session::State::Cookie
  Authentication
  Authentication::Store::Minimal
  Authorization::Roles
  Scheduler
  Redirect
  Sitemap
  +CatalystX::SimpleLogin
  /;
#  Session::Store::Memcached

=head2 CONFIGURATION

Configure the application.

Note that settings in ovpnc.conf (or other external
configuration file that you set up manually) take precedence
over this when using ConfigLoader. Thus configuration
details given here can function as a default configuration,
with an external configuration file acting as an override for
local deployment.

=cut

__PACKAGE__->config({
    ENCODING     => 'utf-8',
});

__PACKAGE__->config(

    name            => 'Ovpnc',

    'default_view'  => 'HTML',
    'default'       => 'application/json',
    'stash_key'     => 'rest',
    'map' => { 
        'text/html'     => [ 'View', 'HTML', ], 
        'text/xml'      => [ 'View', 'XML::Simple', ], 
        'application/x-www-form-urlencoded' => 'JSON',
        'application/json'                  => 'JSON',
    },

    # Disable deprecated behavior
    # needed by old applications
    # ==========================
    disable_component_resolution_regex_fallback => 1,
    enable_catalyst_header                      => 1

);

# ConfigLoader
# ============
__PACKAGE__->config(
    'Plugin::ConfigLoader' => {
        config_local_suffix => 'local',
        driver => {
            'General' => { -LowerCaseNames => 1 }
        }
    }
);


# Cache
# =====
__PACKAGE__->config(
	'Plugin::Cache' => {
    	backend => {
        	class      => "Cache::File",
        	cache_root => getcwd . '/tmp/cache',
            store      => "Minimal",
        }
	}
);

# Alarm
# =====
__PACKAGE__->config(
    alarm => {
        timeout => 60,
        global  => 120,
        handler => sub { die "The application timed-out." }
    }
);


# Cache::Memcached::libmemcached
# ==============================
__PACKAGE__->config(
    'Plugin::Cache' => {
        backend => {
            class   => "Cache::Memcached::libmemcached",
            servers => ['127.0.0.1:11211'],
            debug   => 2,
        }
    }
);

# Static::Simple
# ==============
__PACKAGE__->config(
    'Static::Simple' => {
		static => {
			expires => 86400, # Default expire value (24hrs)
			ignore_extensions => [ qw/html xhtml shtml phtml tmpl tt2 tt asp php/ ],
	        dirs => [
	            'static',
	            qr/^(images|css|js)/,
	        ],
			mime_types => {
                tar  => 'application/x-tar',
                html => 'text/html',
				js   => 'application/javascript',
				json => 'application/json',
				css  => 'text/css',
				xml  => 'text/xml',
                jpg  => 'image/jpg',
                png  => 'image/png',
                ico  => 'image/x-icon',
            },
	    }
	}
);

# XSLT View
# =========
__PACKAGE__->config(
    'View::XSLT' => {

        # relative paths to the
        # directories with templates
        # ==========================
        INCLUDE_PATH       => [ Ovpnc->path_to( 'root', 'xslt' ), ],

        # default extension when getting
        # template name from the current action
        # =====================================
        TEMPLATE_EXTENSION => '.xsl',
        FORCE_TRANSFORM => 1,

        # use for Debug. Will dump the final
        # (merged) configuration for XSLT view
        # ====================================
        DUMP_CONFIG     => 0,
        # XML::LibXSLT specific parameters
        # ================================
        LibXSLT => {
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

# HTML View
# =========
__PACKAGE__->config(
    'View::HTML' => {
        TEMPLATE_EXTENSION => '.tt2',
        INCLUDE_PATH       => [ Ovpnc->path_to( 'root', 'src' ), ],
        PRE_PROCESS        => [ 'built'],

        # Set to 1 for detailed timer
        # stats in your HTML as comments
        # ==============================
        TIMER => 0,

        # This is your wrapper template
        # located in the 'root/src'
        # =============================
        WRAPPER    => 'wrapper.tt2',
        ENCODING   => 'utf-8',
        render_die => 1,
    }
);

# SecureCookies
# =============
__PACKAGE__->config(
    'SecureCookies' => {
        key       => 'Ooc4ohphahN-ah6Aij)aith7zoe2Aineinae7quuaR',
        ssl       => 0,
    },
);

# Assets Plugin
# =============
__PACKAGE__->config(
    'Plugin::Assets' => {
            path => "/static",
            output_path => "built/",
            minify => 0,
            stash_var => "assets", # This is the default setting
        },
);

# Login controller
# ================
__PACKAGE__->config(
    'Controller::Login' => {

        # Force clear session on logout
		# =============================
        clear_session_on_logout => 1,

        # Redirect to login page after logout
		# ===================================
        redirect_after_logout_uri => '/login',

        login_form_args => { authenticate_args => { active => 'Y' }, },

        traits => [ 'Logout', 'WithRedirect', '-RenderAsTTTemplate' ],

        actions => {
        	required => {
        		Does => ['ACL'],
        		AllowedRole => [qw/admin client/], # ANY of these
        		RequiresRole => ['admin'], # ALL of these
        		ACLDetachTo => 'login',
        	},
        },
    },
);


# Session config
# ==============
__PACKAGE__->config(
    'Plugin::Session' => {
        # Memcached
        #memcached_new_args => {
        #  'data' => [ "127.0.0.1:11211" ],
        #},

        flash_to_stash => 1,

        # Session via file
        storage        => $ENV{OVPNC_SESSION_DIR} || 'tmp/session',

        # Session via database
        #dbic_class => 'DB::Session',

        # Default low value
        # will be extended
        # upon login
        expires => 10,

        # Setting this to 1
        # will break ajax calls
        # Todo: set ajax calls
        # to user's user agent
        verify_user_agent => 0,
    },
);

# - Currently overridden in ovpnc.json -
# Database
# ========
#use Config::Any;
#__PACKAGE__->config(
#    'Model::DB' =>
#    {
#        schema_class => 'Ovpnc::Schema',
#        connect_info => Config::Any->load_files({
#            files => [ __PACKAGE__->config->{home} . '/ovpnc.json'], use_ext => 1
#        })->[0]->{ __PACKAGE__->config->{home} . '/ovpnc.json' }
#          ->{'Model::DB'}->{'connect_info'}
#    }
#);

# Start the application
# =====================
__PACKAGE__->setup();

# Scheduler
# =========
__PACKAGE__->schedule(
	at    => '0 * * * *',
    event => '/cron/remove_sessions',
);


=head2 get_version

Make version accessible

=cut

	sub get_version{ return $VERSION; }

    
=head1 AUTHOR

Nuriel Shem-Tov 2012

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


1;
