package Ovpnc::Controller::Cron;
use strict;
use warnings;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

Ovpnc::Controller::Cron - Ovpnc Cron jobs

=head1 DESCRIPTION

Here functions will be placed
to be called from Ovpnc.pm
to run at different times
or process via manual triggers

=head1 METHODS

=cut


=head2 remove_sessions

Remove expired sessions

=cut

	sub remove_sessions : Private {
        my ( $self, $c ) = @_;      
		$c->delete_expired_sessions;
    }


=head1 AUTHOR

Nuriel Shem-Tov

=cut

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;
