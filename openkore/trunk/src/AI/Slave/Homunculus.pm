package AI::Slave::Homunculus;

use strict;
use Time::HiRes qw(time);
use base qw/AI::Slave/;
use Globals;
use Log qw/message warning error debug/;
use Utils;
use Misc;
use Translation;
use AI;

sub checkSkillOwnership { $_[1]->getOwnerType == Skill::OWNER_HOMUN }

sub iterate {
	my $slave = shift;
	
	# homunculus is in rest
	if ($slave->{state} & 2) {
	
	# homunculus is dead / not present
	} elsif ($slave->{state} & 4) {
	
	# homunculus is alive
	} elsif ($slave->{appear_time} && $field->baseName eq $slave->{map}) {
		# auto-feed homunculus
		# We don't need random and feeding limit. They don't prevent from banning or being suspicious.
		$config{homunculus_hunger} = 15 if (!$config{homunculus_hunger}); #Fix value instead of random
		$config{homunculus_return} = 11 if (!$config{homunculus_return}); #Fix value instead of random
		$timeout{ai_homunFeed} = 60 if (!$timeout{ai_homunFeed}); #Timeout value : Default 60sec
	
		if (timeOut($slave->{feed_time}, $timeout{ai_homunFeed}) && ($slave->{hunger} <= $config{homunculus_return} || ($slave->{hunger} <= $config{homunculus_hunger} && $config{homunculus_autoFeed}))) {
			if ($slave->{hunger} <= $config{homunculus_return}) { #Return
				message TF("Homunculus hunger reaches the return value.\n", 'slave');
				my $skill = new Skill(handle => 'AM_REST');
				ai_skillUse2($skill, $char->{skills}{BS_GREED}{lv}, 1, 0, $char, "AM_REST");
				$slave->{feed_time} = time;
			} elsif ($slave->{hunger} ne '' 
			&& $slave->{hunger} <= $config{homunculus_hunger}
			&& timeOut($slave->{feed_time}, $timeout{ai_homunFeed})
			&& $config{homunculus_autoFeed} 
			&& (existsInList($config{homunculus_autoFeedAllowedMaps}, $field->baseName) || !$config{homunculus_autoFeedAllowedMaps})) {
			$slave->{feed_time} = time;
			message TF("Auto-feeding %s (%d hunger).\n", $slave, $slave->{hunger}), 'slave';
			$messageSender->sendHomunculusCommand(1);
			message TF("Next feeding at: %d hunger.\n", $config{homunculus_hunger}), 'slave';
			
			# No random value at initial start of Kore, lets make a few =)
			} elsif ($slave->{actorType} eq 'Homunculus' && !$config{homunculus_hunger}) {
				$slave->{feed_time} = time;
			
			} else {
				$slave->SUPER::iterate;
			}
		}
	}
}

1;
