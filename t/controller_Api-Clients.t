use strict;
use warnings;
use URI;
use Test::More;

BEGIN {  $ENV{CATALYST_DEBUG} = 0; }

use Catalyst::Test 'Ovpnc';
use Ovpnc::Controller::Api::Clients;

# Set the request uri
# and the expected uri
# ====================
use constant TESTURI  => '/api/clients';
use constant EXPECTED => '/login';


# Display only these
# log messages
# ==================
Ovpnc->log->levels( qw/error fatal/ );

my $res = request( TESTURI );
print STDOUT "Original request URI: " . TESTURI
           . ". Goes to URI: " . $res->header('location') . "\n";

# Test the Redirection
# ====================
my $uri = URI->new( $res->header('location') );
is ( $uri->path , EXPECTED);
ok( request( $uri->path )->is_success, 'Request should succeed' );

done_testing();

