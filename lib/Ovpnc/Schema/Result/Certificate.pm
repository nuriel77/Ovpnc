use utf8;
package Ovpnc::Schema::Result::Certificate;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Ovpnc::Schema::Result::Certificate

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

=head1 TABLE: C<certificates>

=cut

__PACKAGE__->table("certificates");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  is_nullable: 0

=head2 common_name

  data_type: 'varchar'
  is_nullable: 0
  size: 42

=head2 revoked

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 created

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 expires

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 type

  data_type: 'varchar'
  is_nullable: 0
  size: 12

=head2 attributes

  data_type: 'text'
  is_nullable: 0

=head2 key_size

  data_type: 'smallint'
  is_nullable: 0

=head2 password

  data_type: 'char'
  is_nullable: 0
  size: 59

=head2 modified

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "user_id",
  { data_type => "integer", is_nullable => 0 },
  "common_name",
  { data_type => "varchar", is_nullable => 0, size => 42 },
  "revoked",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
  "created",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
  "expires",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
  "type",
  { data_type => "varchar", is_nullable => 0, size => 12 },
  "attributes",
  { data_type => "text", is_nullable => 0 },
  "key_size",
  { data_type => "smallint", is_nullable => 0 },
  "password",
  { data_type => "char", is_nullable => 0, size => 59 },
  "modified",
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

=head1 UNIQUE CONSTRAINTS

=head2 C<name>

=over 4

=item * L</common_name>

=back

=cut

__PACKAGE__->add_unique_constraint("name", ["common_name"]);


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2012-12-21 00:27:03
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:3VRdBAX2t1tsYcaH0YIDJA

__PACKAGE__->load_components("InflateColumn::DateTime","EncodedColumn","TimeStamp");

__PACKAGE__->add_columns(
    '+password' => {
      data_type => 'CHAR',
      size      => 59,
      encode_column => 1,
      encode_class  => 'Crypt::Eksblowfish::Bcrypt',
      encode_args   => { key_nul => 0, cost => 14, salt_random => 20 },
      encode_check_method => 'check_password',
    }
);

__PACKAGE__->add_columns(
   modified => { data_type => 'datetime', set_on_create => 1 },
   created => { data_type => 'datetime', set_on_create => 1 },
   expires => { data_type => 'datetime' },
);

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
