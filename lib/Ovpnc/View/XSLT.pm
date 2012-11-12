package Ovpnc::View::XSLT;

use strict;
use base 'Catalyst::View::XSLT';

# example configuration

__PACKAGE__->config(
#    # relative paths to the directories with templates
    INCLUDE_PATH => [
      Ovpnc->path_to( 'root', 'xslt' ),
    ],
    TEMPLATE_EXTENSION => '.xsl', # default extension when getting template name from the current action
	FORCE_TRANSFORM => 1,
    DUMP_CONFIG => 0, # use for Debug. Will dump the final (merged) configuration for XSLT view
    LibXSLT => { # XML::LibXSLT specific parameters
      register_function => [
        {
          uri    => 'urn:ovpnc',
          name   => 'Param',
          subref => sub { return $_[0] },
        },
      ],
    },
);

=head1 NAME

Ovpnc::View::XSLT - XSLT View Component

=head1 SYNOPSIS

L<Ovpnc>

=head1 DESCRIPTION

Catalyst XSLT View.

=head1 AUTHOR

root

=head1 LICENSE

This library is free software . You can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
