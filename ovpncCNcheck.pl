#!/usr/bin/perl
use strict;
use warnings;

#exit 0;

die "Usage: $0 [CN text file] [depth] [CN string]\n"
	unless (@ARGV == 3);

verify_syntax($_)
	for (@ARGV);

{

	my ($to_check) = $ARGV[2] =~ /(CN=.*\/name=.*)\//;

	open (my $cn_file, "<", $ARGV[0])
		or die "Cannot read $ARGV[0]: $!\n";	

	while ( my $line = <$cn_file> ){
		print STDERR "Checking orig line: ". $line . " against: " . $to_check . "\n";
		if ($line =~ $to_check){
			print STDERR "Found match: " . $line . " and " . $to_check . "\n";
			if ($line =~ /^R.*/){
				print STDERR "Certificate is revoked, denying\n";
				exit 1;
			}
			close $cn_file;
			exit 0;
		}
	}
}

sub verify_syntax
{
	shift =~ m/^([a-zA-Z0-9\/\._=@\-]+)$/
		or die "Bad data in argument\n";
}
