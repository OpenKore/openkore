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

package Network::Receive::twRO;

use strict;
use base qw(Network::Receive::ServerType0);
use Globals qw($char @skillsID);
use Log qw(message);
use Translation;
use Utils;
use Utils::DataStructures;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0097' => ['private_message', 'v Z24 V Z*', [qw(len privMsgUser flag privMsg)]], # -1
		'009D' => ['item_exists', 'a4 V C v3 C2', [qw(ID nameID identified x y amount subx suby)]],
		'01C8' => ['item_used', 'a2 V a4 v C', [qw(ID itemID actorID remaining success)]],
		'07FD' => ['special_item_obtain', 'v C V c/Z a*', [qw(len type nameID holder etc)]], # record "c/Z" (holder) means: if the first byte ('c') = 24(dec), then Z24, if 'c' = 18(dec), then Z18, еtc.
		'09FD' => ['actor_moved', 'v C a4 a4 v3 V v2 V2 v V v6 a4 a2 v V C2 a6 C2 v2 V2 C v Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font maxHP HP isBoss opt4 name)]],
		'09FE' => ['actor_connected', 'v C a4 a4 v3 V v2 V2 v7 a4 a2 v V C2 a3 C2 v2 V2 C v Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font maxHP HP isBoss opt4 name)]],
		'09FF' => ['actor_exists', 'v C a4 a4 v3 V v2 V2 v7 a4 a2 v V C2 a3 C3 v2 V2 C v Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize state lv font maxHP HP isBoss opt4 name)]],
		'0A09' => ['deal_add_other', 'V C V C3 a16 a25', [qw(nameID type amount identified broken upgrade cards options)]],
		'0A0A' => ['storage_item_added', 'a2 V V C4 a16 a25', [qw(ID amount nameID type identified broken upgrade cards options)]],
		'0A0B' => ['cart_item_added', 'a2 V V C4 a16 a25', [qw(ID amount nameID type identified broken upgrade cards options)]],
		'0A37' => ['inventory_item_added', 'a2 v V C3 a16 V C2 a4 v a25 C v', [qw(ID amount nameID identified broken upgrade cards type_equip type fail expire unknown options favorite viewID)]],
		'0ADD' => ['item_appeared', 'a4 V v C v2 C2 v C v', [qw(ID nameID type identified x y subx suby amount show_effect effect_type )]],
		'0B32' => ['skills_list'],
		'0B18' => ['inventory_expansion_result', 'v', [qw(result)]], #
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	my %handlers = qw(
		inventory_expansion_result 0B18
		received_characters 099D
		received_characters_info 082D
		skills_list 0B32
		sync_received_characters 09A0
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->{vender_items_list_item_pack} = 'V v2 C V C3 a16 a25';
	$self->{npc_store_info_pack} = "V V C V";
	$self->{buying_store_items_list_pack} = "V v C V";
	$self->{makable_item_list_pack} = "V4";
	$self->{npc_market_info_pack} = "V C V2 v";

	return $self;
}

sub skills_list {
	my ($self, $args) = @_;

	return unless Network::Receive::changeToInGameState();

	my $msg = $args->{RAW_MSG};

	# TODO: per-actor, if needed at all
	# Skill::DynamicInfo::clear;
	my ($ownerType, $hook, $actor) = @{{
		'0B32' => [Skill::OWNER_CHAR, 'packet_charSkills'],
	}->{$args->{switch}}};

	my $skillsIDref = $actor ? \@{$actor->{slave_skillsID}} : \@skillsID;
	delete @{$char->{skills}}{@$skillsIDref};
	@$skillsIDref = ();

	# TODO: $actor can be undefined here
	undef @{$actor->{slave_skillsID}};
	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += 15) {
		my ($ID, $targetType, $lv, $sp, $range, $up, $lv2) = unpack 'v V v3 C v', substr $msg, $i, 15;
		my $handle ||= Skill->new(idn => $ID)->getHandle;

		@{$char->{skills}{$handle}}{qw(ID targetType lv sp range up)} = ($ID, $targetType, $lv, $sp, $range, $up);
		# $char->{skills}{$handle}{lv} = $lv unless $char->{skills}{$handle}{lv};

		binAdd($skillsIDref, $handle) unless defined binFind($skillsIDref, $handle);
		Skill::DynamicInfo::add($ID, $handle, $lv, $sp, $range, $targetType, $ownerType);

		Plugins::callHook($hook, {
			ID => $ID,
			handle => $handle,
			level => $lv,
			upgradable => $up,
			level2 => $lv2,
		});
	}
}

#expand_inventory_result
use constant {
	EXPAND_INVENTORY_RESULT_SUCCESS => 0x0,
	EXPAND_INVENTORY_RESULT_FAILED => 0x1,
	EXPAND_INVENTORY_RESULT_OTHER_WORK => 0x2,
	EXPAND_INVENTORY_RESULT_MISSING_ITEM => 0x3,
	EXPAND_INVENTORY_RESULT_MAX_SIZE => 0x4,
};

sub inventory_expansion_result {
	my($self, $args) = @_;
#msgstringtable
	if ($args->{result} == EXPAND_INVENTORY_RESULT_SUCCESS) {
		message TF("You have successfully expanded the possession limit"),"info";
	} elsif ($args->{result} == EXPAND_INVENTORY_RESULT_FAILED) {
		message TF("Failed to expand the maximum possession limit."),"info";
	} elsif ($args->{result} == EXPAND_INVENTORY_RESULT_OTHER_WORK) {
		message TF("To expand the possession limit, please close other windows"),"info";
	} elsif ($args->{result} == EXPAND_INVENTORY_RESULT_MISSING_ITEM) {
		message TF("Failed to expand the maximum possession limit, insufficient required item"),"info";
	} elsif ($args->{result} == EXPAND_INVENTORY_RESULT_MAX_SIZE) {
		message TF("You can no longer expand the maximum possession limit."),"info";
	}
}

1;
