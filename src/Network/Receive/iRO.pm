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
# iRO (International)
# Servertype overview: http://wiki.openkore.com/index.php/ServerType
package Network::Receive::iRO;

use strict;
use base qw(Network::Receive::ServerType0);

use Globals qw($messageSender %timeout @articles $articles %shop %itemTypes_lut $shopEarned $venderID $venderCID %config @venderItemList);
use Log qw(message debug);
use Misc qw(center itemName);
use Translation qw(T TF);
use Utils qw(formatNumber swrite timeOut);

use Time::HiRes qw(time);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		# TODO: character_creation_successful should be the same as char_block
		'006D' => ['character_creation_successful', 'a4 V9 v V2 v14 Z24 C6 CC x2 Z16 x16 C', [qw(charID exp zeny exp_job lv_job opt1 opt2 option stance manner points_free hp hp_max sp sp_max walk_speed jobID hair_style weapon lv points_skill lowhead shield tophead midhead hair_color clothes_color name str agi vit int dex luk slot renameflag mapName sex)]],
		'0097' => ['private_message', 'v Z24 V Z*', [qw(len privMsgUser flag privMsg)]], # -1
		'082D' => ['received_characters_info', 'x2 C5 x20', [qw(normal_slot premium_slot billing_slot producible_slot valid_slot)]],
		'099D' => ['received_characters', 'x2 a*', [qw(charInfo)]],
		'0A23' => ['achievement_list', 'v v V V v V V', [qw(len ach_count total_points rank current_rank_points next_rank_points)]], # -1
		'0A24' => ['achievement_update', 'V v VVV C V10 V C', [qw(total_points rank current_rank_points next_rank_points ach_id completed objective1 objective2 objective3 objective4 objective5 objective6 objective7 objective8 objective9 objective10 completed_at reward)]], # 66
		'0A26' => ['achievement_reward_ack', 'C V', [qw(received ach_id)]], # 7
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

=pod
struct packet_achievement_update {
	uint16 packet_id;  2
	uint32 total_points; 4
	uint16 rank; 2
	uint32 current_rank_points; 4
	uint32 next_rank_points; 4
	struct ach_list_info ach;
} __attribute__((packed));

struct ach_list_info {
	uint32 ach_id; 4
	uint8 completed; 1
	uint32 objective[MAX_ACHIEVEMENT_OBJECTIVES]; 4*10
	uint32 completed_at; 4
	uint8 reward; 1
} __attribute__((packed));

struct packet_achievement_list {
	uint16 packet_id;
	uint16 packet_len;
	uint32 total_achievements;
	uint32 total_points;
	uint16 rank;
	uint32 current_rank_points;
	uint32 next_rank_points;
	struct ach_list_info ach[MAX_ACHIEVEMENT_DB];
} __attribute__((packed));

struct packet_achievement_reward_ack {
	uint16 packet_id;
	uint8 received;
	uint32 ach_id;
} __attribute__((packed));
=cut

sub achievement_list {
	my ($self, $args) = @_;
	
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	my $headerlen = 22;
	my $achieve_len = 50;

	my @achieves;
	
	for (my $i = $headerlen; $i < $args->{RAW_MSG_SIZE}; $i+=$achieve_len) {
		my $achieve = {};

		($achieve->{ach_id},
		$achieve->{completed},
		$achieve->{objective1},
		$achieve->{objective2},
		$achieve->{objective3},
		$achieve->{objective4},
		$achieve->{objective5},
		$achieve->{objective6},
		$achieve->{objective7},
		$achieve->{objective8},
		$achieve->{objective9},
		$achieve->{objective10},
		$achieve->{completed_at},
		$achieve->{reward})	= unpack('V C V10 V C', substr($msg, $i, $achieve_len));
		push(@achieves, $achieve);
	}
	use Data::Dumper;
	Log::warning "[test dump achiev4] => ".Dumper(\@achieves);
}

sub achievement_update {
	my ($self, $args) = @_;
	
	my %achieve;
	@achieve{qw(ach_id completed objective1 objective2 objective3 objective4 objective5 objective6 objective7 objective8 objective9 objective10 completed_at reward)} = @{$args}{qw(ach_id completed objective1 objective2 objective3 objective4 objective5 objective6 objective7 objective8 objective9 objective10 completed_at reward)};
	
	use Data::Dumper;
	Log::warning "[test dump achiev1] => ".Dumper($args);
	Log::warning "[test dump achiev2] => ".Dumper(\%achieve);
}

sub achievement_reward_ack {
	my ($self, $args) = @_;
	use Data::Dumper;
	Log::warning "[test dump achiev3] => ".Dumper($args);
}

# The packet number didn't change, but the length of the packet did, and
# there's no good way to detect which version we're using based on the data
# the server sends to us.
sub vending_start {
	my ($self, $args) = @_;

	my $msg = $args->{RAW_MSG};
	my $msg_size = unpack("v1",substr($msg, 2, 2));

	#started a shop.
	message TF("Shop '%s' opened!\n", $shop{title}), "success";
	@articles = ();
	# FIXME: why do we need a seperate variable to track how many items are left in the store?
	$articles = 0;

	my $display = center(" $shop{title} ", 79, '-') . "\n" .
		T("#  Name                                       Type        Amount          Price\n");
	for (my $i = 8; $i < $msg_size; $i += 47) {
	    my $item = {};
	    @$item{qw( price number quantity type nameID identified broken upgrade cards options )} = unpack 'V v v C v C C C a8 a25', substr $msg, $i, 47;
		$item->{name} = itemName($item);
	    $articles[delete $item->{number}] = $item;
		$articles++;

		debug ("Item added to Vender Store: $item->{name} - $item->{price} z\n", "vending", 2);

		$display .= swrite(
			"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<< @>>>>> @>>>>>>>>>>>>z",
			[$articles, $item->{name}, $itemTypes_lut{$item->{type}}, formatNumber($item->{quantity}), formatNumber($item->{price})]);
	}
	$display .= ('-'x79) . "\n";
	message $display, "list";
	$shopEarned ||= 0;
}

sub vender_items_list {
	my ($self, $args) = @_;

	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	my $headerlen = 12;

	undef @venderItemList;
	$venderID = $args->{venderID};
	$venderCID = $args->{venderCID};
	my $player = Actor::get($venderID);

	message TF("%s\n" .
		"#   Name                                      Type        Amount          Price\n",
		center(' Vender: ' . $player->nameIdx . ' ', 79, '-')), $config{showDomain_Shop} || 'list';
	for (my $i = $headerlen; $i < $args->{RAW_MSG_SIZE}; $i+=47) {
		my $item = {};
		my $index;

		($item->{price},
		$item->{amount},
		$index,
		$item->{type},
		$item->{nameID},
		$item->{identified}, # should never happen
		$item->{broken}, # should never happen
		$item->{upgrade},
		$item->{cards},
		$item->{options},
		) = unpack('V v2 C v C3 a8 a25', substr($args->{RAW_MSG}, $i, 47));

		$item->{name} = itemName($item);
		$venderItemList[$index] = $item;

		debug("Item added to Vender Store: $item->{name} - $item->{price} z\n", "vending", 2);

		Plugins::callHook('packet_vender_store', {
			venderID => $venderID,
			number => $index,
			name => $item->{name},
			amount => $item->{amount},
			price => $item->{price},
			upgrade => $item->{upgrade},
			cards => $item->{cards},
			options => $item->{options},
			type => $item->{type},
			id => $item->{nameID}
		});

		message(swrite(
			"@<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<< @>>>>> @>>>>>>>>>>>>z",
			[$index, $item->{name}, $itemTypes_lut{$item->{type}}, formatNumber($item->{amount}), formatNumber($item->{price})]),
			$config{showDomain_Shop} || 'list');
	}
	message("-------------------------------------------------------------------------------\n", $config{showDomain_Shop} || 'list');

	Plugins::callHook('packet_vender_store2', {
		venderID => $venderID,
		itemList => \@venderItemList
	});
}

sub received_characters_info {
	my ($self, $args) = @_;

	Scalar::Util::weaken(my $weak = $self);
	my $timeout = {timeout => 6, time => time};

	$self->{charSelectTimeoutHook} = Plugins::addHook('Network::serverConnect/special' => sub {
		if ($weak && timeOut($timeout)) {
			$weak->received_characters({charInfo => '', RAW_MSG_SIZE => 4});
		}
	});

	$self->{charSelectHook} = Plugins::addHook(charSelectScreen => sub {
		if ($weak) {
			Plugins::delHook(delete $weak->{charSelectTimeoutHook}) if $weak->{charSelectTimeoutHook};
		}
	});

	$timeout{charlogin}{time} = time;

	$self->received_characters($args);
}

sub npc_store_begin {
	my $self = shift;

	# The server won't let us move until we send the sell complete packet.
	$messageSender->{sell_mode} = 1;

	$self->SUPER::npc_store_begin(@_);
}

*parse_quest_update_mission_hunt = *Network::Receive::parse_quest_update_mission_hunt_v2;
*reconstruct_quest_update_mission_hunt = *Network::Receive::reconstruct_quest_update_mission_hunt_v2;

1;