package freeCast;

# This plugin is licensed under the GNU GPL
# Copyright 2008 by DInvalid
# Portions Copyright 2005 by kaliwanagan
# --------------------------------------------------
# Experimental! Use on your own risk!
# How to install this thing..:
#
# The plugin will activate if:
# you have the skill free cast at level 1 or higher, and
# config is set:
# runFromTargetFree 1
# runFromTargetFree_min 7
# runFromTargetFree_mid 9
# runFromTargetFree_max 12
#

use strict;
use Plugins;
use Globals;
use Translation qw(T TF);
use Log qw(message warning error);
use AI;
use Skill;
use Misc;
use Network;
use Network::Send;
use Utils;
use Math::Trig;
use Utils::Benchmark;
use Utils::PathFinding;


Plugins::register('Free Cast', 'experimental sage free cast support', \&Unload);
my $hook1 = Plugins::addHook('AI_post', \&call);
my $ID;
my $target;
my %timeout;
my ($myPos, $monsterPos,$monsterDist);

##
# round($number)
#
# Returns the rounded number
sub round {
	my($number) = shift;
	return int($number + .5 * ($number <=> 0));
}


sub Unload {
	Plugins::delHook('AI_post', $hook1);
}

sub call {
	my $i = AI::findAction("attack");
	if (defined $i) {
		my $args = AI::args($i);
		$ID = $args->{ID};
		$target = Actor::get($ID);
		$myPos = $char->{pos_to};
		$monsterPos = $target->{pos_to};
		$monsterDist = round(distance($myPos, $monsterPos));
	}

	if (AI::action eq "skill_use") {
		my $args = AI::args(AI::action);
		my $s = $args->{skillHandle};
		if ($s eq "MG_FIREBOLT" || $s eq "MG_COLDBOLT" || $s eq "MG_LIGHTNINGBOLT" || $s eq "MG_THUNDERSTORM") {
			cast();
		}
	}
}

sub cast {
	if (($char->{skills}{SA_FREECAST}{lv}) && main::timeOut(\%timeout)){

		#message "Cast!\n";
		my ($realMyPos, $realMonsterPos, $realMonsterDist, $hitYou);
		my $realMyPos = calcPosition($char);
		my $realMonsterPos = calcPosition($target);
		my $realMonsterDist = round(distance($realMyPos, $realMonsterPos));

		$myPos = $realMyPos;
		$monsterPos = $realMonsterPos;
		$hitYou = 0;

		if ($config{'runFromTargetFree'} && ($realMonsterDist < $config{'runFromTargetFree_min'})) {
			#my $begin = time;
			my @blocks = $field->calcRectArea($myPos->{x}, $myPos->{y},$config{'runFromTargetFree_mid'});

			my $highest;
			foreach (@blocks) {
				my $dist = ord(substr($field->{dstMap}, $_->{y} * $field->{width} + $_->{x}));
				if (!defined $highest || $dist > $highest) {
					$highest = $dist;
				}
			}
			my $pathfinding = new PathFinding;
			use constant AVOID_WALLS => 4;
			for (my $i = 0; $i < @blocks; $i++) {
				# We want to avoid walls (so we don't get cornered), if possible
				my $dist = ord(substr($field->{dstMap}, $blocks[$i]{y} * $field->{width} + $blocks[$i]{x}));
				if ($highest >= AVOID_WALLS && $dist < AVOID_WALLS) {
					delete $blocks[$i];
					next;
				}

				$pathfinding->reset(
					field => $field,
					start => $myPos,
					dest => $blocks[$i]
				);
				my $ret = $pathfinding->runcount;
				if ($ret < 0 || $ret > $config{'runFromTargetFree_min'} * 2) {
					delete $blocks[$i];
					next;
				}

				delete $blocks[$i] unless ($field->checkLOS($blocks[$i], $realMonsterPos, 1));
			}

			my $largestDist;
			my $best_spot;
			foreach (@blocks) {
				next unless defined $_;
				my $dist = distance($monsterPos, $_);
				if (!defined $largestDist || $dist > $largestDist) {
					$largestDist = $dist;
					$best_spot = $_;
				}
			}

			$char->move($best_spot->{x}, $best_spot->{y}, $ID) if ($best_spot);

		} elsif ($config{'runFromTargetFree'} && ($realMonsterDist > $config{'runFromTargetFree_max'})) {
			my $radius = $config{runFromTargetFree_max}-1;
			my @blocks = calcRectArea2($realMonsterPos->{x}, $realMonsterPos->{y},
			$radius,
			$config{runFromTargetFree_mid});

			my $best_spot;
			my $best_dist;
			for my $spot (@blocks) {
				if (
					$field->isWalkable($spot->{x}, $spot->{y}) &&
					$field->checkLOS($spot, $realMonsterPos, $config{attackCanSnipe})
				) {
					my $dist = distance($realMyPos, $spot);
					if (!defined($best_dist) || $dist < $best_dist) {
						$best_dist = $dist;
						$best_spot = $spot;
					}
				}
			}

			$char->move($best_spot->{x}, $best_spot->{y}, $ID) if ($best_spot);

		}

	}
	$timeout{time} = time;
	$timeout{timeout} = 1;
}

return 1;
