############################################################
#
# itemExchange
# 
# This software is open source, licensed under the 
# GNU General Public License, version 2.

# See this thread for detailed config information:
# http://openkore.sourceforge.net/forum/viewtopic.php?t=8668

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

#itemExchange Grape {
#	npc payon xx yy
#	distance 5
#	steps c c r0 r1 n
#	requiredAmount 1
#	triggerAmount 20
#	inInventory Empty Bottle > 0
#	respawnFirst 1
#}
 
use strict;
use Plugins;
use Globals;
use Log qw(message warning error);
use AI;
use Misc;
 
Plugins::register('itemExchange', 'exchanges items with NPCs using talk sequence', \&Unload);
my $hook1 = Plugins::addHooks(['AI_pre', \&AI_pre]);
my $hook2 = Commands::register(['itemexchange', 'force an item exchange', \&itemexchange_command]);

sub Unload {
	Commands::unregister($hook2);
	Plugins::delHooks($hook1);
}

sub itemexchange_command {
	my ($switch, $args) = @_;
	exchange('command') if ($switch eq "itemexchange");
}

sub AI_pre {
	if (AI::action eq "itemExchange") {
		my $args = AI::args;
		if ($args->{'stage'} eq 'end') {
			AI::dequeue;
		} elsif ($args->{'stage'} eq 'route') {
			my $npcMap = $args->{'npc'}{'map'};
			my $npcX = $args->{'npc'}{'pos'}{'x'};
			my $npcY = $args->{'npc'}{'pos'}{'y'};
			message "Calculating auto-exchange route to $npcMap ($npcX, $npcY)\n", "route";
			main::ai_route($npcMap, $npcX, $npcY,
				attackOnRoute => 0,
				distFromGoal => $args->{'distFromGoal'});
			$args->{'stage'} = 'talk';
		} elsif ($args->{'stage'} eq 'talk') {
			$args->{'stage'} = ($char->{'inventory'}[$args->{'binID'}]{'amount'} >= $args->{'requiredAmount'}) ? 'talk' : 'end';
			main::ai_talkNPC($args->{'npc'}{'pos'}{'x'}, $args->{'npc'}{'pos'}{'y'}, $args->{'steps'}) if ($args->{'stage'} ne 'end');
		}
	}
	exchange('poll') if ((AI::isIdle || AI::action eq "route") && !AI::inQueue("itemExchange"));
}
 
sub exchange {
	my $source = shift;
	my $prefix = "itemExchange_";
	my $i = 0;
 
	while (exists $config{$prefix.$i}) {
		my $binID = main::findIndexStringList_lc($char->{'inventory'}, "name", $config{$prefix.$i});
		my $item = $char->{'inventory'}[$binID];
		if (
		((defined $binID) && ($source eq 'poll') && ($item->{'amount'} >= $config{$prefix.$i."_triggerAmount"}) && (checkSelfCondition($prefix.$i))) ||
		((defined $binID) && ($source eq 'command') && ($item->{'amount'} >= $config{$prefix.$i."_requiredAmount"}))
		) {
			ai_useTeleport(2) if ($config{$prefix.$i."_respawnFirst"});
			my %args;
			$args{'npc'} = {};
			main::getNPCInfo($config{$prefix.$i."_npc"}, $args{'npc'});
			$args{'distFromGoal'} = $config{$prefix.$i."_distance"};
			$args{'steps'} = $config{$prefix.$i."_steps"};
			$args{'requiredAmount'} = $config{$prefix.$i."_requiredAmount"};
			$args{'binID'} = $binID;
			$args{'stage'} = ($field{'name'} eq $args{'npc'}{'map'}) ? 'talk' : 'route';
			AI::queue('itemExchange', \%args);
			last;
		}
		$i++;
	}
}
 
return 1;
