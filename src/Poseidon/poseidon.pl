#!/usr/bin/env perl
###########################################################
# Poseidon server
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# Copyright (c) 2025 OpenKore Development Team
#
# Credits:
# isieo - schematic of XKore 2 and other interesting ideas
# anonymous person - beta-testing
# kaliwanagan - original author
# illusionist - bRO support
# Fr3DBr - bRO Update (El Dicastes++)
###########################################################

#package Poseidon;

use strict;

use FindBin qw($RealBin);
use lib "$RealBin/..";
use lib "$RealBin/../..";
use lib "$RealBin/../deps";
use Time::HiRes qw(time sleep);
use Getopt::Long;

use Poseidon::Config;
use Poseidon::RagnarokServer;
use Poseidon::QueryServer;

use constant POSEIDON_SUPPORT_URL => 'https://openkore.com/wiki/Poseidon';
use constant SLEEP_TIME => 0.01;

our ($roServer, $queryServer);

sub initialize {
	# Starting Poseidon
	my $version = "3.0";
	print ">>> Starting Poseidon $version <<<\n";
	print "Loading configuration...\n";

	# Loading Configuration
	Getopt::Long::Configure('default');
	Poseidon::Config::parseArguments();
	Poseidon::Config::parse_config_file($config{file});

	print "Starting servers...\n";

	$roServer = new Poseidon::RagnarokServer($config{poseidonRoServerPort}, $config{poseidonRoServerIp});
	print "Poseidon RO server is ready   : " . $roServer->getHost() . ":" . $roServer->getPort() . "\n";

	$queryServer = new Poseidon::QueryServer($config{poseidonQueryServerPort}, $config{poseidonQueryServerIp}, $roServer);
	print "Poseidon Query server is ready: " . $queryServer->getHost() . ":" . $queryServer->getPort() . "\n";

	print ">>> Poseidon $version initialized (Debug : ". (($config{debug}) ? "On" : "Off") . ") <<<\n\n";
	print "Please read " . POSEIDON_SUPPORT_URL . " for further instructions.\n";
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
