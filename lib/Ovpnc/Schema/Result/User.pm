use utf8;
package Ovpnc::Schema::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Ovpnc::Schema::Result::User - Ovpnc Users for OpenVPN

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

=head1 TABLE: C<users>

=cut

__PACKAGE__->table("users");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 enabled

  data_type: 'tinyint'
  is_nullable: 0

=head2 username

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=head2 password

  data_type: 'varbinary'
  is_nullable: 0
  size: 60

=head2 password_expires

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 fullname

  data_type: 'varchar'
  is_nullable: 0
  size: 72

=head2 email

  data_type: 'varchar'
  is_nullable: 0
  size: 72

=head2 phone

  data_type: 'varchar'
  is_nullable: 0
  size: 16

=head2 address

  data_type: 'mediumtext'
  is_nullable: 0

=head2 revoked

  data_type: 'tinyint'
  is_nullable: 0

=head2 created

  data_type: 'datetime'
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
  "enabled",
  { data_type => "tinyint", is_nullable => 0 },
  "username",
  { data_type => "varchar", is_nullable => 0, size => 64 },
  "password",
  { data_type => "varbinary", is_nullable => 0, size => 60 },
  "password_expires",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
  "fullname",
  { data_type => "varchar", is_nullable => 0, size => 72 },
  "email",
  { data_type => "varchar", is_nullable => 0, size => 72 },
  "phone",
  { data_type => "varchar", is_nullable => 0, size => 16 },
  "address",
  { data_type => "mediumtext", is_nullable => 0 },
  "revoked",
  { data_type => "tinyint", is_nullable => 0 },
  "created",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
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

=head2 C<email>

=over 4

=item * L</email>

=back

=cut

__PACKAGE__->add_unique_constraint("email", ["email"]);

=head2 C<username>

=over 4

=item * L</username>

=back

=cut

__PACKAGE__->add_unique_constraint("username", ["username"]);

=head1 RELATIONS

=head2 user_roles

Type: has_many

Related object: L<Ovpnc::Schema::Result::UserRole>

=cut

__PACKAGE__->has_many(
  "user_roles",
  "Ovpnc::Schema::Result::UserRole",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 roles

Type: many_to_many

Composing rels: L</user_roles> -> role

=cut

__PACKAGE__->many_to_many("roles", "user_roles", "role");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2012-11-29 01:48:15
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZLY0dALhNSX4BR/lf6Nkww

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
   modified => { data_type => 'datetime', set_on_create => 1 }
);

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
