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
requires 'Moose::Exporter';
requires 'MooseX::Traits';
requires 'MooseX::NonMoose';
requires 'MooseX::MarkAsMethods';
requires 'MooseX::Types::IPv4';
requires 'Scalar::Util';
requires 'Proc::ProcessTable'; 
requires 'Proc::Simple';
requires 'Set::Object';
requires 'Object::Signature';
requires 'Digest::MD5';
requires 'Digest::MD5::File';
requires 'Net::SSLeay';
requires 'Crypt::CBC';
requires 'Crypt::OpenSSL::CA';
requires 'Crypt::OpenSSL::RSA';
requires 'Crypt::OpenSSL::Bignum';
requires 'Crypt::OpenSSL::Random';
requires 'Socket';
requires 'IPC::Run';
requires 'IPC::Cmd';
requires 'Gepok';
requires 'Plack::Handler::Gepok';
requires 'namespace::autoclean';
requires 'Config::General';
requires 'Config::Any';
requires 'XML::LibXML';
requires 'XML::LibXSLT';
requires 'XML::Validator::Schema';
requires 'XML::Simple';
requires 'XML::SAX::ParserFactory';
requires 'HTML::Tree';
requires 'HTML::FormFu';
requires 'HTML::FormFu::Model::DBIC';
requires 'JSON::XS';
requires 'Expect';
requires 'String::MkPasswd';
requires 'Locale::Messages';
requires 'File::Slurp';
requires 'File::Copy';
requires 'File::Touch';
requires 'File::Signature';
requires 'Readonly';
requires 'Cache::File';
requires 'Crypt::Rijndael';
requires 'Linux::Distribution';
requires 'Net::Telnet';
requires 'Net::OpenVPN::Manage';
requires 'DBIx::Class';
requires 'DBIx::Class::TimeStamp';
requires 'DBIx::Class::EncodedColumn';
requires 'DBIx::Class::PassphraseColumn';
requires 'Crypt::Eksblowfish::Bcrypt';
requires 'DBIx::Class::EncodedColumn::Crypt::Eksblowfish::Bcrypt';
requires 'Authen::Passphrase::BlowfishCrypt';
requires 'Catalyst::Runtime' => '5.90014';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Plugin::StackTrace';
requires 'Catalyst::Plugin::Cache';
requires 'Catalyst::Plugin::Assets';
requires 'Catalyst::Plugin::Redirect';
requires 'Catalyst::Controller::REST';
requires 'Catalyst::ActionRole::ACL';
requires 'Catalyst::Controller::ActionRole';
requires 'Catalyst::Action::RenderView';
requires 'Catalyst::View::XML::Simple';
requires 'Catalyst::Plugin::Session::State::Cookie';
requires 'Catalyst::Plugin::Session';
requires 'Catalyst::Plugin::Session::Store::File';
requires 'Catalyst::Plugin::Session::Store::DBIC';
requires 'Catalyst::Plugin::Session::Store::Delegate';
requires 'Catalyst::Plugin::Session::Store::FastMmap';
requires 'Catalyst::Authentication::Store::Htpasswd';
requires 'Catalyst::Authentication::Store::Minimal';
requires 'Catalyst::Authentication::Store::DBIx::Class';
requires 'Catalyst::TraitFor::Model::DBIC::Schema::RequestConnectionPool';
requires 'Catalyst::Model::DBIx::Connector';
requires 'Catalyst::Plugin::SecureCookies';
requires 'Catalyst::Controller::HTML::FormFu';
requires 'Catalyst::Plugin::Compress::Deflate';
requires 'Catalyst::Plugin::Compress::Gzip';
requires 'CatalystX::SimpleLogin';
requires 'Catalyst::Plugin::Sitemap';
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
                  'ovpnc_https.sh',
        )
);
auto_install;
WriteAll;
