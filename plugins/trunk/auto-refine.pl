#########################################################################
#  OpenKore - Auto-Refine
#  Copyright (c) 2008 Bibian
#
# This plugin is licensed under Creative Commons "Attribution-NonCommercial-ShareAlike 2.5"
#
# You are free:
#    * to copy, distribute, display, and perform the work
#    * to make derivative works
# 
# Under the following conditions:
#    * by Attribution: You must attribute the work in the manner specified by the author or licensor.
#    * Noncommercial: You may not use this work for commercial purposes.
#    * Share Alike: If you alter, transform, or build upon this work, you may distribute the resulting work only under a license identical to this one.
#
#    * For any reuse or distribution, you must make clear to others the license terms of this work.
#    * Any of these conditions can be waived if you get permission from the copyright holder.
#
# Your fair use and other rights are in no way affected by the above.
#
# This is a human-readable summary of the Legal Code ( Full License: http://creativecommons.org/licenses/by-nc-sa/2.5/legalcode ). 
# Disclaimer: http://creativecommons.org/licenses/disclaimer-popup?lang=en
# 
#########################################################################
package autoRefine;

use strict;
use Plugins;
use Settings;
use Log qw(message error);
use Utils;
use Globals;
use Task;
use Task::MapRoute;
use Task::TalkNPC;

Plugins::register('Auto-Refine', 'What do you think?', \&unload);
my $hooks = Plugins::addHooks(
	['AI_pre',\&main, undef],
	['map_loaded', \&MapLoaded, undef],
	['packet/sendMapLoaded', \&MapLoaded, undef],
	['parseMsg/pre', \&itemEquiped, undef],
);

my ($item,$metal,$maploaded,$routeCallback,$talkCallback,%npc,$startRefine,$talking);

# Set $maploaded to 1, this incase we reload the plugin for whatever reason...
if ($net && $net->getState() == Network::IN_GAME) {
	$maploaded = 1;
}

sub unload {
    Plugins::delHooks($hooks);
}

$timeout{'refine'}{'timeout'} = 1; # No need to go any faster than 1 iteration per second
$timeout{'refine'}{'time'} = time;

sub main {
	return if (!$maploaded || !$config{"autoRefine_0"} || !timeOut($timeout{'refine'} || ($item && !$item->{equipped})));
	selectItem() if (!$item);
	
	return if (!$item || !$metal || $metal->{amount} < 1);
	
	my ($upgrade,$plus) = $item->name =~ /(.){2}/;
	$item->{upgrade} = $upgrade if ($plus eq "+");
	
	if (!$startRefine) {
		route($npc{map},$npc{x},$npc{y});
	} elsif ($startRefine && $item->{equipped} && $item->{upgrade} < $config{"autoRefine_0_maxRefine"}) { # Item exists, we have metals are near the refiner and equiped the item... it is also below the + treshhold we want
		talkNPC($npc{x},$npc{y},$npc{sequence}." w1 c w1 r0 w1 c w1 c n");
	} elsif ($startRefine && !$item->{equipped}) { # Item exists in inventory but is not equiped, equip it
		$item->equip();
	} elsif ($startRefine && $item->{equipped} && $item->{upgrade} => $config{"autoRefine_0_maxRefine"}) { # Max refined reached, unequip it
		$item->unequip();
		undef $item;
		undef $metal;
	} else {
		$startRefine = 0;
		message("We have run out of items to refine or metals to refine them with!\n","info");
	}
	$timeout{'refine'}{'time'} = time;
}

sub selectItem {
	if ($config{"autoRefine_0"} && !$config{"autoRefine_0_disabled"} && $config{"autoRefine_0_refineStone"} && 
		$config{"autoRefine_0_refineNpc"} && $config{"autoRefine_0_npcSequence"} && $config{"autoRefine_0_zenny"} < $char->{zenny}) {
			
			$item = $char->inventory->getByName($config{"autoRefine_0"});
			$metal = $char->inventory->getByName($config{"autoRefine_0_refineStone"});
			($npc{map},$npc{x},$npc{y}) = $config{"autoRefine_0_refineNpc"} =~ /^(.*) (.*) (.*)$/ if ($item && $metal);
			$npc{sequence} = $config{"autoRefine_0_npcSequence"};
			if (!$item || !$metal) {
				undef $item;
				undef $metal;
			}
		}
	return 0;
}

sub route {
	return if ($taskManager->countTasksByName("MapRoute") > 0 || $startRefine);
	
	my $map = shift;
	my $x = shift;
	my $y = shift;
	my $routeTask = Task::MapRoute->new(map => $map, x => $x, y => $y, distFromGoal => 10, notifyUponArrival => 1);
	$taskManager->add($routeTask);
	$routeCallback = $taskManager->onTaskFinished->add(undef,\&toggleRefine);
}

sub toggleRefine {
	$taskManager->onTaskFinished->remove($routeCallback);
	$startRefine = 1;
}

sub talkNPC {
	return if ($taskManager->countTasksByName("TalkNPC") > 0 || $talking);
	my $x = shift;
	my $y = shift;
	my $sequence = shift;
	my $talkTask = Task::TalkNPC->new(x => $x, y => $y, sequence => $sequence);
	$taskManager->add($talkTask);
	$talking = 1;
	$talkCallback = $taskManager->onTaskFinished->add(undef,\&checkItem);
}

sub checkItem {
	$talking = 0;
	$item = $char->inventory->getByServerIndex($item->{index});
	$taskManager->onTaskFinished->remove($talkCallback);
	if (!$item) {
		$startRefine = 0
		message("Item broke :(\n","info");
	} else {
		message("Upgraded to ".$item->{name}."\n","info");
	}
}

sub itemEquiped {
	my ($self, $args) = @_;
	return if ($args->{switch} ne "00AA" || $args->{switch} ne "00AC"); # 00AA = Item is Equiped packet, 00AC = unequipped	
	$item->{equipped} = ($args->{switch} eq "00AA") ? 1 : 0; # If 00AA then 1, else 0
}

sub MapLoaded {
	$maploaded = 1;
}

return 1;
