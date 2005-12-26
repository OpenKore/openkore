package XKore::GhostServer;

use strict;
use Time::HiRes qw(time usleep);
use XKore::Functions;
use Base::Server;
use base qw(Base::Server);
use XKore::Variables qw($xConnectionStatus %rpackets $tempRecordQueue %currLocationPacket
	$svrObjIndex $tempIp $tempPort $programEnder $localServ $port $ghostIndex
	$clientFeed $socketOut $serverNumber $serverIp $serverPort $record $mapchange
	$ghostPort $recordSocket $recordSock $recordPacket);


sub onClientNew {
	my ($self, $client, $index) = @_;
	$record = 0; #STOP ALL RECORDING
	$ghostIndex = $index;
	print "Accepting on-the-fly Client\n";

}

sub onClientExit {
	my ($self, $client, $index) = @_;
	if ($clientFeed && !$mapchange) {
		# reload the queue after it's empty
	       $recordPacket = '';
	       $recordPacket = new Thread::Queue;
		while ($tempRecordQueue->pending) {
			$recordPacket->enqueue($tempRecordQueue->dequeue_nb);
		}
		$clientFeed = 0;
		$record = 1;
		 print "RELOADING Queue\n";
	}
	print "on-the-fly Client Disconnected\n";
}

sub onClientData {
	my ($self, $client, $data, $index) = @_;

       XKore::Functions::forwardToGhost ($client,$data,$ghostIndex);
    #print "Client $index sent the following data: $data\n";
}


1;
