package Base::Ragnarok::MapServer;

use strict;
use Time::HiRes qw(time);
no encoding 'utf8';
use bytes;

use Modules 'register';
use Base::RagnarokServer;
use Misc;
use base qw(Base::RagnarokServer);
use Utils;
use Network::Receive::ServerType0; # constants only

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

sub map_login {
	my ($self, $args, $client) = @_;
	# maybe sessionstore should store sessionID as bytes?
	my $session = $self->{sessionStore}->get(unpack('V', $args->{sessionID}));

	unless (
		$session && $session->{accountID} eq $args->{accountID}
		# maybe sessionstore should store sessionID as bytes?
		&& pack('V', $session->{sessionID}) eq $args->{sessionID}
		&& $session->{sex} == $args->{sex}
		&& $session->{charID} eq $args->{charID}
		&& $session->{state} eq 'About to load map'
	) {
		$client->close();

	} else {
		$self->{sessionStore}->remove($session);
		$client->{session} = $session;

		if (exists $self->{recvPacketParser}{packet_lut}{define_check}) {
			$client->send($self->{recvPacketParser}->reconstruct({
				switch => 'define_check',
				result => Network::Receive::ServerType0::DEFINE__BROADCASTING_SPECIAL_ITEM_OBTAIN | Network::Receive::ServerType0::DEFINE__RENEWAL_ADD_2,
			}));
		}

		if (exists $self->{recvPacketParser}{packet_lut}{account_id}) {
			$client->send($self->{recvPacketParser}->reconstruct({
				switch => 'account_id',
				accountID => $args->{accountID},
			}));
		} else {
			$client->send($args->{accountID});
		}

		my $charInfo = $self->getCharInfo($session);
		my $coords = '';
		shiftPack(\$coords, $charInfo->{x}, 10);
		shiftPack(\$coords, $charInfo->{y}, 10);
		shiftPack(\$coords, 0, 4);
		$client->send($self->{recvPacketParser}->reconstruct({
			switch => 'map_loaded',
			syncMapSync => int time,
			coords => $coords,
		}));
	}
	
	$args->{mangle} = 2;
}

#	$msg = pack("C*", 0x9b, 0, 0x39, 0x33) .
#		$accountID .
#		pack("C*", 0x65) .
#		$charID .
#		pack("C*", 0x37, 0x33, 0x36, 0x64) .
#		$sessionID .
#		pack("V", getTickCount()) .
#		pack("C*", $sex);

sub unhandledMessage {
	my ($self, $args, $client) = @_;
	if (!$client->{session}) {
		$client->close();
		return 0;
	} else {
		return 1;
	}
}

1;
