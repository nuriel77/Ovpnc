package Ovpnc::Schema::ResultSet::User;
use strict;
use warnings;
use base 'DBIx::Class::ResultSet';


=head1 NAME

Ovpnc::Schema::ResultSet::User

=head2 created_after

A predefined search for recently added clients

=cut

    sub created_after {
        my ($self, $datetime) = @_;

        my $date_str = $self->result_source->schema->storage
                              ->datetime_parser->format_datetime($datetime);

        return $self->search({
             created => { '>' => $date_str }
        });

    }


=head1 AUTHOR

Nuriel Shem-Tov

=cut

1;
