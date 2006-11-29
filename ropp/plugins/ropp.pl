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

package PPEngine;

use lib 'plugins';
use Time::HiRes qw(time);
use Globals;
use Utils;
use strict;
use Plugins;
use Network;
use Network::Send;
use Skills;
use Log;
use Log qw(message);
use Log qw(error);
use Log qw(debug);
use Commands;
use Win32::API;

my %statisticsReporting;
Plugins::register("ppengine", "RO Padded Packet Engine", \&on_unload, \&on_reload);
my $hooks = Plugins::addHooks(
            ['packet_pre/sendSit',	\&doSit, undef],
            ['packet_pre/sendStand', \&doStand, undef],
            ['packet_pre/sendAttack', \&doAttack, undef],
            ['packet_pre/sendSkillUse', \&doSkillUse, undef],
            ['RO_sendMsg_pre',\&onRO_sendMsg_pre, undef],
            ['mainLoop_post',\&doStatistics, undef],
);
my $commands = Commands::register(
     ["syncs", "Prints MapSync, Sync and AccId", \&doSyncs],
);

sub on_unload {
	Commands::unregister($commands);
	Plugins::delHooks($hooks);
}

sub on_reload {
	&on_unload;
}

#Loading ropp.dll and importing functions
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

# Setting packet IDs for Sit/Stand/Attack and SkillUse
SetPacketIDs(0x89, 0x113); # IDs for rRO

my $LastPaddedPacket;

sub doSyncs {
	message "MapSync = [".getHex($syncMapSync)."] Sync = [".getHex($syncSync)."] AccID = [".getHex($accountID)."]\n";
}

sub SetHashData {
	SetAccountId(unpack("L1",$accountID));
	SetMapSync(unpack("L1",$syncMapSync));
	SetSync(unpack("L1",$syncSync));
}

sub GenerateSitStand {
	my $sit = shift;
	my $Packet = " " x 256;
	SetHashData();
	my $len = CreateSitStand($Packet, $sit);
	return substr($Packet, 0, $len);
}

sub GenerateAtk{
	my ($TargetId, $flag) = @_;
	my $Packet = " " x 256;
	SetHashData();
	my $len = CreateAtk($Packet, unpack("L1", $TargetId), $flag);
	return substr($Packet, 0, $len);
}

sub GenerateSkillUse
{
	my ($SkillId, $SkillLv, $TargetId) = @_;
	my $Packet = " " x 256;
	SetHashData();
	my $len = CreateSkillUse($Packet, $SkillId, $SkillLv, unpack("L1", $TargetId));
	return substr($Packet, 0, $len);
}

sub doSit {
	my $hook = shift;
	my $args = shift;
	$args->{return} = 1;
	$args->{msg} = GenerateSitStand(1);
}

sub doStand {
	my $hook = shift;
	my $args = shift;
	$args->{return} = 1;
	$args->{msg} = GenerateSitStand(0);
}

sub doAttack {
	my $hook = shift;
	my $args = shift;
	$args->{return} = 1;
	$args->{msg} = GenerateAtk($args->{monID}, $args->{flag});
}

sub doSkillUse {
	my $hook = shift;
	my $args = shift;
	$args->{return} = 1;
	$args->{msg} = GenerateSkillUse($args->{ID}, $args->{lv},  $args->{targetID});
}

sub onRO_sendMsg_pre {
	my $hookName = shift;
	my $args = shift;
	my $switch = $args->{switch};
	my $msg = $args->{msg};
	my $sendMsg = $args->{sendMsg};
	my ($Packet, $orig, $lib);
	my $Parsed = 0;

	if($switch eq "0089" || $switch eq "0113")
	{
		if(length($LastPaddedPacket) <= length($msg)) {
			$LastPaddedPacket = $msg;
		} else
		{
			$LastPaddedPacket = $msg . substr($LastPaddedPacket, length($msg));
		}
	}

	if(!$config{debugPPEngine}) {
		return;
	} 
	
	if ($switch eq "0089")
	{
		SetHashData();
		DecodePacket($msg, 2);
		my $TargetId = GetKey(0);
		my $Flag = GetKey(1);
		if ($Flag == 2)
		{
			$orig = getHex($msg);
			
			# SetPacket is not actually needed for packet creation. Only for comparing with original packets.
			SetPacket($LastPaddedPacket, length($LastPaddedPacket), $TargetId);

			$lib = getHex(GenerateSitStand(1));
			$Parsed = 1;
			message "======================== Sit ========================\n";
		} elsif ($Flag  == 3)
		{
			$orig = getHex($msg);

			# SetPacket is not actually needed for packet creation. Only for comparing with original packets.
			SetPacket($LastPaddedPacket, length($LastPaddedPacket), $TargetId);

			$lib = getHex(GenerateSitStand(0));
			$Parsed = 1;
			message "======================= Stand =======================\n";
		} elsif ($Flag  == 7 || $Flag == 0)
		{
			$orig = getHex($msg);

			# SetPacket is not actually needed for packet creation. Only for comparing with original packets.
			SetPacket($LastPaddedPacket, length($LastPaddedPacket), $TargetId);

			$lib = getHex(GenerateAtk(pack('L1', $TargetId), $Flag));
			$Parsed = 1;
			message "======================= Attack ======================\n";
			message "Target: [". getHex($TargetId). "] Flag: $Flag\n";
		}
	} elsif ($switch eq "0113")
	{
		SetHashData();
		DecodePacket($msg, 3);
		my $SkillLv = GetKey(0);
		my $SkillId = GetKey(1);
		my $TargetId = pack('L1', GetKey(2));
		$orig = getHex($msg);
		
		# SetPacket is not actually needed for packet creation. Only for comparing with original packets.
		SetPacket($LastPaddedPacket, length($LastPaddedPacket), $TargetId);
		
		$lib = getHex(GenerateSkillUse($SkillId, $SkillLv, $TargetId));
		my $Skill = Skills->new(id => $SkillId);
		$Parsed = 1;
		message "====================== SkillUse ======================\n";
		message "Skill: $SkillId (" . $Skill->name . ")   Level: $SkillLv   Target: [". getHex($TargetId). "]\n";
	}
	if($Parsed)
	{
		if($orig eq $lib)
		{
			message "Packets are identical\n";
		}
		else
		{
			doSyncs();
			message "Packet by RO client:\n";
			message "$orig\n";
			message "Packet by library:\n";
			message "$lib\n";
		}
	}
}

sub doStatistics {
	processStatisticsReporting();
}

# Anonymous statistics reporting. This gives us insight about
# server our users play.
sub processStatisticsReporting {
	return if ($statisticsReporting{done} || !$config{master} || !$config{username});

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

return 1;
