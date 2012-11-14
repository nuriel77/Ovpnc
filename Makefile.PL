#!/usr/bin/env perl
# IMPORTANT: if you delete this file your app will not work as
# expected.  You have been warned.
use inc::Module::Install 1.02;
use Module::Install::PAR;
use Module::Install::Catalyst; # Complain loudly if you don't have
                               # Catalyst::Devel installed or haven't said
                               # 'make dist' to create a standalone tarball.

name 'Ovpnc';
all_from 'lib/Ovpnc.pm';

requires 'Catalyst::Runtime' => '5.90018';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Action::RenderView';
requires 'Catalyst::Script::Test';
requires 'Moose';
requires 'namespace::autoclean';
requires 'Config::General'; # This should reflect the config file format you've chosen
                 # See Catalyst::Plugin::ConfigLoader for supported formats


all_from 'lib/Plack.pm';
all_from 'lib/Net/Server.pm';
all_from 'HTTP/Server/PSGI.pm';

requires  'Catalyst::Engine::FastCGI';

requires 'Devel::Caller';
requires 'Stream::Buffered';
requires 'Stream::Buffered::Auto';
requires 'Stream::Buffered::File';
requires 'Stream::Buffered::PerlIO';
requires 'Starman::Server';
requires 'Plack';
requires 'Plack::TempBuffer';
requires 'Plack::Middleware::ContentLength';
requires 'Plack::Handler::Starman';
requires 'Plack::HTTPParser';
requires 'Plack::HTTPParser::PP';
requires 'Plack::Handler::Standalone';
requires 'Plack::Handler::HTTP::Server::PSGI';
requires 'HTTP::Parser::XS';
requires 'HTTP::Server::PSGI';
requires 'Net::Server';
requires 'Net::Server::SIG';
requires 'Net::Server::PreFork';
requires 'Net::Server::Fork';
requires 'Net::Server::PreForkSimple';
requires 'Plack::Handler::FCGI';
requires 'MooseX::Params::Validate';
requires 'MooseX::SemiAffordanceAccessor';
requires 'MooseX::SemiAffordanceAccessor::Role::Attribute';
requires 'MooseX::Types::Common::Numeric';
requires 'Catalyst::Restarter';
requires 'Catalyst::ScriptRunner';

requires 'Catalyst::Script::Server';

test_requires 'Test::More' => '0.88';


catalyst_par_classes('Catalyst::ScriptRunner');
catalyst_par_classes('Catalyst::Script::FastCGI');
catalyst_par_classes('Catalyst::Engine::CGI');


catalyst_par_core();   # Include modules that are also included
                       # in the standard Perl distribution,
                       # this is optional but highly suggested

catalyst_par();        # Generate a PAR as soon as the blib
                       # directory is ready

catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
