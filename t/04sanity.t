#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use POSIX;

my ($sysname, $nodename, $release, $version, $machine) = POSIX::uname();

#plan skip_all => '';

done_testing();
