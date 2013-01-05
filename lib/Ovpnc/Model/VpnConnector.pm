package Ovpnc::Model::VpnConnector;
use warnings;
use strict;
use File::Slurp;
use Net::OpenVPN::Manage;
use namespace::autoclean;


=head1 NAME

Ovpnc::Model::VpnConnector - Ovpnc VPN Management Connector

=head1 DESCRIPTION

Connector to OpenVPN management port

=head1 METHODS

new

=head2 new

Create connection and return handle

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

=head1 AUTHOR

Nuriel Shem-Tov

=cut

1;
