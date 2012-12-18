#!/usr/bin/perl -w
use warnings;
use strict;
use File::Slurp;
use lib '../lib';

BEGIN { $ENV{CATALYST_DEBUG} = 1 }

use DateTime;
use Ovpnc::Schema;

my $mysql_passwd = read_file ($ENV{MYSQL_PASSWD_FILE}, chomp => 1)
    or die "Cannot read mysql password file: $!";

my $schema = Ovpnc::Schema->connect('dbi:mysql:ovpnc;host=localhost;user=ovpnc;password=' . $mysql_passwd);
my $user_id = $schema->resultset('User')->find(
    { username => $ENV{OVPNC_USER} },
    { search => 'id' }
);
my $admin = $schema->resultset('Log')->create({
    message => "Server started" . ( $ENV{daemon_pid} ? " with pid " . $ENV{daemon_pid} : '' ),
    user_id => $user_id->id,
});


open (my $F, '>>/home/ovpnc/Ovpnc/openvpn/tmp/up.txt') or die "Cannot open up.txt: $!";
print {$F} join "\n", map { $_ . " -> " . $ENV{$_} if $ENV{$_} } sort keys %{ENV};
close $F;
