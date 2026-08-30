package Base::Ragnarok::CharServer;

use strict;
use Time::HiRes qw(time);
use Socket qw(inet_aton);

use Modules 'register';
use Base::RagnarokServer;
use base qw(Base::RagnarokServer);
use Misc;
use I18N qw(stringToBytes);
use Globals qw($char %config $accountID $field %charSvrSet $masterServer);

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
	int => 1,
	look => {
		head => 3,
		body => 3
	}
};

our $nChar = 0;

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

# 09A1 is a client-only request in modern character selection.  It is absent
# from some server receive tables, so expose it only to this server's client
# tokenizer without mutating the shared global packet table.  Do not key this
# on the sender parser: custom/server-specific send tables may omit the
# request even though the browser still sends it.
sub getClientPacketTable {
	my ($self) = @_;
	my %packets = %{ $self->SUPER::getClientPacketTable() || {} };
	if ($self->modern_character_list) {
		$packets{'09A1'} = { length => 2 };
		if ($self->{sendPacketParser}
			&& !exists $self->{sendPacketParser}{packet_list}{'09A1'}) {
			$self->{sendPacketParser}{packet_list}{'09A1'} =
				['sync_received_characters'];
		}
	}
	return \%packets;
}

# A parser can expose more than one packet ID for the same handler name.  The
# packet LUT is populated lazily by reconstruct(), so it cannot be used to
# select the character-list layout during the first character-server login.
sub character_info_switch {
	my ($self) = @_;
	return '082D' if ($self->character_list_switch eq '099D' || $self->character_list_switch eq '0B72')
		&& exists $self->{recvPacketParser}{packet_list}{'082D'};
	return '006B';
}

sub character_list_switch {
	my ($self) = @_;
	my $server_type = $self->{serverType}
		|| ($masterServer && $masterServer->{serverType})
		|| '';
	# LastRO's 2021-11-03 character server answers 09A1 with LIST2
	# (0B72), even though the shared table also contains the older 099D
	# layout.  Keep 099D as the default for other server types.
	# The shared recvpackets length table can be sparse after custom table
	# merges, while Network::Receive still has the concrete 0B72 handler.  Use
	# parser capability first so a modern client never gets the legacy 099D
	# layout merely because a length entry was omitted from the shared table.
	return '0B72'
		if $server_type eq 'kRO_RagexeRE_2021_11_03'
		&& $self->{recvPacketParser}
		&& $self->{recvPacketParser}{packet_list}
		&& exists $self->{recvPacketParser}{packet_list}{'0B72'};
	return '0B72'
		if $server_type eq 'kRO_RagexeRE_2021_11_03'
		&& $self->{rpackets}
		&& exists $self->{rpackets}{'0B72'};
	return '099D' if $self->{rpackets} && exists $self->{rpackets}{'099D'};
	return '0B72' if $self->{rpackets} && exists $self->{rpackets}{'0B72'};
	return '0072';
}

sub modern_character_list {
	my ($self) = @_;
	my $switch = $self->character_list_switch;
	return $switch eq '099D' || $switch eq '0B72';
}

sub game_login {
	# Character server login.
	my ($self, $args, $client) = @_;
	# maybe sessionstore should store sessionID as bytes?
	my $session = $self->{sessionStore}->get(unpack('V', $args->{sessionID}));

	unless (
		$session && $session->{accountID} eq $args->{accountID}
		# maybe sessionstore should store sessionID as bytes?
		&& pack('V', $session->{sessionID}) eq $args->{sessionID}
		&& $session->{sex} == $args->{accountSex}
		&& $session->{state} eq 'About to select character'
	) {
		$client->close();

	} else {
		# SECURITY NOTE: the session should be marked as belonging to this
		# character server only. Right now there is the possibility that
		# someone can login to another character server with a session
		# that was already handled by this one.
		$self->{sessionStore}->mark($session->{sessionID});
		$client->{session} = $session;
		$session->{time} = time;
		$client->send($args->{accountID});

		my $output;
		my $character_info_switch = $self->character_info_switch;
		my $character_list_switch = $self->character_list_switch;
		my @char_list = $self->getCharacters($session);
		if ($self->modern_character_list) {
			$output = $self->{recvPacketParser}->reconstruct({
				switch => $character_info_switch,
				normal_slot => $charSvrSet{normal_slot},
				premium_slot => $charSvrSet{premium_slot},
				billing_slot => $charSvrSet{billing_slot},
				producible_slot => $charSvrSet{producible_slot},
				valid_slot => $charSvrSet{valid_slot},
				chars => \@char_list,
			});

			# XKore2 exposes the bot's complete character list as one page.  The
			# upstream server may advertise several pages for its normal slots,
			# but forwarding that count would make the browser request pages that
			# this proxy cannot populate.
			$output .= $self->{recvPacketParser}->reconstruct({
				switch => 'sync_received_characters',
				sync_Count => 1,
			});
			$client->send($output);
			return;
		} else { # 006B
			$output = $self->{recvPacketParser}->reconstruct({
				switch => $character_info_switch,
				total_slot => $charSvrSet{total_slot},
				premium_start_slot => $charSvrSet{premium_start_slot},
				premium_end_slot => $charSvrSet{premium_end_slot},
				chars => \@char_list,
			});
		}
		$client->send($output);
		
		# Show list of characters.
		&sendCharInfo;
		
		# TODO: Check if we need send accountID
		my $data .= pack('C2 x4 a4 v', 0xB9, 0x08, $args->{accountID}, 0);
		$client->send($data);
	}
}

sub sendCharInfo {
	my ($self, $args, $client) = @_;

	my @char_list = $self->getCharacters($client->{session});
	my $switch = $self->character_list_switch;
	my $packet = $self->{recvPacketParser}->reconstruct({
		switch => $switch,
		chars => \@char_list
	});

	# `PacketParser::reconstruct` normally gets variable-length metadata from
	# the process-wide recvpackets table.  XKore2 can be started with a sparse
	# custom table, so make the length self-consistent for character pages even
	# when that shared entry is absent.
	if (($switch eq '099D' || $switch eq '0B72') && length($packet) >= 4) {
		substr($packet, 2, 2) = pack('v', length($packet));
	}
	$client->send($packet);
}

sub char_login {
	# Select character.
	my ($self, $args, $client) = @_;
	my $session = $client->{session};
	if ($session) {
		$self->{sessionStore}->mark($session->{sessionID});
		my @characters = $self->getCharacters();

		if ($args->{slot} != $char->{slot}) {
			# Invalid character selected.
			$client->send(pack('C*', 0x6C, 0x00, 0));
		} else {
			my $charInfo = $self->{mapServer}->getCharInfo($session);
			if (!$charInfo) {
				# We can't get the character information for some reason.
				$client->send(pack('C*', 0x6C, 0x00, 0));
			} else {
				my $host = inet_aton($self->{mapServer}->getHost);
				$host = inet_aton($client->{BSC_sock}->sockhost) if $host eq "\000\000\000\000";

				$session->{charID} = $char->{charID};
				$session->{state} = 'About to load map';
				$client->send($self->{recvPacketParser}->reconstruct({
					switch => 'received_character_ID_and_Map',
					charID => $char->{charID},
					mapName => $charInfo->{map},
					mapIP => $host,
					mapPort => $self->{mapServer}->getPort,
				}));
			}
		}
	}
	$client->close();
}

sub sync_received_characters {
	my ($self, $args, $client) = @_;
	if ($self->modern_character_list) {
		# 09A1 is the browser's character-list page request.  Every request is
		# answered with a 099D/0B72 page; do not emit the legacy PIN handshake.
		$self->sendCharInfo($args, $client);
		return;
	}
	if ($nChar == 0) {
		&sendCharInfo;
		$nChar = 1;
	} else {
		$client->send($self->{recvPacketParser}->reconstruct({
			switch => 'login_pin_code_request',
			seed => 0,
			accountID => $accountID,
			flag => 7,
		}));
		$nChar = 0;
	}
}

sub ban_check {
	# Ban check.
	# Doing nothing seems to work.
	my ($self, $ID, $client) = @_;
	$client->send($self->{recvPacketParser}->reconstruct({
		switch => 'sync_request',
		accountID => $ID,
	}));
}

sub char_create {
	# Character creation.
	my ($self, $args, $client) = @_;
	# Deny it.
	$client->send(pack('C*', 0x6E, 0x00, 2));
}

sub char_delete {
	# Character deletion.
	my ($self, $args, $client) = @_;
	# Deny it.
	$client->send(pack('C*', 0x70, 0x00, 1));
}

sub unhandledMessage {
	my ($self, $args, $client) = @_;
	$client->close();
}

1;
