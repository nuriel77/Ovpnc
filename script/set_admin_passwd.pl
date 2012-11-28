#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';

use constant USERNAME => 'ovpncadmin';
use constant NEWPASS  => 'ovpncadmin';
 
BEGIN { $ENV{CATALYST_DEBUG} = 1 }
 
use DateTime;
use Ovpnc::Schema;
    
my $schema = Ovpnc::Schema->connect('dbi:mysql:ovpnc;host=localhost;user=ovpnc;password=ovpncadmin');
die "No DB connection\n" unless $schema;

my $admin = $schema->resultset('User')->search(
	{
		'username' => USERNAME
	}
)->single;

if ($admin != 0){
	$admin->password( NEWPASS );
	$admin->update;
	print "Password for " . USERNAME . " updated successfully\n";
}

