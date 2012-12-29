#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

plan skip_all => 'set TEST_POD to enable this test' unless $ENV{TEST_POD};
eval "use Test::Pod 1.14";
plan skip_all => 'Test::Pod 1.14 required' if $@;

my @pod_dirs = qw( ../lib );
all_pod_files_ok( all_pod_files(@pod_dirs) );
