package Ovpnc::Plugins::Connector;
use warnings;
use strict;
use File::Slurp;
use Net::OpenVPN::Manage;

=head1 NAME

Ovpnc::Plugins::Connector - Ovpnc VPN Management Connector

=head1 DESCRIPTION

Connector to OpenVPN management port

=cut

sub new {
    my ( $self, $params ) = @_;
    my $vpn = Net::OpenVPN::Manage->new(
        {
            host     => $params->{host},
            port     => $params->{port},
            password => read_file( $params->{password}, chomp => 1 ) || '',
            timeout  => $params->{timeout},
        }
    ) or die "cannot establish connection: $!";

    return $vpn;
}

1;
