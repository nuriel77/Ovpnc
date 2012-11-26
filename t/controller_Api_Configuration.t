use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Ovpnc';
use Ovpnc::Controller::Api::Configuration;

ok( request('/login')->is_success, 'Request should succeed' );
done_testing();
