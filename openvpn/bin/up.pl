#!/usr/bin/perl -w
use warnings;
use strict;
use File::Slurp;
use Config::Any;
use DateTime;
use lib '../lib';
use Ovpnc::Schema;

$ENV{OVPNC_USER} ||= 'ovpncuser';

=head1 DESCRIPTION

Script to log when openvpn
server goes up.
--up option specified
in /api/server/control

=cut

my $config_file = '../ovpnc.json';
my $cfg = Config::Any->load_files({
            files => [$config_file], use_ext => 1 })
                ->[0]->{"$config_file"}->{'Model::DB'}->{'connect_info'};

=head2 comment

Get the ovpnc current logged in
user's name to log the action

=cut

my $schema = Ovpnc::Schema->connect(
    $cfg->{dsn} . ';user=' . $cfg->{user} . ';password=' . $cfg->{password}
);

my $admin = $schema->resultset('Log')->create({
    message     => "Server started" . ( $ENV{daemon_pid} ? " with pid " . $ENV{daemon_pid} : '' ),
    username    => $ENV{OVPNC_USER},
});
