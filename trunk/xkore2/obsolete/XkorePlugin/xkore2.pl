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
# Plugin VERSION
#
package xkore2;

use strict;
use Time::HiRes qw(time usleep);
use lib $Plugins::current_plugin_folder;

use XKore::Variables qw(%rpackets $tempRecordQueue $xConnectionStatus $svrObjIndex $tempIp $tempPort $programEnder $localServ $port
	$ghostIndex $clientFeed $socketOut $serverNumber $serverIp $serverPort $record $ghostPort
	$recordSocket $recordSock $recordPacket);
use bytes;
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
       ['mainLoop_pre', \&MainLoop],
       ['parseMsg/unknown', \&RecvPackets],
       ['parseMsg/pre', \&RecvPackets],
       ['RO_sendMsg_pre', \&SndPackets]
);

######################
#The Recorder...
######################
	$record = 1;
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

sub MainLoop {
    $recordSocket->iterate;
}

sub RecvPackets {
	my $hookName = shift;
	my $args = shift;
	my $switch = $args->{switch};
	my $msg = $args->{msg};
	my $msg_size = ($hookName eq 'parseMsg/unknown') ? length($msg) : $args->{msg_size};
	message "received unknown $switch\n" if ($hookName eq 'parseMsg/unknown');
	XKore::Functions::forwardToClient($switch,$msg,$msg_size);

}

sub SndPackets {

}
1;
