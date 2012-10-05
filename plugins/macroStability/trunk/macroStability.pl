#############################################################################
# macroStability plugin by imikelance/Revok
# r4
#																			
# Openkore: http://openkore.com/											
# Openkore Brazil: http://openkore.com.br/	
# Plugin Discussion (in portuguese): http://openkore.com.br/index.php?/topic/1688-macrostability-revised-01-by-imikelance/									
#																			
# config.txt lines:															
#																			
# macroStability_disable <boolean flag>										
# 0 or unset	: Plugin enabled											
# 1				: Plugin disabled											
#																			
# macroStability_disableChecks <boolean flag>								
# 0 or unset	: Checks for macro plugin on startup			
# 1				: Disables startup checks
#
# Quick note: if you have a macro or automacro that needs to be triggered while not ingame
# you can add _ignoreState to it's name and this plugin won't pause it.
# Also, you can use "set ignoreState 1" inside your automacro's conditions or declare
# $ignoreState = 1 inside your macro and it should have the same effect.	
#	
# TODO: (if possible) Write a function to go back one step in macros and give users an option to turn this on/off
# DONE: allow users to rename macro.pl without modifying code
#																			
# This source code is licensed under the									
# GNU General Public License, Version 3.									
# See http://www.gnu.org/licenses/gpl.html									
#############################################################################

package macroStability;

use strict;
use Plugins;
use Log qw( warning message error );

# Plugin
Plugins::register("macroStability", "suspend macros when not ingame", \&unload);

	my $myHooks = Plugins::addHooks(
		# kept commented for future releases with this function implemented.
		#["disconnected",       \&manageMacroOnDC,     undef],
		["packet/map_loaded",       \&resumeMacro,     undef],
		['start3',       \&onKStart, undef],
		["Network::stateChanged",       \&pauseMacro,     undef]
);

my $workingFolder = $Plugins::current_plugin_folder;

# Plugin unload
sub unload {
	if (defined $myHooks) {
		message("\nmacroStability unloading.\n\n");
		Plugins::delHooks($myHooks);
		undef $myHooks;
	}
}

# you can change some of this plugin settings below !
use constant {
	PLUGINNAME				=>	"macroStability",
	VERSION					=>	"revised 03",
	# disable almost every message. error messages will still be shown
	SILENT					=>	0,
};

# Subs

# handles macro plugin availability
# DONE: we should check if macro plugin is loaded, not if macro.pl exists.
sub onKStart {
	unless ($::config{macroStability_disableChecks} == 1) {
		my $loaded;
		for (my $i = 0; $i < @Plugins::plugins; $i++) {
			$loaded = 1 if ($Plugins::plugins[$i]->{name} eq "macro");
		}
		unless ($loaded) {
			unload;
			die ("[macroStability] ERROR: macro plugin is not installed.\n".
			"If you know what you're doing, you can disable this warning by setting \"macroStability_disableChecks\" to 1 in ".Settings::getControlFilename("config.txt").".\n");
		}
	}
}

# resumes macro after receiving packet map_loaded
sub resumeMacro {
	if (defined $Macro::Data::varStack{'ignoreState'} && $Macro::Data::varStack{'ignoreState'} == 0) {
		delete $Macro::Data::varStack{'ignoreState'};
	}
	if ($::macro::onHold == 1 && defined $::macro::queue->name) {
		if ($::macro::queue->name =~ /^tempMacro.*/) {
			warningplus("[macro] Disconnected, macro [".$::macro::queue->name." called by ".$Macro::Data::varStack{'.caller'}."] is now resumed.\n");
		} else {
			warningplus("[macro] Connected, macro [".$::macro::queue->name."] is now resumed.\n");
		}
		$::macro::onHold = 0;
	}
}	

# pause macro when not ingame
sub pauseMacro {
	if (defined $::macro::queue && $::config{macroStability_disable} != 1 && $::macro::onHold == 0 && $::net->getState() != 5) {
		if ($::macro::queue->name =~ /^tempMacro.*/) {
			if ($Macro::Data::varStack{'.caller'} =~ /.*_ignoreState$/) {
				warningplus("[macro] Disconnected, ignoring macro [".$::macro::queue->name." called by ".$Macro::Data::varStack{'.caller'}."] because of _ignoreState.\n");
				return;
			} elsif (defined $Macro::Data::varStack{'ignoreState'}) {
				warningplus("[macro] Disconnected, ignoring macro [".$::macro::queue->name." called by ".$Macro::Data::varStack{'.caller'}."] because of \$ignoreState var.\n") unless ($Macro::Data::varStack{'ignoreState'} == 0);
				$Macro::Data::varStack{'ignoreState'} = 0;
				return;
			}
			warningplus("[macro] Disconnected, macro [".$::macro::queue->name." called by ".$Macro::Data::varStack{'.caller'}."] is now paused.\n");
		} else {
			if ($::macro::queue->name =~ /.*_ignoreState$/) {
				warningplus("[macro] Disconnected, ignoring macro [".$::macro::queue->name."] because of _ignoreState.\n");
				return;
			} elsif (defined $Macro::Data::varStack{'ignoreState'}) {
				warningplus("[macro] Disconnected, ignoring macro [".$::macro::queue->name."] because of \$ignoreState var.\n") unless ($Macro::Data::varStack{'ignoreState'} == 0);
				$Macro::Data::varStack{'ignoreState'} = 0;
				return;
			}
			warningplus("[macro] Disconnected, macro [".$::macro::queue->name."] is now paused.\n");
		}
		$::macro::onHold = 1; # pause macros !
	}
}

sub warningplus {
	# SILENT constant support. sub should be renamed, but i'm too lazy to do it
	my ($msg, $msglevel) = @_;
	if (!defined $msglevel || $msglevel == "") {
		warning($msg) unless (SILENT == 1);
	} elsif ($msglevel == 0) {
		message($msg) unless (SILENT == 1);
	} elsif ($msglevel == 1) {
		warning($msg) unless (SILENT == 1);
	} elsif ($msglevel == 2) {
		error($msg);
	}
}
	

# kept commented for future releases with this function implemented.
# sub manageMacroOnDC {
	# my $macroName;
	# $macroName = $::macro::queue->name;
	# if (defined $::macro::queue && $::config{macroStability_disable} != 1 && $::macro::onHold == 0 && $::net->getState() != 5) {	
		# if (!defined $::config{macroStability_onDc} || $::config{macroStability_onDc} == 0) {
			# warning("[macro] Disconnected, macro [".$::macro::queue->name."] is now paused.\n");
			# $::macro::onHold = 1;
		# } elsif ($::config{macroStability_onDc} == 1) {
			# warning("[macro] Disconnected or timed out, restarting [".$::macro::queue->name."].\n");
			# $::macro::onHold = 1;
			# undef $::macro::queue;
			# $::macro::queue = new Macro::Script($macroName, 0);
		# }
	# }
# }

1;
# i luv u mom