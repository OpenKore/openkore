package XKore::GhostServer;

use strict;
use Time::HiRes qw(time usleep);
use XKore::Functions;
use Base::Server;
use base qw(Base::Server);
use XKore::Variables qw($xConnectionStatus %rpackets $tempRecordQueue %currLocationPacket
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

       XKore::Functions::forwardToGhost ($client,$data,$index);
    #print "Client $index sent the following data: $data\n";
}


1;
