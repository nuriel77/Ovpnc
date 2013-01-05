package Ovpnc::Controller::Cron;
use strict;
use warnings;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

	sub remove_sessions : Private {
        my ( $self, $c ) = @_;      
		$c->delete_expired_sessions;
    }

__PACKAGE__->meta->make_immutable( inline_constructor => 0 );

1;