#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';

BEGIN { $ENV{CATALYST_DEBUG} = 1 }

use DateTime;
use Ovpnc::Schema;

my $schema = Ovpnc::Schema->connect('dbi:mysql:ovpnc;host=localhost;user=ovpnc;password=ovpncadmin');
my $admin = $schema->resultset('User')->create({
	username 	=> 'laptop',
	enabled  	=> 1,
	password	=> 'test1234',
	fullname	=> 'laptop-home',
	email		=> 'laptop@some.nl',
	phone		=> '232323',
	address		=> 'somestreet',
	revoked		=> 0
});
$admin->create_related('user_roles', { user_id => $admin->id, role_id => 1 });
