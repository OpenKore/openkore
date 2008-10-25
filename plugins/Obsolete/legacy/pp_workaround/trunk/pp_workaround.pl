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

BEGIN {
	push(@INC,"$Plugins::current_plugin_folder");
}

use strict;
use Plugins;
use Log qw(message warning error debug);
use Globals;
use Skills;
use Win32::GuiTest;

my $packSize0089;
my $packet0113;

my $hooks = Plugins::addHooks(
		['start3', \&startWarning],
		['RO_sendMsg_pre', \&main],
	  ['packet_pre/sendAttack', \&control_0089],
	  ['packet_pre/sendSkillUse', \&control_0113],
	  ['packet_pre/sendSit', \&control_0089],
	  ['packet_pre/sendStand', \&control_0089],
	  ['packet_outMangle/0089', \&manglePackets],
	  ['packet_outMangle/0113', \&manglePackets],
);



sub Reload { Unload(); }
sub Unload { Plugins::delHooks($hooks); }
sub manglePackets { 1; }
sub startWarning { warning("\nTHIS PLUGIN IS HIGHLY EXPERIMENTAL. USE AT YOUR OWN RISK.\n"); }

Plugins::register('PP_Workaround', 'Packet Padding workaround', \&Unload, \&Reload);

sub sendKey {
	my $key = shift;
	
	my @windows = Win32::GuiTest::FindWindowLike(0, "^Ragnarok");
	foreach (@windows) {
		Win32::GuiTest::SetForegroundWindow($_);
		Win32::GuiTest::SendKeys("{$key}");
	}
	#message "$key key pressed \n";
}

sub main {
	my $hook = shift;
	my $args = shift;

	my $switch = $args->{switch};
	my $msg = $args->{msg};
	my $sendMsg = $args->{realMsg};
	
	if ($switch eq '007E') {
		#message "SYNC by RO client\n";
		$timeout{'ai_attack'}{timeout} = 0;
		undef $packSize0089;
		undef $packet0113;
		
	} elsif ($switch eq '0072') {
		undef $packSize0089;
		undef $packet0113;
	
	} elsif ($switch eq '0089') {
		if (!$packSize0089) {
			$packSize0089 = length($msg);
			#message "len_pre: $packSize0089\n";
		} 
	} elsif ($switch eq '0113') {
		if (!$packet0113) {
			$packet0113 = $msg;
		}
	} # End if
}

sub control_0089 {
	my $hook = shift;
	my $args = shift;
	
	#message "$hook\n";
	$args->{return} = 1;
	
	if ($packSize0089) {
	
		if ($hook eq 'packet_pre/sendSit') {
			$args->{msg} = sendSit();
			
		} elsif ($hook eq 'packet_pre/sendStand') {
			$args->{msg} = sendStand();
		
		} elsif ($hook eq 'packet_pre/sendAttack') {
			#message "0089: $packSize0089\n";
			$args->{msg} = sendAttack($args->{monID}, $args->{flag});
		}
			
	} else {
		sendKey("INSERT");
	}
}

sub control_0113 {
	my $hook = shift;
	my $args = shift;
	
	#message "$hook\n";
	$args->{return} = 1;
	
	if ($packet0113) {
		$args->{msg} = sendSkillUse($args->{ID}, $args->{lv}, $args->{targetID});
		
	} else {
		sendKey("F1");
	} # End if 
}

sub sendSit {
	my $msg =
	pack("S", 0x0089) .
	pack("S", $packSize0089) .
	"\x00" x ($packSize0089 - 8) .
	pack("V", 0x02);
}

sub sendStand {
	my $msg =
	pack("S", 0x0089) .
	pack("S", $packSize0089) .
	"\x00" x ($packSize0089 - 8) .
	pack("V", 0x03);
}


sub sendAttack {
	my $monID = shift;
	my $flag = shift;
	my $msg;
	
	if ($packSize0089 & 1) {
		my $n = ($packSize0089 + 2 - 45) >> 1;
		
		$msg =
			pack("S", 0x0089) .
			pack("S", $packSize0089) .
			"\x00" x ($n + 31) . $monID .
			"\x00" x $n .
			pack("V", $flag);
			
		} else {
			my $n = ($packSize0089 - 20) >> 1;
				
			$msg =
				pack("S", 0x0089) .
				pack("S", $packSize0089) .
				"\x00" x $n . $monID .
				"\x00" x ($n + 8).
				pack("V", $flag);
				
		} # End if
	return $msg;
}

sub sendSkillUse {
	my $ID = shift;
	my $lv = shift;
	my $targetID = shift;
	
	
	my $selfSkill = Skills->new(name => $config{packetPadding_0_selfSkill});
	my $selfSkill_ID = unpack("H*", pack("v", $selfSkill->id));
	my $selfSkill_lvl = unpack("H*", pack("v", $config{packetPadding_0_selfSkill_lvl}));
	
	$ID = unpack("H*", pack("v", $ID));
	$lv = unpack("H*", pack("v", $lv));

	my $msg = unpack("H*", $packet0113);
	$msg =~ s/$selfSkill_ID/$ID/i;
	$msg =~ s/$selfSkill_lvl/$lv/i;
	substr($msg, -8) = unpack("H*", $targetID) if $targetID;

	$msg = pack("H*", $msg);
	return $msg;
}

1;