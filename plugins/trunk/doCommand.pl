package doCommand;

#
# This plugin is licensed under the GNU GPL
# Copyright 2005 by kaliwanagan
# --------------------------------------------------

use strict;
use Plugins;
use Globals;
use Log qw(message warning error);
use Misc;
use Utils;
use Commands;
use Time::HiRes qw(time);

Plugins::register('doCommand', 'do a command on certain conditions', \&Unload);
my $hook = Plugins::addHook('AI_post', \&doCommand);

sub Unload {
	Plugins::delHook('AI_post', $hook);
}

my $time;

sub doCommand {
	my $prefix = "doCommand_";
	
	for (my $i =0; (exists $config{$prefix.$i}); $i++) {
		if ((main::checkSelfCondition($prefix.$i)) && main::timeOut($time, $config{$prefix.$i."_timeout"})) {
			Commands::run($config{$prefix.$i});
			$time = time;
		}
	}
}

return 1;