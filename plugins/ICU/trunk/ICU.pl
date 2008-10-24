#########################################################################
#  OpenKore - ICU
#  Copyright (c) 2007 Bibian
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

package ICU; 
  
use strict; 
use Globals; 
use Plugins; 
use Utils; 
use Log qw(debug message warning error); 
use Misc;
  
Plugins::register('I.C.U 0.2.3', 'Detects GM Bot tests.', \&onUnload); 
  
my $hooks = Plugins::addHooks( 
	['is_casting', \&skillDetect, undef], 
	['packet_skilluse', \&skillDetect, undef],
	['Network::Receive::map_changed',\&teleportDetect, undef],
	['mainLoop_post',\&checkCommands, undef],
	['teleport_sent',\&teleported, undef]
); 

my (@commands,%commandInfo,$position,$allowedTeleport);
 
sub onUnload { 
	Plugins::delHooks($hooks); 
} 
 
sub teleported {
	my ($self, $args) = @_;
	$allowedTeleport = 1;
}
 
sub teleportDetect {
	my ($self, $args) = @_;
	my $oldmap = $args->{oldMap};
	
	if ($allowedTeleport || !$config{'icu_0_teleportDetect'}) {
		$allowedTeleport = 0;
		return;
	}
	logEvent("Unauthorized/Forced teleport detected (From ".$oldmap." to ".$field{'name'}." \n");
	playSound("teleport") if $config{'icu_0_teleportSound'};
	runCommands("teleport") if ($config{'icu_0_teleportCommands'});
}

# This part of the plugin is not done yet...
sub skillDetect { 
	my ($self, $args) = @_;
    my $sourceID = $args->{sourceID}; 
    my $targetID = $args->{targetID}; 
    my $skillID = $args->{skillID}; 
	my %coords;
		$coords{x} = $args->{x};
		$coords{y} = $args->{y}; 
	$position = calcPosition($char);
   
   if (($config{'icu_0_skillOnSelfDetect'}) && ($targetID eq $accountID && $sourceID ne $accountID) 
								|| (blockDistance($position,\%coords) < $config{'icu_0_groundSkillDistance'})) {
		my $skill = new Skill(idn => $skillID);
		playSound("skillOnSelf");
		
		if (!$coords{x} && !$coords{y}) {
				logEvent("AID: ".unpack("V1",$sourceID)." used ".$skill->getName()." on us!\n");
			} elsif ($coords{x} && $coords{y}) {
				logEvent("AID: ".unpack("V1",$sourceID)." used ".$skill->getName()." near us\n");
			}
		runCommands("skillOnSelf") if ($config{'icu_0_skillOnSelfCommands'});
	} 
}

sub runCommands {
	my $event = shift;
	
	return if ($commandInfo{count} > 0); # There are still commands that are waiting to be executed!
	
	if ($event eq "teleport") {
			@commands = split(/,/, $config{'icu_0_teleportCommands'});
		} elsif ($event eq "skillOnSelf") {
			@commands = split(/,/, $config{'icu_0_skillOnSelfCommands'});
		} elsif ($event eq "skillOnMonster") {
			@commands = split(/,/, $config{'icu_0_skillOnMonsterCommands'});
		}
	$commandInfo{count} = @commands;
	$commandInfo{time} = time;
	$commandInfo{randomTime} = rand(4);
	logEvent("Preparing to execute ".$commandInfo{count}." commands in response to \"$event\" event. \n");
}

sub logEvent {
	return if (!$config{'icu_0_log'});
	my $string = shift;
	chatLog("k", "*** ".$string." (Our location: ".$field{name}." x:".$position->{x}." y:".$position->{y}.") ***");
}

sub playSound {
	my $event = shift;
	if ($event eq "teleport") {
			Utils::Win32::playSound("".$config{'icu_0_teleportSound'}."")
		} elsif ($event eq "skillOnSelf") {
			Utils::Win32::playSound("".$config{'icu_0_skillOnSelfSound'}."")
		} elsif ($event eq "skillOnMonster") {
			Utils::Win32::playSound("".$config{'icu_0_skillOnMonsterSound'}."")
		}
}

sub checkCommands {
	return if (!$commandInfo{count} || !timeOut($commandInfo{'time'},($config{'icu_0_commandTimeout'} + $commandInfo{randomTime})));
	Commands::run($commands[$commandInfo{current}]);
	logEvent("Ran command ".$commands[$commandInfo{current}]." with ".($config{'icu_0_commandTimeout'} + $commandInfo{randomTime})." second delay");
	$commandInfo{current}++;
	$commandInfo{count}--;
	$commandInfo{randomTime} = rand(2);
	$commandInfo{time} = time;
	
}

return 1;
