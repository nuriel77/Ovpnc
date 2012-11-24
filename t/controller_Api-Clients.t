use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Ovpnc';
use Ovpnc::Controller::Api::Client;

ok( request('/api/client')->is_success, 'Request should succeed' );
done_testing();
