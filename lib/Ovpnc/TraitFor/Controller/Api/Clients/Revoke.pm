package Ovpnc::TraitFor::Controller::Api::Clients::Revoke;
use warnings;
use strict;
use Moose::Role;
use namespace::autoclean;
use vars qw( $vpn_dir $tools );

has vpn_dir => (
	is => 'ro',
	isa => 'Str',
	required => 1,
);

has utils_dir => (
	is => 'ro',
	isa => 'Str',
	required => 1,
);

sub revoke_certificate {
    my ( $self, $client ) = @_;

    my $_ret_val;
	$vpn_dir = $self->vpn_dir;
	$tools = $self->utils_dir;

    # vars script location
    my $vars = $tools . '/vars';

    # build command
    my $command = $tools . '/revoke-full';

    # Check if can run
    if ( -e $tools . '/vars' and -e $command and -x $command ) {
	    # Run command
	    $_ret_val =
	    	`cd $tools && . $vars > /dev/null && $command $client 2>&1`;

	    # Check exit status
	    if ( $? >> 8 != 0 or $_ret_val =~ /Error opening/g ) {
	        return { error => 'Revocation failure for \'' . $client . '\': ' . $_ret_val };
	    }

		if ( $_ret_val =~ /ERROR:Already revoked/g ) {
	        return { error => 'Revocation failure for \'' . $client
	          . '\': Already revoked' };
		}

	    if ( $_ret_val =~ /error 23.*certificate revoked\n/g ) {
	        $_ret_val = 'Ok';
	    }
    } else {
        die "Error revoking client " . $client;
    }

    return $_ret_val;
}

1;
