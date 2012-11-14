#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use POSIX;

use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Ovpnc';
use Ovpnc::Controller::Api;
use Ovpnc::Controller::Sanity;

ok( request('/')->is_success, 'Request should succeed' );
done_testing();
