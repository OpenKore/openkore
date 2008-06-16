#########################################################################
#  OpenKore - Telesearch Plugin v2
#  Copyright (c) 2006 ViVi
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
package telesearchV2;

use strict;
use Plugins;
use Settings;
use Log qw(message error);
use Utils;
use AI;
use Globals;

Plugins::register('Tele-Search v2', 'Alternative tele-search v2.', \&unload);
my $hooks = Plugins::addHooks(
	['AI_pre',\&search, undef],
	['map_loaded', \&MapLoaded, undef],
	['packet/sendMapLoaded', \&MapLoaded, undef],
);

my ($maploaded,$allow_tele);

# Set $maploaded to 1, this incase we reload the plugin for whatever reason...
if ($net && $net->getState() == Network::IN_GAME) {
	$maploaded = 1;
}

sub unload {
    Plugins::delHooks($hooks);
	message("Unloaded Teleport search v2.\n","info");
}
	   
sub MapLoaded {
	$maploaded = 1;
}

sub checkIdle {
	if (AI::action eq "move" && AI::action(1) eq "route" || AI::action eq "route" && !AI::inQueue("attack","skill_use")) {
		return 1;
	} else {
		return 0;
	}
}

sub canTeleport {
	$config{'teleport_search_minSp'} = 10 if (!$config{'teleport_search_minSp'});
	my $item = $char->inventory->getByName("Fly Wing");
	
	if ((!$config{'teleportAuto_useSkill'} && $item) || # Using flywings
		($config{'teleportAuto_useSkill'} > 1) || # Using no SP for teleport
		($config{'teleportAuto_useSkill'} == 1 && $config{'teleport_search_minSp'} <= $char->{sp})) { # Using SP to teleport
		return 1;
	} else {
		return 0;
	}
}

sub search {
	if ($config{'teleport_search'} && Misc::inLockMap() && $timeout{'ai_teleport_search'}{'timeout'}) {
		
		if ($maploaded && !$allow_tele)  {
			$timeout{'ai_teleport_search'}{'time'} = time;
			$allow_tele = 1;
                        
		# Check if we're allowed to teleport, if map is loaded, timeout has passed and we're just looking for targets.
		} elsif ($maploaded && $allow_tele && timeOut($timeout{'ai_teleport_search'}) && checkIdle() && canTeleport()) {
			message("Attemping to tele-search.\n","info");
			$allow_tele = 0;
			$maploaded = 0;
			# Attempt to teleport, give error and unload plugin if we cant.
			if (!Misc::useTeleport(1)) {
				error ("Unable to tele-search cause we can't teleport!\n");
				return;
			} 

		# We're doing something else besides looking for monsters, reset the timeout.
		} elsif (!checkIdle()) {
			$timeout{'ai_teleport_search'}{'time'} = time;
		}
		
        # Oops! timeouts.txt is missing a crucial value, lets use the default value ;)
        } elsif (!$timeout{'ai_teleport_search'}{'timeout'}) {
			error ("timeouts.txt missing setting! Using default timeout of 5 seconds.\n");
			$timeout{'ai_teleport_search'}{'timeout'} = 5;
			return;
        }
}

return 1;
