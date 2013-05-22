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
	%config $questList %cart
);
use Base::Ragnarok::MapServer;
use base qw(Base::Ragnarok::MapServer);
use Network::MessageTokenizer;
use I18N qw(stringToBytes);
use Utils qw(shiftPack);

use Log qw(debug);

my $RunOnce = 1;

# Overrided method.
sub onClientNew {
	my ($self, $client, $index) = @_;
	$self->SUPER::onClientNew($client, $index);

	# In here we store messages that the RO client wants to
	# send to the server.
	$client->{outbox} = new Network::MessageTokenizer($self->getRecvPackets());
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

	my $output = '';

	# Player stats.
	$output .= pack('C2 v1 C12 v12 x4',
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
	$client->send($output);

	# More stats
	$output  = pack('C2 v V', 0xB0, 0x00, 0, $char->{walk_speed} * 1000);		# Walk speed
	$output .= pack('C2 v V', 0xB0, 0x00, 5, $char->{hp});				# Current HP
	$output .= pack('C2 v V', 0xB0, 0x00, 6, $char->{hp_max});			# Max HP
	$output .= pack('C2 v V', 0xB0, 0x00, 7, $char->{sp});				# Current SP
	$output .= pack('C2 v V', 0xB0, 0x00, 8, $char->{sp_max});			# Max SP
	$output .= pack('C2 v V', 0xB0, 0x00, 12, $char->{points_skill});		# Skill points left
	$output .= pack('C2 v V', 0xB0, 0x00, 24, $char->{weight} * 10);		# Current weight
	$output .= pack('C2 v V', 0xB0, 0x00, 25, $char->{weight_max} * 10);		# Max weight
	$output .= pack('C2 v V', 0xB0, 0x00, 53, $char->{attack_delay});		# Attack speed
	$client->send($output);

	# Base stat info (str, agi, vit, int, dex, luk) this time with bonus
	$output  = pack('C2 V3', 0x41, 0x01, 13, $char->{str}, $char->{str_bonus});
	$output .= pack('C2 V3', 0x41, 0x01, 14, $char->{agi}, $char->{agi_bonus});
	$output .= pack('C2 V3', 0x41, 0x01, 15, $char->{vit}, $char->{vit_bonus});
	$output .= pack('C2 V3', 0x41, 0x01, 16, $char->{int}, $char->{int_bonus});
	$output .= pack('C2 V3', 0x41, 0x01, 17, $char->{dex}, $char->{dex_bonus});
	$output .= pack('C2 V3', 0x41, 0x01, 18, $char->{luk}, $char->{luk_bonus});
	$client->send($output);

	# Make the character face the correct direction
	$client->send(pack('C2 a4 C1 x1 C1', 0x9C, 0x00,
		$char->{ID}, $char->{look}{head}, $char->{look}{body})
	);

	# Send attack range
	$output  = pack('C2 v', 0x3A, 0x01, $char->{attack_range});
	# Send weapon/shield appearance
	$output .= pack('C2 a4 C v2', 0xD7, 0x01, $char->{ID}, 2, $char->{weapon}, $char->{shield});
	# Send status info
	$output .= pack('C2 a4 v3 x', 0x19, 0x01, $char->{ID}, $char->{opt1}, $char->{opt2}, $char->{option});
	$client->send($output);


	# Send more status information
	# TODO: Find a faster/better way of doing this? This seems cumbersome.
	$output = '';
	if ($RunOnce) {
		foreach my $ID (keys %{$char->{statuses}}) {
			while (my ($statusID, $statusName) = each %statusHandle) {
				if ($ID eq $statusName) {
#					$output .= pack('C2 v a4 C', 0x96, 0x01, $statusID, $char->{ID}, 1);
					if ($statusID == 673) {
						# for Cart active
						$output .= pack('C2 v a4 C V4', 0x3F, 0x04, $statusID, $char->{ID}, 1, 9999, $cart{type}, 0, 0);
					} else {
						$output .= pack('C2 v a4 C', 0x96, 0x01, $statusID, $char->{ID}, 1);
					}
				}
			}
		}
	}
	$client->send($output) if (length($output) > 0);

	# Send spirit sphere information
	$output  = pack('C2 a4 v', 0xD0, 0x01, $char->{ID}, $char->{spirits}) if ($char->{spirits});
	# Send exp-required-to-level-up info
	$output .= pack('C2 v V', 0xB1, 0x00, 22, $char->{exp_max});
	$output .= pack('C2 v V', 0xB1, 0x00, 23, $char->{exp_job_max});
	$client->send($output);

	# Send skill information
	$output = '';
	foreach my $ID (@skillsID) {
		$output .= pack('v2 x2 v3 a24 C',
			$char->{skills}{$ID}{ID}, $char->{skills}{$ID}{targetType},
			$char->{skills}{$ID}{lv}, $char->{skills}{$ID}{sp},
			$char->{skills}{$ID}{range}, $ID, $char->{skills}{$ID}{up});
	}
	$output = pack('C2 v', 0x0F, 0x01, length($output) + 4) . $output;
	$client->send($output);
	
	# Send Hotkeys
	if ($hotkeyList) {
		$output = '';
		if(@{$hotkeyList} <= 28) { # todo: there is also 07D9,254
			$output .=  pack('v', 0x02B9); # old interface (28 hotkeys)
		} else {
			$output .=  pack('v', 0x07D9); # renewal interface as of: RagexeRE_2009_06_10a (38 hotkeys)
		}
		for (my $i = 0; $i < @{$hotkeyList}; $i++) {
			$output .= pack('C V v', $hotkeyList->[$i]->{type}, $hotkeyList->[$i]->{ID}, $hotkeyList->[$i]->{lv});
		}
		$client->send($output) if (@{$hotkeyList});
	}

	# Send cart information includeing the items
	if ($char->cartActive && $RunOnce) {
		$output = pack('C2 v2 V2', 0x21, 0x01, $cart{items}, $cart{items_max}, ($cart{weight} * 10), ($cart{weight_max} * 10));
		$client->send($output);
		
		my @stackable;
		my @nonstackable;
		my $n = 0;
		for (my $i = 0; $i < @{$cart{'inventory'}}; $i++) {
			next if (!$cart{'inventory'}[$i] || !%{$cart{'inventory'}[$i]});
			my $item = $cart{'inventory'}[$i];
			$item->{index} = $i;
			if ($item->{type} <= 3 || $item->{type} == 6 || $item->{type} == 10 || $item->{type} == 16 || $item->{type} == 17 || $item->{type} == 19) {
				push @stackable, $item;
			} else {
				push @nonstackable, $item;
			}
		}
		
		# Send stackable item information
		$output = '';
		$n = 0;
		foreach my $item (@stackable) {
			$output .= pack('v2 C2 v2 a8 l',
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
		$output = pack('C2 v', 0xE9, 0x02, length($output) + 4) . $output;
		$client->send($output) if ($n > 0);
		
		# Send non-stackable item information
		$output = '';
		$n = 0;
		foreach my $item (@nonstackable) {
			$output .= pack('v2 C2 v2 C2 a8 l v2',
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
		$output = pack('C2 v', 0xD2, 0x02, length($output) + 4) . $output;
		$client->send($output) if ($n > 0);
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
		$output = '';
		foreach my $item (@stackable) {
			$output .= pack('v2 C2 v1 x2',
				$item->{index},
				$item->{nameID},
				$item->{type},
				1,  # identified
				$item->{amount}
			);
		}
		$output = pack('C2 v', 0xA3, 0x00, length($output) + 4) . $output;
		$client->send($output);

		# Send non-stackable item (mostly equipment) information
		$output = '';
		foreach my $item (@nonstackable) {
			$output .= pack('v2 C2 v2 C2 a8',
				$item->{index}, $item->{nameID}, $item->{type},
				$item->{identified}, $item->{type_equip}, $item->{equipped}, $item->{broken},
				$item->{upgrade}, $item->{cards});
		}
		$output = pack('C2 v', 0xA4, 0x00, length($output) + 4) . $output;
		$client->send($output);
	}
	
	# Send equipped arrow information
	$client->send(pack('C2 v', 0x3C, 0x01, $char->{arrow})) if ($char->{arrow});

	# Send info about items on the ground
	$output = '';
	foreach my $ID (@itemsID) {
		next if !defined($ID) || !$items{$ID};
		$output .= pack('C2 a4 v x v3 x2', 0x9D, 0x00,
			$ID, $items{$ID}{nameID},
			$items{$ID}{pos}{x}, $items{$ID}{pos}{y}, $items{$ID}{amount});
	}
	$client->send($output) if (length($output) > 0);

	# Send all portal info
	$output = '';
	foreach my $portal (@{$portalsList->getItems()}) {
		my $coords = '';
		shiftPack(\$coords, $portal->{pos}{x}, 10);
		shiftPack(\$coords, $portal->{pos}{y}, 10);
		shiftPack(\$coords, 0, 4);
		$output .= $self->{recvPacketParser}->reconstruct({
			switch => 'actor_exists',
			coords => $coords,
			map { $_ => $portal->{$_} } qw(object_type ID type)
		});
	}
	$client->send($output) if (length($output) > 0);

	# Send all NPC info
	$output = '';
	foreach my $npc (@{$npcsList->getItems()}) {
		my $coords = '';
		shiftPack(\$coords, $npc->{pos}{x}, 10);
		shiftPack(\$coords, $npc->{pos}{y}, 10);
		shiftPack(\$coords, $npc->{look}{body}, 4);
		$output .= $self->{recvPacketParser}->reconstruct({
			switch => 'actor_exists',
			coords => $coords,
			map { $_ => $npc->{$_} } qw(object_type ID opt1 opt2 option type)
		});
	}
	$client->send($output) if (length($output) > 0);

	# Send all monster info
	$output = '';
	foreach my $monster (@{$monstersList->getItems()}) {
		my $coords = '';
		shiftPack(\$coords, $monster->{pos_to}{x}, 10);
		shiftPack(\$coords, $monster->{pos_to}{y}, 10);
		shiftPack(\$coords, $monster->{look}{body}, 4);
		$output .= $self->{recvPacketParser}->reconstruct({
			switch => 'actor_exists',
			walk_speed => $monster->{walk_speed} * 1000,
			coords => $coords,
			map { $_ => $monster->{$_} } qw(object_type ID opt1 opt2 option type lv)
		});
	}
	$client->send($output) if (length($output) > 0);

	# Send info about pets
	$output = '';
	foreach my $pet (@{$petsList->getItems()}) {
		my $coords = '';
		shiftPack(\$coords, $pet->{pos_to}{x}, 10);
		shiftPack(\$coords, $pet->{pos_to}{y}, 10);
		shiftPack(\$coords, $pet->{look}{body}, 4);
		$output .= $self->{recvPacketParser}->reconstruct({
			switch => 'actor_exists',
			walk_speed => $pet->{walk_speed} * 1000,
			coords => $coords,
			map { $_ => $pet->{$_} } qw(object_type ID type hair_style lv)
		});
	}
	$client->send($output) if (length($output) > 0);

	# Send info about surrounding players
	$output = '';
	foreach my $player (@{$playersList->getItems()}) {
		my $coords = '';
		shiftPack(\$coords, $player->{pos_to}{x}, 10);
		shiftPack(\$coords, $player->{pos_to}{y}, 10);
		shiftPack(\$coords, $player->{look}{body}, 4);
		$output .= pack('C2 a4 v4 x2 v8 x2 v a4 a4 v x2 C2 a3 x2 C v',
			0x2A, 0x02, $player->{ID}, $player->{walk_speed} * 1000,
			$player->{opt1}, $player->{opt2}, $player->{option},
			$player->{jobID}, $player->{hair_style}, $player->{weapon}, $player->{shield},
			$player->{headgear}{low}, $player->{headgear}{top}, $player->{headgear}{mid},
			$player->{hair_color}, $player->{look}{head}, $player->{guildID}, $player->{emblemID},
			$player->{opt3}, $player->{stance}, $player->{sex}, $coords,
			($player->{dead}? 1 : ($player->{sitting}? 2 : 0)), $player->{lv});
	}
	$client->send($output) if (length($output) > 0);

	# Send vendor list
	$output = '';
	foreach my $ID (@venderListsID) {
		next if !defined($ID) || !$venderLists{$ID};
		$output .= pack('C2 a4 a30 x50', 0x31, 0x01, $ID, stringToBytes($venderLists{$ID}{title}));
	}
	$client->send($output) if (length($output) > 0);

	# Send chatrooms
	$output = '';
	foreach my $ID (@chatRoomsID) {
		next if !defined($ID) || !$chatRooms{$ID} || !$chatRooms{$ID}{ownerID};
		# '00D7' => ['chat_info', 'x2 a4 a4 v1 v1 C1 a*', [qw(ownerID ID limit num_users public title)]],
		my $chatMsg = pack('a4 a4 v2 C1 a* x1',
			$chatRooms{$ID}{ownerID}, $ID, $chatRooms{$ID}{limit},
			$chatRooms{$ID}{num_users}, $chatRooms{$ID}{public},
			stringToBytes($chatRooms{$ID}{title}));
		$output .= pack('C2 v', 0xD7, 0x00, length($chatMsg) + 4) . $chatMsg;
	}
	$client->send($output) if (length($output) > 0);

	# Send active ground effect skills
	$output = '';
	foreach my $ID (@skillsID) {
		next if !defined($ID) || !$spells{$ID};
		$output .= pack('C2 a4 a4 v2 C2 x81', 0xC9, 0x01,
			$ID, $spells{$ID}{sourceID},
			$spells{$ID}{pos}{x}, $spells{$ID}{pos}{y}, $spells{$ID}{type},
			$spells{$ID}{fail});
	}
	$client->send($output) if (length($output) > 0);

	# Send friend list
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
	$output = pack('C2 v', 0x01, 0x02, length($friendMsg) + 4) . $friendMsg;
	$client->send($output);
	$client->send($friendOnlineMsg);
	undef $friendMsg;
	undef $friendOnlineMsg;

	# Send party list
	if ($char->{party}) {
		my $num = 0;
		$output = '';
		foreach my $ID (@partyUsersID) {
			next if !defined($ID) || !$char->{party}{users}{$ID};
			if (!$char->{party}{users}{$ID}{admin}) {
				$num++;
			}
			$output .= pack("a4 Z24 Z16 C2",
				$ID, stringToBytes($char->{party}{users}{$ID}{name}),
				$char->{party}{users}{$ID}{map},
				$char->{party}{users}{$ID}{admin} ? 0 : $num,
				1 - $char->{party}{users}{$ID}{online});
		}
		$output = pack('C2 v Z24', 0xFB, 0x00,
			length($output) + 28,
			stringToBytes($char->{party}{name})) .
			$output;
		$client->send($output);
	}

	# Send pet information
	if (defined $pet{ID}) {
		$output  = pack('C2 C a4 V', 0xA4, 0x01, 0, $pet{ID}, 0);
		$output .= pack('C2 C a4 V', 0xA4, 0x01, 5, $pet{ID}, 0x64);
		$output .= pack('C2 Z24 C v4', 0xA2, 0x01,
			stringToBytes($pet{name}), $pet{renameflag}, $pet{level},
			$pet{hungry}, $pet{friendly}, $pet{accessory});
		$client->send($output);
	}

	# Send guild info
	if ($char->{guildID}) {
		$output = pack('C2 V3 x5 Z24', 0x6C, 0x01,
			$char->{guildID}, $char->{guild}{emblem}, $char->{guild}{mode},
			stringToBytes($char->{guild}{name}));
		$client->send($output);
	}

	# Send quest/mission info
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
		$output = pack('C2 v V', 0xB1, 0x02, length($q_output) + 8, $k) . $q_output;
		$output .= pack('C2 v V', 0xB2, 0x02, length($m_output) + 8, $k) . $m_output;
		$client->send($output);
	}
	
	#Hack to Avoid Sprite Error Crash if you are level 99
	#This is acomplished by sending gm hide and unhiding again
	$output = pack('C15', 0x29, 0x02, 0xA7, 0x94, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x40);
	$client->send($output);
	
	#$output = pack('C15', 0x29, 0x02, 0xA7, 0x94, 0x04);
	$output = $self->{recvPacketParser}->reconstruct({
		switch => '0229',
		ID => $char->{ID},
		opt1 => $char->{opt1},
		opt2 => $char->{opt2},
		option => $char->{option},
		stance => $char->{stance}
	});
	$client->send($output);
	
	if ($config{verbose} && !$config{XKore_silent}) {
		$client->send($self->{recvPacketParser}->reconstruct({
			switch => 'system_chat',
			message => $Settings::welcomeText,
		}));
	}
	
	$args->{mangle} = 2;
	$RunOnce = 0;
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
	$args->{mangle} = 2;
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

