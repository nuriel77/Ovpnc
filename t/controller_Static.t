use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Ovpnc';
use Ovpnc::Controller::Static;

ok( request('/static')->is_success, 'Request should succeed' );
done_testing();
