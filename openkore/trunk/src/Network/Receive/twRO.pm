#########################################################################
#  OpenKore - Network subsystem
#  Copyright (c) 2006 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# twRO (Taiwan)
# Servertype overview: http://wiki.openkore.com/index.php/ServerType
package Network::Receive::twRO;

use strict;
use Time::HiRes;

use Globals;
use base qw(Network::Receive::ServerType0);
use Log qw(message warning error debug);
use Network::MessageTokenizer;
use Misc;
use Utils;
use Translation;
use I18N qw(bytesToString stringToBytes);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'006D' => ['character_creation_successful', 'a4 V9 v V2 v14 Z24 C6 v2 Z*', [qw(charID exp zeny exp_job lv_job opt1 opt2 option stance manner points_free hp hp_max sp sp_max walk_speed type hair_style weapon lv points_skill lowhead shield tophead midhead hair_color clothes_color name str agi vit int dex luk slot renameflag mapname)]],
		'0097' => ['private_message', 'v Z28 Z*', [qw(len privMsgUser privMsg)]],
		'082D' => ['received_characters_info', 'x2 C5 x20', [qw(normal_slot premium_slot billing_slot producible_slot valid_slot)]],
		'08FF' => ['actor_status_active2', 'a4 v V4', [qw(ID type tick unknown1 unknown2 unknown3)]],
		'099B' => ['map_property3', 'v a4', [qw(type info_table)]],
		'099F' => ['area_spell_multiple2', 'v a*', [qw(len spellInfo)]], # -1
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	my %handlers = qw(
		actor_moved 0856
		actor_exists 0857
		actor_connected 0858
		account_id 0283
		received_characters 099D
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

*parse_quest_update_mission_hunt = *Network::Receive::ServerType0::parse_quest_update_mission_hunt_v2;
*reconstruct_quest_update_mission_hunt = *Network::Receive::ServerType0::reconstruct_quest_update_mission_hunt_v2;

sub sync_received_characters {
	my ($self, $args) = @_;
	if (exists $args->{sync_Count}) {
		$charSvrSet{sync_Count} = $args->{sync_Count};
		$charSvrSet{sync_CountDown} = $args->{sync_Count};
	}

	if ($config{'XKore'} ne '1') {
		# FIXME twRO client really sends only one sync_received_characters?
		$messageSender->sendToServer($messageSender->reconstruct({switch => 'sync_received_characters'}));
		$charSvrSet{sync_CountDown}--;
	}
}

sub received_characters_info {
	my ($self, $args) = @_;

	$charSvrSet{normal_slot} = $args->{normal_slot} if (exists $args->{normal_slot});
	$charSvrSet{premium_slot} = $args->{premium_slot} if (exists $args->{premium_slot});
	$charSvrSet{billing_slot} = $args->{billing_slot} if (exists $args->{billing_slot});
	$charSvrSet{producible_slot} = $args->{producible_slot} if (exists $args->{producible_slot});
	$charSvrSet{valid_slot} = $args->{valid_slot} if (exists $args->{valid_slot});

	$timeout{charlogin}{time} = time;
}

sub message_string { #twRO msgtable
	my ($self, $args) = @_;

	if ($msgTable[++$args->{msg_id}]) { # show message from msgstringtable
		warning T($msgTable[$args->{msg_id}]."\n");
		$self->mercenary_off() if ($args->{msg_id} >= 1267 && $args->{msg_id} <= 1270);

	} else {
		if ($args->{msg_id} == 1267) {
			message T("Mercenary soldier's duty hour is over.\n"), "info";
			$self->mercenary_off ();

		} elsif ($args->{msg_id} == 1268) {
			message T("Your mercenary soldier has been killed.\n"), "info";
			$self->mercenary_off ();

		} elsif ($args->{msg_id} == 1269) {
			message T("Your mercenary soldier has been fired.\n"), "info";
			$self->mercenary_off ();

		} elsif ($args->{msg_id} == 1270) {
			message T("Your mercenary soldier has ran away.\n"), "info";
			$self->mercenary_off ();

		} elsif ($args->{msg_id} ==	1358) {
			message T("View player equip request denied.\n"), "info";

		} elsif ($args->{msg_id} == 1712) {
			warning T("You need to be at least base level 10 to send private messages.\n"), "info";

		} elsif ($args->{msg_id} == 1924) {
			warning T("Please try again after the current operation (i.e. NPC chat, crafting)\n"), "info";

		} elsif ($args->{msg_id} == 1774) {
			warning T("You cannot equip this item due to the level required\n"), "info";

		} elsif ($args->{msg_id} == 1775) {
			warning T("You cannot use this item due to the level required\n"), "info";

		} else {
			warning TF("msg_id: %s gave unknown results in: %s\n", $args->{msg_id}, $self->{packet_list}{$args->{switch}}->[0]);
		}
	}
}

#08FF
sub actor_status_active2 {
	my ($self, $args) = @_;

	return unless Network::Receive::changeToInGameState();
	my ($type, $ID, $tick, $unknown1, $unknown2, $unknown3) = @{$args}{qw(type ID tick unknown1 unknown2 unknown3)};
	my $status = defined $statusHandle{$type} ? $statusHandle{$type} : "UNKNOWN_STATUS_$type";
	$cart{type} = $unknown1 if ($type == 673 && defined $unknown1 && ($ID eq $accountID)); # for Cart active
	$args->{skillName} = defined $statusName{$status} ? $statusName{$status} : $status;
	($args->{actor} = Actor::get($ID))->setStatus($status, 1, $tick == 9999 ? undef : $tick, $args->{unknown1});
}

#099B
sub map_property3 {
	my ($self, $args) = @_;

	if($config{'status_mapType'}){
		$char->setStatus(@$_) for map {[$_->[1], $args->{type} == $_->[0]]}
		grep { $args->{type} == $_->[0] || $char->{statuses}{$_->[1]} }
		map {[$_, defined $mapTypeHandle{$_} ? $mapTypeHandle{$_} : "UNKNOWN_MAPTYPE_$_"]}
		0 .. List::Util::max $args->{type}, keys %mapTypeHandle;
	}

	$pvp = {6 => 1, 8 => 2, 19 => 3}->{$args->{type}};
	if ($pvp) {
		Plugins::callHook('pvp_mode', {
			pvp => $pvp # 1 PvP, 2 GvG, 3 Battleground
		});
	}
}

#099F
sub area_spell_multiple2 {
	my ($self, $args) = @_;

	# Area effect spells; including traps!
	my $len = $args->{len} - 4;
	my $spellInfo = $args->{spellInfo};
	my $msg = "";
	my $binID;
	my ($ID, $sourceID, $x, $y, $type, $range, $fail);
	for (my $i = 0; $i < $len; $i += 18) {
		$msg = substr($spellInfo, $i, 18);
		($ID, $sourceID, $x, $y, $type, $range, $fail) = unpack('a4 a4 v3 X2 C2', $msg);

		if ($spells{$ID} && $spells{$ID}{'sourceID'} eq $sourceID) {
			$binID = binFind(\@spellsID, $ID);
			$binID = binAdd(\@spellsID, $ID) if ($binID eq "");
		} else {
			$binID = binAdd(\@spellsID, $ID);
		}
	
		$spells{$ID}{'sourceID'} = $sourceID;
		$spells{$ID}{'pos'}{'x'} = $x;
		$spells{$ID}{'pos'}{'y'} = $y;
		$spells{$ID}{'pos_to'}{'x'} = $x;
		$spells{$ID}{'pos_to'}{'y'} = $y;
		$spells{$ID}{'binID'} = $binID;
		$spells{$ID}{'type'} = $type;
		if ($type == 0x81) {
			message TF("%s opened Warp Portal on (%d, %d)\n", getActorName($sourceID), $x, $y), "skill";
		}
		debug "Area effect ".getSpellName($type)." ($binID) from ".getActorName($sourceID)." appeared on ($x, $y)\n", "skill", 2;
	}

	Plugins::callHook('packet_areaSpell', {
		fail => $fail,
		sourceID => $sourceID,
		type => $type,
		x => $x,
		y => $y
	});
}

1;