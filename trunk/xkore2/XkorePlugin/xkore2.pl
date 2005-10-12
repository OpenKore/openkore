#!/usr/bin/env perl
###########################################################
#
# X-Kore 2
# This software is open source, licensed under the
# GNU General Public License, version 2.
# Copyright by isieo (isieox *a@t* gmail *DO.t* com), 2005
# Thanks to:
# VCL - for telling me about Base::Server ..
# kaliwanagan - Fakeserver.pl which helped alot here...
#
# PROTOTYPE VERSION 2.0! Rewrite of Prototype 1 using base::server
#
package xkore2;

use strict;
use Time::HiRes qw(time usleep);
use FindBin qw($RealBin);
use lib "$RealBin/src";
use lib "$RealBin/../.../openkore/src";
use lib "$RealBin/../.../src";
use Interface::Console;
use bytes;

use XKore::Variables qw(%rpackets $tempRecordQueue $xConnectionStatus $svrObjIndex $tempIp $tempPort $programEnder $localServ $port
	$ghostIndex $clientFeed $socketOut $serverNumber $serverIp $serverPort $record $ghostPort
	$recordSocket $recordSock $recordPacket);	
use Thread::Queue;
use Globals;
use Modules;
use Settings;
use Misc;
use Utils;
use Network;
use Globals;
use Log qw(message warning error debug);
use Plugins;

my $hooks = Plugins::addHooks(
       ['parseMsg/pre', \&RecvPackets],
       ['RO_sendMsg_pre', \&RecvPackets]
);
#########################
#Files
#########################
import Settings qw(addConfigFile);
my $loadID = addConfigFile("$Settings::tables_folder/recvpackets.txt", \%rpackets, \&parseDataFile2);
Settings::load($loadID);

######################
#The Recorder...
######################
	$record;
	$ghostPort = 6901;
	$recordSocket = new XKore::GhostServer($ghostPort);
	$recordSock;
	$recordPacket = new Thread::Queue;
	$tempRecordQueue = new Thread::Queue;
	$clientFeed = 0;
	$ghostIndex;


	$programEnder = 0; # this is to end the loop main loop
	$xConnectionStatus = 0 ; #used for
#########################
#Connection stuffs..
#########################
use XKore::Functions;
use XKore::GhostServer;
#use variables;
######################
#Main Loop
######################
#Line:4747 Plugins::callHook('parseMsg/pre', {switch => $switch, msg => $msg, msg_size => $msg_size});
sub RecvPackets {
	$switch = shift;
	$msg = shift;
	$msg_size = shift;
	forwardToClient($switch,$msg,$msg_size);

}

/*
message "---XKore2---\nWaiting For Controller Client...\n" ;
while (!$programEnder) {
	$localServ->iterate;
	$recordSocket->iterate;
	usleep 10000;
	if (defined($socketOut) && dataWaiting(\$socketOut)) {

		$socketOut->recv($msg,$Settings::MAX_READ);

		if ($msg eq '') {
		 Network::disconnect(\$socketOut);

		} else {
			$msgSend .= $msg;
			$msg_length = length($msgSend);
			#this loop is used to check for the packet length

			while ($msgSend ne "") {
				$msgSend = XKore::Functions::forwardToClient ($localServ,$msgSend,$localServ->{clients}[$svrObjIndex]);
				last if ($msg_length == length($msgSend));
				$msg_length = length($msgSend);
			}

		}

	}

}
*/
1;
