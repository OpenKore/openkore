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
	# Sync Ex Reply Array 
	$self->{sync_ex_reply} = {
		'085A', '0884', '085B', '0885', '085C', '0886', '085D', '0887', '085E', '0888', '085F', '0889', '0860', '088A', '0861', '088B', '0862', '088C', '0863',
		'088D', '0864', '088E', '0865', '088F', '0866', '0890', '0867', '0891', '0868', '0892', '0869', '0893', '086A', '0894', '086B', '0895', '086C', '0896', 
		'086D', '0897', '086E', '0898', '086F', '0899', '0870', '089A', '0871', '089B', '0872', '089C', '0873', '089D', '0874', '089E', '0875', '089F', '0876', 
		'08A0', '0877', '08A1', '0878', '08A2', '0879', '08A3', '087A', '08A4', '087B', '08A5', '087C', '08A6', '087D', '08A7', '087E', '08A8', '087F', '08A9', 
		'0880', '08AA', '0881', '08AB', '0882', '08AC', '0883', '08AD', '0917', '0941', '0918', '0942', '0919', '0943', '091A', '0944', '091B', '0945', '091C', 
		'0946', '091D', '0947', '091E', '0948', '091F', '0949', '0920', '094A', '0921', '094B', '0922', '094C', '0923', '094D', '0924', '094E', '0925', '094F', 
		'0926', '0950', '0927', '0951', '0928', '0952', '0929', '0953', '092A', '0954', '092B', '0955', '092C', '0956', '092D', '0957', '092E', '0958', '092F', 
		'0959', '0930', '095A', '0931', '095B', '0932', '095C', '0933', '095D', '0934', '095E', '0935', '095F', '0936', '0960', '0937', '0961', '0938', '0962', 
		'0939', '0963', '093A', '0964', '093B', '0965', '093C', '0966', '093D', '0967', '093E', '0968', '093F', '0969', '0940', '096A',
	};
	
	foreach my $key (keys %{$self->{sync_ex_reply}}) { $packets{$key} = ['sync_request_ex']; }
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
