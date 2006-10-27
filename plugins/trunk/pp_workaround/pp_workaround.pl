##################################################################################
#  Copyright (C) 2006  Kaliwanagan and Darkfate
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License
#  as published by the Free Software Foundation; either version 2
#  of the License, or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
#	 packetPadding {
#		 selfSkill <Skillname>
#		 selfSkill_lvl <Skill level>
#	 }
##################################################################################

package PP_Workaround;

use strict;
use Plugins;
use Log qw(message warning error debug);
use Globals;
use Skills;

BEGIN {
	push(@INC,"$Plugins::current_plugin_folder");
}

use Win32::GuiTest;

my $packSize0089 = 0;
my $packet0113 = 0;

my $hooks = Plugins::addHooks(
		['RO_sendMsg_pre', \&getPacketProto],
	  ['packet_pre/sendAttack', \&sendAttack],
	  ['packet_pre/sendSit', \&sendAttack],
	  ['packet_pre/sendStand', \&sendAttack],
	  ['packet_pre/sendSkillUse', \&sendSkillUse],
	  ['packet_outMangle/0089', \&manglePacket0089],
	 	['packet_outMangle/0113', \&manglePacket0113],
);

sub Reload { Unload(); }
sub Unload { Plugins::delHooks($hooks); }

Plugins::register('PP_Workaround', 'Packet Padding workaround', \&Unload, \&Reload);

########## Mangle all attack and skill packets except teleport ##########
sub manglePacket0113 {
	my ($hook, $args) = @_;
	
	if (unpack("H*", $args->{data}) =~ /1A000000/i) { # Don't Mangle Teleport Packets (Fly and BfWing)
		# I think the chances that this pattern matches on an other Packet is low (Users should report if it happens)
		return 0;
	}	
	return 1;
}

sub manglePacket0089 { 1; }

########## Sends a key to the Ragnarok client ##########
sub sendKey {
	my $key = shift;
	
	my @windows = Win32::GuiTest::FindWindowLike(0, "^Ragnarok");
	foreach (@windows) {
		Win32::GuiTest::SetForegroundWindow($_);
		Win32::GuiTest::SendKeys("{$key}");
	}
	message "$key key pressed \n";
}

########## Captures the packet(0113) and length (0089) ##########
sub getPacketProto {
	my ($hook, $args) = @_;

	my $switch = $args->{switch};
	my $msg = $args->{msg};
	my $sendMsg = $args->{realMsg};
	
	if ($switch eq '007E') { # Client sync
		message "SYNC by RO client\n";
    # Reset packetsize
		$packSize0089 = 0;
		$packet0113 = 0;
		#sendKey("INSERT");
		#sendKey("F1")
		
	} elsif ($switch eq '0072') { # If map loaded
		$packSize0089 = 0; # Reset packet size
		$packet0113 = 0;
	
	} elsif ($switch eq '0089') { # Attack/Sit/Stand
		if (!$packSize0089) { # Packet length not yet captured
			$packSize0089 = length($msg);
		} 
				
	} elsif ($switch eq '0113') { # Skill use
		if (!$packet0113) { # Packet length not yet captured
			$packet0113 = unpack("H*", $msg);
		}
	} # End if
}

########## Checks condition and calls the attack function ##########
sub sendAttack {
	my ($hook, $args) = @_;
	
	message "$hook\n";
	$args->{return} = 1;
	$args->{msg} = "";
	message "packet prototype: $packSize0089\n";
	if ($packSize0089 <= 0) { # Don't continue if packet length is unavailable
			sendKey("INSERT");
			return;
	}
	$args->{msg} = getPadding0089($hook, $args->{monID}, $args->{flag});
}

########## Checks condition and calls the skill function ##########
sub sendSkillUse {
	my ($hook, $args) = @_;
	
	message "$hook\n";
	$args->{return} = 1;
	$args->{msg} = "";
	message "packet prototype: $packet0113\n";
	if (!$packet0113) {
		sendKey("F1");
		return;
	}
	$args->{msg} = getPadding0113($hook, $args->{ID}, $args->{lv}, $args->{targetID});
}

########## Creates and returns the attack packet ##########	
sub getPadding0089 {
	my ($hook, $monID, $flag) = @_;
	my $n;
	my $sRecord;
	my $msg;
	
	if ($packSize0089 > 0) {
		my $sFlag = pack("V", $flag);
		
		if ($flag == 0x02 || $flag == 0x03) { # Sit/Stand
			$sRecord = "\x00" x ($packSize0089 - 8) . $sFlag;
			$msg = pack("S", 0x0089) . pack("S", $packSize0089) . $sRecord;
			
		} else { # End if # Attack
			if ($packSize0089 & 1) {
				$n = ($packSize0089 + 2 - 45) >> 1; # 45 -> Minimum odd number
				$sRecord = "\x00" x ($n + 31) . $monID . "\x00" x $n . $sFlag;
				
			} else {
				$n = ($packSize0089 - 20) >> 1; # 20 -> Minimum even number
				$sRecord = "\x00" x $n . $monID . "\x00" x ($n + 8). $sFlag;
				}
			$msg = pack("S", 0x0089) . pack("S", $packSize0089) . $sRecord;
		}
		return $msg;
	} # End if
	return "";
}

########## Creates (substitution) and returns the skill packet ##########
sub getPadding0113 {
	my ($hook, $ID, $lv, $targetID) = @_;
	my $msg;
	
	my $selfSkill = Skills->new(name => $config{packetPadding_0_selfSkill});
	my $selfSkill_ID = unpack("H*", pack("v", $selfSkill->id)); # Get the ID of the self skill
	my $selfSkill_lvl = unpack("H*", pack("v", $config{packetPadding_0_selfSkill_lvl})); # Get the lvl of the self skill from the config
	
	if ($packet0113) {
		$ID = unpack("H*", pack("v", $ID)); # Unpack it as string, reversed
		$lv = unpack("H*", pack("v", $lv)); # Unpack it as string, reversed

		$msg = $packet0113;
		$msg =~ s/$selfSkill_ID/$ID/i; # Replace the skill ID
		$msg =~ s/$selfSkill_lvl/$lv/i; # Replace the skill lvl
		substr($msg, -8) = unpack("H*", $targetID); # Replace the target
		
		$msg = pack("H*", $msg);
		return $msg;
		} # End if	
	return "";
	}

1;