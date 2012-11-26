use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Ovpnc';
use Ovpnc::Controller::Api::Server::Verb;

ok( request('/api/server/verbosity')->is_success, 'Request should succeed' );
done_testing();
