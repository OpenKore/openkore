# OpenKore - Padded Packet Emulator Plugin.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See http://www.gnu.org/licenses/gpl.html for the full license.
#
# ====================================================================================
#
# Author: Jack Aplegame
# Library development: Jerry, kLabMouse, Jack Applegame
#
# To switch to test mode add debugPPEngine = 1 to config.txt 
# Test mode available only in XKore 1 mode.
# In test mode plugin will compare created padded packets with packets 
# sent by original client when sitting/standing, attacking and using skills, and show
# debug information.

package PaddedPacketsPlugin;

use strict;
use lib $Plugins::current_plugin_folder;
use Time::HiRes qw(time);

use Globals;
use Plugins;
use Utils;
use Network;
use Network::Send;
use Skill;
use Log qw(message error debug warning);
use Commands;
use Win32::API;

Plugins::register("ppengine", "RO Padded Packet Engine", \&onUnload);
my $hooks = Plugins::addHooks(
	['Network::serverConnect/master', \&init, undef], #Fix me: this hook is not working in XKore mode
	['map_loaded', \&init, undef], #Init for XKore mode
	['packet_pre/sendSit',      \&onSendSit, undef],
	['packet_pre/sendStand',    \&onSendStand, undef],
	['packet_pre/sendAttack',   \&onSendAttack, undef],
	['packet_pre/sendSkillUse', \&onSendSkillUse, undef],
	['RO_sendMsg_pre',          \&onRO_sendMsg_pre, undef],
	['mainLoop_post',           \&processStatisticsReporting, undef],
);
my $commands = Commands::register(
	["syncs", "Prints MapSync, Sync and AccId", \&cmdSyncs],
);

# Loading ropp.dll and importing functions
$ENV{PATH} .= ";$Plugins::current_plugin_folder";
Win32::API->Import('ropp', 'PP_CreateSitStand', 'PN' ,'N') or die "Can't import PP_CreateSitStand\n$!";
Win32::API->Import('ropp', 'PP_CreateAtk', 'PNN' ,'N') or die "Can't import PP_CreateAtk\n$!";
Win32::API->Import('ropp', 'PP_CreateSkillUse', 'PNNN' ,'N') or die "Can't import PP_CreateSkillUse\n$!";

Win32::API->Import('ropp', 'PP_SetMapSync', 'N') or die "Can't import PP_SetMapSync\n$!";
Win32::API->Import('ropp', 'PP_SetSync', 'N') or die "PP_SetSync\n$!";
Win32::API->Import('ropp', 'PP_SetAccountId', 'N') or die "Can't import PP_SetAccountId\n$!";
Win32::API->Import('ropp', 'PP_SetPacketIDs', 'NN') or die "Can't import PP_PP_SetPacketIDs\n$!";
Win32::API->Import('ropp', 'PP_SetPacket', 'PNN') or die "Can't import PP_SetPacket\n$!";

Win32::API->Import('ropp', 'PP_DecodePacket', 'PN') or die "Can't import PP_DecodePacket\n$!";
Win32::API->Import('ropp', 'PP_GetKey', 'N' ,'N') or die "Can't import PP_GetKey\n$!";

my ($enabled, $attackID, $skillUseID);
my $LastPaddedPacket;

sub onUnload {
	Commands::unregister($commands);
	Plugins::delHooks($hooks);
}

sub init {
	# Setting packet IDs for Sit/Stand/Attack and SkillUse
	$enabled = $masterServer->{paddedPackets};
	if ($enabled) {
		$attackID   = hex($masterServer->{paddedPackets_attackID}) || 0x89;
		$skillUseID = hex($masterServer->{paddedPackets_skillUseID}) || 0x113;
		PP_SetPacketIDs($attackID, $skillUseID);
		$attackID   = sprintf('%04X', $attackID);
		$skillUseID = sprintf('%04X', $skillUseID);
	}
}

sub onSendSit {
	if ($enabled) {
		my ($hook, $args) = @_;
		$args->{return} = 1;
		$args->{msg} = generateSitStand(1);
	}
}

sub onSendStand {
	if ($enabled) {
		my ($hook, $args) = @_;
		$args->{return} = 1;
		$args->{msg} = generateSitStand(0);
	}
}

sub onSendAttack {
	if ($enabled) {
		my ($hook, $args) = @_;
		$args->{return} = 1;
		$args->{msg} = generateAtk($args->{monID}, $args->{flag});
	}
}

sub onSendSkillUse {
	if ($enabled) {
		my ($hook, $args) = @_;
		$args->{return} = 1;
		$args->{msg} = generateSkillUse($args->{ID}, $args->{lv},  $args->{targetID});
	}
}

sub onRO_sendMsg_pre {
	return unless ($enabled);
	my (undef, $args) = @_;
	my $switch = $args->{switch};
	my $msg = $args->{msg};
	my $sendMsg = $args->{sendMsg};
	my ($Packet, $orig, $lib);
	my $Parsed = 0;

	if ($switch eq $attackID || $switch eq $skillUseID) {
		if(length($LastPaddedPacket) <= length($msg)) {
			$LastPaddedPacket = $msg;
		} else {
			$LastPaddedPacket = $msg . substr($LastPaddedPacket, length($msg));
		}
	}
	return if (!$config{debugPPEngine});

	if ($switch eq $attackID) {
		setHashData();
		PP_DecodePacket($msg, 2);
		my $TargetId = GetKey(0);
		my $Flag = GetKey(1);
		if ($Flag == 2) {
			$orig = getHex($msg);
			
			# SetPacket is not actually needed for packet creation. Only for comparing with original packets.
			PP_SetPacket($LastPaddedPacket, length($LastPaddedPacket), $TargetId);

			$lib = getHex(generateSitStand(1));
			$Parsed = 1;
			message "======================== Sit ========================\n";
		} elsif ($Flag  == 3)
		{
			$orig = getHex($msg);

			# SetPacket is not actually needed for packet creation. Only for comparing with original packets.
			PP_SetPacket($LastPaddedPacket, length($LastPaddedPacket), $TargetId);

			$lib = getHex(generateSitStand(0));
			$Parsed = 1;
			message "======================= Stand =======================\n";
		} elsif ($Flag  == 7 || $Flag == 0)
		{
			$orig = getHex($msg);

			# SetPacket is not actually needed for packet creation. Only for comparing with original packets.
			PP_SetPacket($LastPaddedPacket, length($LastPaddedPacket), $TargetId);

			$lib = getHex(generateAtk(pack('L1', $TargetId), $Flag));
			$Parsed = 1;
			message "======================= Attack ======================\n";
			message "Target: [". getHex($TargetId). "] Flag: $Flag\n";
		}
	} elsif ($switch eq $skillUseID) {
		setHashData();
		PP_DecodePacket($msg, 3);
		my $SkillLv = PP_GetKey(0);
		my $SkillId = PP_GetKey(1);
		my $TargetId = pack('L1', GetKey(2));
		$orig = getHex($msg);
		
		# SetPacket is not actually needed for packet creation. Only for comparing with original packets.
		PP_SetPacket($LastPaddedPacket, length($LastPaddedPacket), $TargetId);
		
		$lib = getHex(generateSkillUse($SkillId, $SkillLv, $TargetId));
		my $skill = new Skill(idn => $SkillId);
		$Parsed = 1;
		message "====================== SkillUse ======================\n";
		message "Skill: $SkillId (" . $skill->getName() . ")   Level: $SkillLv   Target: [". getHex($TargetId). "]\n";
	}
	if ($Parsed) {
		if ($orig eq $lib) {
			message "Packets are identical\n";
		} else {
			cmdSyncs();
			message "Packet by RO client:\n";
			message "$orig\n";
			message "Packet by library:\n";
			message "$lib\n";
		}
	}
}

sub cmdSyncs {
	message "MapSync = [".getHex($syncMapSync)."] Sync = [".getHex($syncSync)."] AccID = [".getHex($accountID)."]\n";
}


####################################


# Anonymous statistics reporting. This gives us insight about
# server our users play.
sub processStatisticsReporting {
	our %statisticsReporting;
	return if (!$enabled || $statisticsReporting{done} || !$config{master} || !$config{username});

	if (!$statisticsReporting{http}) {
		use Utils qw(urlencode);
		import Utils::Whirlpool qw(whirlpool_hex);

		# Note that ABSOLUTELY NO SENSITIVE INFORMATION about the
		# user is sent. The username is filtered through an
		# irreversible hashing algorithm before it is sent to the
		# server. It is impossible to deduce the user's username
		# from the data sent to the server.
		my $url = "http://www.openkore.com/ropp_statistics.php";
		my $postData = "server=" . urlencode($config{master});
		$postData .= "&product=" . urlencode($Settings::NAME);
		$postData .= "&version=" . urlencode($Settings::VERSION);
		$postData .= "&uid=" . urlencode(whirlpool_hex($config{master} . $config{username} . $userSeed));
		$statisticsReporting{http} = new StdHttpReader($url, $postData);
		debug "Posting anonymous usage statistics to $url\n", "statisticsReporting";
	}

	my $http = $statisticsReporting{http};
	if ($http->getStatus() == HttpReader::DONE) {
		$statisticsReporting{done} = 1;
		delete $statisticsReporting{http};
		debug "Statistics posting completed.\n", "statisticsReporting";

	} elsif ($http->getStatus() == HttpReader::ERROR) {
		$statisticsReporting{done} = 1;
		delete $statisticsReporting{http};
		debug "Statistics posting failed: " . $http->getError() . "\n", "statisticsReporting";
	}
}

sub setHashData {
	PP_SetAccountId(unpack("L1", $accountID));
	PP_SetMapSync(unpack("L1", $syncMapSync));
	PP_SetSync(unpack("L1", $syncSync));
}

sub generateSitStand {
	my ($sit) = @_;
	my $packet = " " x 256;
	setHashData();
	my $len = PP_CreateSitStand($packet, $sit);
	return substr($packet, 0, $len);
}

sub generateAtk{
	my ($targetId, $flag) = @_;
	my $packet = " " x 256;
	setHashData();
	my $len = PP_CreateAtk($packet, unpack("L1", $targetId), $flag);
	return substr($packet, 0, $len);
}

sub generateSkillUse {
	my ($skillId, $skillLv, $targetId) = @_;
	my $packet = " " x 256;
	setHashData();
	my $len = PP_CreateSkillUse($packet, $skillId, $skillLv, unpack("L1", $targetId));
	return substr($packet, 0, $len);
}

1;
