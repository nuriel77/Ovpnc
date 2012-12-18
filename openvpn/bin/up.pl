#!/usr/bin/perl -w
use warnings;
use strict;
use File::Slurp;
use lib '../lib';

BEGIN { $ENV{CATALYST_DEBUG} = 1 }


use DateTime;
use Ovpnc::Schema;

my $mysql_passwd = read_file ('../config/.mysql', chomp=>1)
    or die "Cannot read mysql password file: $!";

my $schema = Ovpnc::Schema->connect('dbi:mysql:ovpnc;host=localhost;user=ovpnc;password=' . $mysql_passwd);
my $admin = $schema->resultset('Log')->create({
    message => "Server started",
    user_id => 1,
});


