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
package proxy;

use strict;
use Time::HiRes qw(time usleep);
use FindBin qw($RealBin);
use lib "$RealBin/src";
use lib "$RealBin/../openkore/src";
use lib "$RealBin/../src";
use Interface::Console;
use bytes;

use XKore::Variables qw($xConnectionStatus $tempMsg $tempIp $tempPort $programEnder $localServ $port $xkoreSock $clientFeed $socketOut $serverNumber $serverIp $serverPort $record $ghostPort $recordSocket $recordSock $recordPacket);
use Thread::Queue;
use Globals;
use Modules;
use Misc;
use Utils;
use Network;
use Globals;
use Log qw(message warning error debug);

#########################
#Files
#########################
import Settings qw(addConfigFile);
addConfigFile("$Settings::tables_folder/recvpackets.txt", \%rpackets, \&parseDataFile2);


#########################
#VARIABLES
#########################
  $serverNumber = 0; # the server number TODO: parse username to get this value.
  $serverIp = '66.111.61.90'; #ipaddress of the server TODO put this in a file.. OR read from servers.txt
  $serverPort = 6900; #PORT of the server TODO same as above

######################
#The Recorder...
######################
  $record;
  $ghostPort = 6901;
  $recordSocket = new XKore::GhostServer($ghostPort);
  $recordSock;
  $recordPacket = new Thread::Queue;
  $clientFeed = 0;
  $xkoreSock;
  $port = 6900; #Controler client's listener port

 $localServ = new XKore::Server($port);

  $programEnder = 0;
   $xConnectionStatus = 0 ;
#########################
#Connection stuffs..
#########################
use XKore::Server;
use XKore::Functions;
use XKore::GhostServer;
#use variables;
######################
#Main Loop
######################
my $msgSend;
while (!$programEnder){
    $localServ->iterate;
    $recordSocket->iterate;

                 if (defined($socketOut) && dataWaiting(\$socketOut)) {
                   #sleep 1;
                   usleep 501000;
                   $socketOut->recv($msg,3000);

                  if ($msg eq '') {
                     Network::disconnect(\$socketOut);
                        #$xConnectionStatus = 0;
                       #last;
                     }else{
                       $msgSend = $msg;
                       my $msg_length = length($msgSend);

                       printf "Client Id $localServ->{index} \n"  ;
                       while ($msgSend ne "") {
                         $recordSocket->sendData($recordSocket->{clients}[0],$msgSend) if ($clientFeed == 1);
                         #$localServ->sendData($localServ->{clients}[$localServ->{index}],$msgSend);
                         $msgSend = XKore::Functions::forwardToClient ($localServ,$msgSend,$localServ->{clients}[$tempMsg]);
                         last if ($msg_length == length($msgSend));
                         $msg_length = length($msgSend);
                       }
                       #sendMsgToServer(\$localServ,$msg);
                     }
                 }else{
                   usleep 10000;
                 }




}







