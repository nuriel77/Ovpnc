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
  is_foreign_key: 1
  is_nullable: 0

=head2 user

  data_type: 'varchar'
  is_nullable: 0
  size: 72

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 72

=head2 created_by

  data_type: 'varchar'
  is_nullable: 0
  size: 72

=head2 key_cn

  data_type: 'varchar'
  is_nullable: 0
  size: 42

=head2 key_org

  data_type: 'text'
  is_nullable: 0

=head2 key_ou

  data_type: 'text'
  is_nullable: 0

=head2 key_country

  data_type: 'varchar'
  is_nullable: 0
  size: 2

=head2 key_province

  data_type: 'varchar'
  is_nullable: 0
  size: 128

=head2 key_city

  data_type: 'varchar'
  is_nullable: 0
  size: 128

=head2 key_size

  data_type: 'smallint'
  is_nullable: 0

=head2 key_expire

  data_type: 'integer'
  is_nullable: 0

=head2 key_email

  data_type: 'varchar'
  is_nullable: 0
  size: 40

=head2 key_serial

  data_type: 'char'
  is_nullable: 0
  size: 2

=head2 revoked

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 cert_type

  data_type: 'varchar'
  is_nullable: 0
  size: 12

=head2 cert_file

  data_type: 'text'
  is_nullable: 0

=head2 key_file

  data_type: 'text'
  is_nullable: 0

=head2 cert_digest

  data_type: 'varchar'
  is_nullable: 0
  size: 40

=head2 key_digest

  data_type: 'varchar'
  is_nullable: 0
  size: 40

=head2 created

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 0

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
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "user",
  { data_type => "varchar", is_nullable => 0, size => 72 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 72 },
  "created_by",
  { data_type => "varchar", is_nullable => 0, size => 72 },
  "key_cn",
  { data_type => "varchar", is_nullable => 0, size => 42 },
  "key_org",
  { data_type => "text", is_nullable => 0 },
  "key_ou",
  { data_type => "text", is_nullable => 0 },
  "key_country",
  { data_type => "varchar", is_nullable => 0, size => 2 },
  "key_province",
  { data_type => "varchar", is_nullable => 0, size => 128 },
  "key_city",
  { data_type => "varchar", is_nullable => 0, size => 128 },
  "key_size",
  { data_type => "smallint", is_nullable => 0 },
  "key_expire",
  { data_type => "integer", is_nullable => 0 },
  "key_email",
  { data_type => "varchar", is_nullable => 0, size => 40 },
  "key_serial",
  { data_type => "char", is_nullable => 0, size => 2 },
  "revoked",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
  "cert_type",
  { data_type => "varchar", is_nullable => 0, size => 12 },
  "cert_file",
  { data_type => "text", is_nullable => 0 },
  "key_file",
  { data_type => "text", is_nullable => 0 },
  "cert_digest",
  { data_type => "varchar", is_nullable => 0, size => 40 },
  "key_digest",
  { data_type => "varchar", is_nullable => 0, size => 40 },
  "created",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 0 },
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

=head1 RELATIONS

=head2 user

Type: belongs_to

Related object: L<Ovpnc::Schema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "Ovpnc::Schema::Result::User",
  { id => "user_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07022 @ 2012-12-29 01:41:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:NMufGYH2JaXOhcPnMCyL3g

__PACKAGE__->load_components("InflateColumn::DateTime","EncodedColumn","TimeStamp");

__PACKAGE__->add_columns(
   modified => { data_type => 'datetime',   set_on_create => 1 },
   created  => { data_type => 'date',       set_on_create => 1 },
);

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
