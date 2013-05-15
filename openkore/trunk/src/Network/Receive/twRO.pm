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
use Utils qw(timeOut getHex);
use Translation;
use I18N qw(bytesToString stringToBytes);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'006D' => ['character_creation_successful', 'a4 V9 v V2 v14 Z24 C6 v2 Z*', [qw(charID exp zeny exp_job lv_job opt1 opt2 option stance manner points_free hp hp_max sp sp_max walk_speed type hair_style weapon lv points_skill lowhead shield tophead midhead hair_color clothes_color name str agi vit int dex luk slot renameflag mapname)]],
		'0097' => ['private_message', 'v Z28 Z*', [qw(len privMsgUser privMsg)]],
		'082D' => ['characters_slots_info', 'v C5 x20', [qw(packet_len normal_slot premium_slot billing_slot producible_slot valid_slot)]],
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
	$charSvrSet{sync_Count} = $args->{sync_Count} if (exists $args->{sync_Count});

	if ($config{'XKore'} ne '1') {
		# FIXME twRO client really sends only one sync_received_characters?
		$messageSender->sendToServer($messageSender->reconstruct({switch => 'sync_received_characters'}));
	}
}

sub characters_slots_info {
	my ($self, $args) = @_;

	$charSvrSet{packet_len} = $args->{packet_len} if (exists $args->{packet_len});
	$charSvrSet{normal_slot} = $args->{normal_slot} if (exists $args->{normal_slot});
	$charSvrSet{premium_slot} = $args->{premium_slot} if (exists $args->{premium_slot});
	$charSvrSet{billing_slot} = $args->{billing_slot} if (exists $args->{billing_slot});
	$charSvrSet{producible_slot} = $args->{producible_slot} if (exists $args->{producible_slot});
	$charSvrSet{valid_slot} = $args->{valid_slot} if (exists $args->{valid_slot});

	$timeout{charlogin}{time} = time;
}

sub message_string { #twRO msgtable
	my ($self, $args) = @_;

	if (@msgTable[$args->{msg_id}++]) { # show message from msgstringtable
		warning T(@msgTable[$args->{msg_id}++]."\n");
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
1;