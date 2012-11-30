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
use Ovpnc::Plugins::Sanity;

Ovpnc->log->levels( qw/error fatal/ );

ok( request('/login')->is_success, 'Request should succeed' );
done_testing();
