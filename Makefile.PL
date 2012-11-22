# expected.  You have been warned.
use inc::Module::Install 1.02;

requires 'Module::Install::Catalyst';

use Module::Install::Catalyst; # Complain loudly if you don't have
                               # Catalyst::Devel installed or haven't said
                               # 'make dist' to create a standalone tarball.


name 'Ovpnc';
all_from 'lib/Ovpnc.pm';

requires 'boolean';
requires 'fields';
requires 'Module::Locate';
requires 'Moose';
requires 'Net::SSLeay';
requires 'Gepok';
requires 'Plack::Handler::Gepok';
requires 'namespace::autoclean';
requires 'Config::General';
requires 'XML::LibXML';
requires 'XML::LibXSLT';
requires 'XML::Validator::Schema';
requires 'XML::LibXML::Document';
requires 'XML::Simple';
requires 'XML::SAX::ParserFactory';
requires 'JSON::XS';
requires 'Tie::IxHash';
requires 'File::Slurp';
requires 'File::Copy';
requires 'Readonly';
requires 'Cache::File';
requires 'Net::Telnet';
requires 'Net::OpenVPN::Manage';

requires 'Catalyst::Runtime' => '5.90014';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Plugin::StackTrace';
requires 'Catalyst::Plugin::Cache';
requires 'Catalyst::Plugin::Assets';
requires 'Catalyst::Controller::REST';
requires 'Catalyst::Controller::ActionRole';
requires 'Catalyst::Action::RenderView';
requires 'Catalyst::View::XML::Simple';
requires 'Catalyst::Plugin::Session';
requires 'Catalyst::Plugin::Session::Store::File';
requires 'Catalyst::Plugin::Session::State::Cookie';
requires 'Catalyst::Authentication::Store::Htpasswd';
requires 'Catalyst::Authentication::Store::Minimal';
requires 'Catalyst::Plugin::Compress::Deflate';
requires 'Catalyst::Plugin::Compress::Gzip';
requires 'CatalystX::SimpleLogin';
requires 'Catalyst::Plugin::Authorization::Roles';
requires 'Catalyst::Script::Server';
requires 'Catalyst::View::TT';
requires 'Catalyst::View::XSLT';
requires 'Catalyst::View::JSON';



test_requires 'Test::More' => '0.88';

license 'eupl';

catalyst_par_options("--verbose=2 -x");
catalyst;

install_script glob(
        join (' ',
                  'script/ovpnc_fastcgi.pl',
                  'script/ovpnc_server.pl',
        )
);
auto_install;
WriteAll;
