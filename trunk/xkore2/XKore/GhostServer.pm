package XKore::GhostServer;

use strict;
use Time::HiRes qw(time usleep);
use XKore::Functions;
use Base::Server;
use base qw(Base::Server);
use XKore::Variables qw($xConnectionStatus $tempRecordQueue $currLocationPacket
	$tempMsg $tempIp $tempPort $programEnder $localServ $port $xkoreSock
	$clientFeed $socketOut $serverNumber $serverIp $serverPort $record
	$ghostPort $recordSocket $recordSock $recordPacket);


sub onClientNew {
	my ($self, $client, $index) = @_;
	$record = 0; #Do not REcord
	print "Accepting on-the-fly Client\n";

}

sub onClientExit {
	my ($self, $client, $index) = @_;
	$clientFeed = 0;
	print "on-the-fly Client Disconnected\n";
}

sub onClientData {
	my ($self, $client, $data, $index) = @_;

	my $switch = uc(unpack("H2", substr($data, 1, 1))) . uc(unpack("H2", substr($data, 0, 1)));

		if ($switch eq '007E') {
			$recordSocket->sendData($client,pack("c*",0x7F,0x00,0xD7,0xD0,0xA4,0x59));
			$data = '' ;
		}elsif ($switch eq '0064' || $switch eq '0065' || $switch eq '0066' || $switch eq '0072'
			|| $switch eq '007D' ) {
			$data = '' ;
		}
		if ($recordPacket->pending){
			my $stkData = $recordPacket->dequeue_nb;
			printf "Received on-the-fly Client data $switch\n";
			if ($switch eq '0073'){
				$data = $currLocationPacket;
			}
			$switch = uc(unpack("H2", substr($stkData, 1, 1))) . uc(unpack("H2", substr($stkData, 0, 1)));
			printf "Sending $switch data to on-the-fly Client\n";
			#sleep 1;
			$recordSocket->sendData($client,$stkData);

		}else{
			$recordPacket = $tempRecordQueue;
			#$recordSock = $new;
			$clientFeed = 1;
		}

		 ####
		XKore::Functions::forwardToServer ($localServ,$data) if ($clientFeed == 1 && $data ne '');
    #print "Client $index sent the following data: $data\n";
}


1;
