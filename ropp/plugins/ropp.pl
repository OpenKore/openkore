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
use Skills;
use Log qw(message error debug);
use Commands;
use Win32::API;

Plugins::register("ppengine", "RO Padded Packet Engine", \&onUnload);
my $hooks = Plugins::addHooks(
	['Network::serverConnect/master', \&init, undef],
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

my %statisticsReporting;

# Loading ropp.dll and importing functions
Win32::API->Import('ropp', 'CreateSitStand', 'PL' ,'N') or die "Can't import CreateSitStand\n$!";
Win32::API->Import('ropp', 'CreateAtk', 'PLL' ,'N') or die "Can't import CreateAtk\n$!";
Win32::API->Import('ropp', 'CreateSkillUse', 'PLLL' ,'N') or die "Can't import CreateSkillUse\n$!";

Win32::API->Import('ropp', 'SetMapSync', 'L') or die "Can't import SetMapSync\n$!";
Win32::API->Import('ropp', 'SetSync', 'L') or die "SetSync\n$!";
Win32::API->Import('ropp', 'SetAccountId', 'L') or die "Can't import SetAccountId\n$!";
Win32::API->Import('ropp', 'SetPacketIDs', 'LL') or die "Can't import SetPacketIDs\n$!";
Win32::API->Import('ropp', 'SetPacket', 'PLL') or die "Can't import SetPacket\n$!";

Win32::API->Import('ropp', 'DecodePacket', 'PL') or die "Can't import DecodePacket\n$!";
Win32::API->Import('ropp', 'GetKey', 'L' ,'N') or die "Can't import GetKey\n$!";

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
		SetPacketIDs($attackID, $skillUseID);
		$attackID = sprintf('%04x', $attackID);
		$attackID = sprintf('%04x', $skillUseID);
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
		$args->{msg} = GenerateAtk($args->{monID}, $args->{flag});
	}
}

sub onSendSkillUse {
	if ($enabled) {
		my ($hook, $args) = @_;
		$args->{return} = 1;
		$args->{msg} = GenerateSkillUse($args->{ID}, $args->{lv},  $args->{targetID});
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
		DecodePacket($msg, 2);
		my $TargetId = GetKey(0);
		my $Flag = GetKey(1);
		if ($Flag == 2) {
			$orig = getHex($msg);
			
			# SetPacket is not actually needed for packet creation. Only for comparing with original packets.
			SetPacket($LastPaddedPacket, length($LastPaddedPacket), $TargetId);

			$lib = getHex(generateSitStand(1));
			$Parsed = 1;
			message "======================== Sit ========================\n";
		} elsif ($Flag  == 3)
		{
			$orig = getHex($msg);

			# SetPacket is not actually needed for packet creation. Only for comparing with original packets.
			SetPacket($LastPaddedPacket, length($LastPaddedPacket), $TargetId);

			$lib = getHex(generateSitStand(0));
			$Parsed = 1;
			message "======================= Stand =======================\n";
		} elsif ($Flag  == 7 || $Flag == 0)
		{
			$orig = getHex($msg);

			# SetPacket is not actually needed for packet creation. Only for comparing with original packets.
			SetPacket($LastPaddedPacket, length($LastPaddedPacket), $TargetId);

			$lib = getHex(generateAtk(pack('L1', $TargetId), $Flag));
			$Parsed = 1;
			message "======================= Attack ======================\n";
			message "Target: [". getHex($TargetId). "] Flag: $Flag\n";
		}
	} elsif ($switch eq $skillUseID) {
		setHashData();
		DecodePacket($msg, 3);
		my $SkillLv = GetKey(0);
		my $SkillId = GetKey(1);
		my $TargetId = pack('L1', GetKey(2));
		$orig = getHex($msg);
		
		# SetPacket is not actually needed for packet creation. Only for comparing with original packets.
		SetPacket($LastPaddedPacket, length($LastPaddedPacket), $TargetId);
		
		$lib = getHex(generateSkillUse($SkillId, $SkillLv, $TargetId));
		my $Skill = Skills->new(id => $SkillId);
		$Parsed = 1;
		message "====================== SkillUse ======================\n";
		message "Skill: $SkillId (" . $Skill->name . ")   Level: $SkillLv   Target: [". getHex($TargetId). "]\n";
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
	return if ($enabled && $statisticsReporting{done} || !$config{master} || !$config{username});

	if (!$statisticsReporting{http}) {
		use Utils qw(urlencode);
		import Utils::Whirlpool qw(whirlpool_hex);

		# Note that ABSOLUTELY NO SENSITIVE INFORMATION about the
		# user is sent. The username is filtered through an
		# irreversible hashing algorithm before it is sent to the
		# server. It is impossible to deduce the user's username
		# from the data sent to the server.
		my $url = "http://www.openkore.com/ropp_statistics.php?";
		$url .= "server=" . urlencode($config{master});
		$url .= "&product=" . urlencode($Settings::NAME);
		$url .= "&version=" . urlencode($Settings::VERSION);
		$url .= "&uid=" . urlencode(whirlpool_hex($config{master} . $config{username} . $userSeed));
		$statisticsReporting{http} = new StdHttpReader($url);
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
	SetAccountId(unpack("L1", $accountID));
	SetMapSync(unpack("L1", $syncMapSync));
	SetSync(unpack("L1", $syncSync));
}

sub generateSitStand {
	my ($sit) = @_;
	my $packet = " " x 256;
	setHashData();
	my $len = CreateSitStand($packet, $sit);
	return substr($packet, 0, $len);
}

sub generateAtk{
	my ($targetId, $flag) = @_;
	my $packet = " " x 256;
	setHashData();
	my $len = CreateAtk($packet, unpack("L1", $targetId), $flag);
	return substr($packet, 0, $len);
}

sub generateSkillUse {
	my ($skillId, $skillLv, $targetId) = @_;
	my $packet = " " x 256;
	setHashData();
	my $len = CreateSkillUse($packet, $skillId, $skillLv, unpack("L1", $targetId));
	return substr($packet, 0, $len);
}

1;
