use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Ovpnc';
use Ovpnc::Controller::Certificates;

ok( request('/certificates')->is_success, 'Request should succeed' );
done_testing();
