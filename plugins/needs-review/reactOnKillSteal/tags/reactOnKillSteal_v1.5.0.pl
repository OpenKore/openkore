# =======================
# reactOnKillSteal v1.5.0
# =======================
# by hakore (hakore@users.sourceforge.net)
# see documentation at: http://openkore.sourceforge.net/forum/viewtopic.php?t=8648

package reactOnKillSteal;

use strict;
use Plugins;
use Globals;
use Utils;
use Log qw(message error warning debug);
use Commands;
use Misc;

my %ksCounts;
my %ksReactions;
my $forget_time;


Plugins::register('reactOnKillSteal', 'react when kill stealed', \&Unload);
my $hooks = Plugins::addHooks(
            ['is_casting', \&onParseMsg, undef],
            ['packet_skilluse', \&onParseMsg, undef],
            ['packet_attack', \&onParseMsg, undef],
            ['AI_pre', \&onAIpre, undef]
);

sub Unload {
	Plugins::delHooks($hooks);
	message "reactOnKillSteal plugin unloaded.\n";
};

sub onAIpre {
	return unless ($main::conState == 5);
	return if (!$config{'reactOnKillSteal'});
	my $command = $ai_v{temp}{reactOnKillSteal}{command};

	if ($command && timeOut($ai_v{temp}{reactOnKillSteal}{time}, $ai_v{temp}{reactOnKillSteal}{timeOut_delay})) {
		if (!Commands::run($command)) {
			main::parseCommand($command) if (defined &main::parseCommand);
		}
		$ai_v{temp}{reactOnKillSteal}{isEmoticon} = 1 if ($command =~ /^e\s/);
		undef $ai_v{temp}{reactOnKillSteal}{command};
		$ai_v{temp}{reactOnKillSteal}{time} = time;
	}

	if ($config{'reactOnKillSteal_forgetReactions'} && timeOut($forget_time, 30)) {
		foreach (keys %ksReactions) {
			if (timeOut($ksReactions{$_}{'time'}, $config{'reactOnKillSteal_forgetReactions'})) {
				delete $ksReactions{$_};
			}
		}
		$forget_time = time;
	}
}

sub onParseMsg {
	return unless ($main::conState == 5);
	return if (!$config{'reactOnKillSteal'});
	my ($trigger, $args) = @_;

	my $ID1 = $args->{sourceID};
	my $ID2 = $args->{targetID};

	if ($ID1 eq $accountID && $monsters{$ID2}) {
		# You attack monster
		# If monster is untouched mark it so we know we need to react if this is kill stealed
		$monsters{$ID2}{reactOnKillSteal} = 1 if !$monsters{$ID2}{reactOnKillSteal} && checkMonsterUnengaged($ID2);

	} elsif ($ID2 eq $accountID && $monsters{$ID1}) {
		# Monster attacks you
		# If monster is untouched mark it so we know we need to react if this is kill stealed
		$monsters{$ID1}{reactOnKillSteal} = 1 if !$monsters{$ID1}{reactOnKillSteal} && checkMonsterUnengaged($ID1);

	} elsif (
	  # Player attacks monster
	  !$monsters{$ID1} && $monsters{$ID2}

	  # Ignore Player Unknown #0
	  && (unpack("V1", $ID1) ne "0")

	  # We only trigger reaction on KS if we are currently attacking a monster
	  && AI::action eq "attack"
	  && $monsters{$ai_seq_args[0]{ID}} 
	  && (!timeOut(AI::args->{ai_attack_giveup}) || $config{attackNoGiveup})

	  # If the monster is your target or you are the target of the monster
	  && ($ID2 eq AI::args->{ID} || $monsters{$ID2}{target} eq $accountID)

	  # And if the monster is previouly marked 'reactOnKillSteal'
	  && $monsters{$ID2}{reactOnKillSteal}
	) {
		# This is a new monster, increment kill steal count
		if (!$monsters{$ID2}{ksedByPlayer}{$ID1}) {
			$ksCounts{$ID1}++;
			$monsters{$ID2}{ksedByPlayer}{$ID1} = 1;
		}
		
		# Stop here if the previous reaction is not yet executed
		return if $ai_v{temp}{reactOnKillSteal}{command};
		
		# Stop here if the timeout has not yet elapsed
		return unless timeOut($ai_v{temp}{reactOnKillSteal}{time}, $ai_v{temp}{reactOnKillSteal}{timeOut});
		undef $ai_v{temp}{reactOnKillSteal}{timeOut};
		
		my $damage;
		my $skillID;
		
		# resolve $damage and $skillID values from the the 3 different hooks
		if ($trigger eq 'packet_attack') {
			$damage = $args->{dmg};
			$skillID = 0;
		} elsif ($trigger eq 'packet_skilluse') {
			$damage = $args->{damage};
			$skillID = $args->{skillID};
		} else {
			$damage = 0;
			$skillID = $args->{skillID};
		}
		
		# Determine the reactOnKillSteal block to use
		for (my $i = 0; exists $config{"reactOnKillSteal_$i"}; $i++) {
			my $prefix = "reactOnKillSteal_$i";
			next if (!$config{$prefix});
			
			if ( checkKillStealCondition(
				$prefix, 
				$ID1, 
				$ID2, 
				$damage, 
				$skillID, 
				($trigger eq 'is_casting') ? 1 : 0
			)) {
				# determine the set of commands to use
				my $commandList;
				
				my $j = $ksReactions{$ID1}{$i};
				
				if (!$j) {
					$commandList = $config{$prefix};
					$ai_v{temp}{reactOnKillSteal}{lastCommand} = $prefix;
				
				} elsif (exists $config{$prefix . "_altCommand_" . ($j - 1)}) {
					if ($config{$prefix . "_altCommand_" . ($j - 1)}) {
						$commandList = $config{$prefix . "_altCommand_" . ($j - 1)};
						$ai_v{temp}{reactOnKillSteal}{lastCommand} = $prefix . "_altCommand_" . ($j - 1);
					} else {
						$commandList = $config{$ai_v{temp}{reactOnKillSteal}{lastCommand}};
					}
				} elsif (exists $config{$prefix . "_altCommand_persist"}) {
					if ($config{$prefix . "_altCommand_persist"}) {
						$commandList = $config{$prefix . "_altCommand_persist"};
						$ai_v{temp}{reactOnKillSteal}{lastCommand} = $prefix . "_altCommand_persist";
					} else {
						$commandList = $config{$ai_v{temp}{reactOnKillSteal}{lastCommand}};
					}	
				}
				
				if ($commandList) {
					# Choose a random command from the list
					my $command;
					my @commands;
					
					@commands = split(/\s*;+\s*/, $commandList);
					$command = $commands[rand(@commands)];
					
					if ($command) {
						# remove leading whitespaces
						$command =~ s/^\s*//g;
						
						# resolve keywords
						$command =~ s/\@monsterNum/$monsters{$ID2}{binID}/gi;
						$command =~ s/\@monsterName/$monsters{$ID2}{name}/gi;
						$command =~ s/\@playerNum/$players{$ID1}{binID}/gi;
						$command =~ s/\@playerName/$players{$ID1}{name}/gi;
						
						my $source = Actor::get($ID1);
						my $target = Actor::get($ID2);
						message("$source kill steals my $target! [" . int($ksCounts{$ID1}) . "x]\n", "reactOnKillSteal");
						
						my $delay = getCommandChatDelay($command);
						
						# ensure that you will not spam emoticons that overwrite each other
						$delay = 3.9 if ($command =~ /^e\s/ && $ai_v{temp}{reactOnKillSteal}{isEmoticon} == 1);
						undef $ai_v{temp}{reactOnKillSteal}{isEmoticon};
						
						message("Reacting to kill steal - execute command \"$command\" (delay " . int($delay * 1000) . "ms)\n", "reactOnKillSteal");
						
						$ai_v{temp}{reactOnKillSteal}{command} = $command;
						$ai_v{temp}{reactOnKillSteal}{timeOut_delay} = $delay;
					}
					
					$ksReactions{$ID1}{$i}++;
					$ksReactions{$ID1}{total}++;
					$ksReactions{$ID1}{time} = time;
					
					my $timeOut = $config{"reactOnKillSteal_timeout"};
					$timeOut += rand($config{"reactOnKillSteal_timeoutSeed"}) if $config{"reactOnKillSteal_timeoutSeed"};
					
					$ai_v{temp}{reactOnKillSteal}{timeOut} = $timeOut;
					$ai_v{temp}{reactOnKillSteal}{time} = time;
				}
				last;
			
			}
		
		}
	
	}

};


##
# checkMonsterUnengaged(ID)
# ID: ID of the monster
#
# determines if the monster hasn't attacked a player
# and players haven't attacked the monster.
sub checkMonsterUnengaged {
	my $ID = shift;
	my $monster = $monsters{$ID};

	# If monster hasn't been attacked by other players
	if (!binSize([keys %{$monster->{'missedFromPlayer'}}])
	 && !binSize([keys %{$monster->{'dmgFromPlayer'}}])
	 && !binSize([keys %{$monster->{'castOnByPlayer'}}])

	 # and it hasn't attacked any other player
	 && !binSize([keys %{$monster->{'missedToPlayer'}}])
	 && !binSize([keys %{$monster->{'dmgToPlayer'}}])
	 && !binSize([keys %{$monster->{'castOnToPlayer'}}])
	) {
		return 1;
	} else {
		return 0;
	}
};



##
# getCommandChatDelay(command)
# command: console command
#
# determines if the console command is a chat
# and returns a corresponding delay (to simulate typing).
sub getCommandChatDelay {
	my $command = shift;
	my $isChat = 0;
	my $message;
	if ($command =~ /^c\s/ || $command =~ /^g\s/ || $command =~ /^p\s/) {
		(undef, $message) = split(/ +/, $command, 2);
		$isChat = 1;
	} elsif ($command =~ /^pm\s/) {
		(undef, undef, $message) = split(/ /, $command, 3);
		$isChat = 1;
	}
		
	## COPIED FROM processChatResponse, ChatQueue.pm
	# Calculate a small delay (to simulate typing)
	# The average typing speed is 65 words per minute.
	# The average length of a word used by RO players is 4.25 characters (yes I measured it).
	# So the average user types 65 * 4.25 = 276.25 charcters per minute, or
	# 276.25 / 60 = 4.6042 characters per second
	# We also add a random delay of 0.5-1.5 seconds. <-- changed this to 0-0.75 seconds.
	return rand(0.75) + length($message) / 4.6042 if $isChat;
};



sub checkKillStealCondition {
	my ($prefix, $ID1, $ID2, $damage, $skillID, $isCasting) = @_;

	return 0 if ($config{$prefix . "_disabled"} > 0);
	if ($config{$prefix . "_inLockOnly"} > 0) { return 0 unless $field{name} eq $config{lockMap}; }


	if ($config{$prefix . "_notParty"} > 0) { 
		return 0 if Utils::existsInList($config{tankersList}, $players{$ID1}{name}) ||
			($chars[$config{'char'}]{'party'} && %{$chars[$config{'char'}]{'party'}}
			&& $chars[$config{'char'}]{'party'}{'users'}{$ID1} && %{$chars[$config{'char'}]{'party'}{'users'}{$ID1}}); }
	if ($config{$prefix . "_notTankModeTarget"} > 0) { 
		return 0 if $config{'tankMode'} && $config{'tankModeTarget'} eq $players{$ID1}{'name'}; }
	if ($config{$prefix . "_attackTargetOnly"} > 0) { return 0 unless AI::args->{ID} eq $ID2; }


	if ($config{$prefix . "_monsters"}) {
		return 0 unless existsInList($config{$prefix . "_monsters"}, $monsters{$ID2}{'name'}); }
	if ($config{$prefix . "_notMonsters"}) {
		return 0 if existsInList($config{$prefix . "_notMonsters"}, $monsters{$ID2}{'name'}); }

	if ($config{$prefix . "_whenPlayerIsUnknown"} > 0) { 
		return 0 unless !UNIVERSAL::isa($players{$ID1}, 'Actor') && !$config{$prefix . "_whenPlayerIsKnown"}; }
	if ($config{$prefix . "_whenPlayerIsKnown"} > 0) { 
		return 0 if !UNIVERSAL::isa($players{$ID1}, 'Actor') && !$config{$prefix . "_whenPlayerIsUnknown"}; }
		
	if ($config{$prefix . "_players"}) {
		return 0 unless existsInList($config{$prefix . "_players"}, $players{$ID1}{'name'}); }
	if ($config{$prefix . "_notPlayers"}) {
		return 0 if existsInList($config{$prefix . "_notPlayers"}, $players{$ID1}{'name'}); }
	if ($config{$prefix . "_playerIDs"}) {
		return 0 unless existsInList($config{$prefix . "_playerIDs"}, unpack("V1", $ID1)); }
	if ($config{$prefix . "_notPlayerIDs"}) {
		return 0 if existsInList($config{$prefix . "_notPlayerIDs"}, unpack("V1", $ID1)); }


	if ($config{$prefix . "_player_lvl"}) {
		return 0 unless Utils::inRange($players{$ID1}{lv}, $config{$prefix . "_player_lvl"}); }
	if ($config{$prefix . "_player_sex"}) {
		return 0 unless $sex_lut{$players{$ID1}{'sex'}} eq $config{$prefix . "_player_sex"}; }
	if ($config{$prefix . "_player_isJob"}) {
		return 0 unless Utils::existsInList($config{$prefix . "_player_isJob"}, $jobs_lut{$players{$ID1}{'jobID'}}); }
	if ($config{$prefix . "_player_isNotJob"}) {
		return 0 if Utils::existsInList($config{$prefix . "_player_isNotJob"}, $jobs_lut{$players{$ID1}{'jobID'}}); }


	if ($config{$prefix . "_player_damage"}) {
		return 0 unless Utils::inRange($monsters{$ID2}{'dmgFromPlayer'}{$ID1}, $config{$prefix . "_player_damage"}); }
	if ($config{$prefix . "_player_misses"}) {
		return 0 unless Utils::inRange($monsters{$ID2}{'missedFromPlayer'}{$ID1}, $config{$prefix . "_player_misses"}); }
	if ($config{$prefix . "_player_ksCount"}) {
		return 0 unless Utils::inRange($ksCounts{$ID1}, $config{$prefix . "_player_ksCount"}); }
	if ($config{$prefix . "_player_reactionCount"}) {
		return 0 unless Utils::inRange($ksReactions{$ID1}{total}, $config{$prefix . "_player_reactionCount"}); }


	if ($config{$prefix . "_damage"}) { 
		return 0 unless Utils::inRange($damage, $config{$prefix . "_damage"}); }
	if ($config{$prefix . "_skills"}) {
		message($prefix . "_skills = " . $config{$prefix . "_skills"} . ", \$skillID = $skillID\n", "reactOnKillSteal");
		if (!$skillID) {
			return 0 unless Utils::existsInList($config{$prefix . "_skills"}, "Normal Attack");
		} else {
			return 0 unless Utils::existsInList($config{$prefix . "_skills"}, Skills->new(id => $skillID)->name);
		}
	}
	if ($config{$prefix . "_notSkills"}) {
		if (!$skillID) {
			return 0 if Utils::existsInList($config{$prefix . "_notSkills"}, "Normal Attack");
		} else {
			return 0 if Utils::existsInList($config{$prefix . "_notSkills"}, Skills->new(id => $skillID)->name);
		}
	}
	if ($config{$prefix . "_isCasting"} > 0) { return 0 unless ($isCasting); }

	return 1;
};

return 1;
