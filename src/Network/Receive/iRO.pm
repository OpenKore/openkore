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

use Globals qw($messageSender %timeout);
use Log qw(debug);
use Misc qw(monsterName);
use Utils qw(timeOut);

use Time::HiRes qw(time);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'006D' => ['character_creation_successful', 'a4 V9 v V2 v14 Z24 C6 v2', [qw(charID exp zeny exp_job lv_job opt1 opt2 option stance manner points_free hp hp_max sp sp_max walk_speed type hair_style weapon lv points_skill lowhead shield tophead midhead hair_color clothes_color name str agi vit int dex luk slot renameflag)]],
		'0097' => ['private_message', 'v Z24 V Z*', [qw(len privMsgUser flag privMsg)]], # -1
		'082D' => ['received_characters_info', 'x2 C5 x20', [qw(normal_slot premium_slot billing_slot producible_slot valid_slot)]],
		'099D' => ['received_characters', 'x2 a*', [qw(charInfo)]],
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
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