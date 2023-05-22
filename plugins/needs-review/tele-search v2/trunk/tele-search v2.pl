# =======================
# Tele-Search v2.1
# =======================
# This plugin is licensed under the GNU GPL
# Copyright (c) 2006 by ViVi [mod by ya4ept]
#
# http://forums.openkore.com/viewtopic.php?f=34&t=134
# http://sourceforge.net/p/openkore/code/HEAD/tree/plugins/tele-search%20v2/trunk/
#
# Example (put in config.txt):
#	route_randomWalk 1
#	teleport_search 1
#	teleport_search_minSp 10
#
# Put in timeouts.txt:
#	ai_teleport_search 5

package telesearchV2;

use strict;
use Plugins;
use Globals qw($char %config $net %timeout);
use Log qw(message error);
use Utils qw(timeOut);
use AI;


Plugins::register('Tele-Search v2', 'Alternative tele-search v2.', \&unload, \&unload);

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
	undef $maploaded;
	undef $allow_tele;
	message "Tele-Search v2 plugin unloading or reloading\n", 'success';
}

sub MapLoaded {
	$maploaded = 1;
}

sub checkIdle {
	if (AI::action eq "move" && AI::action(1) eq "route" || AI::action eq "route" && !AI::inQueue("attack","skill_use", "buyAuto", "sellAuto", "storageAuto")) {
		return 1;
	} else {
		return 0;
	}
}

sub search {
	if ($config{'teleport_search'} && Misc::inLockMap() && $timeout{'ai_teleport_search'}{'timeout'}) {

		if ($maploaded && !$allow_tele) {
			$timeout{'ai_teleport_search'}{'time'} = time;
			$allow_tele = 1;

		# Check if we're allowed to teleport, if map is loaded, timeout has passed and we're just looking for targets.
		} elsif ($maploaded && $allow_tele && timeOut($timeout{'ai_teleport_search'}) && checkIdle()) {
			message ("Attemping to tele-search.\n","info");
			$allow_tele = 0;
			$maploaded = 0;
			# Attempt to teleport, give error and unload plugin if we cant.
			if (!Misc::canUseTeleport(1)) {
				error ("Unable to tele-search cause we can't teleport!\n");
				return;
			}
			ai_useTeleport(1);

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

1;