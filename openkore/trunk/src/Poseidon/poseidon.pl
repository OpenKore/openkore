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
# Fr3DBr - bRO Update (El Dicastes++)
###########################################################

#package Poseidon;

use strict;
use FindBin qw($RealBin);
use lib "$RealBin/..";
use lib "$RealBin/../deps";
use Time::HiRes qw(time sleep);
use Poseidon::Config;
use Poseidon::RagnarokServer;
use Poseidon::QueryServer;

use constant POSEIDON_SUPPORT_URL => 'http://wiki.openkore.com/index.php?title=Poseidon';
use constant SLEEP_TIME => 0.01;

our ($roServer, $queryServer);

sub initialize 
{
	# Loading Configuration
	Poseidon::Config::parse_config_file ("poseidon.txt", \%config);

	# Starting Poseidon
	print "Starting Poseidon 2.1 (26 Sep 2012)...\n";
	$roServer = new Poseidon::RagnarokServer($config{ragnarokserver_port}, $config{ragnarokserver_ip});
	print "Ragnarok Online Server Ready At : " . $config{ragnarokserver_ip} . ":" . $config{ragnarokserver_port} . "\n";
	$queryServer = new Poseidon::QueryServer($config{queryserver_port}, $config{queryserver_ip}, $roServer);
	print "Query Server Ready At : " . $config{queryserver_ip} . ":" . $config{queryserver_port} . "\n";
	print ">>> Poseidon 2.1 initialized <<<\n\n";
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
