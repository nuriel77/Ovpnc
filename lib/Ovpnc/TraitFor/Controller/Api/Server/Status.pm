package Ovpnc::TraitFor::Controller::Api::Server::Status;
use warnings;
use strict;
use Moose::Role;
use namespace::autoclean;

has vpn => (
    is        => 'ro',
    isa       => 'Object',
    required  => 1,
    predicate => '_has_vpn',
    clearer   => '_disconnect_vpn',
);

has regex => (
    is       => 'ro',
    isa      => 'HashRef',
    required => 1,
);

=head2

Gets the status

=cut

sub get_status {
    my $self = shift;

    return { error => 'No connection to management port' }
      unless $self->_has_vpn;

    # Get the current status table in version 2 format from the process.
    my $_status = $self->vpn->status(2);

    # If method returned false, return error message.
    return { error => $self->vpn->{error_msg} }
      unless ($_status);

    # Start assigning data for stashing
    my $data = { clients => [] };
    $data->{title}  = $self->vpn->version();
    $data->{status} = "Server online";

    my $regex = $self->regex->{client_list};

    # Parse the status output
    for (@$_status) {
        chomp;
        if (/$regex/) {
            push(
                @{ $data->{clients} },
                {
                    name       => $1 || 'anon',
                    virtual_ip => $3 || 'unassigned',
                    remote_port => ( ( split ':', $2 )[-1] ) || 'unknown',
                    remote_ip   => ( ( split ':', $2 )[0] )  || 'unknown',
                    bytes_recv => $4 || 0,
                    bytes_sent => $5 || 0,
                    conn_since => $6 || '',
                    epoc_since => $7 || ''
                }
            );
        }
    }

    return $data;
}

1;
