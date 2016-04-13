############################################################
#
# Forge
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
# 

package forge;

import Settings qw(addConfigFile);
import Misc qw(inInventory);

use strict;
use Plugins;
use Globals;
use Utils;
use Log qw(message);
use Network::Send;
use Settings;
use FileParsers;

our %forge;
our %items_rlut;
our $allof;
our $numtimes;
Plugins::register('Forge', 'Enables Forge Commands', \&Unload);
my $hooks = Plugins::addHooks(
		['AI_pre',		\&AutoForge,		undef],
		['Command_post',	\&onCommandPost,	undef],
		['start2',		\&loadfile,		undef]
);

sub Unload {
	Plugins::delHooks($hooks);
}

sub loadfile {
  addConfigFile("$Settings::tables_folder/forge.txt", \%forge, \&parseConfigFile);
  addConfigFile("$Settings::tables_folder/items.txt", \%items_rlut, \&parseROReverseLUT);
}

sub AutoForge {
	if (timeOut($timeout{forge}{time},0.5)) {
		$timeout{forge}{time} = time;
		if (AI::action eq "Forge" && AI::args->{done}) {
				AI::dequeue;
		} elsif (AI::action eq "Forge") {
			my $args = AI::args;
			$timeout{forge}{time} = time;	
			if (CanForge($allof)) {
				Forge($allof);
			} else {
				$args->{done} = 1;
			}
		}
	}
}


##### COMMAND
sub onCommandPost {
	my (undef, $args) = @_;
	my ($cmd, $subcmd, $all) = split(' ', $args->{input}, 3);
	my $i = 0;
	my $x = 1;
	my $item;
	my $error=0;
	my $ii;
	my $invIndex;
	if ($cmd eq "forge") {
		if ($subcmd eq "list") {
			while (exists $forge{"forge_$i"}) {
				$ii = $i;
				$i++;
				next if (!CanForge($ii));
				$item = $forge{"forge_".$ii};
				message "$ii $item\n";
			}
		} else {
			if ($forge{"forge_".$subcmd}) {
				if ($all eq "all") { 
					$allof = $subcmd;
					AI::queue('Forge');
				} else {
					Forge($subcmd);
				}
			}
		}
	}
		$args->{return} = 1;
}

sub sendForgeItem {
	my $r_socket = shift;
	my $index = shift;
	my $msg = pack("C*", 0x8E, 0x01) . pack("S*", $index) . pack("C*", 0x00, 0x00, 0x00, 0x00, 0x00, 0x00);
	sendMsgToServer($r_socket, $msg);
}

sub CanForge {
	my $num = shift;
	my $x=1;
	my $error=0;
	while (exists $forge{"forge_".$num."_item_".$x}) {
		$error = 1 if (!binFind(\@skillsID, $skills_rlut{lc($forge{"forge_".$num."_skill"})}) && $forge{"forge_".$num."_skill"});
		$error = 1 if (!inInventory($forge{"forge_".$num."_item_".$x}, $forge{"forge_".$num."_item_".$x."_amount"}));
		$error = 1 if (!inInventory($forge{"forge_".$num."_req"}, 1));
		$x++;
		last if ($error eq 1);
	}
	return 1 if ($error eq 0);
	return 0;

}


sub parseROReverseLUT {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my @stuff;
	open FILE, $file;
	foreach (<FILE>) {
		s/\r//g;
		next if /^\/\//;
		@stuff = split /#/, $_;
		$stuff[1] =~ s/_/ /g;
		if ($stuff[0] ne "" && $stuff[1] ne "") {
			$$r_hash{$stuff[1]} = $stuff[0];
		}
	}
	close FILE;
}

sub Forge {
	my $num = shift;
	my $x=1;
	my $item=$forge{"forge_".$num};
	if (!CanForge($num)) {
		message "use forge list for a list of items you can forge.\n";
	} else {
		my $index = findIndexStringList_lc($char->{inventory}, "name", $forge{"forge_".$num."_req"});
		if (defined $index || !$forge{"forge_".$num."_req"}) {
			sendItemUse(\$remote_socket, $char->{inventory}[$index]{index}, $accountID) if ($forge{"forge_".$num."_req"});
			if ($forge{"forge_".$num."_useSkill"} eq 1) {
				my $forgeSkill = new Skills(auto => $forge{"forge_".$num."_skill"});
				sendSkillUse(\$remote_socket, $forgeSkill->id, undef, $accountID);
			}
			sendForgeItem(\$remote_socket, $items_rlut{$item});
		} else {
			message "You must have a ".$forge{"forge_".$num."_req"}." to forge ".$forge{"forge_".$num};
		}
	}
}

return 1;