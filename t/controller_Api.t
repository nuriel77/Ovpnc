use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Ovpnc';
use Ovpnc::Controller::Api;

ok( request('/api')->is_success, 'Request should succeed' );
done_testing();
