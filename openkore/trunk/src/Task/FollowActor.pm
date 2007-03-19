#########################################################################
#  OpenKore - Long intra-map movement task
#  Copyright (c) 2006 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# This task allows you to follow an actor (the target). This task will
# continue infinitely until you stop it, or until the target has
# disappeared from our sight.
#
# Note that this task does not handle situations where the target has entered
# a portal. It also does not look up the target's coordinate using the party
# list, of the target is a player who's in the party. This task is specialized
# in following a single actor within the same map. More advanced follow
# abilities should be implemented by a different task (TODO: write such a
# task).
package Task::FollowActor;

use strict;
use Time::HiRes qw(time);
use Scalar::Util;

use Modules 'register';
use Globals;
use Task;
use base qw(Task);
use Task::Route;
use Network;
use Log qw(debug);
use Actor;
use Utils qw(timeOut distance getVector moveAlongVector calcPosition);
use Utils::Exceptions;


##
# Task::FollowActor->new(options...)
#
# Create a new Task::FollowActor object. The following options are allowed:
# `l
# - All options allowed for Task->new() except 'mutexes'.
# - actor (required) - The Actor to follow.
# - actorList (required) - The ActorList which contains the actor object.
#                          This is used to check whether the actor is still on screen.
# - maxDistance - The maximum distance that the actor may be away from you.
# - minDistance - If the distance to the actor is greater than maxDistance, then walk
#                 to the actor until you're within distance minDistance.
# `l`
sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new(@_, mutexes => ['movement']);

	if (!$args{actor} || !$args{actorList}) {
		ArgumentException->throw(error => "Invalid arguments.");
	}

	$self->{actorID} = $args{actor}{ID};
	$self->{actorList} = $args{actorList};
	$self->{minDistance} = $args{minDistance} || 1.42; # sqrt(2)
	$self->{maxDistance} = $args{maxDistance} || 1.42; # sqrt(2)

	$self->{probe}{timeout} = 0.33;
	$self->{wait_after_login}{timeout} = 2;

	my @holder = ($self);
	Scalar::Util::weaken($holder[0]);
	$self->{hook} = Plugins::addHook('Network::stateChanged', \&networkStateChanged, \@holder);

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	Plugins::delHook($self->{hook});
}

sub iterate {
	my ($self) = @_;
	return if (!timeOut($self->{probe}));

	if ($net->getState() != Network::IN_GAME) {
		# We got disconnected, so re-lookup the target Actor object when
		# we're reconnected.
		delete $self->{actor};

	} elsif (timeOut($self->{wait_after_login}) && $char->{pos_to} && defined $char->{pos_to}{x}) {
		my $actor = $self->{actor};
		if (!$actor) {
			$actor = $self->{actor} = $self->{actorList}->getByID($self->{actorID});
			if (!$actor) {
				# Target is not on screen and we don't know where it went.
				debug "FollowActor - we lost the target\n", "followActor";
				$self->setDone();
			}
		}
		if ($actor->{dead} || $actor->{disappeared} || $actor->{teleported} || $actor->{disconnected}) {
			# We know the target is gone.
			debug "FollowActor - target is gone\n", "followActor";
			$self->setDone();
		} elsif ($actor->{pos_to} && defined $actor->{pos_to}{x}) {
			# Target is still there.
			$self->processFollow();
		}
	}
	$self->{probe}{time} = time;
}
	
sub processFollow {
	my ($self) = @_;
	my $actor = $self->{actor};

	# Check whether the target is within acceptable distance limits.
	my $distance = distance($char->{pos_to}, $actor->{pos_to});
	if ($distance > $self->{maxDistance}) {
		$self->{withinLimits} = 0;

		# Find an interception point, and go there.

		my $interceptPoint = intercept($char, $actor, $actor->{walk_speed});
		if ($self->{task}) {
			# If we're already walking, check whether we need to adjust the path.
			my $currentDestination = $self->{task}->destCoords();
			if (distance($interceptPoint, $currentDestination) > 1.42) {
				debug "FollowActor - readjusting existing route\n", "followActor";
				$self->{task}->stop();
				delete $self->{task};
			}
		}

		if (!$self->{task}) {
			my $task = $self->{task} = new Task::Route(
				x => $interceptPoint->{x},
				y => $interceptPoint->{y},
				maxTime => 5);
			$task->activate();
			$self->setMutexes('movement');
		}

		$self->{task}->iterate();
		if ($self->{task}->getStatus() == Task::DONE) {
			delete $self->{task};
			$self->setMutexes();
		}

	} else {
		$self->{withinLimits} = 1;
		if ($self->{task}) {
			$self->{task}->stop();
			delete $self->{task};
			$self->setMutexes();
		}
	}
}

sub networkStateChanged {
	my (undef, undef, $holder) = @_;
	if ($net->getState() == Network::IN_GAME) {
		# After logging into the game, wait some time for
		# actors to appear on screen.
		my $self = $holder->[0];
		$self->{wait_after_login}{time} = time;
	}
}

##
# boolean $Task_FollowActor->withinLimits()
#
# Check whether the distance to the actor to be followed is within the
# distance limits, as given to the constructor.
sub withinLimits {
	return $_[0]->{withinLimits};
}

# Hash* intercept(Actor actorA, Actor actorB, int variance)
#
# Find an interception point which allows actor A to intercept actor B.
sub intercept {
	my ($actorA, $actorB, $variance) = @_;
	my $aPos = calcPosition($actorA);
	my $bPos = calcPosition($actorB);
	my %actorB_vec;
	getVector(\%actorB_vec, $actorB->{pos_to}, $bPos);
	my $maxDist = distance($bPos, $actorB->{pos_to});

	for (my $dist = 1; $dist < $maxDist; $dist++) {
		my %try;
		moveAlongVector(\%try, $bPos, \%actorB_vec, $dist);

		my $actorA_to_try_dist = distance($aPos, \%try);
		my $aWalkTime = $actorA_to_try_dist / $actorA->{walk_speed};
		my $bWalkTime = $dist / $actorB->{walk_speed};

		#printf("tryX = %.2f, tryY = %.2f, aTime = %.2f, bTime = %.2f\n",
		#	$try{x}, $try{y}, $aWalkTime, $bWalkTime);

		if ($aWalkTime < $bWalkTime) {
			# Add a small variance to cope with network lag.
			$dist += $variance;
			$dist = $maxDist if ($dist > $maxDist);
			moveAlongVector(\%try, $bPos, \%actorB_vec, $dist);

			$try{x} = int $try{x};
			$try{y} = int $try{y};
			return \%try;
		}
	}
	return $actorB->{pos_to};
}

# sub testIntercept {
# 	my $a = new Actor('Player');
# 	$a->{pos}    = { x => 12, y => 1 };
# 	$a->{pos_to} = { x => 12, y => 1 };
# 	$a->{walk_speed} = 1;
# 	$a->{time_move}  = time;
# 
# 	my $b = new Actor('Monster');
# 	$b->{pos}    = { x => 16, y => 4};
# 	$b->{pos_to} = { x => 1,  y => 6 };
# 	$b->{walk_speed} = 1;
# 	$b->{time_move}  = time;
# 	$b->{time_move_calc} = distance($b->{pos}, $b->{pos_to}) * $b->{walk_speed};
# 
# 	my $ret = intercept($a, $b, $b->{walk_speed});
# 	print "x = $ret->{x}\n";
# 	print "y = $ret->{y}\n";
# }
# testIntercept();

1;
