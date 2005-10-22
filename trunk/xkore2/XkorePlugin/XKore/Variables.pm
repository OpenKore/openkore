package $Plugins::current_plugin_folder::XKore::Variables;
use Exporter 'import';
use base qw(Exporter);

@EXPORT_OK =qw(%rpackets $xConnectionStatus %currLocationPacket $svrObjIndex $tempIp $tempPort $mapchange
	$programEnder $localServ $tempRecordQueue $port $ghostIndex $clientFeed $socketOut $serverNumber
	$serverIp $serverPort $record $ghostPort $recordSocket $recordSock $recordPacket $firstLogin);

our $socketOut; #the out going connection handle
our $serverNumber; # the server number TODO: parse username to get this value.
our $serverIp; #ipaddress of the server TODO put this in a file.. OR read from servers.txt
our $serverPort; #PORT of the server TODO same as above
our $mapchange;
our $tempRecordQueue;
our %rpackets;
our $record;
our $ghostPort;
our $recordSocket;
our $recordSock;
our $recordPacket;
our $clientFeed;
our $ghostIndex;
our $port; #Controler client's listener port
our $xConnectionStatus;
our $localServ;
our $tempIp;
our $tempPort;
our $svrObjIndex;
our $programEnder;
our %currLocationPacket;
our $firstLogin;
1;
