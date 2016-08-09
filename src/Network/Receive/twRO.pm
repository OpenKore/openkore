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

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	# Settings::addTableFile(Settings::getRecvPacketsFilename(),
	# loader => [\&parseRecvpackets, \%rpackets]);
	
	#new packets
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
		
		'0953' => ['sync_request_ex'],
		'094E' => ['sync_request_ex'],
		'0893' => ['sync_request_ex'],
		'093B' => ['sync_request_ex'],
		'089F' => ['sync_request_ex'],
		'0867' => ['sync_request_ex'],
		'094D' => ['sync_request_ex'],
		'0817' => ['sync_request_ex'],
		'08A1' => ['sync_request_ex'],
		'0899' => ['sync_request_ex'],
		'087B' => ['sync_request_ex'],
		'0877' => ['sync_request_ex'],
		'08A7' => ['sync_request_ex'],
		'0958' => ['sync_request_ex'],
		'083C' => ['sync_request_ex'],
		'087E' => ['sync_request_ex'],
		'0883' => ['sync_request_ex'],
		'0868' => ['sync_request_ex'],
		'0802' => ['sync_request_ex'],
		'087A' => ['sync_request_ex'],
		'0884' => ['sync_request_ex'],
		'0366' => ['sync_request_ex'],
		'091E' => ['sync_request_ex'],
		'0941' => ['sync_request_ex'],
		'0369' => ['sync_request_ex'],
		'086A' => ['sync_request_ex'],
		'094C' => ['sync_request_ex'],
		'095F' => ['sync_request_ex'],
		'0368' => ['sync_request_ex'],
		'0A5A' => ['sync_request_ex'],
		'089E' => ['sync_request_ex'],
		'0950' => ['sync_request_ex'],
		'0892' => ['sync_request_ex'],
		'0961' => ['sync_request_ex'],
		'0865' => ['sync_request_ex'],
		'0936' => ['sync_request_ex'],
		'0360' => ['sync_request_ex'],
		'088D' => ['sync_request_ex'],
		'0944' => ['sync_request_ex'],
		'0932' => ['sync_request_ex'],
		'0A68' => ['sync_request_ex'],
		'08AA' => ['sync_request_ex'],
		'093E' => ['sync_request_ex'],
		'0946' => ['sync_request_ex'],
		'0951' => ['sync_request_ex'],
		'0919' => ['sync_request_ex'],
		'087D' => ['sync_request_ex'],
		'095E' => ['sync_request_ex'],
		'0967' => ['sync_request_ex'],
		'0920' => ['sync_request_ex'],
		'08AD' => ['sync_request_ex'],
		'0890' => ['sync_request_ex'],
		'0918' => ['sync_request_ex'],
		'0888' => ['sync_request_ex'],
		'086B' => ['sync_request_ex'],
		'093C' => ['sync_request_ex'],
		'093D' => ['sync_request_ex'],
		'0880' => ['sync_request_ex'],
		'0931' => ['sync_request_ex'],
		'0963' => ['sync_request_ex'],
		'0928' => ['sync_request_ex'],
		'087C' => ['sync_request_ex'],
		'0962' => ['sync_request_ex'],
		'085A' => ['sync_request_ex'],
		'091A' => ['sync_request_ex'],
		'086F' => ['sync_request_ex'],
		'0885' => ['sync_request_ex'],
		'0965' => ['sync_request_ex'],
		'0935' => ['sync_request_ex'],
		'0882' => ['sync_request_ex'],
		'0364' => ['sync_request_ex'],
		'0954' => ['sync_request_ex'],
		'0895' => ['sync_request_ex'],
		'0969' => ['sync_request_ex'],
		'089B' => ['sync_request_ex'],
		'0933' => ['sync_request_ex'],
		'085F' => ['sync_request_ex'],
		'0881' => ['sync_request_ex'],
		'0869' => ['sync_request_ex'],
		'088B' => ['sync_request_ex'],
		'0864' => ['sync_request_ex'],
		'094F' => ['sync_request_ex'],
		'0934' => ['sync_request_ex'],
		'095C' => ['sync_request_ex'],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	$self->{sync_ex_reply} = {
		'0953' => '0437',
		'094E' => '0926',
		'0893' => '0860',
		'093B' => '0871',
		'089F' => '08A0',
		'0867' => '089A',
		'094D' => '085B',
		'0817' => '0960',
		'08A1' => '0929',
		'0899' => '0894',
		'087B' => '088E',
		'0877' => '0955',
		'08A7' => '0A69',
		'0958' => '08A4',
		'083C' => '0875',
		'087E' => '0896',
		'0883' => '094A',
		'0868' => '0952',
		'0802' => '0966',
		'087A' => '092D',
		'0884' => '0835',
		'0366' => '0891',
		'091E' => '0811',
		'0941' => '0921',
		'0369' => '0A6C',
		'086A' => '0878',
		'094C' => '0367',
		'095F' => '0872',
		'0368' => '088A',
		'0A5A' => '07E4',
		'089E' => '0A5C',
		'0950' => '0A6E',
		'0892' => '085E',
		'0961' => '035F',
		'0865' => '091C',
		'0936' => '095D',
		'0360' => '089C',
		'088D' => '02C4',
		'0944' => '0957',
		'0932' => '0874',
		'0A68' => '0925',
		'08AA' => '0949',
		'093E' => '086C',
		'0946' => '0873',
		'0951' => '0923',
		'0919' => '093F',
		'087D' => '0862',
		'095E' => '0436',
		'0967' => '0438',
		'0920' => '092F',
		'08AD' => '0886',
		'0890' => '0879',
		'0918' => '094B',
		'0888' => '0968',
		'086B' => '0927',
		'093C' => '092C',
		'093D' => '08A3',
		'0880' => '0939',
		'0931' => '023B',
		'0963' => '086E',
		'0928' => '0945',
		'087C' => '085C',
		'0962' => '022D',
		'085A' => '0887',
		'091A' => '0943',
		'086F' => '0924',
		'0885' => '0917',
		'0965' => '0202',
		'0935' => '0866',
		'0882' => '08AC',
		'0364' => '0937',
		'0954' => '092E',
		'0895' => '0819',
		'0969' => '0922',
		'089B' => '0897',
		'0933' => '0942',
		'085F' => '092A',
		'0881' => '08A9',
		'0869' => '07EC',
		'088B' => '086D',
		'0864' => '0815',
		'094F' => '088C',
		'0934' => '093A',
		'095C' => '088F',
	};
	
	#New item type6
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
	
	return $self;
}

*parse_quest_update_mission_hunt = *Network::Receive::parse_quest_update_mission_hunt_v2;
*reconstruct_quest_update_mission_hunt = *Network::Receive::reconstruct_quest_update_mission_hunt_v2;

sub gameguard_request {
	my ($self, $args) = @_;

	debug "NProtect request received\n", "NProtect";
	return if ($config{NProtect} && $config{NProtect} == 0);

	if ($config{NProtect} == 1 || !$config{NProtect}) { #Re-log
		my $relogSecond = $timeout{'NProtect_relog_second'}{'timeout'} || 3; # 1 - 3 seconds
		error TF("NProtect check request received. Re-loging in %s seconds.\n", $relogSecond), 'info';
		
		#Re-logging in after random sec
		$taskManager->add(
			new Task::Chained(tasks => [
				new Task::Wait(seconds => rand(int($timeout{'NProtect_relog_delay'}{'timeout'})) + 1 || 5),
				new Task::Function(function => sub {relog(rand($relogSecond) + 1);$_[0]->setDone;})
			])
		);
	}
}

sub sync_received_characters {
	my ($self, $args) = @_;
	if (exists $args->{sync_Count}) {
		$charSvrSet{sync_Count} = $args->{sync_Count};
		$charSvrSet{sync_CountDown} = $args->{sync_Count};
	}

	if ($config{'XKore'} ne '1') {
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
		return $items->{type6} ;
	}
	#Exception
	warning "items_nonstackable: unsupported packet ($args->{switch})!\n";
}

sub items_stackable {
	my ($self, $args) = @_;
	my $items = $self->{nested}->{items_stackable};

	if ($args->{switch} eq '0991' ||# inventory
		$args->{switch} eq '0993' ||# cart
		$args->{switch} eq '0995'	# storage
	) {
		return $items->{type6};
	}
	#Exception
	warning "items_stackable: unsupported packet ($args->{switch})!\n";
}

sub parse_items_nonstackable {
	my ($self, $args) = @_;
	$self->parse_items($args, $self->items_nonstackable($args), sub {
		my ($item) = @_;
		
		$item->{amount} = 1 unless ($item->{amount});
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
	});
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
	});
}

1;