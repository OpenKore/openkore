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
# idRO (Indonesia)
# Servertype overview: http://wiki.openkore.com/index.php/ServerType
package Network::Receive::idRO;

use strict;
use base qw(Network::Receive::ServerType0);
use Globals qw(%config $messageSender %timeout);
use I18N qw(bytesToString);
use Log qw(debug message);
use Misc qw(chatLog monsterName stripLanguageCode);
use Time::HiRes qw(time);
use Translation;
use Utils qw(getHex timeOut);

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

sub system_chat {
	my ($self, $args) = @_;
	my $message = bytesToString($args->{message});
	my $prefix;
	my $color;

	if ($message =~ s/^ssss//g) {  # forces color yellow, or WoE indicator?
		$prefix = T('[WoE]');
	} elsif ($message =~ /^micc.{24}([0-9A-Fa-f]{6})(.*)/) { #appears in idRO: [micc][23_chars_name][\x00\x00][color][name][blablabla][message]
		$color = $1;
		$message = $2;
		$prefix = T('[S]');
	} elsif ($message =~ s/^blue//g) {  # forces color blue
		$prefix = T('[S]');
	} elsif ($message =~ /^tool([0-9a-fA-F]{6})(.*)/) {
		$color = $1;
		$message = $2;
		$prefix = T('[S]');
	} else {
		$prefix = T('[S]');
	}
	$message =~ s/\000//g; # remove null charachters
	$message =~ s/^ +//g; $message =~ s/ +$//g; # remove whitespace in the beginning and the end of $message
	stripLanguageCode(\$message);
	chatLog("s", "$message\n") if ($config{logSystemChat});
	# Translation Comment: System/GM chat
	message "$prefix $message\n", "schat";
	ChatQueue::add('gm', undef, undef, $message) if ($config{callSignGM});

	Plugins::callHook('packet_sysMsg', {
		Msg => $message,
		MsgColor => $color,
		MsgUser => undef # TODO: implement this value, we can get this from "micc" messages by regex.
	});
}

*parse_quest_update_mission_hunt = *Network::Receive::parse_quest_update_mission_hunt_v2;
*reconstruct_quest_update_mission_hunt = *Network::Receive::reconstruct_quest_update_mission_hunt_v2;

1;
