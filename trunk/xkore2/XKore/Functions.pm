package XKore::Functions;

use strict;
use Time::HiRes qw(time usleep);
use Interface::Console;
use bytes;

use XKore::Variables qw(%rpackets $tempRecordQueue $xConnectionStatus %currLocationPacket $svrObjIndex
	$tempIp $tempPort $programEnder $localServ $port $xkoreSock $clientFeed
	$socketOut $serverNumber $serverIp $serverPort $record $ghostPort $recordSocket
	 $recordSock $recordPacket $firstLogin);
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

#forwardToServer ( Socket , Data );
#sends data to the RO servers
sub forwardToServer {

	my ($roServer,$msgSend) = @_;
	my $switch = uc(unpack("H2", substr($msgSend, 1, 1))) . uc(unpack("H2", substr($msgSend, 0, 1)));

	message "Forwarding $switch to the Server\n";
	if ($switch eq '007D'){
	# $msgSend =pack("C*", 0x65,0) . $accountID . $sessionID . $sessionID2 . $accountSex;
		sendMsgToServer(\$socketOut,$msgSend);
	}else{
		 sendMsgToServer(\$socketOut,$msgSend);
	}
}

#forwardToClient ( Server Object , Data , $Client Number );
#sends data to the RO Client
sub forwardToClient {
	my ($roSendToServ,$msgSend,$client) = @_;
	my $msg_size;
	my $i;
	my $sessionID;
	my $accountID;
	my $sessionID2;
	my $accountSex;

	my $switch = uc(unpack("H2", substr($msgSend, 1, 1))) . uc(unpack("H2", substr($msgSend, 0, 1)));
	message "Received packet $switch from Server\n";

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
		message "receiving ".length($msgSend)." of $msg_size\n";
		if (length($msgSend) < $msg_size) {
			return $msgSend;
		}

	} elsif ($rpackets{$switch} > 1) {
		# Static length packet
		$msg_size = $rpackets{$switch};
		if (length($msgSend) < $msg_size) {
			return $msgSend;
		}
	 } else {
		$recordPacket->enqueue($msgSend) if ($record == 1 && $switch ne '0000');
		$recordSocket->sendData($recordSocket->{clients}[0],$msgSend) if ($clientFeed == 1); #Sends message to the Ghost client when it's ready..
		$roSendToServ->sendData($client,$msgSend);
		return "";
	 }

	message "Forwarding packet $switch length:".length($msgSend)." to the Client\n";
	if ($switch eq '0069'){
	  #Intecepts the login packet
		$sessionID = substr($msgSend, 4, 4);
		$accountID = substr($msgSend, 8, 4);
		$sessionID2 = substr($msgSend, 12, 4);
		$accountSex = unpack("C1",substr($msgSend, 46, 1));
		my $num = 0;
		my @servers;

		#put the server list in an array...
	       # $msg_size = length($msgSend);
		for($i = 47; $i < $msg_size; $i+=32) {
			$servers[$num]{'ip'} = makeIP(substr($msgSend, $i, 4));
			$servers[$num]{'port'} = unpack("S1", substr($msgSend, $i+4, 2));
			($servers[$num]{'name'}) = substr($msgSend, $i + 6, 20) =~ /([\s\S]*?)\000/;
			$servers[$num]{'users'} = unpack("L",substr($msgSend, $i + 26, 4));
			$num++;
		}

		# Store The ipAddress and port so that it can be used in Server::onClientNew
		$tempIp = $servers[$serverNumber]{'ip'};
		$tempPort = $servers[$serverNumber]{'port'};

		$msgSend =substr($msgSend, 0, 47); #cuts off the "real" server information

		## TODO: REMOVE all the Hexes.. Join using the existing packets.
		my $fakeMsgSend = $msgSend . pack("C*",127,0,0,1) . pack("S1",$ghostPort) .
			"Ghosting Mode" .
			pack("C*",,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00);

		$recordPacket->enqueue($fakeMsgSend) if ($record == 1); #records the "Ghost Mode's" Fake Login.


		$msgSend .= pack("C*",127,0,0,1) . pack("S1",$port) .	 #Fakes the ipaddress that the client suppose
			"Xkore2 On " .$servers[$serverNumber]{'name'}.	 # to login with.
			pack("C*",,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00);

		$roSendToServ->sendData($client,$msgSend); #sends the faked data to the client.

		$xConnectionStatus = 1;  #see Server::onClientNew for more infomation on this

	}elsif ($switch eq '0071'){
	 #'0071' => ['received_character_ID_and_Map', 'a4 Z16 a4 v1', [qw(charID mapName mapIP mapPort)]],

		$tempIp = makeIP(substr($msgSend,22,4)); #get the ipaddress of the mapserver
		$tempPort = unpack("S1", substr($msg, 26, 2)); #get the port of the mapserver

		$msgSend = substr($msgSend,0,22).pack("C*",127,0,0,1) . pack("S1",$port); #fake the mapserv data.

		$roSendToServ->sendData($client,$msgSend);

		$msgSend = substr($msgSend,0,22).pack("C*",127,0,0,1) . pack("S1",$ghostPort); #fake ghost mapserver data

		$recordPacket->enqueue($msgSend) if ($record == 1); #queue up the faked data

		$xConnectionStatus = 2; #see Server::onClientNew for more infomation on this

	}elsif ($switch eq '0073') {
		$currLocationPacket{spawn} = $msgSend; #Force Change map packet
		$roSendToServ->sendData($client,$msgSend);
		$recordPacket->enqueue($msgSend) if ($record == 1); #queue up the faked data

	}elsif ($switch eq '007D') {  ##HACK to make client stop sending so many rubbish...
		$currLocationPacket{spawn} = $msgSend; #Force Change map packet
		$roSendToServ->sendData($client,$msgSend);
		$recordSocket->sendData($recordSocket->{clients}[0],$msgSend) if ($clientFeed == 1); #Sends message to the Ghost client when it's ready..
		$msgSend = "";

	}elsif ($switch eq '0091') {
		$currLocationPacket{mapis} = $msgSend; #Force Change map packet
		$roSendToServ->sendData($client,$msgSend);

	}elsif ($switch eq '0092') {
	#'0092' => ['map_changed', 'Z16 x4 a4 v1', [qw(map IP port)]],

		$tempIp = makeIP(substr($msgSend,22,4)); #get the ipaddress of the mapserver
		$tempPort = unpack("S1", substr($msg, 26, 4)); #get the port of the mapserver

		$msgSend = substr($msgSend,0,22).pack("C*",127,0,0,1) . pack("S1",$port); #fake the mapserv data.

		$roSendToServ->sendData($client,$msgSend);

		$msgSend = substr($msgSend,0,22).pack("C*",127,0,0,1) . pack("S1",$ghostPort); #fake ghost mapserver data

		#$recordPacket->enqueue($msgSend) if ($record == 1); #queue up the faked data

		$xConnectionStatus = 2; #see Server::onClientNew for more infomation on this
	}elsif ($switch eq '00B0') {
		$recordPacket->enqueue($msgSend) if ($record == 1);
		$record = 0; #stop the recording
		$tempRecordQueue = $recordPacket;  #stores the faked data in another queue...( for multiple logins)
		$xConnectionStatus = 3; #change the connection status
		$roSendToServ->sendData($client,$msgSend);

	}elsif ($switch eq '0087') {
		$currLocationPacket{position} = $msgSend; #keeps track of the character's position in the map
		$roSendToServ->sendData($client,$msgSend);

	}elsif ($switch eq '0187' || $switch eq '0081' ) {
		#do not record this packet
		$roSendToServ->sendData($client,$msgSend);
	}else{
		$recordPacket->enqueue($msgSend) if ($record == 1); #record all other datas not intercepted
		$roSendToServ->sendData($client,$msgSend); #sends all data not intercepted to the client
	}
	$recordSocket->sendData($recordSocket->{clients}[0],$msgSend) if ($clientFeed == 1); #Sends message to the Ghost client when it's ready..
	$msgSend = (length($msgSend) >= $msg_size) ? substr($msgSend, $msg_size, length($msgSend) - $msg_size) : "";
	return $msgSend; #returns the extra traling data if it's not a part of the curent packet.
}

sub forwardToGhost {
	my ($client,$data,$index) = @_;

	my $switch = uc(unpack("H2", substr($data, 1, 1))) . uc(unpack("H2", substr($data, 0, 1)));
	if ($switch eq '007E') {
	#intercepts the send sync packet and send a "receive" sync packet to the ghost client
		$recordSocket->sendData($client,pack("c*",0x7F,0x00,0xD7,0xD0,0xA4,0x59));
		$data = '' ; # empties the $data so that it won't send to the server..
      #  }elsif ($switch eq '0085') {
       #	 $recordSocket->sendData($client,$currLocationPacket{mapis}.$currLocationPacket{spawn}) if ($firstLogin == 1);
       #	 $firstLogin = 0;
	}elsif ($switch eq '0064' || $switch eq '0065' || $switch eq '0066'){ #|| $switch eq '0072'
	      #  || $switch eq '007D' ) {
		$data = '' ;  #do not send those packets to the server
	}

	if ($recordPacket->pending && !$clientFeed){
	       my $stkData = $recordPacket->dequeue_nb; #unqueue the last data and put it in $stkData
		message "Received on-the-fly Client data $switch\n";

		if ($switch eq '0073'){
			$clientFeed = 1; #stop replaying packets when it's 0073
		}

		$switch = uc(unpack("H2", substr($stkData, 1, 1))) . uc(unpack("H2", substr($stkData, 0, 1)));
		message "Sending $switch data to on-the-fly Client\n";
		$recordSocket->sendData($client,$stkData); #sends the queued stuff to the client.

		if (!defined($rpackets{$switch}) && $recordPacket->pending && $switch ne '0071'){
		  #sends the next packet if it's not in the recvpackets.txt
			$stkData = $recordPacket->dequeue_nb;
			$switch = uc(unpack("H2", substr($stkData, 1, 1))) . uc(unpack("H2", substr($stkData, 0, 1)));
			message "Sending $switch data to on-the-fly Client\n";
			$recordSocket->sendData($client,$stkData);
		}
	}else {
		#$recordSocket->sendData($client,$currLocationPacket{position});
		$firstLogin = 1;
		$recordPacket = $tempRecordQueue; # reload the queue after it's empty
		#$recordSock = $new;
		$clientFeed = 1; # start diverting data received from the server to the client
	}

		 # Sends the data to the server.
		XKore::Functions::forwardToServer ($localServ,$data) if ($clientFeed == 1 && $data ne '');

}

1;
