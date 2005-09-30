package XKore::GhostServer;

use strict;
use Time::HiRes qw(time usleep);
use XKore::Functions;
use Base::Server;
use base qw(Base::Server);
use XKore::Variables qw($xConnectionStatus $tempRecordQueue $currLocationPacket
	$svrObjIndex $tempIp $tempPort $programEnder $localServ $port $xkoreSock
	$clientFeed $socketOut $serverNumber $serverIp $serverPort $record
	$ghostPort $recordSocket $recordSock $recordPacket);


sub onClientNew {
	my ($self, $client, $index) = @_;
	$record = 0; #STOP ALL RECORDING
	print "Accepting on-the-fly Client\n";

}

sub onClientExit {
	my ($self, $client, $index) = @_;
	if ($clientFeed) {
		$clientFeed = 0;
		$recordPacket = $tempRecordQueue;
	}
	print "on-the-fly Client Disconnected\n";
}

sub onClientData {
	my ($self, $client, $data, $index) = @_;

	my $switch = uc(unpack("H2", substr($data, 1, 1))) . uc(unpack("H2", substr($data, 0, 1)));

		if ($switch eq '007E') {
		  #intercepts the send sync packet and send a "receive" sync packet to the ghost client
			$recordSocket->sendData($client,pack("c*",0x7F,0x00,0xD7,0xD0,0xA4,0x59));
			$data = '' ; # empties the $data so that it won't send to the server..
		}elsif ($switch eq '0064' || $switch eq '0065' || $switch eq '0066' || $switch eq '0072'
			|| $switch eq '007D' ) {
			$data = '' ;  #do not send those packets to the server
		}
		if ($recordPacket->pending && !$clientFeed){
			my $stkData = $recordPacket->dequeue_nb; #unqueue the last data and put it in $stkData
			printf "Received on-the-fly Client data $switch\n";

			if ($switch eq '0073'){
				$data = $currLocationPacket;  #this is the 'You Move' packet.. this is used to tell the
								#ghost client where it is now.
			}

			$switch = uc(unpack("H2", substr($stkData, 1, 1))) . uc(unpack("H2", substr($stkData, 0, 1)));
			printf "Sending $switch data to on-the-fly Client\n";

			$recordSocket->sendData($client,$stkData); #sends the queued stuff to the client.

		}else{
			$recordPacket = $tempRecordQueue; # reload the queue after it's empty
			#$recordSock = $new;
			$clientFeed = 1; # start diverting data received from the server to the client
		}

		 # Sends the data to the server.
		XKore::Functions::forwardToServer ($localServ,$data) if ($clientFeed == 1 && $data ne '');
    #print "Client $index sent the following data: $data\n";
}


1;
