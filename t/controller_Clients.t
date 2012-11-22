use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Ovpnc';
use Ovpnc::Controller::Clients;

ok( request('/clients')->is_success, 'Request should succeed' );
done_testing();
