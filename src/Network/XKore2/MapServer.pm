#########################################################################
#  OpenKore - X-Kore Mode 2
#  Copyright (c) 2007 OpenKore developers
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Map server implementation.

package Network::XKore2::MapServer;

use strict;
use Globals qw(
	$char $field %statusHandle @skillsID @itemsID %items
	$portalsList $npcsList $monstersList $playersList $petsList
	@friendsID %friends %pet @partyUsersID %spells
	@chatRoomsID %chatRooms @venderListsID %venderLists $hotkeyList
	%config $questList $incomingMessages $masterServer $messageSender
	%cashShop
);
use Base::Ragnarok::MapServer;
use base qw(Base::Ragnarok::MapServer);
use Network::MessageTokenizer;
use I18N qw(stringToBytes);
use Utils qw(shiftPack getTickCount getCoordString);

use Log qw(debug warning error);

my $RunOnce = 1;
	
sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	debug "XKore 2 Map Server started \n";
	$self->{kore_map_loaded_hook} = Plugins::addHook('packet/map_loaded', \&kore_map_loaded, $self);
	$self->{kore_disconnected} = Plugins::addHook('disconnected', \&kore_disconnected, $self);
	return $self;
}
	
# Overrided method.
sub onClientNew {
	my ($self, $client, $index) = @_;
	$self->SUPER::onClientNew($client, $index);
	if ($messageSender->{encryption}) { # using encryption?
		# enable MID encryption.
		cryptKeys($client, $messageSender->{encryption}{crypt_key_1}, $messageSender->{encryption}{crypt_key_2}, $messageSender->{encryption}{crypt_key_3});
	}
	
	# In here we store messages that the RO client wants to
	# send to the server.
	$client->{outbox} = new Network::MessageTokenizer($self->getRecvPackets());
	push (@{$self->{clients}}, $client); # keep a list of clients
	# TODO: remove disconnected clients
}
sub kore_map_loaded {
	my (undef, $args, $self) = @_;
	foreach my $client (@{$self->{clients}}) {
		if ($client->{session}{dummy}) {
			$client->send($self->{recvPacketParser}->reconstruct({
				switch => 'map_change',
				map => $field->name() . ".gat",
				x => $char->{pos_to}{x},
				y => $char->{pos_to}{y},
			}));
			$client->{session}{dummy} = 0;			
		}
	}
}

sub kore_disconnected {
	my (undef, $args, $self) = @_;
	if (!$config{XKore_silent}) {
		foreach my $client (@{$self->{clients}}) {
			$client->send($self->{recvPacketParser}->reconstruct({
				switch => 'system_chat',
				message => 'OpenKore disconnected, please wait...',
			}));
		}
	}
}

sub cryptKeys {
	my $self = shift;
	$self->{encryption} = {
		'crypt_key_1' => Math::BigInt->new(shift),
		'crypt_key_2' => Math::BigInt->new(shift),
		'crypt_key_3' => Math::BigInt->new(shift),
	};
	# calculate first key
	$self->{encryption}->{crypt_key} = $self->{encryption}->{crypt_key_1};
}

sub onClientData {
	my ($self, $client, $data) = @_;
	my $additional_data;
	encryptMessageID($client, \$data); # encrypt MID
	#debug sprintf("XKore2 Server: Received packet %s \n", Network::MessageTokenizer::getMessageID($data)), "xkore2_server";
	$data = $client->{tokenizer}->slicePacket($data, \$additional_data); # slice packet if needed
	$client->{tokenizer}->add($data, 1);
	$client->{outbox} && $client->{outbox}->add($_) for $self->{sendPacketParser}->process(
		$client->{tokenizer}, $self, $client
	);
	$self->onClientData($client, $additional_data) if $additional_data;
}

sub gameguard_reply {
	my ($self, $args, $client) = @_;
	if ($config{gameGuard} == 0) {
		debug("Replying XKore 2's gameguard query");
	} else {
		# mangle, may be unsafe
		$args->{mangle} = 2;
	}
}

sub npc_talk_continue {
	my ($self, $args, $client) = @_;
	# TODO: Mangle every npc_talk packet during talkNPC sequences
	$args->{mangle} = 2 if ($config{autoTalkCont});
}

# Overrided method.
sub getCharInfo {
	my ($self, $session) = @_;
	if ($char && $field && !$session->{dummy}) {
		return {
			map => $field->name() . ".gat",
			x => $char->{pos_to}{x},
			y => $char->{pos_to}{y}
		};
	} else {
		$session->{dummy} = 1;
		return Base::Ragnarok::MapServer::DUMMY_POSITION;
	}
}

sub encryptMessageID {
	my ($self, $r_message) = @_;
	if ($self->{encryption}) {
		my $messageID = unpack("v", $$r_message);
		# by Fr3DBr		
		# Calculating the Encryption Key
		$self->{encryption}->{crypt_key} = ($self->{encryption}->{crypt_key} * $self->{encryption}->{crypt_key_3} + $self->{encryption}->{crypt_key_2}) & 0xFFFFFFFF;
		# Xoring the Message ID
		$messageID = ($messageID ^ (($self->{encryption}->{crypt_key} >> 16) & 0x7FFF)) & 0xFFFF;
		$$r_message = pack("v", $messageID) . substr($$r_message, 2);
	}
}

sub map_loaded {
	# The RO client has finished loading the map.
	# Send character information to the RO client.
	my ($self, $args, $client) = @_;
	no encoding 'utf8';
	use bytes;

	my $char;
	# TODO: Character vending, character in chat, character in deal
	# TODO: Cart Items, Guild Notice
	# TODO: Fix walking speed? Might that be part of the map login packet? Or 00BD?

	if (!$client->{session}) {
		$client->close();
		return;
	} elsif ($client->{session}{dummy}) {
		$char = Base::Ragnarok::CharServer::DUMMY_CHARACTER;
	} elsif ($Globals::char) {
		$char = $Globals::char;
	} else {
		$char = Base::Ragnarok::CharServer::DUMMY_CHARACTER;
		$client->{session}{dummy} = 1;
	}
	# Do this just in case $client->{session}{dummy} was set after
	# the user logs in.
	$char->{ID} = $client->{session}{accountID};
	$self->send_player_info($client, $char);
	$self->send_avoid_sprite_error_hack($client, $char);
	$self->send_npc_info($client);
	$self->send_inventory($client, $char);
	$self->send_ground_items($client);
	$self->send_portals($client);
	$self->send_npcs($client);
	$self->send_monsters($client);
	$self->send_npcs($client);
	$self->send_pets($client);
	$self->send_vendors($client);
	$self->send_chatrooms($client);
	$self->send_ground_skills($client);
	$self->send_friends_list($client);
	$self->send_party_list($client, $char);
	$self->send_pet($client);
	$self->send_welcome($client);
	
	$args->{mangle} = 2;
	$RunOnce = 0;
}

sub send_quest_info {
	my ($self, $client) = @_;
	my $data = undef;
	my $q_output = '';
	my $m_output = '';
	my $tmp = '';
	my $k = 0;
	my $mi = 0;
	foreach my $questID (keys %{$questList}) {
		my $quest = $questList->{$questID};
		$q_output .= pack('V C', $questID, $quest->{active});

		# misson info
		$tmp = '';
		$mi = 0;
		foreach my $mobID (keys %{$quest->{missions}}) {
			my $mission = $quest->{missions}->{$mobID};
			$tmp = pack('V v Z24', $mission->{mobID}, $mission->{count}, $mission->{mobName_org});
			$mi++;
		}
		$m_output .= pack('V3 v a90', $questID, $quest->{time_start}, $quest->{time}, $mi, $tmp);
		$k++;
	}
	if ($k > 0 && length($q_output) > 0) {
		$data = pack('C2 v V', 0xB1, 0x02, length($q_output) + 8, $k) . $q_output;
		$data .= pack('C2 v V', 0xB2, 0x02, length($m_output) + 8, $k) . $m_output;
		$client->send($data);
	}
}
	
sub send_guild_info {
	my ($self, $client) = @_;
	my $data = undef;
	if ($char->{guildID}) {
		$data = pack('C2 V3 x5 Z24', 0x6C, 0x01,
			$char->{guildID}, $char->{guild}{emblem}, $char->{guild}{mode},
			stringToBytes($char->{guild}{name}));
		$client->send($data);
	}
}

sub send_pet {
	my ($self, $client) = @_;
	my $data = undef;
	if (defined $pet{ID}) {
		$data  = pack('C2 C a4 V', 0xA4, 0x01, 0, $pet{ID}, 0);
		$data .= pack('C2 C a4 V', 0xA4, 0x01, 5, $pet{ID}, 0x64);
		$data .= pack('C2 Z24 C v4', 0xA2, 0x01,
			stringToBytes($pet{name}), $pet{renameflag}, $pet{level},
			$pet{hungry}, $pet{friendly}, $pet{accessory});
		$client->send($data);
	}
}
sub send_party_list {
	my ($self, $client, $char) = @_;
	my $data = undef;
	if ($char->{party}) {
		my $num = 0;
		foreach my $ID (@partyUsersID) {
			next if !defined($ID) || !$char->{party}{users}{$ID};
			if (!$char->{party}{users}{$ID}{admin}) {
				$num++;
			}
			$data .= pack("a4 Z24 Z16 C2",
				$ID, stringToBytes($char->{party}{users}{$ID}{name}),
				$char->{party}{users}{$ID}{map},
				$char->{party}{users}{$ID}{admin} ? 0 : $num,
				1 - $char->{party}{users}{$ID}{online});
		}
		$data = pack('C2 v Z24', 0xFB, 0x00,
			length($data) + 28,
			stringToBytes($char->{party}{name})) .
			$data;
		$client->send($data);
	}
}

sub send_vendors {
	my ($self, $client) = @_;
	my $data = undef;
	foreach my $ID (@venderListsID) {
		next if !defined($ID) || !$venderLists{$ID};
		$data .= pack('C2 a4 a30 x50', 0x31, 0x01, $ID, stringToBytes($venderLists{$ID}{title}));
	}
	$client->send($data) if (length($data) > 0);
}

sub send_chatrooms {
	my ($self, $client) = @_;
	my $data = undef;
	foreach my $ID (@chatRoomsID) {
		next if !defined($ID) || !$chatRooms{$ID} || !$chatRooms{$ID}{ownerID};
		# '00D7' => ['chat_info', 'x2 a4 a4 v1 v1 C1 a*', [qw(ownerID ID limit num_users public title)]],
		my $chatMsg = pack('a4 a4 v2 C1 a* x1',
			$chatRooms{$ID}{ownerID}, $ID, $chatRooms{$ID}{limit},
			$chatRooms{$ID}{num_users}, $chatRooms{$ID}{public},
			stringToBytes($chatRooms{$ID}{title}));
		$data .= pack('C2 v', 0xD7, 0x00, length($chatMsg) + 4) . $chatMsg;
	}
	$client->send($data) if (length($data) > 0);
}

sub send_ground_skills {
	my ($self, $client) = @_;
	my $data = undef;
	foreach my $ID (@skillsID) {
		next if !defined($ID) || !$spells{$ID};
		$data .= pack('C2 a4 a4 v2 C2 x81', 0xC9, 0x01,
			$ID, $spells{$ID}{sourceID},
			$spells{$ID}{pos}{x}, $spells{$ID}{pos}{y}, $spells{$ID}{type},
			$spells{$ID}{fail});
	}
	$client->send($data) if (length($data) > 0);
}
sub send_friends_list {
	my ($self, $client) = @_;
	my $data = undef;
	my ($friendMsg, $friendOnlineMsg);
	foreach my $ID (@friendsID) {
		next if !defined($ID) || !$friends{$ID};
		$friendMsg .= pack('a4 a4 Z24',
			$friends{$ID}{accountID},
			$friends{$ID}{charID},
			stringToBytes($friends{$ID}{name}));
		if ($friends{$ID}{online}) {
			$friendOnlineMsg .= pack('C2 a4 a4 C',
				0x06, 0x02,
				$friends{$ID}{accountID},
				$friends{$ID}{charID},
				0);
		};
	}
	$data = pack('C2 v', 0x01, 0x02, length($friendMsg) + 4) . $friendMsg;
	$client->send($data);
	$client->send($friendOnlineMsg);
	undef $friendMsg;
	undef $friendOnlineMsg;
}	
sub send_pets {
	my ($self, $client) = @_;
	my $data = undef;
	foreach my $pet (@{$petsList->getItems()}) {
		my $coords = '';
		shiftPack(\$coords, $pet->{pos_to}{x}, 10);
		shiftPack(\$coords, $pet->{pos_to}{y}, 10);
		shiftPack(\$coords, $pet->{look}{body}, 4);
		$data .= $self->{recvPacketParser}->reconstruct({
			switch => 'actor_exists',
			walk_speed => $pet->{walk_speed} * 1000,
			coords => $coords,
			map { $_ => $pet->{$_} } qw(object_type ID type hair_style lv)
		});
	}
	$client->send($data) if (length($data) > 0);
}

sub send_monsters {
	my ($self, $client) = @_;
	my $data = undef;
	foreach my $monster (@{$monstersList->getItems()}) {
		my $coords = '';
		shiftPack(\$coords, $monster->{pos_to}{x}, 10);
		shiftPack(\$coords, $monster->{pos_to}{y}, 10);
		shiftPack(\$coords, $monster->{look}{body}, 4);
		$data .= $self->{recvPacketParser}->reconstruct({
			switch => 'actor_exists',
			walk_speed => $monster->{walk_speed} * 1000,
			coords => $coords,
			map { $_ => $monster->{$_} } qw(object_type ID opt1 opt2 option type lv)
		});
	}
	$client->send($data) if (length($data) > 0);
}

sub send_npcs {
	my ($self, $client) = @_;
	my $data = undef;
	foreach my $npc (@{$npcsList->getItems()}) {
		my $coords = '';
		shiftPack(\$coords, $npc->{pos}{x}, 10);
		shiftPack(\$coords, $npc->{pos}{y}, 10);
		shiftPack(\$coords, $npc->{look}{body}, 4);
		$data .= $self->{recvPacketParser}->reconstruct({
			switch => 'actor_exists',
			coords => $coords,
			map { $_ => $npc->{$_} } qw(object_type ID opt1 opt2 option type)
		});
	}
	$client->send($data) if (length($data) > 0);
}

sub send_portals {
	my ($self, $client) = @_;
	# Send portals info
	my $data = undef;
	my $switch = ($masterServer->{serverType} eq 'bRO')?'0857':'actor_exists';
	foreach my $portal (@{$portalsList->getItems()}) {
		my $coords = '';
		shiftPack(\$coords, $portal->{pos}{x}, 10);
		shiftPack(\$coords, $portal->{pos}{y}, 10);
		shiftPack(\$coords, 0, 4);
		$data .= $self->{recvPacketParser}->reconstruct({
			switch => $switch,
			coords => $coords,
			map { $_ => $portal->{$_} } qw(object_type ID type)
		});
	}
	$client->send($data) if (length($data) > 0);
}

sub send_ground_items {
	my ($self, $client) = @_;
	# Send info about items on the ground
	my $data = undef;
	foreach my $ID (@itemsID) {
		next if !defined($ID) || !$items{$ID};
		$data .= pack('C2 a4 v x v3 x2', 0x9D, 0x00,
			$ID, $items{$ID}{nameID},
			$items{$ID}{pos}{x}, $items{$ID}{pos}{y}, $items{$ID}{amount});
	}
	$client->send($data) if (length($data) > 0);
}

sub send_sit {
	my ($self, $client) = @_;
	# '08C8' => ['actor_action', 'a4 a4 a4 V3 x v C V', [qw(sourceID targetID tick src_speed dst_speed damage div type dual_wield_damage)]],
	$client->send($self->{recvPacketParser}->reconstruct({
			switch => 'actor_action',
			sourceID => $client->{session}{accountID},
			targetID => pack("V", 0),
			tick => pack("V", 9999),
			src_speed => 0,
			dst_speed => 0,
			damage => 0,
			div => 0,
			type => Network::PacketParser::ACTION_SIT,
			dual_wield_damage => 0
		}));
}

sub send_welcome {
	my ($self, $client) = @_;
	if (!$config{XKore_silent}) {
		$client->send($self->{recvPacketParser}->reconstruct({
			switch => 'system_chat',
			message => $Settings::welcomeText,
		}));
	}
}

sub send_player_info {
	my ($self, $client, $char) = @_;
	my $data = undef;
	
	# Player stats.
	$data = pack('C2 v1 C12 v12 x4',
		0xBD, 0x00,
		$char->{points_free},

		$char->{str}, $char->{points_str}, $char->{agi}, $char->{points_agi},
		$char->{vit}, $char->{points_vit}, $char->{int}, $char->{points_int}, $char->{dex},
		$char->{points_dex}, $char->{luk}, $char->{points_luk},

		$char->{attack}, $char->{attack_bonus},
		$char->{attack_magic_min}, $char->{attack_magic_max},
		$char->{def}, $char->{def_bonus},
		$char->{def_magic}, $char->{def_magic_bonus},
		$char->{hit},
		$char->{flee},
		$char->{flee_bonus}, $char->{critical}
	);
	$client->send($data);

	# More stats
	$data  = pack('C2 v V', 0xB0, 0x00, 0, $char->{walk_speed} * 1000);		# Walk speed
	$data .= pack('C2 v V', 0xB0, 0x00, 5, $char->{hp});				# Current HP
	$data .= pack('C2 v V', 0xB0, 0x00, 6, $char->{hp_max});			# Max HP
	$data .= pack('C2 v V', 0xB0, 0x00, 7, $char->{sp});				# Current SP
	$data .= pack('C2 v V', 0xB0, 0x00, 8, $char->{sp_max});			# Max SP
	$data .= pack('C2 v V', 0xB0, 0x00, 12, $char->{points_skill});		# Skill points left
	$data .= pack('C2 v V', 0xB0, 0x00, 24, $char->{weight} * 10);		# Current weight
	$data .= pack('C2 v V', 0xB0, 0x00, 25, $char->{weight_max} * 10);		# Max weight
	$data .= pack('C2 v V', 0xB0, 0x00, 53, $char->{attack_delay});		# Attack speed
	$client->send($data);

	# Base stat info (str, agi, vit, int, dex, luk) this time with bonus
	$data  = pack('C2 V3', 0x41, 0x01, 13, $char->{str}, $char->{str_bonus});
	$data .= pack('C2 V3', 0x41, 0x01, 14, $char->{agi}, $char->{agi_bonus});
	$data .= pack('C2 V3', 0x41, 0x01, 15, $char->{vit}, $char->{vit_bonus});
	$data .= pack('C2 V3', 0x41, 0x01, 16, $char->{int}, $char->{int_bonus});
	$data .= pack('C2 V3', 0x41, 0x01, 17, $char->{dex}, $char->{dex_bonus});
	$data .= pack('C2 V3', 0x41, 0x01, 18, $char->{luk}, $char->{luk_bonus});
	$client->send($data);

	# # Make the character face the correct direction
	$client->send(pack('C2 a4 C1 x1 C1', 0x9C, 0x00,
		$char->{ID}, $char->{look}{head}, $char->{look}{body})
	);

	# Send attack range
	$data  = pack('C2 v', 0x3A, 0x01, $char->{attack_range});
	# Send weapon/shield appearance
	$data .= pack('C2 a4 C v2', 0xD7, 0x01, $char->{ID}, 2, $char->{weapon}, $char->{shield});
	# Send status info
	$data .= pack('v a4 v3 x', 0x119, $char->{ID}, $char->{opt1}, $char->{opt2}, $char->{option});
	$client->send($data);
	
	if ($RunOnce) {
		foreach my $ID (keys %{$char->{statuses}}) {
			while (my ($statusID, $statusName) = each %statusHandle) {
				if ($ID eq $statusName) {
#					$data .= pack('C2 v a4 C', 0x96, 0x01, $statusID, $char->{ID}, 1);
					if ($statusID == 673) {
						# for Cart active
						$data .= pack('C2 v a4 C V4', 0x3F, 0x04, $statusID, $char->{ID}, 1, 9999, $char->cart->type, 0, 0);
					} elsif ($statusID == 622) {
						# sit
						$data .= pack('C2 v a4 C V4', 0x3F, 0x04, $statusID, $char->{ID}, 1, 9999, 1, 0, 0);
						$self->send_sit($client);
					} else {
						$data .= pack('C2 v a4 C', 0x96, 0x01, $statusID, $char->{ID}, 1);
					}
				}
			}
		}
	}
	
	$client->send($data) if (length($data) > 0);
	
	# Send spirit sphere information
	$data  = pack('C2 a4 v', 0xD0, 0x01, $char->{ID}, $char->{spirits}) if ($char->{spirits});
	# Send exp-required-to-level-up info
	$data .= pack('C2 v V', 0xB1, 0x00, 22, $char->{exp_max});
	$data .= pack('C2 v V', 0xB1, 0x00, 23, $char->{exp_job_max});
	$client->send($data);
	
	# Send skill information
	$data = undef;
	foreach my $ID (@skillsID) {
		$data .= pack('v2 x2 v3 a24 C',
			$char->{skills}{$ID}{ID}, $char->{skills}{$ID}{targetType},
			$char->{skills}{$ID}{lv}, $char->{skills}{$ID}{sp},
			$char->{skills}{$ID}{range}, $ID, $char->{skills}{$ID}{up});
	}
	$data = pack('C2 v', 0x0F, 0x01, length($data) + 4) . $data;
	$client->send($data);
	
	# Send Hotkeys
	if ($hotkeyList) {
		$data = undef;
		if(@{$hotkeyList} <= 28) { # todo: there is also 07D9,254
			$data .=  pack('v', 0x02B9); # old interface (28 hotkeys)
		} else {
			$data .=  pack('v', 0x07D9); # renewal interface as of: RagexeRE_2009_06_10a (38 hotkeys)
		}
		for (my $i = 0; $i < @{$hotkeyList}; $i++) {
			$data .= pack('C V v', $hotkeyList->[$i]->{type}, $hotkeyList->[$i]->{ID}, $hotkeyList->[$i]->{lv});
		}
		$client->send($data) if (@{$hotkeyList});
	}
	
	# Send info about items on the ground
	$data = undef;
	foreach my $ID (@itemsID) {
		next if !defined($ID) || !$items{$ID};
		$data .= pack('C2 a4 v x v3 x2', 0x9D, 0x00,
			$ID, $items{$ID}{nameID},
			$items{$ID}{pos}{x}, $items{$ID}{pos}{y}, $items{$ID}{amount});
	}
	$client->send($data) if (length($data) > 0);
	
	
	# # Send info about surrounding players
	foreach my $player (@{$playersList->getItems()}) {
		my $coords = '';
		shiftPack(\$coords, $player->{pos_to}{x}, 10);
		shiftPack(\$coords, $player->{pos_to}{y}, 10);
		shiftPack(\$coords, $player->{look}{body}, 4);
		$data .= pack('C2 a4 v4 x2 v8 x2 v a4 a4 v x2 C2 a3 x2 C v',
			0x2A, 0x02, $player->{ID}, $player->{walk_speed} * 1000,
			$player->{opt1}, $player->{opt2}, $player->{option},
			$player->{jobID}, $player->{hair_style}, $player->{weapon}, $player->{shield},
			$player->{headgear}{low}, $player->{headgear}{top}, $player->{headgear}{mid},
			$player->{hair_color}, $player->{look}{head}, $player->{guildID}, $player->{emblemID},
			$player->{opt3}, $player->{stance}, $player->{sex}, $coords,
			($player->{dead}? 1 : ($player->{sitting}? 2 : 0)), $player->{lv});
	}
	$client->send($data) if (length($data) > 0);
}

sub send_inventory {
	my ($self, $client, $char) = @_;
	my $data = undef;
	# Send cart information includeing the items
	if (!$client->{session}{dummy} && $char->cartActive && $RunOnce) {
		$data = pack('C2 v2 V2', 0x21, 0x01, $char->cart->items, $char->cart->items_max, ($char->cart->weight * 10), ($char->cart->weight_max * 10));
		$client->send($data);
		
		my @stackable;
		my @nonstackable;
		my $n = 0;
		foreach my $item (@{$char->cart->getItems()}) {
			$item->{index} = $i;#TEST
			if ($item->{type} <= 3 || $item->{type} == 6 || $item->{type} == 10 || $item->{type} == 16 || $item->{type} == 17 || $item->{type} == 19) {
				push @stackable, $item;
			} else {
				push @nonstackable, $item;
			}
		}
		
		# Send stackable item information
		$data = undef;
		$n = 0;
		foreach my $item (@stackable) {
			$data .= pack('v2 C2 v2 a8 l',
				$item->{index},
				$item->{nameID},
				$item->{type},
				$item->{identified},  # identified
				$item->{amount},
				$item->{type_equip},
				$item->{cards},
				$item->{expire},
			);
			$n++;
		}
		$data = pack('C2 v', 0xE9, 0x02, length($data) + 4) . $data;
		$client->send($data) if ($n > 0);
		
		# Send non-stackable item information
		$data = undef;
		$n = 0;
		foreach my $item (@nonstackable) {
			$data .= pack('v2 C2 v2 C2 a8 l v2',
				$item->{index},
				$item->{nameID},
				$item->{type},
				$item->{identified},  # identified
				$item->{type_equip},
				$item->{equipped},
				$item->{broken},
				$item->{upgrade},
				$item->{cards},
				$item->{expire},
				$item->{bindOnEquipType},
				$item->{sprite_id},
			);
			$n++;
		}
		$data = pack('C2 v', 0xD2, 0x02, length($data) + 4) . $data;
		$client->send($data) if ($n > 0);
	}

		# Sort items into stackable and non-stackable
	if (UNIVERSAL::isa($char, 'Actor::You')) {
		my @stackable;
		my @nonstackable;
		foreach my $item (@{$char->inventory->getItems()}) {
			if ($item->{type} <= 3 || $item->{type} == 6 || $item->{type} == 10 || $item->{type} == 16 || $item->{type} == 17 || $item->{type} == 19) {
				push @stackable, $item;
			} else {
				push @nonstackable, $item;
			}
		}

		# Send stackable item information
		$data = undef;
		foreach my $item (@stackable) {
			$data .= pack('v2 C2 v1 x2',
				$item->{index},
				$item->{nameID},
				$item->{type},
				1,  # identified
				$item->{amount}
			);
		}
		$data = pack('C2 v', 0xA3, 0x00, length($data) + 4) . $data;
		$client->send($data);

		# Send non-stackable item (mostly equipment) information
		$data = undef;
		foreach my $item (@nonstackable) {
			$data .= pack('v2 C2 v2 C2 a8',
				$item->{index}, $item->{nameID}, $item->{type},
				$item->{identified}, $item->{type_equip}, $item->{equipped}, $item->{broken},
				$item->{upgrade}, $item->{cards});
		}
		$data = pack('C2 v', 0xA4, 0x00, length($data) + 4) . $data;
		$client->send($data);
	}
	
	# Send equipped arrow information
	$client->send(pack('C2 v', 0x3C, 0x01, $char->{arrow})) if ($char->{arrow});
}

sub send_npc_info {
	my ($self, $client) = @_;
	my $data = undef;
	my $switch = ($masterServer->{serverType} eq 'bRO')?'0857':'actor_exists';
	
	foreach my $npc (@{$npcsList->getItems()}) {
		my $coords = '';
		shiftPack(\$coords, $npc->{pos}{x}, 10);
		shiftPack(\$coords, $npc->{pos}{y}, 10);
		shiftPack(\$coords, $npc->{look}{body}, 4);
		$data .= $self->{recvPacketParser}->reconstruct({
			switch => $switch,
			coords => $coords,
			map { $_ => $npc->{$_} } qw(object_type ID opt1 opt2 option type)
		});
	}
	$client->send($data) if (length($data) > 0);
}

sub send_avoid_sprite_error_hack {
	my ($self, $client, $char) = @_;
	my $data = pack('C15', 0x29, 0x02, 0xA7, 0x94, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x40);
	$client->send($data);
	$data = $self->{recvPacketParser}->reconstruct({
		switch => '0229',
		ID => $char->{ID},
		opt1 => $char->{opt1},
		opt2 => $char->{opt2},
		option => $char->{option},
		stance => $char->{stance}
	});
	$client->send($data);
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
			# BUGGY $client->send($args->{accountID});
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

sub restart {
	my ($self, $args, $client) = @_;
	# If they want to character select/respawn, kick them to the login screen
	# immediately (GM kick)
	$client->send(pack('C3', 0x81, 0, 15));
	
	$args->{mangle} = 2;
	$RunOnce = 1;
}

sub quit_request {
	my ($self, $args, $client) = @_;
	# Client wants to quit
	$client->send(pack('C*', 0x8B, 0x01, 0, 0));
	$args->{mangle} = 2;
	$RunOnce = 1;
}

sub sync {
	my ($self, $args, $client) = @_;
	# my $data = $self->{recvPacketParser}->reconstruct({
			# switch => 'received_sync',
			# time => getTickCount
		# });
	#$client->send($data);
	$args->{mangle} = 2;
}

sub request_cashitems {
	my ($self, $args, $client) = @_;
	$self->send_cash_list($client);
	$args->{mangle} = 2;
}

sub send_cash_list {
	my ($self, $client) = @_;
	# '08CA' => ['cashitem', 'v3 a*', [qw(len amount tabcode itemInfo)]],#-1
	return unless defined $cashShop{list};
	my $pack_string  = "v V";
	for (my $tab = 0; $tab < @{$cashShop{list}}; $tab++) {
		my $item_block;
		foreach my $item (@{$cashShop{list}[$tab]}) {
			$item_block .= pack($pack_string, $item->{item_id}, $item->{price});
			$self->send_cash_tab($client, $tab, \$item_block) if (length($item_block) >= (6*64));	
		}
		# send current tab
		# max tab size: 392 total and 384 item_block
		$self->send_cash_tab($client, $tab, \$item_block);
	}
}

sub send_cash_tab {
	my ($self, $client, $tab_code, $item_block) = @_;
	my $data = $self->{recvPacketParser}->reconstruct({
		switch => 'cash_shop_list',
		len => 8+length($$item_block),
		tabcode => $tab_code,
		amount => length($$item_block)/6,
		itemInfo => $$item_block
	});
	$$item_block = undef;
	$client->send($data) if (length($data) > 0);
}

# Not sure what these are, but don't let it get to the RO server.
sub less_effect {
	my ($self, $args, $client) = @_;
	$args->{mangle} = 2;
}

sub guild_check {
	my ($self, $args, $client) = @_;
	$args->{mangle} = 2;
}

sub guild_info_request {
	my ($self, $args, $client) = @_;
	$args->{mangle} = 2;
}

1;

