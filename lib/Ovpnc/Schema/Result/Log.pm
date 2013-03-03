package Ovpnc::Schema::Result::Log;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 NAME

Ovpnc::Schema::Result::Log

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
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
  },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07000 @ 2013-03-03 21:43:06
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jhkSrXmRcu4+woH9TQeIHg

__PACKAGE__->load_components("InflateColumn::DateTime","TimeStamp");

__PACKAGE__->add_columns(
   modified => { data_type => 'datetime',   set_on_create => 1 },
   created  => { data_type => 'date',       set_on_create => 1 },
);

# You can replace this text with custom content, and it will be preserved on regeneration
1;
