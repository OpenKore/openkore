package Base::Ragnarok::CharServer;

use strict;
use Time::HiRes qw(time);
use Socket qw(inet_aton);

use Modules 'register';
use Base::RagnarokServer;
use base qw(Base::RagnarokServer);
use Misc;
use Globals qw(%config);

use constant SESSION_TIMEOUT => 120;
use constant DUMMY_CHARACTER => {
	charID => pack("V", 1234),
	lv_job => 50,
	hp => 1,
	hp_max => 1,
	sp => 1,
	sp_max => 1,
	walk_speed => 1,
	jobID => 8, # Priest
	hair_style => 2,
	lv => 1,
	hair_color => 5,
	clothes_color => 1,
	name => 'Character',
	str => 1,
	agi => 1,
	vit => 1,
	dex => 1,
	luk => 1,
	look => {
		head => 3,
		body => 3
	}
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
	$self->{mapServer} = $options{mapServer};
	$self->{name} = $options{name} || 'Ragnarok Online';
	$self->{charBlockSize} = $options{charBlockSize} || 106;
	return $self;
}

sub getName {
	return $_[0]->{name};
}

sub getPlayersCount {
	return 0;
}

sub getCharacters {
	die "This is an abstract method and has not been implemented.";
}

sub charBlockSize {
	return $_[0]->{charBlockSize};
}

sub process_0065 {
	# Character server login.
	my ($self, $client, $message) = @_;
	my ($accountID, $sessionID, $sessionID2, $gender) = unpack('x2 a4 V V x2 C', $message);
	my $session = $self->{sessionStore}->get($sessionID);

	if (!$session || $session->{accountID} ne $accountID || $session->{sessionID} != $sessionID
	  || $session->{sex} != $gender || $session->{state} ne 'About to select character') {
		$client->close();

	} else {
		no encoding 'utf8';
		use bytes;

		# Show list of characters.
		my $output = '';
		my $index = -1;
		foreach my $char ($self->getCharacters($session)) {
			$index++;
			next if (!$char);
			my $charStructure = pack('x' . $self->charBlockSize());

			substr($charStructure, 0, 18) = pack('a4 V3 v',
				$char->{charID},	# character ID
				$char->{exp},		# base experience
				$char->{zenny},		# zeny
				$char->{exp_job},	# job experience
				$char->{lv_job}		# job level
			);

			substr($charStructure, 42, 64) = pack('v7 x2 v x2 v x2 v4 Z24 C6 v',
				$char->{hp},
				$char->{hp_max},
				$char->{sp},
				$char->{sp_max},
				$char->{walk_speed} * 1000,
				$char->{jobID},
				$char->{hair_style},
				$char->{lv},
				$char->{headgear}{low},
				$char->{headgear}{top},
				$char->{headgear}{mid},
				$char->{hair_color},
				$char->{clothes_color},
				$char->{name},
				$char->{str},
				$char->{agi},
				$char->{vit},
				$char->{int},
				$char->{dex},
				$char->{luk},
				$index
			);

			$output .= $charStructure;
		}
        if ($self->{serverType} == 8){
            $output = pack('C20') . $output;
        }

		# SECURITY NOTE: the session should be marked as belonging to this
		# character server only. Right now there is the possibility that
		# someone can login to another character server with a session
		# that was already handled by this one.

		$self->{sessionStore}->mark($session);
		$client->{session} = $session;
		$session->{time} = time;
		$client->send($accountID);
		if ($config{XKore_altCharServer} == 0){
		  $client->send(pack('C2 v', 0x6B, 0x00, length($output) + 4) . $output);
		}else{
          $client->send(pack('C2 v', 0x72, 0x00, length($output) + 4) . $output);
        }
	}

}

sub process_0066 {
	# Select character.
	my ($self, $client, $message) = @_;
	my $session = $client->{session};
	if ($session) {
		$self->{sessionStore}->mark($session);
		my ($charIndex) = unpack('x2 C', $message);
		my @characters = $self->getCharacters();
		if (!$characters[$charIndex]) {
			# Invalid character selected.
			$client->send(pack('C*', 0x6C, 0x00, 0));
		} else {
			my $char = $characters[$charIndex];
			my $charInfo = $self->{mapServer}->getCharInfo($session);
			if (!$charInfo) {
				# We can't get the character information for some reason.
				$client->send(pack('C*', 0x6C, 0x00, 0));
			} else {
				my $output = pack('C2 a4 Z16 a4 v',
					0x71, 0x00,
					$char->{charID},
					$charInfo->{map},
					inet_aton($self->{mapServer}->getHost()),
					$self->{mapServer}->getPort()
				);
				$session->{charID} = $char->{charID};
				$session->{state} = 'About to load map';
				$client->send($output);
			}
		}
	}
	$client->close();
}

sub process_0187 {
	# Ban check.
	# Doing nothing seems to work.
}

sub process_0067 {
	# Character creation.
	my ($self, $client) = @_;
	# Deny it.
	$client->send(pack('C*', 0x6E, 0x00, 2));
}

sub process_0067 {
	# Character deletion.
	my ($self, $client) = @_;
	# Deny it.
	$client->send(pack('C*', 0x70, 0x00, 1));
}

sub unhandledMessage {
	my ($self, $client) = @_;
	$client->close();
}

1;
