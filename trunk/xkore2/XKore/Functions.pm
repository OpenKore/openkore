package XKore::Functions;

use strict;
use Time::HiRes qw(time usleep);
use Interface::Console;
use bytes;

use XKore::Variables qw(%rpackets $xConnectionStatus $currLocationPacket $tempMsg
	$tempIp $tempPort $programEnder $localServ $port $xkoreSock $clientFeed
	$socketOut $serverNumber $serverIp $serverPort $record $ghostPort $recordSocket
	 $recordSock $recordPacket);
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

sub forwardToServer1 {
   my ($roSendToServ,$msgSend,$indexsu) = @_;
  $roSendToServ->sendData($indexsu,"hello");
}

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
	$recordSocket->sendData($recordSocket->{clients}[0],$msgSend) if ($clientFeed == 1); #Sends message to the Ghost client when it's ready..

	#######Currently not doing anything...
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
		# Unknown packet - ignore it
		if (!existsInList($config{'debugPacket_exclude'}, $switch)) {
			warning("Unknown packet - $switch Forwarding it anyway\n");
			dumpData($msgSend) if ($config{'debugPacket_unparsed'});
		}
		#return $msgSend;
		$roSendToServ->sendData($client,$msgSend);
		return "";
	 }
	########
	message "Forwarding packet $switch length:".length($msgSend)." to the Client\n";
	if ($switch eq '0069'){
	     #	 if (length($msgSend) < 47) {
		#	 return $msgSend;
	       # }
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
		#debug "packet size = $msg_size \n";
		$tempIp = $servers[$serverNumber]{'ip'};
		$tempPort = $servers[$serverNumber]{'port'};

		$msgSend =substr($msgSend, 0, 47);#.pack("C1",0);
		#$roSendToServ->sendData($client,$msgSend);

		my $fakeMsgSend = $msgSend . pack("C*",127,0,0,1) . pack("S1",$ghostPort) .
			"Ghosting Mode" .
			pack("C*",,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00) .
			substr($msgSend, 47);

		$recordPacket->enqueue($fakeMsgSend) if ($record == 1);


		$msgSend .= pack("C*",127,0,0,1) . pack("S1",$port) .
			"Xkore2 On " .$servers[$serverNumber]{'name'}.
			pack("C*",,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00);

		$roSendToServ->sendData($client,$msgSend);

		$xConnectionStatus = 1;
		printf $xConnectionStatus."\n";

	       # return "";

	}elsif ($switch eq '0071'){
	 #'0071' => ['received_character_ID_and_Map', 'a4 Z16 a4 v1', [qw(charID mapName mapIP mapPort)]],

		$tempIp = makeIP(substr($msgSend,22,4));
		$tempPort = unpack("S1", substr($msg, 26, 2));

		$msgSend = substr($msgSend,0,22).pack("C*",127,0,0,1) . pack("S1",$port);

		$roSendToServ->sendData($client,$msgSend);
		$msgSend = substr($msgSend,0,22).pack("C*",127,0,0,1) . pack("S1",$ghostPort);

		$recordPacket->enqueue($msgSend) if ($record == 1);
		$xConnectionStatus = 2;
		$localServ->iterate;
		sleep 1;
	      #  return "";

	}elsif ($switch eq '0073'){
		$recordPacket->enqueue($msgSend) if ($record == 1);
		$record = 0;
		$roSendToServ->sendData($client,$msgSend);

	}elsif ($switch eq '0087') {
		$currLocationPacket = $msgSend;
		$roSendToServ->sendData($client,$msgSend);

	}else{
		$recordPacket->enqueue($msgSend) if ($record == 1);
		$roSendToServ->sendData($client,$msgSend);
	}
	$msgSend = (length($msgSend) >= $msg_size) ? substr($msgSend, $msg_size, length($msgSend) - $msg_size) : "";
	return $msgSend;
}

1;
