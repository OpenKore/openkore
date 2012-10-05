#############################################################################
# avoidSyncEx plugin by imikelance										
#																			
# Openkore: http://openkore.com/											
# Openkore Brazil: http://openkore.com.br/		
#															
# 20:26 quarta-feira, 1 de fevereiro de 2012
# 	- released !					
#																			
# This source code is licensed under the									
# GNU General Public License, Version 3.									
# See http://www.gnu.org/licenses/gpl.html									
#############################################################################
package avoidSyncEx;

use strict;
use Plugins;
use Utils qw( timeConvert existsInList );
use Time::Hires qw(time);
use Log qw( warning message error );
use AI;
use Globals;

use constant {
	PLUGINNAME				=>	"avoidSyncEx",
	# you can change some of this plugin settings below !
	DEBUG					=>	0,		# set to 1 to show debug messages
	SILENT					=>	0,		# disable almost every message. error messages will still be shown
	MIN_TIME				=>	8,		# use minutes. you can use, for example, 1.5 for 1 minute and 30 seconds.
	MIN_TIME_SEED			=>	0.5,	# use minutes. you can use, for example, 1.5 for 1 minute and 30 seconds.
	MAX_TIME				=>	9,		# after <time> seconds we'll ignore >some< checks and try to disconnect as soon as possible
	DC_TIME					=>	5,		# use seconds
	DC_TIME_SEED			=>	10,		# use seconds
	DEACTIVATE				=>	1,
};


# Plugin
Plugins::register(PLUGINNAME, "avoid sync ex request", \&unload);

	my $myHooks = Plugins::addHooks(
		['Network::stateChanged',       \&ingame],
		['AI_pre', 					\&checkTime],
	);


my $timeToDc;
my $timeToDcMax;

my $workingFolder = $Plugins::current_plugin_folder;
# won't disconnect if any of these AI actions are queued
my @notWhile = qw(macro attack skill_use NPC items_gather take items_take teleport);
# won't disconnect if any of these AI actions are queued while in emergency DC mode
my @notWhileE = qw(macro);
my @mapdb;
&start;

if (DEACTIVATE == 1) {
	&unload;
}
	

# Subs

sub checkTime {
	return unless (time >= $timeToDc);
	my $map = $field->baseName;
	foreach (@mapdb) {
		if ($_ eq $map) {
			msg("Not allowed to disconnect while in this map ".$field->baseName." !", 3, 1);
			return;
		}
	}
	if (time > $timeToDcMax) {
		my $notWhileE;
		foreach $notWhileE (@notWhileE) {
			if (existsInList($notWhileE, AI::action())) {
				msg("Waiting for $notWhileE action to finish", 3, 1);
				return;
			}
		}
		msg("Disconnecting with urgency to avoid sync request EX.");
		&crelog();
	} elsif ( time >= $timeToDc ) {
		# won't dc if any of the following actions are queued
		my $notWhile;
		foreach $notWhile (@notWhile) {
			if (existsInList($notWhile, AI::action())) {
				msg("Waiting for $notWhile action to finish", 3, 1);
				return;
			}
		}
		msg("Disconnecting to avoid sync request EX.");
		&crelog();
	}
}

sub crelog {
	Commands::run("relog ".(DC_TIME + int(rand(DC_TIME_SEED))));
}

sub ingame {
	return if ($::net->getState() != 3);
	AI::clear("sitting", "sitAuto");
	$timeToDc = time + (MIN_TIME*60) + int(rand(MIN_TIME_SEED*60));
	$timeToDcMax = time + (MAX_TIME*60);
	msg("Got current time !", 2, 1);
	msg("We'll disconnect in ".&timeConvert($timeToDc - time)." to avoid sync request ex !", 2, 0);
}

sub start {
	# nosave parser
	# brAthena\npc\mapflag\nosave.txt
	# thx insidemybrain !
	open MAPDBH, "<:utf8", $workingFolder."/nosave.txt"
		or die "cannot open ".$workingFolder."/nosave.txt: $!";
		while (<MAPDBH>) {
			chomp;
			my $currline = $_;
			$currline =~ s/^\s*//; $currline =~ s/\s*$//; 
			if (($currline !~ /^\/\//) and ($currline ne "")){
				if ($currline =~ /^(.*)\tmapflag\tnosave\tSavePoint$/) {
					push(@mapdb, $1);
				}
			}
			
		}
	close MAPDBH;
	msg("MapDB loaded ! ",0,1);
}

sub msg {
	# SILENT constant support and sprintf.
	my ($msg, $msglevel, $debug) = @_;
	
	unless ($debug eq 1 && DEBUG ne 1) {
	$msg = "[".PLUGINNAME."] ".$msg."\n";
		if (!defined $msglevel || $msglevel == "" || $msglevel == 0) {
			warning($msg) unless (SILENT == 1);
		} elsif ($msglevel == 1) {
			message($msg) unless (SILENT == 1);
		} elsif ($msglevel == 2) {
			warning($msg) unless (SILENT == 1);
		} elsif ($msglevel == 3) {
			error($msg);
		}
	}
	return 1;
}

# Plugin unload
sub unload {
	message("\n".PLUGINNAME." unloading.\n\n");
	Plugins::delHooks($myHooks);
	undef $workingFolder;
	undef $timeToDc;
	undef $timeToDcMax;
	undef @notWhile;
	undef @notWhileE;
	undef @mapdb;
}

1;
# i luv u mom