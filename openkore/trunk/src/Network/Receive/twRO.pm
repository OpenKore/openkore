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
use Globals;
use base qw(Network::Receive::ServerType0);
use Log qw(message warning error debug);
use Network::MessageTokenizer;
use I18N qw(bytesToString stringToBytes);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'006D' => ['character_creation_successful', 'a4 V9 v V2 v14 Z24 C6 v2', [qw(charID exp zeny exp_job lv_job opt1 opt2 option stance manner points_free hp hp_max sp sp_max walk_speed type hair_style weapon lv points_skill lowhead shield tophead midhead hair_color clothes_color name str agi vit int dex luk slot renameflag)]],
		'0097' => ['private_message', 'v Z28 Z*', [qw(len privMsgUser privMsg)]],
		'07FA' => ['inventory_item_removed', 'v3', [qw(reason index amount)]], #//0x07fa,8
		'097A' => ['quest_all_list2', 'v3 a*', [qw(len count unknown message)]],
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	my %handlers = qw(
		actor_moved 0856
		actor_exists 0857
		actor_connected 0858
		account_id 0283
		received_characters 082D
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

*parse_quest_update_mission_hunt = *Network::Receive::ServerType0::parse_quest_update_mission_hunt_v2;
*reconstruct_quest_update_mission_hunt = *Network::Receive::ServerType0::reconstruct_quest_update_mission_hunt_v2;

sub quest_all_list2 {
	my ($self, $args) = @_;
	$questList = {};
	my $msg;
	my ($questID, $active, $time_start, $time, $mission_amount);
	my $i = 0;
	my ($mobID, $count, $amount, $mobName);
	while ($i < $args->{RAW_MSG_SIZE} - 8) {
		$msg = substr($args->{message}, $i, 15);
		($questID, $active, $time_start, $time, $mission_amount) = unpack('V C V2 v', $msg);
		$questList->{$questID}->{active} = $active;
		debug "$questID $active\n", "info";
		
		my $quest = \%{$questList->{$questID}};
		$quest->{time_start} = $time_start;
		$quest->{time} = $time;
		$quest->{mission_amount} = $mission_amount;
		debug "$questID $time_start $time $mission_amount\n", "info";
		$i += 15;
		
		if ($mission_amount > 0) {
			for (my $j = 0 ; $j < $mission_amount ; $j++) {
				$msg = substr($args->{message}, $i, 32);
				($mobID, $count, $amount, $mobName) = unpack('V v2 Z24', $msg);
				my $mission = \%{$quest->{missions}->{$mobID}};
				$mission->{mobID} = $mobID;
				$mission->{count} = $count;
				$mission->{amount} = $amount;
				$mission->{mobName_org} = $mobName;
				$mission->{mobName} = bytesToString($mobName);
				debug "- $mobID $count / $amount $mobName\n", "info";
				$i += 32;
			}
		}
	}
}

1;