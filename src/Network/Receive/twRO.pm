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
use Log qw(message debug warning);
use Network::MessageTokenizer;
use Misc;
use Utils;
use Translation;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'006D' => ['character_creation_successful', 'a4 V9 v V2 v14 Z24 C6 v2 Z*', [qw(charID exp zeny exp_job lv_job opt1 opt2 option stance manner points_free hp hp_max sp sp_max walk_speed type hair_style weapon lv points_skill lowhead shield tophead midhead hair_color clothes_color name str agi vit int dex luk slot renameflag mapname)]],
		'0097' => ['private_message', 'v Z28 Z*', [qw(len privMsgUser privMsg)]],
		'082D' => ['received_characters_info', 'x2 C5 x20', [qw(normal_slot premium_slot billing_slot producible_slot valid_slot)]],
		'099B' => ['map_property3', 'v a4', [qw(type info_table)]],
		'099F' => ['area_spell_multiple2', 'v a*', [qw(len spellInfo)]], # -1
		'0A3B' => ['misc_effect', 'v a4 C v', [qw(len ID flag effect)]],
		'0A0C' => ['inventory_item_added', 'v3 C3 a8 V C2 V v', [qw(index amount nameID identified broken upgrade cards type_equip type fail expire bindOnEquipType)]],#31
		'0991' => ['inventory_items_stackable', 'v a*', [qw(len itemInfo)]],#-1
		'0A0D' => ['inventory_items_nonstackable', 'v a*', [qw(len itemInfo)]],#-1
		'0A0A' => ['storage_item_added', 'v V v C4 a8', [qw(index amount nameID type identified broken upgrade cards)]],
		'0A0B' => ['cart_item_added', 'v V v C x26 C2 a8', [qw(index amount nameID identified broken upgrade cards)]],
		'0993' => ['cart_items_stackable', 'v a*', [qw(len itemInfo)]],#-1
		'0A0F' => ['cart_items_nonstackable', 'v a*', [qw(len itemInfo)]],#-1
		'0995' => ['storage_items_stackable', 'v Z24 a*', [qw(len title itemInfo)]],#-1
		'0A10' => ['storage_items_nonstackable', 'v Z24 a*', [qw(len title itemInfo)]],#-1
		'094D' => ['sync_request_ex'],
		'0819' => ['sync_request_ex'],
		'0817' => ['sync_request_ex'],
		'0923' => ['sync_request_ex'],
		'0867' => ['sync_request_ex'],
		'0924' => ['sync_request_ex'],
		'087B' => ['sync_request_ex'],
		'0A5A' => ['sync_request_ex'],
		'088B' => ['sync_request_ex'],
		'088A' => ['sync_request_ex'],
		'08A2' => ['sync_request_ex'],
		'086B' => ['sync_request_ex'],
		'0366' => ['sync_request_ex'],
		'089D' => ['sync_request_ex'],
		'0281' => ['sync_request_ex'],
		'085C' => ['sync_request_ex'],
		'0897' => ['sync_request_ex'],
		'0957' => ['sync_request_ex'],
		'0871' => ['sync_request_ex'],
		'0952' => ['sync_request_ex'],
		'0944' => ['sync_request_ex'],
		'0893' => ['sync_request_ex'],
		'0939' => ['sync_request_ex'],
		'0863' => ['sync_request_ex'],
		'093A' => ['sync_request_ex'],
		'093C' => ['sync_request_ex'],
		'0919' => ['sync_request_ex'],
		'0873' => ['sync_request_ex'],
		'095B' => ['sync_request_ex'],
		'08A0' => ['sync_request_ex'],
		'085A' => ['sync_request_ex'],
		'0876' => ['sync_request_ex'],
		'0926' => ['sync_request_ex'],
		'087E' => ['sync_request_ex'],
		'0811' => ['sync_request_ex'],
		'092D' => ['sync_request_ex'],
		'0922' => ['sync_request_ex'],
		'0946' => ['sync_request_ex'],
		'07E4' => ['sync_request_ex'],
		'0955' => ['sync_request_ex'],
		'085E' => ['sync_request_ex'],
		'086E' => ['sync_request_ex'],
		'094F' => ['sync_request_ex'],
		'0935' => ['sync_request_ex'],
		'0872' => ['sync_request_ex'],
		'0367' => ['sync_request_ex'],
		'0927' => ['sync_request_ex'],
		'0966' => ['sync_request_ex'],
		'0950' => ['sync_request_ex'],
		'08A9' => ['sync_request_ex'],
		'088D' => ['sync_request_ex'],
		'0963' => ['sync_request_ex'],
		'0937' => ['sync_request_ex'],
		'087D' => ['sync_request_ex'],
		'0947' => ['sync_request_ex'],
		'02C4' => ['sync_request_ex'],
		'0933' => ['sync_request_ex'],
		'093D' => ['sync_request_ex'],
		'091F' => ['sync_request_ex'],
		'08AD' => ['sync_request_ex'],
		'0925' => ['sync_request_ex'],
		'0959' => ['sync_request_ex'],
		'0360' => ['sync_request_ex'],
		'0881' => ['sync_request_ex'],
		'092E' => ['sync_request_ex'],
		'0A68' => ['sync_request_ex'],
		'087C' => ['sync_request_ex'],
		'0921' => ['sync_request_ex'],
		'0896' => ['sync_request_ex'],
		'087A' => ['sync_request_ex'],
		'023B' => ['sync_request_ex'],
		'0875' => ['sync_request_ex'],
		'0882' => ['sync_request_ex'],
		'093E' => ['sync_request_ex'],
		'091C' => ['sync_request_ex'],
		'0945' => ['sync_request_ex'],
		'0890' => ['sync_request_ex'],
		'0931' => ['sync_request_ex'],
		'089C' => ['sync_request_ex'],
		'086F' => ['sync_request_ex'],
		'0866' => ['sync_request_ex'],
		'0869' => ['sync_request_ex'],
		'0956' => ['sync_request_ex'],
		'094C' => ['sync_request_ex'],
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	$self->{nested} = {
		items_nonstackable => { # EQUIPMENTITEM_EXTRAINFO
			type6 => {
				len => 57,
				types => 'v2 C V2 C a8 l v2 x26 C',
				keys => [qw(index nameID type type_equip equipped upgrade cards expire bindOnEquipType sprite_id flag)],
			},
		},
		items_stackable => { # ITEMLIST_NORMAL_ITEM
			type6 => {
				len => 24,
				types => 'v2 C v V a8 l C',
				keys => [qw(index nameID type amount type_equip cards expire flag)],
			},
		},
	};

	my %handlers = qw(
		actor_moved 0856
		actor_exists 0857
		actor_connected 0858
		account_id 0283
		received_characters 099D
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->{sync_ex_reply} = {
		'094D' => '0877',
		'0819' => '0874',
		'0817' => '0942',
		'0923' => '0938',
		'0867' => '088C',
		'0924' => '0202',
		'087B' => '087F',
		'0A5A' => '0365',
		'088B' => '093B',
		'088A' => '0885',
		'08A2' => '0361',
		'086B' => '07EC',
		'0366' => '096A',
		'089D' => '086A',
		'0281' => '0941',
		'085C' => '094A',
		'0897' => '0895',
		'0957' => '095A',
		'0871' => '093F',
		'0952' => '0920',
		'0944' => '092A',
		'0893' => '0368',
		'0939' => '0A69',
		'0863' => '0369',
		'093A' => '08AB',
		'093C' => '092F',
		'0919' => '091D',
		'0873' => '0967',
		'095B' => '022D',
		'08A0' => '085F',
		'085A' => '091B',
		'0876' => '0954',
		'0926' => '0962',
		'087E' => '0879',
		'0811' => '035F',
		'092D' => '0887',
		'0922' => '08A3',
		'0946' => '0362',
		'07E4' => '0918',
		'0955' => '0969',
		'085E' => '088F',
		'086E' => '089A',
		'094F' => '092B',
		'0935' => '0A6C',
		'0872' => '0880',
		'0367' => '0364',
		'0927' => '0438',
		'0966' => '0862',
		'0950' => '0936',
		'08A9' => '0965',
		'088D' => '0883',
		'0963' => '083C',
		'0937' => '086D',
		'087D' => '0949',
		'0947' => '0892',
		'02C4' => '0960',
		'0933' => '0864',
		'093D' => '0802',
		'091F' => '0437',
		'08AD' => '085B',
		'0925' => '0815',
		'0959' => '08A6',
		'0360' => '0951',
		'0881' => '0878',
		'092E' => '092C',
		'0A68' => '0961',
		'087C' => '0884',
		'0921' => '0865',
		'0896' => '0889',
		'087A' => '0943',
		'023B' => '0363',
		'0875' => '091E',
		'0882' => '08AC',
		'093E' => '0860',
		'091C' => '0891',
		'0945' => '0A5C',
		'0890' => '0894',
		'0931' => '086C',
		'089C' => '095E',
		'086F' => '0932',
		'0866' => '0930',
		'0869' => '089F',
		'0956' => '094B',
		'094C' => '0940',
	};

	return $self;
}

*parse_quest_update_mission_hunt = *Network::Receive::parse_quest_update_mission_hunt_v2;
*reconstruct_quest_update_mission_hunt = *Network::Receive::reconstruct_quest_update_mission_hunt_v2;

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

sub items_nonstackable {
	my ($self, $args) = @_;

	my $items = $self->{nested}->{items_nonstackable};

	if ($args->{switch} eq '0A0D' ||# inventory
		$args->{switch} eq '0A0F' ||# cart
		$args->{switch} eq '0A10'	# storage
	) {
		return $items->{type6};
	} else {
		warning "items_nonstackable: unsupported packet ($args->{switch})!\n";
	}
}

sub items_stackable {
	my ($self, $args) = @_;

	my $items = $self->{nested}->{items_stackable};

	if ($args->{switch} eq '0991' ||# inventory
		$args->{switch} eq '0993' ||# cart
		$args->{switch} eq '0995'	# storage
	) {
		return $items->{type6};

	} else {
		warning "items_stackable: unsupported packet ($args->{switch})!\n";
	}
}

sub parse_items_nonstackable {
	my ($self, $args) = @_;
	$self->parse_items($args, $self->items_nonstackable($args), sub {
		my ($item) = @_;
		$item->{amount} = 1 unless ($item->{amount});
#message "1 nameID = $item->{nameID}, flag = $item->{flag} >> ";
		if ($item->{flag} == 0) {
			$item->{broken} = $item->{identified} = 0;
		} elsif ($item->{flag} == 1 || $item->{flag} == 5) {
			$item->{broken} = 0;
			$item->{identified} = 1;
		} elsif ($item->{flag} == 3 || $item->{flag} == 7) {
			$item->{broken} = $item->{identified} = 1;
		} else {
			message T ("Warning: unknown flag!\n");
		}
#message "2 broken = $item->{broken}, identified = $item->{identified}\n";
	})
}

sub parse_items_stackable {
	my ($self, $args) = @_;
	$self->parse_items($args, $self->items_stackable($args), sub {
		my ($item) = @_;
		$item->{idenfitied} = $item->{identified} & (1 << 0);
		if ($item->{flag} == 0) {
			$item->{identified} = 0;
		} elsif ($item->{flag} == 1 || $item->{flag} == 3) {
			$item->{identified} = 1;
		} else {
			message T ("Warning: unknown flag!\n");
		}
	})
}

sub vending_start {
	my ($self, $args) = @_;

	my $msg = $args->{RAW_MSG};
	my $msg_size = unpack("v1",substr($msg, 2, 2));

	#started a shop.
	message TF("Shop '%s' opened!\n", $shop{title}), "success";
	@articles = ();
	# FIXME: why do we need a seperate variable to track how many items are left in the store?
	$articles = 0;

	# FIXME: Read the packet the server sends us to determine
	# the shop title instead of using $shop{title}.
	my $display = center(" $shop{title} ", 79, '-') . "\n" .
		T("#  Name                                   Type            Amount          Price\n");
	for (my $i = 8; $i < $msg_size; $i += 47) {
		my $number = unpack("v1", substr($msg, $i + 4, 2));
		my $item = $articles[$number] = {};
		$item->{nameID} = unpack("v1", substr($msg, $i + 9, 2));
		$item->{quantity} = unpack("v1", substr($msg, $i + 6, 2));
		$item->{type} = unpack("C1", substr($msg, $i + 8, 1));
		$item->{identified} = unpack("C1", substr($msg, $i + 11, 1));
		$item->{broken} = unpack("C1", substr($msg, $i + 12, 1));
		$item->{upgrade} = unpack("C1", substr($msg, $i + 13, 1));
		$item->{cards} = substr($msg, $i + 14, 8);
		$item->{price} = unpack("V1", substr($msg, $i, 4));
		$item->{name} = itemName($item);
		$articles++;

		debug ("Item added to Vender Store: $item->{name} - $item->{price} z\n", "vending", 2);

		$display .= swrite(
			"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<  @>>>>  @>>>>>>>>>>>z",
			[$articles, $item->{name}, $itemTypes_lut{$item->{type}}, formatNumber($item->{quantity}), formatNumber($item->{price})]);
	}
	$display .= ('-'x79) . "\n";
	message $display, "list";
	$shopEarned ||= 0;
}
1;