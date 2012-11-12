package Ovpnc::View::HTML;
use Moose;
use namespace::autoclean;

extends 'Catalyst::View::TT';

__PACKAGE__->config(
     TEMPLATE_EXTENSION => '.tt2',
	 INCLUDE_PATH => [
                Ovpnc->path_to( 'root', 'src' ),
            ],
     # Set to 1 for detailed timer stats in your HTML as comments
     TIMER              => 1,
     # This is your wrapper template located in the 'root/src'
     WRAPPER => 'wrapper.tt2',
	 ENCODING     => 'utf-8',
     render_die => 1,
);

=head1 NAME

Ovpnc::View::HTML - TT View for Ovpnc

=head1 DESCRIPTION

TT View for Ovpnc.

=head1 SEE ALSO

L<Ovpnc>

=head1 AUTHOR

Nuriel Shem-Tov

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
