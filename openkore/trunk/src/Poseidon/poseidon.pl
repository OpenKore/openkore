#!/usr/bin/env perl
###########################################################
# Poseidon server
#
# This program is free software; you can redistribute it and/or 
# modify it under the terms of the GNU General Public License 
# as published by the Free Software Foundation; either version 2 
# of the License, or (at your option) any later version.
#
# Copyright (c) 2005-2006 OpenKore Development Team
#
# Credits:
# isieo - schematic of XKore 2 and other interesting ideas
# anonymous person - beta-testing
# kaliwanagan - original author
# illusionist - bRO support
###########################################################

use strict;
use FindBin qw($RealBin);
use lib "$RealBin/..";
use lib "$RealBin/../deps";
use Time::HiRes qw(time sleep);
use Poseidon::RagnarokServer;
use Poseidon::QueryServer;


use constant POSEIDON_SUPPORT_URL => 'http://wiki.openkore.com/index.php?title=Poseidon';

use constant RAGNAROK_SERVER_HOST => '127.0.0.1';
use constant RAGNAROK_SERVER_PORT => 6900;

use constant QUERY_SERVER_HOST => '127.0.0.1';
use constant QUERY_SERVER_PORT => 24390;

use constant SLEEP_TIME => 0.01;

our ($roServer, $queryServer);


sub initialize {
	print "Starting Poseidon...\n";
	$roServer = new Poseidon::RagnarokServer(RAGNAROK_SERVER_PORT,
		RAGNAROK_SERVER_HOST);
	$queryServer = new Poseidon::QueryServer(QUERY_SERVER_PORT,
		QUERY_SERVER_HOST, $roServer);
	print ">>> Poseidon initialized <<<\n\n";
	print "Please read " . POSEIDON_SUPPORT_URL . "\n";
	print "for further instructions.\n";
}


sub __start {
	initialize();
	while (1) {
		$roServer->iterate();
		$queryServer->iterate();
		sleep SLEEP_TIME;
	}
}

__start() unless defined $ENV{INTERPRETER};
