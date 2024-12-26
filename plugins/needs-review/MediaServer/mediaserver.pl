use strict;
use Time::HiRes qw(time sleep);
use FindBin qw($RealBin);
use lib "$RealBin/..";
use lib "$RealBin/../src";
use MediaServer;

use constant MEDIA_SERVER_HOST => '127.0.0.1';
use constant MEDIA_SERVER_PORT => 12701;

use constant SLEEP_TIME => 0.05;

our $mediaServer;

sub initialize {
	print "Starting mediaServer...\n";
	$mediaServer = new mediaServer(MEDIA_SERVER_PORT, MEDIA_SERVER_HOST);
	print ">>> mediaServer initialized <<<\n";
}

sub __start {
	initialize();
	while (1) {
		$mediaServer->iterate();
		sleep SLEEP_TIME;
	}
}

__start() unless defined $ENV{INTERPRETER};
