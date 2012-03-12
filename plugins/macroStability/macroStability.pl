#############################################################################
# macroStability revised 03 plugin by imikelance										
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
# 0 or unset	: Checks for macro plugin and macro file on startup			
# 1				: Disables startup checks
#
# Quick note: if you have a macro or automacro that needs to be triggered while not ingame
# you can add _ignoreState to it's name and this plugin won't pause it.
# Also, you can use "set ignoreState 1" inside your automacro's conditions or declare
# $ignoreState = 1 inside your macro and it should have the same effect.	
#
# 22:37 quarta-feira, 15 de fevereiro de 2012 - revised 03
#	- working with Openkore r7946		
#
# 19:37 domingo, 29 de janeiro de 2012 - revised 02
#	- added ignoreState variable support
#   - added SILENT constant. Set it to 1 to hide macroStability common warnings
#	- fixed a small bug where Openkore would crash if "reload macros" is used while macros are paused.
#
# 19:53 quinta-feira, 26 de janeiro de 2012 - revised 01
# 	- now you can use _ignoreState to avoid pausing any macro
#
# 09:15 domingo, 1 de janeiro de 2012 (Happy new year!)
# 	- released !			
#
# TODO: (if possible) Write a function to go back one step in macros and give users an option to turn this on/off
# TODO: allow users to rename macro.pl without modifying code
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
# TODO: we should check if macro plugin is loaded, not if macro.pl exists.
sub onKStart {
	unless ($::config{macroStability_disableChecks} == 1) {
		unless (-e $workingFolder."/macro.pl") {
			error("[macroStability] ERROR: macro plugin is not installed or it was renamed from macro.pl.\n");
			error("If you renamed macro.pl, please set \"macroStability_disableChecks\" to 1 in ".Settings::getControlFilename("config.txt").".\n");
			error("macroStability will now unload.\n");
			unload;
			die "macro plugin is not installed or it was renamed from macro.pl.";
		}
		if (defined $::config{macro_file}) {
			if (!defined Settings::getControlFilename($::config{macro_file})) {
				error("[macroStability] ".$::config{macro_file}." is not found.\n");
				error("macroStability will now unload.\n");
				unload;
			}
		} else {
			if (!defined Settings::getControlFilename("macros.txt")) {
				error("[macroStability] macros.txt is not found.\n");
				error("macroStability will now unload.\n");
				unload;
			}
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