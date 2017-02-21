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
use lib "$RealBin/../..";
use lib "$RealBin/../deps";
use Time::HiRes qw(time sleep);
use Poseidon::Config;
use Poseidon::RagnaServerHolder;
use Poseidon::QueryServer;
use Poseidon::ConnectServer;

use constant POSEIDON_SUPPORT_URL => 'http://wiki.openkore.com/index.php?title=Poseidon';
use constant SLEEP_TIME => 0.01;


our ($roServer, $queryServer, $connectServer);
my $time = 0;
my $timeout = 1;

sub initialize {
	# Loading Configuration
	Poseidon::Config::parse_config_file ("poseidon.txt", \%config);
	
	my $number_of_clients = $config{number_of_clients};
	
	my $ragna_ip = $config{ragnarokserver_ip};
	my $first_ragna_port = $config{ragnarokserver_first_port};
	$roServer = Poseidon::RagnaServerHolder->new($number_of_clients, $ragna_ip, $first_ragna_port);
	print "Ragnarok Online Server Ready\n";
	
	my $query_ip = $config{queryserver_ip};
	my $query_port = $config{queryserver_port};
	$queryServer = Poseidon::QueryServer->new($query_port, $query_ip, $roServer);
	print "Query Server Ready At : " . $queryServer->getHost() . ":" . $queryServer->getPort() . "\n";
	
	my $connect_port = $config{connectserver_port};
	my $connect_ip = $config{connectserver_ip};
	$connectServer = new Poseidon::ConnectServer($connect_port, $connect_ip, $roServer, $queryServer);
	print "Connect Server Ready At : " . $connectServer->getHost() . ":" . $connectServer->getPort() . "\n";
	
	print ">>> Poseidon 2.1 initialized <<<\n\n";
	print "Please read " . POSEIDON_SUPPORT_URL . "\n";
	print "for further instructions.\n";
}

sub __start {
	initialize();
	while (1) {
		$connectServer->iterate;
		$roServer->iterate;
		$queryServer->iterate;
		sleep SLEEP_TIME;
	}
}

__start() unless defined $ENV{INTERPRETER};
