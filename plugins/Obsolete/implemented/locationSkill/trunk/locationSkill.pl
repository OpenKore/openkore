package locationSkill;

#
# Based on the suggestions by pmak
# This plugin is licensed under the GNU GPL
# Copyright 2005 by kaliwanagan
# --------------------------------------------------
#
# How to install this thing..:
#
# in control\config.txt add:
#  
#locationSkill skillname {		# name of the area skill to use
#	coords [x, y[, map] ]		# if x and y are omitted, cast the skill at char's current location
#	whenAtCoords [x, y[, range]]	# only cast when at specified coordinates, or is within range
#	lvl [x]				# defaults to 10 if unspecified
#	coords_whenGround 		# similar to whenGround and whenNotGround - only cast the spell if the ...
#	coords_whenNotGround		# target coordinate has/doesn't have the specified ground effect
#	skillDelay			# cast skill only after n seconds have passed, counted from the last time the same skill was cast
#	blockDelayBeforeUse 	    	# cast skill only after n seconds have passed, counted *before* the last time skill block was used
#	blockDelayAfterUse	     	# same as blockDelayBeforeUse, but count seconds *after* the skill block was used
#	hp
#	sp
#	onAction
#	whenStatusActive
#	whenStatusInactive
#	whenFollowing
#	spirit
#	aggressives
#	monsters
#	notMonsters
#	stopWhenHit 0
#	notWhileSitting 0
#	notInTown 0
#	disabled 0
#	inInventory
#}

use strict;
use Plugins;
use Globals;
use Log qw(message warning error);
use AI;
use Skills;

Plugins::register('locationSkill', 'cast skill at a certain location', \&Unload);
my $hook1 = Plugins::addHook('AI_post', \&call);
my $hook2 = Plugins::addHook('packet_skilluse', \&packet_skilluse);

sub Unload {
	Plugins::delHook('packet_skilluse', $hook2);
	Plugins::delHook('AI_post', $hook1);
}

my %skillUse;
my %delay;

sub packet_skilluse {
	my (undef, $args) = @_;
	my $skillID = $args->{'skillID'};
	my $sourceID = $args->{'sourceID'};
	my $x = $args->{'x'};
	my $y = $args->{'y'};
	
	if ($sourceID eq $accountID) {
		$skillUse{$skillID} = 1;
	}
}

sub call {
	if (AI::action eq 'locationSkill') {
		my $args = AI::args;
		if ($args->{'stage'} eq 'end') {
			AI::dequeue;
		} elsif ($args->{'stage'} eq 'skillUse') {
			main::ai_skillUse(
				$args->{'handle'}, 
				$args->{'lvl'}, 
				$args->{'maxCastTime'}, 
				$args->{'minCastTime'}, 
				$args->{'x'}, $args->{'y'}
			);
			$args->{'stage'} = 'end';
		}
	}
	locationSkill() if (AI::isIdle); 
}

sub locationSkill {
	my $prefix = "locationSkill_";
	my $i = 0;
	while (exists $config{$prefix.$i}) {
		if ((main::checkSelfCondition($prefix.$i)) &&
			main::timeOut($delay{$prefix.$i."_blockDelayBeforeUse"}) && 
			main::timeOut($delay{$prefix.$i."_blockDelayAfterUse"})
		) {
			my $skillObj = Skills->new(name => $config{$prefix.$i});
			unless ($skillObj->handle) {
				my $msg = "Unknown skill name ".$config{$prefix.$i}." in $prefix.$i\n";
				error $msg;
				configModify($prefix.$i."_disabled", 1);
				next;
			}

			my %skill;
			($skill{'x'}, $skill{'y'}, my $map) = split / *, */, $config{$prefix.$i."_coords"};
			my $pos = main::calcPosition($char);
			$skill{'x'} = $skill{'x'} || $pos->{'x'};
			$skill{'y'} = $skill{'y'} || $pos->{'y'};

			$delay{$prefix.$i."_blockDelayBeforeUse"}{'timeout'} = $config{$prefix.$i."_blockDelayBeforeUse"};
			if (!$delay{$prefix.$i."_blockDelayBeforeUse"}{'set'}) {
				$delay{$prefix.$i."_blockDelayBeforeUse"}{'time'} = time;
				$delay{$prefix.$i."_blockDelayBeforeUse"}{'set'} = 1;
			}
	
			$delay{$prefix.$skillObj->handle."_skillDelay"}{'timeout'} = $config{$prefix.$i."_skillDelay"};
			if ($skillUse{$skillObj->id}) { # set the delays only when the skill gets successfully cast
				$delay{$prefix.$skillObj->handle."_skillDelay"}{'time'} = time;
				$skillUse{$skillObj->id} = 0;
			}

			my %range;
			($range{'x'}, $range{'y'}, $range{'range'}) = split / *, */, $config{$prefix.$i."_whenAtCoords"};

			my $inRange;
			$inRange = (($pos->{'x'} <= ($range{'x'} + $range{'range'})) &&
						($pos->{'x'} >= ($range{'x'} - $range{'range'})) &&
						($pos->{'y'} <= ($range{'y'} + $range{'range'})) &&
						($pos->{'y'} >= ($range{'y'} - $range{'range'})));
			undef %range;

			if ((checkCoordsCondition($prefix.$i."_coords",\%skill)) &&
				main::timeOut($delay{$prefix.$skillObj->handle."_skillDelay"}) &&
				(($inRange || (!$config{$prefix.$i."_whenAtCoords"}))) && 
				(($map eq $field{'name'}) || !$map)
			) {
				$skill{'handle'} = $skillObj->handle;
				$skill{'lvl'} = ($config{$prefix.$i."_lvl"}) || 10;
				$skill{'maxCastTime'} = $config{$prefix.$i."_maxCastTime"};
				$skill{'minCastTime'} = $config{$prefix.$i."_minCastTime"};
				$skill{'stage'} = 'skillUse';
				AI::queue('locationSkill', \%skill);
				$delay{$prefix.$i."_blockDelayAfterUse"}{'timeout'} = $config{$prefix.$i."_blockDelayAfterUse"};
				$delay{$prefix.$i."_blockDelayAfterUse"}{'time'} = time;
				$delay{$prefix.$i."_blockDelayBeforeUse"}{'set'} = 0;
				last;
			}
		}
		$i++;
	}
}

sub checkCoordsCondition {
	my $prefix = shift;
	my $coord = shift;

	if ($config{$prefix."_whenGround"}) {
		return 0 unless main::whenGroundStatus($coord, $config{$prefix."_whenGround"});
	}
	if ($config{$prefix."_whenNotGround"}) {
		return 0 if main::whenGroundStatus($coord, $config{$prefix."_whenNotGround"});
	}

	return 1;
}

return 1; 
