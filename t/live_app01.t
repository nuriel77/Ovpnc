#!/usr/bin/env perl
use strict;
use warnings;
use XML::LibXML;
use lib 'lib';
use autobox::Core;
use Test::More;
use HTTP::Request;

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
ok (
        my $mech = Test::WWW::Mechanize::Catalyst->new( cookie_jar => {} ),
        'Create new test user-agent'
);


# Fire up
# =======
run_checks($mech);


=head2 run_checks

Run the checks

=cut


sub run_checks {
    my $mech = shift;

    $mech->{catalyst_debug} = $ENV{CATALYST_DEBUG};

    # Get the sitemap links
    # =====================
    $mech->get_ok('http://localhost/sitemap', 'Get sitemap links');

    my $sitemap = _parse_xml( $mech->content );

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
    $mech->get_ok( 'http://localhost/logout', "And logout again" );

    # Check restrictions
    # while logged out
    # ==================
    for my $link ( @{$sitemap} ){
        my $status = 200;

        if ( $link->{url} =~ /\/api$/
         and $link->{method} ne 'POST'
        ){
            $status = 200;
        }
        elsif ( $link->{url} =~ /\/api/ ){
            $status = 403;
        }

        if ( $link->{url} =~ /certificates\/download/ ){
            $link->{url} .= '/ovpncadmin/all';
        }

        _check_methods(
            $link->{url},
            $link->{method},
            $status
        );
    }

    # Login to run another
    # check as above
    # ====================
    $mech->get_ok(
            'http://localhost/login?username='
            . USERNAME . '&password=' . PASSWD,
        "Login 'ovpncadmin'");
    $mech->get_ok('http://localhost/', 'Getting main page');
    $mech->content_contains("Ovpnc Navigation Menu");
    
    for my $link ( @{$sitemap} ){
        my $status = 200;

        if ( $link->{url} =~ /\/api/
         and $link->{method} ne 'GET'
        ){
            $status = 400;
        }

        if ( $link->{url} =~ /\/api\/configuration/
         and $link->{method} eq 'UPDATE'
        ){
            $status = 200;
        }

        if ( $link->{url} =~ /api\/server$/
         and $link->{method} eq 'GET'
        ){
            $status = 404;
        }

        _check_methods(
            $link->{url},
            $link->{method},
            $status
        );
    }


    # Remove temporary session directory
    # ==================================
    ok ( _remove_sessions(), 'Remove temporary sessions' );

}


=head2 _check_methods

Check various method requests
to a specific link

=cut

sub _check_methods{
    my ( $link, $method, $status ) = @_;
    my $request = HTTP::Request->new( $method => $link );
    $mech->request( $request );
    ok ( $mech->status == $status, 'Check method ' . $method  .' at: '. $link . ', expected status: ' . $status );
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


=head2 _parse_xml

Prase the sitemap links

=cut

sub _parse_xml {

    my $dom = XML::LibXML->load_xml( string => shift );
    my @links = $dom->getElementsByTagName('loc');
    return [ map {
        my $str = $_->string_value();
        my ($method) = $str =~ /_([A-Z]*)$/;
        $str =~ s/_[A-Z]*$//;
        $method ||= 'GET';
        {
            url     => $str,
            method  => $method
        }
    } @links ];
 
}

