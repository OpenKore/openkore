package XKore::Server;

use strict;
use XKore::Variables qw($xConnectionStatus $tempMsg $tempIp $tempPort $programEnder $localServ $port $xkoreSock $clientFeed $socketOut $serverNumber $serverIp $serverPort $record $ghostPort $recordSocket $recordSock $recordPacket);
use Network::Send;

use XKore::Functions;
use Base::Server;
use base qw(Base::Server);

#sub new {
 #       my ($class, $port) = @_;
 #       my $self;

 #       $self = $class->SUPER::new($port);
 #       return if (!$self);
 #       $self->{oldIndex} = [];
 #       return $self;
#}



sub client {
  my ($self, $client, $msg) = @_;
    return $client;
}

sub connected{
 1;
}

sub onClientNew {
    my ($self, $client, $index) = @_;
    ##print "Client $index connected with connection status = $xConnectionStatus .\n";

    #$localServ->sendData($client,"hello");
    if ($xConnectionStatus == 0){
      Network::disconnect(\$socketOut);
        Network::connectTo(\$socketOut, $serverIp, $serverPort);
        $record = 1;
        #$xConnectionStatus = 1;

        #$xConnectionStatus[$index] = 1;
     }elsif ($xConnectionStatus == 1){
       Network::disconnect(\$socketOut);
       Network::connectTo(\$socketOut, $tempIp, $tempPort);
     }elsif ($xConnectionStatus == 2){
       Network::disconnect(\$socketOut);
       Network::connectTo(\$socketOut, $tempIp, $tempPort);
     }
     $tempMsg = $index;
}

sub onClientExit {
    my ($self, $client, $index) = @_;
    ##print "Client $index disconnected with connection status = $xConnectionStatus .\n";

}

sub onClientData {
    my ($self, $client, $data, $index) = @_;
    #sendMsgToServer(\$socketOut,$data);
    xkoreFunctions::forwardToServer ($localServ,$data);
    ##print "Client ($client->{host}) $index sent the following data: $data \n";
}

1;
