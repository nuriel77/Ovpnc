#!/usr/bin/env perl
use strict;
use warnings;
use Cwd;
use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/inc";
use Test::Harness;

BEGIN {
    $ENV{CATALYST_DEBUG} ||= 0;
    $Test::Harness::verbose = 1
        if $ENV{TEST_DEBUG};
}


my $usage_msg = "USAGE: $0 [ all | t/my_test01.t t/my_test02.t ]\n";


=head1 NAME

test_ovpnc - Test OpenVPN Controller

=head1 DESCRIPTION

Runs all test or only requested test

=cut

if ( -d 't/' ){
    chdir ('t/');
}
else {
    die "Need to chdir to 't/' directory but failed.\n"
           . "Try to run from the root of the application";
}

die "File not found\n". $usage_msg
    unless -f '../' . $ARGV[0];
die "USAGE: $0 [ all | t/my_test01.t t/my_test02.t ]\n"
    unless ( @ARGV and ( $ARGV[0] eq 'all' || -f '../' . $ARGV[0] ) );

my @new_argv = map { $_ =~ s/t\///; $_ } @ARGV;

my @tests;
if ($new_argv[0] eq 'all') {
    @tests = glob('*.t');
} else {
    for my $test ( @new_argv ) {
        push @tests, $test
            if -f $test;
    }
}

die "No tests found\n" unless @tests;

runtests(@tests);

unlink 'tmp' if ( -d 'tmp' );

__END__
