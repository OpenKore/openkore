############################################################
#
# itemexchange
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

# See this thread for detailed config information:
# http://openkore.sourceforge.net/forum/viewtopic.php?t=3497

package itemexchange;

use strict;
use Plugins;
use Commands;
use Globals;
use Log;
use Utils;

Plugins::register('itemexchange', 'exchanges items with NPCs using talk sequence', \&unload);
my $mainLoopHook = Plugins::addHook('AI_pre', \&mainLoop);
my $hookCommandPost = Plugins::addHook('Command_post', \&onCommandPost);

sub unload {
	Plugins::delHook('AI_pre', $mainLoopHook);
	Plugins::delHook('Command_post', $hookCommandPost);
}

sub onCommandPost {
	my (undef, $args) = @_;
	my ($cmd, $subcmd) = split(' ', $args->{input}, 2);

	if ($cmd eq "itemexchange") {
		AI::queue('itemExchange');
		$args->{return} = 1;
	}
}

sub mainLoop {
	ITEMEXCHANGE: {

	if ((AI::isIdle || AI::action eq 'route') && !AI::inQueue('itemExchange') && $::config{'itemExchange'} && $::config{'itemExchange_npc'} ne "" && itemexchange::check()) {
		AI::queue('itemExchange');
	}

	if (AI::action eq "itemExchange" && AI::args->{done}) {
		# Autoexchange finished
		AI::dequeue;

	} elsif (AI::action eq "itemExchange") {
		# Main autoexchange block
		my $args = AI::args;

		# Stop if itemExchange is not enabled, or if the specified NPC is invalid
		$args->{npc} = {};
		main::getNPCInfo($::config{'itemExchange_npc'}, $args->{npc});
		if (!$::config{'itemExchange'} || !defined($args->{npc}{ok})) {
			$args->{done} = 1;
			return;
		}

		# Determine whether we have to move to the NPC
		my $do_route = 0;
		if ($::field{'name'} ne $args->{npc}{map}) {
			$do_route = 1;
		} else {
			my $distance = Utils::distance($args->{npc}{pos}, $::char->{pos_to});
			if ($distance > $::config{'itemExchange_distance'}) {
				$do_route = 1;
			}
		}

		if ($do_route) {
			Log::message "Calculating auto-exchange route to: $::maps_lut{$args->{npc}{map}.'.rsw'}($args->{npc}{map}): $args->{npc}{pos}{x}, $args->{npc}{pos}{y}\n", "route";
			main::ai_route($args->{npc}{map}, $args->{npc}{pos}{x}, $args->{npc}{pos}{y},
				attackOnRoute => 1,
				distFromGoal => $::config{'itemExchange_distance'});
		} else {
			# Talk to NPC if we haven't done so
			if (!defined($args->{queuedTalkSequence})) {
				$args->{queuedTalkSequence} = 1;

				if (defined $args->{npc}{id}) {
					main::ai_talkNPC(ID => $args->{npc}{id}, $::config{'itemExchange_npc_steps'}); 
				} else {
					main::ai_talkNPC($args->{npc}{pos}{x}, $args->{npc}{pos}{y}, $::config{'itemExchange_npc_steps'}); 
				}

				return;
			}

			if (itemexchange::check(1)) {
				undef $args->{queuedTalkSequence};
			}
			else {
				$args->{done} = 1;
			}
		}
	}

	} #END OF BLOCK ITEMEXCHANGE
}

sub check {
	my $exchangeAlreadyActive = shift;
	my $j = 0;

	while ($::config{"itemExchange_item_$j"}) {
		last if (!$::config{"itemExchange_item_$j"} || !$::config{"itemExchange_item_$j"."_requiredAmount"} || !$::config{"itemExchange_item_$j"."_triggerAmount"});
		my $amount;

		my $item = $::config{"itemExchange_item_$j"};
		if ($exchangeAlreadyActive) {
			$amount = $::config{"itemExchange_item_$j"."_requiredAmount"};
		} else {
			$amount = $::config{"itemExchange_item_$j"."_triggerAmount"};
		}

		my $index = Utils::findIndexStringList_lc($::char->{inventory}, "name", $::config{"itemExchange_item_$j"});
		return 0 if (!defined $index || $::char->{'inventory'}[$index]{'amount'} < $amount);

		$j++;
	}

	return 1;
}
return 1;