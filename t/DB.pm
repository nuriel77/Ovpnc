package t::DB;
use strict;
use warnings;
use Try::Tiny;
use DBICx::TestDatabase;
use lib 'lib';
use Ovpnc ();
use Test::WWW::Mechanize::Catalyst 'Ovpnc';
use File::Touch;

my $schema;
sub make_schema { $schema ||= DBICx::TestDatabase->new( shift ) }

sub install_test_database {
    my ($app, $schema) = @_;
    Ovpnc->model( 'DB' )->schema( $schema );
}

sub import {
    my $self        = shift;
    my $appname     = 'Ovpnc';
    my $schema_name = $appname . '::Schema';
    my $schema      = make_schema( $schema_name );
    install_test_database( $appname, $schema );
    try {
        my $rs = $schema->resultset( 'User' );
    }
    catch {
        my $exception = $_;
        BAIL_OUT( 'Fixture creation failed: ' . $exception );
    };
}

1;
