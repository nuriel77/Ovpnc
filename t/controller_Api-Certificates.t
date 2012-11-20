use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Ovpnc';
use Ovpnc::Controller::Api::Certificates;

ok( request('/api/certificates')->is_success, 'Request should succeed' );
done_testing();
