#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';
use autobox::Core;
use Test::More;

use constant  USERNAME  => 'ovpncadmin';
use constant  PASSWD    => 'ovpncadmin';
use constant  APP_NAME  => 'Ovpnc';

BEGIN {
    $ENV{CATALYST_DEBUG}            = 1;
    $ENV{OVPNC_SESSION_DIR}         ||= '/tmp/ovpnc';
    $ENV{OVPNC_NO_ROOT_USER_CHECK}  ||= ( $< == 0 ? 1 : 0 );
}

eval "use Test::WWW::Mechanize::Catalyst 'Ovpnc'";
plan $@
    ? ( skip_all => 'Test::WWW::Mechanize::Catalyst required' )
    : 'no_plan';



=head1 NAME

Test Ovpnc Live Application

=head1 DESCRIPTION

Test Ovpnc application using Test::WWW::Mechanize::Catalyst

=cut


# Define users
# ============
ok ( my $mech = Test::WWW::Mechanize::Catalyst->new,
    'Create new test user-agent' );


# Fire up
# =======
run_checks($mech);


=head2 run_checks

Run the checks

=cut


sub run_checks {
    my $mech = shift;

    $mech->{catalyst_debug} = $ENV{CATALYST_DEBUG};

    # Check redirect to login
    # =======================
    $mech->get_ok("http://localhost/", "Check redirect of base URL");

    # Login title
    # ============
    $mech->title_is(  APP_NAME ." - " ."Login", "Check for 'login' title" );

    # Use content_contains() to
    # match on test in the html body
    # ==============================
    $mech->content_contains( "Password:" );

    # Login via form
    # ==============
    $mech->submit_form_ok({
            fields => {
                username => 'ovpncadmin',
                password => 'ovpncadmin',
            }}, 'Trying to login...');

    # Check for title and content
    # to see if we are logged in
    # ===========================
    $mech->title_is( APP_NAME, "Check for 'Ovpnc' title" );
    $mech->content_contains("Ovpnc Navigation Menu");

    # From logout we should get
    # redirected to login link
    # =========================
    $mech->get_ok( 'http://localhost/logout', 'Go to logout link' );
    $mech->title_is( APP_NAME . " - " . "Login", "Check for redirection to main page when already logged in.");
    $mech->content_contains( "Password:" );

    # Test that we are really logged out
    # ==================================
    for ( qw[ certificates clients ] ){
        $mech->get_ok( 'http://localhost/'.$_, "Go to a login required page('" . $_ ."'), expect redirect to '/login'." );
        $mech->content_contains( "Password:" );
    }

    # Login user
    # via parameters
    # ==============
    $mech->get_ok(
            'http://localhost/login?username='
            . USERNAME . '&password=' . PASSWD,
        "Login 'ovpncadmin'");
    $mech->content_contains("Ovpnc Navigation Menu");

    # Check that while being logged in
    # and going to '/login' we get
    # redirected back in
    # ================================
    $mech->get_ok( 'http://localhost/login', "Test back to '/login' page, expect redirect because already logged in." );
    $mech->content_contains("Ovpnc Navigation Menu");

    # Logout once more
    # ================
    $mech->get_ok( 'http://localhost/logout', 'Go to logout link' );
    $mech->title_is( APP_NAME . " - " . "Login", "Check for redirection to main page when already logged in.");

    for ( qw[ certificates clients clients/add certificates/add server server/status ] ){
        $mech->get_ok( 'http://localhost/api/' . $_, 'Check Api link: ' . $_ );
        $mech->title_is( APP_NAME . " - " . "Login", "Check for redirection to main page when already logged in.");
    }


    # Remove temporary session directory
    # ==================================
    ok ( _remove_sessions(), 'Remove temporary sessions' );

}

=head2 _remove_sessions

Remove temporary sessions
created by this test

=cut

sub _remove_sessions{
    if ( my $sess_dir = $ENV{OVPNC_SESSION_DIR} ) {
        `rm -rf $sess_dir`;
        if ( $? >> 8 == 0 ){
            print STDERR 'Cleaning temporary session files' if grep /\-v/, @ARGV;
            return 1;
        }
        else {
            print STDERR "Failed removing temporary session files from '" . $sess_dir . "'" if grep /\-v/, @ARGV;
            return 0;
        }
    }
}
