use strict;
use warnings;
use Test::More;
use URI;

use Catalyst::Test 'Ovpnc';
use Ovpnc::Controller::Api::Certificates;

BEGIN {  $ENV{CATALYST_DEBUG} = 0; }


use constant EXPECTED => '/login';


# Display only these
# log messages
# ==================
Ovpnc->log->levels( qw/error fatal/ );

my $res = request( 'api/certificates' );
print STDOUT "Original request URI: " . '/api/certificates'
           . ". Goes to URI: " . $res->header('location') . "\n";

# Test the Redirection
# ====================
my $uri = URI->new( $res->header('location') );
is ( $uri->path , EXPECTED);
ok( request( $uri->path )->is_success, 'Request should succeed' );

done_testing();
