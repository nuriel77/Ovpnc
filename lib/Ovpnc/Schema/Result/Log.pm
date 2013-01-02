use utf8;
package Ovpnc::Schema::Result::Log;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Ovpnc::Schema::Result::Log

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<log>

=cut

__PACKAGE__->table("log");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 message

  data_type: 'text'
  is_nullable: 0

=head2 username

  data_type: 'varchar'
  is_nullable: 0
  size: 72

=head2 timestamp

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "message",
  { data_type => "text", is_nullable => 0 },
  "username",
  { data_type => "varchar", is_nullable => 0, size => 72 },
  "timestamp",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2013-01-02 12:37:18
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:MvIDz9324xrprAFEvQSxBA

__PACKAGE__->load_components("InflateColumn::DateTime","TimeStamp");

__PACKAGE__->add_columns(
   timestamp => { data_type => 'datetime', set_on_create => 1 }
);

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
