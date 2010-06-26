package AI::Slave::Homunculus;

use strict;
use base qw/AI::Slave/;
use Globals;
use Log qw/message warning error debug/;
use Utils;
use Misc;
use Translation;

sub checkSkillOwnership { $_[1]->getOwnerType == Skill::OWNER_HOMUN }

sub iterate {
	my $slave = shift;
	
	# homunculus is in rest
	if ($slave->{state} & 2) {
	# homunculus is dead
	} elsif ($slave->{state} & 4) {
	# homunculus is alive
	} elsif ($slave->{appear_time} && $field{name} eq $slave->{map}) {
		# auto-feed homunculus
		$config{homunculus_intimacyMax} = 999 if (!$config{homunculus_intimacyMax});
		$config{homunculus_intimacyMin} = 911 if (!$config{homunculus_intimacyMin});
		$config{homunculus_hungerTimeoutMax} = 60 if (!$config{homunculus_hungerTimeoutMax});
		$config{homunculus_hungerTimeoutMin} = 10 if (!$config{homunculus_hungerTimeoutMin});
		$config{homunculus_hungerMin} = 11 if (!$config{homunculus_hungerMin});
		$config{homunculus_hungerMax} = 24 if (!$config{homunculus_hungerMax});

		# Stop feeding when homunculus reaches 999~1000 intimacy, its useless to keep feeding from this point on
		# you can starve it till it gets 911 hunger (actually you can starve it till 1 but we wanna keep its intimacy loyal).
		if (($slave->{intimacy} >= $config{homunculus_intimacyMax}) && $slave->{feed}) {
			$slave->{feed} = 0
		} elsif (($slave->{intimacy} <= $config{homunculus_intimacyMin}) && !$slave->{feed}) {
			$slave->{feed} = 1
		}

		if ($slave->{hungerThreshold} 
			&& $slave->{hunger} ne '' 
			&& $slave->{hunger} <= $slave->{hungerThreshold} 
			&& timeOut($slave->{feed_time}, $slave->{feed_timeout})
			&& $slave->{feed}
			&& $config{homunculus_autoFeed} 
			&& (existsInList($config{homunculus_autoFeedAllowedMaps}, $field{'name'}) || !$config{homunculus_autoFeedAllowedMaps})) {
			
			$slave->processFeeding();
			message TF("Auto-feeding your Homunculus (%d hunger).\n", $slave->{hunger}), 'slave';
			$messageSender->sendHomunculusCommand(1);
			message TF("Next feeding at: %d hunger.\n", $slave->{hungerThreshold}), 'slave';
		
		# No random value at initial start of Kore, lets make a few =)
		} elsif ($slave->{actorType} eq 'Homunculus' && !$slave->{hungerThreshold}) {
			$slave->processFeeding();
		
		} else {
			$slave->SUPER::iterate;
		}
	}
}

sub processFeeding {
	my $slave = shift;
	
	# Homun loses intimacy if you let hunger fall lower than 11 and if you feed it above 75 (?)
	$slave->{hungerThreshold} = $config{homunculus_hungerMin}+ int(rand($config{homunculus_hungerMax} - $config{homunculus_hungerMin}));
	# Make a random timeout, to appear more humanlike when we have to feed our homun more than once in a row.
	$slave->{feed_timeout} = int(rand(($config{homunculus_hungerTimeoutMax})-$config{homunculus_hungerTimeoutMin}))+$config{homunculus_hungerTimeoutMin};
	$slave->{feed_time} = time;
}

1;
