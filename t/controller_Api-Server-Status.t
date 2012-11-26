use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Ovpnc';
use Ovpnc::Controller::Api::Server::Status;

ok( request('/api/server/status')->is_success, 'Request should succeed' );
done_testing();
