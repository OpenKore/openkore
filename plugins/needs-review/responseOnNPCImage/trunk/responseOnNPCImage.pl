#########################################################################
# This software is open source, licensed under the GNU General Public
# License, version 2.
# Basically, this means that you're allowed to modify and distribute
# this software. However, if you distribute modified versions, you MUST
# also distribute the source code.
# See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
#
# responseOnNPCImage v2
#
# Copyright 2007 by abt123 [mod ya4ept]
#
# NOTE: This plugin meant to be use with hakore's reactOnNPC
# http://forums.openkore.com/viewtopic.php?f=34&t=1071
# http://forums.openkore.com/viewtopic.php?f=34&t=198
#
# Example (put in config.txt):
# Some server use image name as a response.
# responseOnNPCImage_equal <num | text | resp | or leave blank for disable>
# reactOnNPC talkImage text {
#	type text
#	msg_0 [Bot Check]
#	msg_1 /.*/
# }
#########################################################################

package responseOnNPCImage;

use strict;
use Plugins;
use FileParsers qw(parseDataFile);
use Globals qw(%config %talk);
use I18N qw(bytesToString);
use Log qw(message error);

Plugins::register('responseOnNPCImage', 'respose base on NPC Image', \&onUnload, \&onUnload);

my $cmd = Commands::register(['talkImage', 'talk response by image', \&cmdTalkImage]);
my $hooks = Plugins::addHooks(
	['packet/npc_image', \&onNPCImage],
	['packet_pre/npc_talk_number', \&onNPCTalkInput],
	['packet_pre/npc_talk_text', \&onNPCTalkInput],
	['packet/npc_talk_responses', \&onNPCResponses]
);
my $imageName;
my @NPCresponses;

# Syntax:
# '<image name>' => '<response>',
# <image name> - if you got following message 
#	[responseOnNPCImage] Image name >> "????"
# then the ???? is a <image name>.
#
# <response> - Any text that contained in NPC response choice(s) or number.
my %imageTable = (
	'cbot_1' => 'poring',
	'cbot_2' => 'lunatic',
	'cbot_3' => 'fabre',
	'cbot_4' => 'drops',

	'29028246' => '1',
	'29029000' => '2',
	'29029754' => '3',
	'29030508' => '4',
	'29031262' => '5',
	'29032016' => '6',

	'one' => '1',
	'two' => '2',
	'three' => '3',
	'four' => '4',

	'botcheck1' => '234',
	'botcheck2' => '786',
	'botcheck3' => '568',
	'botcheck4' => '311',
	'botcheck5' => '682',
	'botcheck6' => '166',
	'botcheck7' => 'PORING',
	'botcheck8' => 'RODA',
	'botcheck9' => 'ALICE',
	'botcheck10' => 'ACIDUS',
	'botcheck11' => 'HARPY',
	'botcheck12' => 'HEATER',
	'botcheck13' => 'KIEL',
	'botcheck14' => 'ORC',
	'botcheck15' => 'PRIEST',
	'botcheck16' => 'PALADIN',
);

sub onUnload {
	Plugins::delHooks($hooks);
	Commands::unregister($cmd);
	undef %imageTable;
	undef $imageName;
	undef @NPCresponses;
	message "responseOnNPCImage plugin unloading or reloading\n", 'success';
}

sub onNPCImage {
	my (undef, $args) = @_;
	$imageName = bytesToString($args->{npc_image});
	return unless $imageName;
	message "[responseOnNPCImage] Image name >> \"$imageName\"\n", "info";
}

sub onNPCTalkInput {
	my (undef, $args) = @_;
	$talk{ID} = $args->{ID};
}

sub onNPCResponses {
	my (undef, $args) = @_;
	my $msg = I18N::bytesToString(unpack("Z*", substr($args->{RAW_MSG}, 8)));
	@NPCresponses = ();
	my @preTalkResponses = split /:/, $msg;
	foreach my $response (@preTalkResponses) {
		$response =~ s/\^[a-fA-F0-9]{6}//g;
		push @NPCresponses, $response if ($response ne '');
	}
}

sub cmdTalkImage {
	my (undef, $args) = @_;
	my $cmd = '';

	if ($args !~ /resp|num|text/) {
		error "Syntax Error in function 'talkImage' (Talk to NPC base on NPC image)\n" .
			"Usage: talkImage <resp | num | text>\n";
		return;
	}
	if ($imageName eq '') {
		error "[responseOnNPCImage] Doesn't seen any image yet!\n";
		return;
	}
	if (defined $imageTable{$imageName} && $imageTable{$imageName} ne '') {
		if ($args eq 'num') {
			$cmd = "talk num $imageTable{$imageName}";
		} elsif ($args eq 'text') {
			$cmd = "talk text $imageTable{$imageName}";
		} elsif ($args eq 'resp') {
			message "[responseOnNPCImage] Match \"$imageTable{$imageName}\" to response list.\n", "info";
			my $i = 0;
			foreach (@NPCresponses) {
				last if ($_ =~ /$imageTable{$imageName}/i);
				$i++;
			}
			if ($i < (scalar @NPCresponses)) {
				$cmd = "talk resp $i";
			} else {
				error "[responseOnNPCImage] Can not match \"$imageTable{$imageName}\" to response list.\n";
				message "[responseOnNPCImage] You must response by yourself now!\n", "info";
			}
		}
	} else {
		if ($args eq 'num') {
			if ($config{"responseOnNPCImage_equal"} eq 'num') {
				$cmd = "talk num $imageName";
			} else {
				error "[responseOnNPCImage] Image name not equal to number.\n";
				message "[responseOnNPCImage] You must response by yourself now!\n", "info";
			}
		} elsif ($args eq 'text') {
			if ($config{"responseOnNPCImage_equal"} eq 'text') {
				$cmd = "talk text $imageName";
			} else {
				error "[responseOnNPCImage] Image name not equal to text.\n";
				message "[responseOnNPCImage] You must response by yourself now!\n", "info";
			}
		} elsif ($args eq 'resp') {
			if ($config{"responseOnNPCImage_equal"} eq 'resp') {
				message "[responseOnNPCImage] Match \"$imageName\" to response list.\n", "info";
				my $i = 0;
				foreach (@NPCresponses) {
					next unless $_;
					last if ($_ =~ /$imageName/i);
					$i++;
				}
				if ($i < (scalar @NPCresponses)) {
					$cmd = "talk resp $i";
				} else {
					error "[responseOnNPCImage] Can not match \"$imageName\" to response list.\n";
					message "[responseOnNPCImage] You must response by yourself now!\n", "info";
				}
			} else {
				error "[responseOnNPCImage] Image name not equal to response choice.\n";
				message "[responseOnNPCImage] You must response by yourself now!\n", "info";
			}
		}
	}

	if ($cmd ne '') {
		message "[responseOnNPCImage] Executing command \"$cmd\".\n", "success";
		Commands::run($cmd);
		$imageName = '';
	}
}

1;