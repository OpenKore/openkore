#########################################################################
#  OpenKore - Telesearch Plugin v2
#  Copyright (c) 2005 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: $
#  $Id: $
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
	['map_loaded', \&MapLoaded, undef]
	['packet/sendMapLoaded', \&MapLoaded, undef]    
);

my ($maploaded,$allow_tele,$disallow);

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

sub search {
	if ($config{'teleport_search'} && Misc::inLockMap() && $timeout{'ai_teleport_search'}{'timeout'}) {
	
		if ($maploaded && !$allow_tele)  {
			$timeout{'ai_teleport_search'}{'time'} = time;
			$allow_tele = 1;
                        
		# Check if we're allowed to teleport, if map is loaded, timeout has passed and we're just looking for targets.
		} elsif ($maploaded && $allow_tele && timeOut($timeout{'ai_teleport_search'}) && checkIdle()) {
			message("Attemping to tele-search.\n","info");
			$allow_tele = 0;
			$maploaded = 0;
			# Attempt to teleport, give error and unload plugin if we cant.
			if (!Misc::useTeleport(1)) {
				error ("Fatal error, we dont have the skill nor items to teleport! - Unloading plugin.\n");
				unload();
				return;
			} 

		# We're doing something else besides looking for monsters, reset the timeout.
		} elsif (!checkIdle()) {
			$timeout{'ai_teleport_search'}{'time'} = time;
		}
		
        # Oops! timeouts.txt is missing a crucial value, we'll kill the plugin here...
        } elsif (!$timeout{'ai_teleport_search'}{'timeout'}) {
			error ("timeouts.txt missing setting! Add 'ai_teleport_search 5' to make the plugin work.\n");
			unload();
			return;
        }
}

return 1;
