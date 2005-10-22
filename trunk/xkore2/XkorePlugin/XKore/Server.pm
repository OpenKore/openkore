package XkorePlugin::XKore::Server;

use strict;
use XkorePlugin::XKore::Variables qw($xConnectionStatus $svrObjIndex $tempIp $tempPort $programEnder
	$localServ $port $ghostIndex $clientFeed $socketOut $serverNumber $serverIp
	$serverPort $record $ghostPort $recordSocket $recordSock $recordPacket $mapchange);

use XkorePlugin::Network::Send;
use XkorePlugin::XKore::Functions;
use Base::Server;
use base qw(Base::Server);

sub client {
	my ($self, $client, $msg) = @_;
	return $client;
}

sub onClientNew {
	my ($self, $client, $index) = @_;
	if ($xConnectionStatus == 0){	# client's first conenction to the server
		Network::disconnect(\$socketOut);
		Network::connectTo(\$socketOut, $serverIp, $serverPort); # connects to the login server
		$record = 1; #start all recording
	}elsif ($xConnectionStatus == 1){
		Network::disconnect(\$socketOut);
		Network::connectTo(\$socketOut, $tempIp, $tempPort); #connects to the char server
	}elsif ($xConnectionStatus == 2){
		Network::disconnect(\$socketOut);
		Network::connectTo(\$socketOut, $tempIp, $tempPort); #same as $xConnectionStatus == 1 but saperated for future use.
	}
	$svrObjIndex = $index;
}

sub onClientExit {
	my ($self, $client, $index) = @_;
	##print "Client $index disconnected with connection status = $xConnectionStatus .\n";
	if ($xConnectionStatus == 3){
		Network::disconnect(\$socketOut);
		$xConnectionStatus = 0 ;   #sets conection to 0 again so that it can be relogable..
	}
}

sub onClientData {
	my ($self, $client, $data, $index) = @_;
	XkorePlugin::XKore::Functions::forwardToServer ($localServ,$data); #forwards data to the RO server..
	##print "Client ($client->{host}) $index sent the following data: $data \n";
}

1;
