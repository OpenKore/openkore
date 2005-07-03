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

# Original itemExchange by xlr82xs
# Modified by Joseph
# Modified again by kaliwanagan

package itemExchange;
 
#itemExchange Rough Oridecon {
#	npc prt_in 63 69
#	distance 5
#	steps c r0 n
#	requiredAmount 5
#	triggerAmount 5
#}
 
use strict;
use Plugins;
use Globals;
use Log qw(message warning error);
use AI;
use Misc;
 
Plugins::register('itemExchange', 'exchanges items with NPCs using talk sequence', \&Unload);
my $hook1 = Plugins::addHook('AI_pre', \&AI_pre);
 
sub Unload {
	Plugins::delHook('AI_pre', $hook1);
}
 
sub AI_pre {
	if (AI::action eq "itemExchange") {
		my $args = AI::args;
		if ($args->{'stage'} eq 'end') {
			AI::dequeue;
		} elsif ($args->{'stage'} eq 'route') {
			message "Calculating auto-exchange route \n", "route";
			main::ai_route($args->{'npc'}{'map'}, $args->{'npc'}{'pos'}{'x'}, $args->{'npc'}{'pos'}{'y'},
				attackOnRoute => 1,
				distFromGoal => $args->{'distFromGoal'});
			$args->{'stage'} = 'talk';
		} elsif ($args->{'stage'} eq 'talk') {
			$args->{'stage'} = ($char->{'inventory'}[$args->{'invIndex'}]{'amount'} >= $args->{'requiredAmount'}) ? 'talk' : 'end';
			main::ai_talkNPC($args->{'npc'}{'pos'}{'x'}, $args->{'npc'}{'pos'}{'y'}, $args->{'steps'}) if ($args->{'stage'} ne 'end');
		}
	}
	exchange() if ((AI::isIdle || AI::action eq "route") && !AI::inQueue("itemExchange"));
}
 
sub exchange {
	my $prefix = "itemExchange_";
	my $i = 0;
 
	while (exists $config{$prefix.$i}) {
		my $invIndex = main::findIndexStringList_lc($char->{'inventory'}, "name", $config{$prefix.$i});
		my $item = $char->{'inventory'}[$invIndex];
		if ((defined $invIndex) && ($item->{'amount'} >= $config{$prefix.$i."_triggerAmount"})) {
			my %args;
			$args{'npc'} = {};
			main::getNPCInfo($config{$prefix.$i."_npc"}, $args{'npc'});
			$args{'distFromGoal'} = $config{$prefix.$i."_distance"};
			$args{'steps'} = $config{$prefix.$i."_steps"};
			$args{'requiredAmount'} = $config{$prefix.$i."_requiredAmount"};
			$args{'invIndex'} = $invIndex;
			$args{'stage'} = ($field{'name'} eq $args{'npc'}{'map'}) ? 'talk' : 'route';
			AI::queue('itemExchange', \%args);
			last;
		}
		$i++;
	}
}
 
return 1;