package XkorePlugin::XKore::Functions;

use strict;
use Time::HiRes qw(time usleep);
use Interface::Console;
use bytes;

use XkorePlugin::XKore::Variables qw($tempRecordQueue $xConnectionStatus %currLocationPacket $svrObjIndex
	$tempIp $tempPort $programEnder $localServ $port $ghostIndex $clientFeed $mapchange
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
#Line:4500 Plugins::callHook('RO_sendMsg_pre', {switch => $switch, msg => $msg, realMsg => \$sendMsg});
	my ($roServer,$msgSend) = @_;
	my $switch = uc(unpack("H2", substr($msgSend, 1, 1))) . uc(unpack("H2", substr($msgSend, 0, 1)));

	message "Forwarding $switch to the Server\n";
	if ($switch eq '0065'){
	# $msgSend =pack("C*", 0x65,0) . $accountID . $sessionID . $sessionID2 . $accountSex;
	       sendMsgToServer(\$remote_socket,$msgSend);
	}else{
	# is there a way to use the parseSendMsg function in function.pl ?
	       sendMsgToServer(\$remote_socket,$msgSend);

	}
}

#forwardToClient ( Server Object , Data , $Client Number );
#sends data to the RO Client
sub forwardToClient {
	my ($switch,$msg,$msg_size) = @_;
	my $i;
	my $sessionID;
	my $accountID;
	my $sessionID2;
	my $accountSex;

	my $extraData = (length($msg) >= $msg_size) ? substr($msg, $msg_size, length($msg) - $msg_size) : "";
	my $msgSend = substr($msg, 0, $msg_size);
	message "Forwarding packet $switch length:".$msg_size." to the Client\n";
	if ($switch eq '0069'){

		$msgSend = substr($msgSend, 0, 47).pack("C*",127,0,0,1) . pack("S1",$ghostPort) .
			"Ghosting Mode" .
			pack("C*",,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00);

		$recordPacket->enqueue($msgSend) if ($record == 1); #records the "Ghost Mode's" Fake Login.

	}elsif ($switch eq '0071'){
	 #'0071' => ['received_character_ID_and_Map', 'a4 Z16 a4 v1', [qw(charID mapName mapIP mapPort)]],

		$msgSend = substr($msgSend,0,22).pack("C*",127,0,0,1) . pack("S1",$ghostPort); #fake ghost mapserver data

		$recordPacket->enqueue($msgSend.$extraData) if ($record == 1); #queue up the faked data
		$mapchange = 1;

	}elsif ($switch eq '0073') {
		$currLocationPacket{spawn} = $msgSend; #Force Change map packet
		$recordPacket->enqueue($msgSend.$extraData) if ($record == 1); #queue up the faked data
		$mapchange = 1;

	}elsif ($switch eq '007D') {
		$currLocationPacket{spawn} = $msgSend; #Force Change map packet

	}elsif ($switch eq '0091') {
		$mapchange = 1;
		$currLocationPacket{mapis} = $msgSend; #Force Change map packet

	}elsif ($switch eq '0092') {
	#'0092' => ['map_changed', 'Z16 x4 a4 v1', [qw(map IP port)]],
		$mapchange = 1;
		$msgSend = substr($msgSend,0,22).pack("C*",127,0,0,1) . pack("S1",$ghostPort); #fake ghost mapserver data
		$recordPacket->enqueue($msgSend.$extraData) if ($record == 1); #queue up the faked data

	}elsif ($switch eq '0119') {
		$recordPacket->enqueue($msgSend) if ($record == 1);
		$record = 0; #stop the recording

	}elsif ($switch eq '0087') {
		$currLocationPacket{position} = $msgSend; #keeps track of the character's position in the map

	}elsif ($switch eq '0187' || $switch eq '0081' ) {
		#do not record this packet
		$msgSend = '';
	}else{
		$mapchange = 0;
		$recordPacket->enqueue($msgSend.$extraData) if ($record == 1); #record all other datas not intercepted
	}
	message "Sending Ghost Data $switch\n" if ($clientFeed == 1);
       $recordSocket->sendData($recordSocket->{clients}[$ghostIndex],$msgSend) if ($clientFeed == 1); #Sends message to the Ghost client when it's ready..

	return 1;
}

sub forwardToGhost {
	my ($client,$data,$index) = @_;

	my $switch = uc(unpack("H2", substr($data, 1, 1))) . uc(unpack("H2", substr($data, 0, 1)));
	if ($switch eq '007E') {
	#intercepts the send sync packet and send a "receive" sync packet to the ghost client
		$recordSocket->sendData($client,pack("c*",0x7F,0x00,0xD7,0xD0,0xA4,0x59));
		$data = '' ; # empties the $data so that it won't send to the server..

	}elsif ($switch eq '0085' && $firstLogin) {
		$clientFeed = 1;
		$recordSocket->sendData($client,$currLocationPacket{mapis}.$currLocationPacket{spawn}) if ($firstLogin == 1);
		$firstLogin = 0;

	}elsif ($switch eq '0064' || $switch eq '0065' || $switch eq '0066' || $switch eq '018A' || $switch eq '007D'){ #|| $switch eq '0072'
	      #  || $switch eq '007D' ) {
		$data = '' ;  #do not send those packets to the server
	}
	if ($recordPacket->pending && !$clientFeed){
	       my $stkData = $recordPacket->dequeue_nb; #unqueue the last data and put it in $stkData
		message "Received on-the-fly Client data $switch\n";

		if ($switch eq '0119'){
			$clientFeed = 1; #stop replaying packets when it's 0073
		}

		$switch = uc(unpack("H2", substr($stkData, 1, 1))) . uc(unpack("H2", substr($stkData, 0, 1)));
		message "Sending $switch data to on-the-fly Client\n";
		$recordSocket->sendData($client,$stkData); #sends the queued stuff to the client.
		$tempRecordQueue->enqueue($stkData);
		message ("hoe\n") if (!defined($rpackets{$switch})) ;
		while ((!defined($rpackets{$switch}) && $recordPacket->pending)){
		  #sends the next packet if it's not in the recvpackets.txt
			$stkData = $recordPacket->dequeue_nb;
			$switch = uc(unpack("H2", substr($stkData, 1, 1))) . uc(unpack("H2", substr($stkData, 0, 1)));
			message "Sending $switch data to on-the-fly Client\n";
			$recordSocket->sendData($client,$stkData);
			$tempRecordQueue->enqueue($stkData);
		}
		$firstLogin = 1;
	}else {
		#$recordSocket->sendData($client,$currLocationPacket{position});
		#$recordSock = $new;
		$clientFeed = 1; # start diverting data received from the server to the client
	}

		 # Sends the data to the server.
		forwardToServer ($localServ,$data) if ($clientFeed == 1 && $data ne '');

}

1;
