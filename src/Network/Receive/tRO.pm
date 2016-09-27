#################################################################################################
#  OpenKore - Network subsystem									#
#  This module contains functions for sending messages to the server.				#
#												#
#  This software is open source, licensed under the GNU General Public				#
#  License, version 2.										#
#  Basically, this means that you're allowed to modify and distribute				#
#  this software. However, if you distribute modified versions, you MUST			#
#  also distribute the source code.								#
#  See http://www.gnu.org/licenses/gpl.html for the full license.				#
#################################################################################################
# tRO (Thai)
package Network::Receive::tRO;
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
		'0276' => ['account_server_info', 'x2 a4 a4 a4 a4 a26 C a4 a*', [qw(sessionID accountID sessionID2 lastLoginIP lastLoginTime accountSex iAccountSID serverInfo)]],
		'006D' => ['character_creation_successful', 'a4 V9 v V2 v14 Z24 C6 v2 Z*', [qw(charID exp zeny exp_job lv_job opt1 opt2 option stance manner points_free hp hp_max sp sp_max walk_speed type hair_style weapon lv points_skill lowhead shield tophead midhead hair_color clothes_color name str agi vit int dex luk slot renameflag mapname)]],
		'0097' => ['private_message', 'v Z28 Z*', [qw(len privMsgUser privMsg)]],
		'082D' => ['received_characters_info', 'x2 C5 x20', [qw(normal_slot premium_slot billing_slot producible_slot valid_slot)]],
		'099B' => ['map_property3', 'v a4', [qw(type info_table)]],
		'099F' => ['area_spell_multiple2', 'v a*', [qw(len spellInfo)]], # -1
		'0A3B' => ['misc_effect', 'v a4 C v', [qw(len ID flag effect)]],
		'0990' => ['inventory_item_added', 'v3 C3 a8 V C2 V v', [qw(index amount nameID identified broken upgrade cards type_equip type fail expire bindOnEquipType)]],#31
		'0991' => ['inventory_items_stackable', 'v a*', [qw(len itemInfo)]],#-1
		'0992' => ['inventory_items_nonstackable', 'v a*', [qw(len itemInfo)]],#-1
		'0993' => ['cart_items_stackable', 'v a*', [qw(len itemInfo)]],#-1
		'0994' => ['cart_items_nonstackable', 'v a*', [qw(len itemInfo)]],#-1
		'0995' => ['storage_items_stackable', 'v Z24 a*', [qw(len title itemInfo)]],#-1
		'0996' => ['storage_items_nonstackable', 'v Z24 a*', [qw(len title itemInfo)]],#-1
		'0A7B' => ['gameguard_request', 'v a*', [qw(len data)]],#-1
		'085A' => ['sync_request_ex'],
		'085B' => ['sync_request_ex'],
		'085C' => ['sync_request_ex'],
		'085D' => ['sync_request_ex'],
		'085E' => ['sync_request_ex'],
		'085F' => ['sync_request_ex'],
		'0860' => ['sync_request_ex'],
		'0861' => ['sync_request_ex'],
		'0862' => ['sync_request_ex'],
		'0863' => ['sync_request_ex'],
		'0864' => ['sync_request_ex'],
		'0865' => ['sync_request_ex'],
		'0866' => ['sync_request_ex'],
		'0867' => ['sync_request_ex'],
		'0868' => ['sync_request_ex'],
		'0869' => ['sync_request_ex'],
		'086A' => ['sync_request_ex'],
		'086B' => ['sync_request_ex'],
		'086C' => ['sync_request_ex'],
		'086D' => ['sync_request_ex'],
		'086E' => ['sync_request_ex'],
		'086F' => ['sync_request_ex'],
		'0870' => ['sync_request_ex'],
		'0871' => ['sync_request_ex'],
		'0872' => ['sync_request_ex'],
		'0873' => ['sync_request_ex'],
		'0874' => ['sync_request_ex'],
		'0875' => ['sync_request_ex'],
		'0876' => ['sync_request_ex'],
		'0877' => ['sync_request_ex'],
		'0878' => ['sync_request_ex'],
		'0879' => ['sync_request_ex'],
		'087A' => ['sync_request_ex'],
		'087B' => ['sync_request_ex'],
		'087C' => ['sync_request_ex'],
		'087D' => ['sync_request_ex'],
		'087E' => ['sync_request_ex'],
		'087F' => ['sync_request_ex'],
		'0880' => ['sync_request_ex'],
		'0881' => ['sync_request_ex'],
		'0882' => ['sync_request_ex'],
		'0883' => ['sync_request_ex'],
		'0917' => ['sync_request_ex'],
		'0918' => ['sync_request_ex'],
		'0919' => ['sync_request_ex'],
		'091A' => ['sync_request_ex'],
		'091B' => ['sync_request_ex'],
		'091C' => ['sync_request_ex'],
		'091D' => ['sync_request_ex'],
		'091E' => ['sync_request_ex'],
		'091F' => ['sync_request_ex'],
		'0920' => ['sync_request_ex'],
		'0921' => ['sync_request_ex'],
		'0922' => ['sync_request_ex'],
		'0923' => ['sync_request_ex'],
		'0924' => ['sync_request_ex'],
		'0925' => ['sync_request_ex'],
		'0926' => ['sync_request_ex'],
		'0927' => ['sync_request_ex'],
		'0928' => ['sync_request_ex'],
		'0929' => ['sync_request_ex'],
		'092A' => ['sync_request_ex'],
		'092B' => ['sync_request_ex'],
		'092C' => ['sync_request_ex'],
		'092D' => ['sync_request_ex'],
		'092E' => ['sync_request_ex'],
		'092F' => ['sync_request_ex'],
		'0930' => ['sync_request_ex'],
		'0931' => ['sync_request_ex'],
		'0932' => ['sync_request_ex'],
		'0933' => ['sync_request_ex'],
		'0934' => ['sync_request_ex'],
		'0935' => ['sync_request_ex'],
		'0936' => ['sync_request_ex'],
		'0937' => ['sync_request_ex'],
		'0938' => ['sync_request_ex'],
		'0939' => ['sync_request_ex'],
		'093A' => ['sync_request_ex'],
		'093B' => ['sync_request_ex'],
		'093C' => ['sync_request_ex'],
		'093D' => ['sync_request_ex'],
		'093E' => ['sync_request_ex'],
		'093F' => ['sync_request_ex'],
		'0940' => ['sync_request_ex']
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}
	$self->{nested} = {
		items_nonstackable => { # EQUIPMENTITEM_EXTRAINFO
			type6 => {
				len => 31,
				types => 'v2 C V2 C a8 l v2 C',
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
		'085A' => '0884',
		'085B' => '0885',
		'085C' => '0886',
		'085D' => '0887',
		'085E' => '0888',
		'085F' => '0889',
		'0860' => '088A',
		'0861' => '088B',
		'0862' => '088C',
		'0863' => '088D',
		'0864' => '088E',
		'0865' => '088F',
		'0866' => '0890',
		'0867' => '0891',
		'0868' => '0892',
		'0869' => '0893',
		'086A' => '0894',
		'086B' => '0895',
		'086C' => '0896',
		'086D' => '0897',
		'086E' => '0898',
		'086F' => '0899',
		'0870' => '089A',
		'0871' => '089B',
		'0872' => '089C',
		'0873' => '089D',
		'0874' => '089E',
		'0875' => '089F',
		'0876' => '08A0',
		'0877' => '08A1',
		'0878' => '08A2',
		'0879' => '08A3',
		'087A' => '08A4',
		'087B' => '08A5',
		'087C' => '08A6',
		'087D' => '08A7',
		'087E' => '08A8',
		'087F' => '08A9',
		'0880' => '08AA',
		'0881' => '08AB',
		'0882' => '08AC',
		'0883' => '08AD',
		'0917' => '0941',
		'0918' => '0942',
		'0919' => '0943',
		'091A' => '0944',
		'091B' => '0945',
		'091C' => '0946',
		'091D' => '0947',
		'091E' => '0948',
		'091F' => '0949',
		'0920' => '094A',
		'0921' => '094B',
		'0922' => '094C',
		'0923' => '094D',
		'0924' => '094E',
		'0925' => '094F',
		'0926' => '0950',
		'0927' => '0951',
		'0928' => '0952',
		'0929' => '0953',
		'092A' => '0954',
		'092B' => '0955',
		'092C' => '0956',
		'092D' => '0957',
		'092E' => '0958',
		'092F' => '0959',
		'0930' => '095A',
		'0931' => '095B',
		'0932' => '095C',
		'0933' => '095D',
		'0934' => '095E',
		'0935' => '095F',
		'0936' => '0960',
		'0937' => '0961',
		'0938' => '0962',
		'0939' => '0963',
		'093A' => '0964',
		'093B' => '0965',
		'093C' => '0966',
		'093D' => '0967',
		'093E' => '0968',
		'093F' => '0969',
		'0940' => '096A'
	};
	return $self;
}

*parse_quest_update_mission_hunt = *Network::Receive::parse_quest_update_mission_hunt_v2;
*reconstruct_quest_update_mission_hunt = *Network::Receive::reconstruct_quest_update_mission_hunt_v2;

sub gameguard_request {
	my ($self, $args) = @_;

	message T ("Receive Gameguard!\n");
	my $msg = pack('v*', length($args->{data}) + 4, 0xA7B, $args->{len}) . $args->{data};
	$self->{net}->{xkore_socket}->send($msg);
	my $msg2;
	$self->{net}->{xkore_socket}->recv($msg2, 2);
	my $newSize = unpack('v', $msg2);
	$self->{net}->{xkore_socket}->recv($msg2, $newSize);
	
	$messageSender->sendToServer($msg2);
	#$messageSender->sendToServer(pack('H*', 'this for your remote 0A7C gen'));
	
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

	if ($args->{switch} eq '0992' ||# inventory
		$args->{switch} eq '0994' ||# cart
		$args->{switch} eq '0996'	# storage
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


1;