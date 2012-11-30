#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Catalyst::Test 'Ovpnc';

Ovpnc->log->levels( qw/error fatal/ );

ok( request('/login')->is_success,
    'Request should succeed and be redirected to login' );

done_testing();
