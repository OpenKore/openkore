package Base::Ragnarok::MapServer;

use strict;
use Time::HiRes qw(time);
no encoding 'utf8';
use bytes;

use Globals;
use Modules 'register';
use Base::RagnarokServer;
use Misc;
use base qw(Base::RagnarokServer);
use Utils;
use constant SESSION_TIMEOUT => 120;
use constant DUMMY_POSITION => {
	map => 'prontera.gat',
	x => 154,
	y => 198
};


sub new {
	my $class = shift;
	my %options = @_;
	my $self = $class->SUPER::new(
		$options{host},
		$options{port},
		$options{serverType},
		$options{rpackets}
	);
	$self->{sessionStore} = $options{sessionStore};
	return $self;
}

sub getCharInfo {
	#my ($self, $session) = @_;
}

sub handleLogin {
	my ($self, $client, $accountID, $charID, $sessionID, $gender) = @_;
	my $session = $self->{sessionStore}->get($sessionID);

	if (!$session || $session->{accountID} ne $accountID || $session->{sessionID} != $sessionID
	  || $session->{sex} != $gender || $session->{charID} ne $charID
	  || $session->{state} ne 'About to load map') {
		$client->close();

	} else {
		$self->{sessionStore}->remove($session);
		$client->{session} = $session;

		$client->send($accountID);

		my $charInfo = $self->getCharInfo($session);
		my $coords = '';
		shiftPack(\$coords, $charInfo->{x}, 10);
		shiftPack(\$coords, $charInfo->{y}, 10);
		shiftPack(\$coords, 0, 4);
		my $output = pack("C2 V a3 x2",
			0x73, 0x00,
			int(time),	# syncMapSync
			$coords		# character coordinates
		);
		$client->send($output);
		
		# Send the walking speed to the client, else the client just snaps around till it gets a speed increase/decrease 
		$output  = pack('C2 v V', 0xB0, 0x00, 0, $char->{walk_speed} * 1000);		# Walk speed
		# Send weapon/shield appearance
		$output .= pack('C2 a4 C v2', 0xD7, 0x01, $char->{ID}, 2, $char->{weapon}, $char->{shield});
		# Send status info
		$output .= pack('C2 a4 v3 x', 0x19, 0x01, $char->{ID}, $char->{param1}, $char->{param2}, $char->{param3});
		$client->send($output);
	}
}

sub process_0072 {
	my ($self, $client, $message) = @_;
	if ($self->{serverType} == 0) {
		# Map server login.
      my ($accountID, $charID, $sessionID, $gender) = unpack('x2 a4 a4 V x4 C', $message);
      $self->handleLogin($client, $accountID, $charID, $sessionID, $gender);
      return 1;
	} elsif ($self->getServerType()  == 8) {
		# packet sendSkillUse
		$self->unhandledMessage($client, $message);
		return 0;
	} else { #oRO and pRO and idRO
		my ($accountID, $charID, $sessionID, $gender) = unpack('x2 a4 x5 a4 x2 V x4 C', $message);
      $self->handleLogin($client, $accountID, $charID, $sessionID, $gender);
      return 1;
	}
}

sub process_00F3 {
	my ($self, $client, $message) = @_;
	if ($self->getServerType() == 18) {
		# Map server login.
		my ($charID, $accountID, $sessionID, $gender) = unpack('x5 a4 a4 x V x9 x4 C', $message);
		$self->handleLogin($client, $accountID, $charID, $sessionID, $gender);
		return 1;
	} else {
		$self->unhandledMessage($client, $message);
		return 0;
	}
}

#	$msg = pack("C*", 0x9b, 0, 0x39, 0x33) .
#		$accountID .
#		pack("C*", 0x65) .
#		$charID .
#		pack("C*", 0x37, 0x33, 0x36, 0x64) .
#		$sessionID .
#		pack("V", getTickCount()) .
#		pack("C*", $sex);

sub process_009B {
	my ($self, $client, $message) = @_;

	if ($self->getServerType() == 8) {
		# Map server login.
		my ($accountID , $charID, $sessionID, $gender) = unpack('x4 a4 x a4 x4 V x4 C', $message);
		$self->handleLogin($client, $accountID, $charID, $sessionID, $gender);
		return 1;
	} else {
		$self->unhandledMessage($client, $message);
		return 0;
	}
}

sub unhandledMessage {
	my ($self, $client) = @_;
	if (!$client->{session}) {
		$client->close();
		return 0;
	} else {
		return 1;
	}
}

1;
