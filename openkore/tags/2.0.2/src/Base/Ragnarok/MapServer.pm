package Base::Ragnarok::MapServer;

use strict;
use Time::HiRes qw(time);
no encoding 'utf8';
use bytes;

use Modules 'register';
use Base::RagnarokServer;
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

		$client->send(pack("C2 V a3 x2",
			0x73, 0x00,
			int(time),	# syncMapSync
			$coords		# character coordinates
		));
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
