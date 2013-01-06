use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Ovpnc';
use Ovpnc::Controller::Logs;

ok( request('/logs')->is_success, 'Request should succeed' );
done_testing();
