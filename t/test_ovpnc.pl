#!/usr/bin/env perl
use strict;
use warnings;
use Cwd;
use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/inc";
use Test::Harness;

BEGIN {
    $ENV{CATALYST_DEBUG} = 0;
    $Test::Harness::verbose = 1
        if $ENV{TEST_DEBUG};
}

=head1 NAME

test_ovpnc - Test OpenVPN Controller

=head1 DESCRIPTION

Runs all test or only requested test

=cut

die "USAGE: $0 all|my_test01.t my_test02.t\n"
    unless ( @ARGV && ( $ARGV[0] eq 'all' || -f $ARGV[0] ) );

if ( getcwd =~ /\/t$/ ){
    chdir ('../')
        or die "Need to chdir to root directory but failed."
                . "Try to run from the root of the application";
}

my @tests;
if ($ARGV[0] eq 'all') {
    @tests = glob('t/*.t');
} else {
    for my $test ( @ARGV ) {
        push @tests, $test
            if -f $test;
    }
}

die "No tests found\n" unless @tests;

runtests(@tests);

__END__
