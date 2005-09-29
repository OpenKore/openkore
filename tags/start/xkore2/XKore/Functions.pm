package XKore::Functions;

use strict;
use Time::HiRes qw(time usleep);
use Interface::Console;
use bytes;

use XKore::Variables qw($xConnectionStatus $currLocationPacket $tempMsg $tempIp $tempPort $programEnder $localServ $port $xkoreSock $clientFeed $socketOut $serverNumber $serverIp $serverPort $record $ghostPort $recordSocket $recordSock $recordPacket);
use IO::Socket;
use Thread::Queue;
use Globals;
use Modules;
use Settings;
use Network::Send;
use Misc;
use Utils;
use Network;
use Globals;
use Log qw(message warning error debug);





######################
# Functions
######################
sub forwardToServer {
         #my $roServer = shift;
        #my $msgSend = shift;
         my ($roServer,$msgSend) = @_;
         my $switch = uc(unpack("H2", substr($msgSend, 1, 1))) . uc(unpack("H2", substr($msgSend, 0, 1)));

         message "Forwarding $switch to the Server\n";
        if ($switch eq '007D'){
         # $msgSend =pack("C*", 0x65,0) . $accountID . $sessionID . $sessionID2 . $accountSex;
               # $roServer->send($msgSend);
                 sendMsgToServer(\$socketOut,$msgSend);
        }else{
               #$roServer->send($msgSend) ;
                 sendMsgToServer(\$socketOut,$msgSend);
        }
}

sub forwardToServer1 {
   my ($roSendToServ,$msgSend,$indexsu) = @_;
  $roSendToServ->sendData($indexsu,"hello");
}

sub forwardToClient {
          #  my $roSendToServ = shift;
          #  my $msgSend = shift;
            my ($roSendToServ,$msgSend,$client) = @_;
            my $msg_size;
            my $i;
           # my $xConnectionStatus;
            my $sessionID;
            my $accountID;
            my $sessionID2;
            my $accountSex;
            my $switch = uc(unpack("H2", substr($msgSend, 1, 1))) . uc(unpack("H2", substr($msgSend, 0, 1)));
            message "Forwarding packet $switch to the Client\n";
            ######### Checks for complete packets by comparing the length in recvpackets.txt
                if ($rpackets{$switch} eq "-" || $switch eq "0070") {
                        # Complete packet; the size of this packet is equal
                        # to the size of the entire data
                        $msg_size = length($msgSend);

                } elsif ($rpackets{$switch} eq "0") {
                        # Variable length packet
                        if (length($msgSend) < 4) {
                                return $msgSend;
                        }
                        $msg_size = unpack("S1", substr($msgSend, 2, 2));
                        if (length($msgSend) < $msg_size) {
                                return $msgSend;
                        }

                } elsif ($rpackets{$switch} > 1) {
                        # Static length packet
                        $msg_size = $rpackets{$switch};
                        if (length($msgSend) < $msg_size) {
                                return $msgSend;
                        }

                }
            ########

            if ($switch eq '0069'){

                        $sessionID = substr($msgSend, 4, 4);
                        $accountID = substr($msgSend, 8, 4);
                        $sessionID2 = substr($msgSend, 12, 4);
                        $accountSex = unpack("C1",substr($msgSend, 46, 1));
                        my $num = 0;
                        my @servers;
                        #put the server list in an array...
                         $msg_size = length($msgSend);
                        for($i = 47; $i < $msg_size; $i+=32) {
                                $servers[$num]{'ip'} = makeIP(substr($msgSend, $i, 4));
                                print $servers[$num]{'ip'};
                                #$servers[$num]{'ip'} = $masterServer->{ip} if ($masterServer && $masterServer->{private});
                                $servers[$num]{'port'} = unpack("S1", substr($msg, $i+4, 2));
                                ($servers[$num]{'name'}) = substr($msgSend, $i + 6, 20) =~ /([\s\S]*?)\000/;
                                $servers[$num]{'users'} = unpack("L",substr($msgSend, $i + 26, 4));
                                $num++;
                        }
                        printf "packet size = $msg_size \n";
                           $tempIp = $servers[$serverNumber]{'ip'};
                           $tempPort = $servers[$serverNumber]{'port'};

                           #printf makeIP(substr($msgSend, $i, 4));
                          $msgSend =substr($msgSend, 0, 46).pack("C1",0);
                          $roSendToServ->sendData($client,$msgSend);

                           $recordPacket->enqueue($msgSend) if ($record == 1);
                          #sendMsgToServer(\$new,pack("C*",66,111,61,90) . pack("S1",7000) .
                          $msgSend = pack("C*",127,0,0,1) . pack("S1",$port) .
                                        "Xkore2 On " .$servers[$serverNumber]{'name'} .
                                        pack("C*",,0x00,0x00,0x00,0x00,
                                        0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00);
                         $roSendToServ->sendData($client,$msgSend);
                          $msgSend = pack("C*",127,0,0,1) . pack("S1",$ghostPort) .
                                        "XKore2" .
                                        pack("C*",,0x00,0x00,0x00,0x00,
                                        0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00);

                    #$charServerLogin = $msgSend;
                    #Network::disconnect(\$roSendToServ);
                   $recordPacket->enqueue($msgSend) if ($record == 1);

                                 $xConnectionStatus = 1;
                                 printf $xConnectionStatus."\n";
                                #$localServ = new xkoreServer($port);
                                #$localServ = new xkoreServer ($port);
                                return "";

            }elsif ($switch eq '0071'){
       #'0071' => ['received_character_ID_and_Map', 'a4 Z16 a4 v1', [qw(charID mapName mapIP mapPort)]],
                  #@   my $remotePorty = unpack("S1", substr($msg, 26, 2));
                   #  my $remoteIpAdd = makeIP(substr($msgSend,22,4));
                     $tempIp = makeIP(substr($msgSend,22,4));
                     $tempPort = unpack("S1", substr($msg, 26, 2));

                       $msgSend = substr($msgSend,0,22).pack("C*",127,0,0,1) . pack("S1",$port);
                    # Network::connectTo(\$roSendToServ, $remoteIpAdd, $remotePorty );

                     $roSendToServ->sendData($client,$msgSend);
                     $msgSend = substr($msgSend,0,22).pack("C*",127,0,0,1) . pack("S1",$ghostPort);
                           #$roSendToServ = $charServ;
                          # $mapServerLogin = $msgSend;
                   $recordPacket->enqueue($msgSend) if ($record == 1);
                     $xConnectionStatus = 2;  #here
                     $localServ->iterate;
                     sleep 1;
                     return "";
            }elsif ($switch eq '0073'){
           #       sendMsgToServer(\$new,substr($msgSend, 0, 18) . pack("C",1));
                    #here
                   $recordPacket->enqueue($msgSend) if ($record == 1);
                   #$xConnectionStatus = 2;
                   $record = 0;
                   $roSendToServ->sendData($client,$msgSend);
            }elsif ($switch eq '0081'){
                   #$xConnectionStatus = 0;
                   $roSendToServ->sendData($client,$msgSend);
            }elsif ($switch eq '0087') {
                    $currLocationPacket = $msgSend;
                   $roSendToServ->sendData($client,$msgSend);
            }else{
                   #sendMsgToServer($roSendToServ,$msgSend);
                   #return $self->sendData($client, $msg)
                   $recordPacket->enqueue($msgSend) if ($record == 1);
                   $roSendToServ->sendData($client,$msgSend);
                   #$xConnectionStatus = 0;
                   return "";
                  }#$new->send($msgSend);# if ($new && $new->connected());
        $msg = (length($msg) >= $msg_size) ? substr($msg, $msg_size, length($msg) - $msg_size) : "";
        return $msg;
}

1;
