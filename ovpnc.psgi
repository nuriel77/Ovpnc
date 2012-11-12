use strict;
use warnings;

use Ovpnc;

my $app = Ovpnc->apply_default_middlewares(Ovpnc->psgi_app);
$app;

