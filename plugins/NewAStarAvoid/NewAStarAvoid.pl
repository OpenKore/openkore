package NewAStarAvoid;

use strict;
use Globals;
use Settings;
use Misc;
use Plugins;
use Utils;
use Log qw(message debug error warning);
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

Plugins::register('NewAStarAvoid', 'Enables smart pathing using the dynamic aspect of D* Lite pathfinding', \&onUnload);

use constant {
	PLUGIN_NAME => 'NewAStarAvoid',
	ENABLE_MOVE => 1,
	ENABLE_REMOVE => 1,
};

use constant {
	ENABLE_AVOID_MONSTERS => 1,
	ENABLE_AVOID_PLAYERS => 0,
	ENABLE_AVOID_AREASPELLS => 0,
	ENABLE_AVOID_PORTALS => 0,
};

my $hooks = Plugins::addHooks(
	['PathFindingReset', \&on_PathFindingReset], # Changes args
	['AI_pre/manual', \&on_AI_pre_manual],    # Recalls routing
	['packet_mapChange', \&on_packet_mapChange],
);

my $obstacle_hooks = Plugins::addHooks(
	# Mobs
	['add_monster_list',	\&on_add_monster_list],
	['monster_disappeared', \&on_monster_disappeared],
	['monster_moved',		\&on_monster_moved],
	
	# Players
	['add_player_list',		\&on_add_player_list],
	['player_disappeared',	\&on_player_disappeared],
	['player_moved',		\&on_player_moved],
	
	# Spells
	['packet_areaSpell',				\&on_add_areaSpell_list],
	['packet_pre/area_spell_disappears', \&on_areaSpell_disappeared],
	
	# portals
	['add_portal_list',		\&on_add_portal_list],
	['portal_disappeared',	\&on_portal_disappeared],
);

my $mobhooks = Plugins::addHooks(
	['checkMonsterAutoAttack',	\&on_checkMonsterAutoAttack],
);

sub onUnload {
    Plugins::delHooks($hooks);
	Plugins::delHooks($obstacle_hooks);
    Plugins::delHooks($mobhooks);
}

my %mob_nameID_obstacles = (
	1368 => { # planta carnivora
		weight => 2000,
		dist => 12,
		drop_target_near => 0,
		drop_dest_near => 0,
	}
);

my %player_name_obstacles = (
	
);

my %area_spell_type_obstacles = (
	
);

my %portals_obstacles = (
	weight => 5000,
	dist => 12,
);

my %obstaclesList;

my %removed_obstacle_still_in_list;

my $mustRePath = 0;

my $weight_limit = 65000;

my $teleport_soon = 0;
my $teleport_soon_timeout;

sub on_packet_mapChange {
	undef %obstaclesList;
	$mustRePath = 0;
}

sub on_checkMonsterAutoAttack {
	my (undef, $args) = @_;
	
	my $realMonsterPos = calcPosition($args->{monster});
	my $obstacle = is_there_an_obstacle_near_pos($realMonsterPos, 1);
	if (defined $obstacle) {
		debug "[avoidObstacle 2] Not picking target ".$args->{monster}." because there is an Obstacle outside the screen nearby.\n";
		$args->{return} = 0;
		return;
	}
}

# 1 => target
# 2 => dest
sub is_there_an_obstacle_near_pos {
	my ($pos, $type) = @_;
	foreach my $obstacle_ID (keys %obstaclesList) {
		my $obstacle = $obstaclesList{$obstacle_ID};
		
		if (($type == 1 && $obstacle->{drop_target_near} == 1) || ($type == 2 && $obstacle->{drop_dest_near} == 1)) {
			my $obstacle_last_pos = $obstacle->{pos_to};
		
			my $dist = blockDistance($pos, $obstacle_last_pos);
			my $min_dist = 13;#TODO config this
			next unless ($dist <= $min_dist);
			
			return 1;
		}
	}
	return undef;
}

sub on_AI_pre_manual_drop_target_near_Obstacle {
	my @obstacles = keys(%obstaclesList);
	return unless (@obstacles > 0);
	if (
		   (AI::action eq "attack" && AI::args->{ID})
		|| (AI::action eq "route" && AI::action (1) eq "attack" && AI::args->{attackID})
		|| (AI::action eq "move" && AI::action (2) eq "attack" && AI::args->{attackID})
	) {
		my $args = AI::args;
		my $ID;
		my $ataqArgs;
		if (AI::action eq "attack") {
			$ID = $args->{ID};
			$ataqArgs = AI::args(0);
		} else {
			if (AI::action(1) eq "attack") {
				$ataqArgs = AI::args(1);
				
			} elsif (AI::action(2) eq "attack") {
				$ataqArgs = AI::args(2);
			}
			$ID = $args->{attackID};
		}
		
		my $target = Actor::get($ID);
		return unless ($target);
		my $target_is_aggressive = is_aggressive($target, undef, 0, 0);
		
		my $realMonsterPos = calcPosition($target);
		
		my $obstacle = is_there_an_obstacle_near_pos($realMonsterPos, 1);
		
		if (defined $obstacle) {
			#$char->sendAttackStop;
			if ($target_is_aggressive) {
				warning "[avoidObstacle 3] Dropping agressive target ".$target." during attack because an Obstacle appeared near it.\n";
				$teleport_soon = 1;
				$teleport_soon_timeout->{time} = time;
				$teleport_soon_timeout->{timeout} = 0.8;
				
			} else {
				warning "[avoidObstacle 4] Dropping target ".$target." before attack because an Obstacle appeared near it.\n";
				AI::dequeue while (AI::inQueue("attack"));
			}
		}
	}
}

sub on_AI_pre_manual_teleport_soon {
	return unless ($teleport_soon == 1);
	return unless (main::timeOut($teleport_soon_timeout));
	$teleport_soon = 0;
	useTeleport(1);
}

sub on_AI_pre_manual_drop_route_dest_near_Obstacle {
	my @obstacles = keys(%obstaclesList);
	return unless (@obstacles > 0);
	
	my $arg_i;
	if (AI::is("route")) {
		$arg_i = 0;
		return if (AI::action (1) eq "attack");
	} elsif (AI::action eq "move" && AI::action (1) eq "route") {
		$arg_i = 1;
		return if (AI::action (2) eq "attack");
	} else {
		return;
	}
	
	
	my $args = AI::args($arg_i);
	my $task = get_task($args);
	return unless (defined $task);
	
	return unless ($task->{isRandomWalk} || ($task->{isToLockMap} && $field->baseName eq $config{'lockMap'}));
	
	my $obstacle = is_there_an_obstacle_near_pos($task->{dest}{pos}, 2);
	if (defined $obstacle) {
		warning "[avoidObstacle 5] Dropping current route dest because an Obstacle appeared near it.\n";
		AI::clear("move", "route");
	}
}

###################################################
######## Main obstacle management
###################################################

sub add_obstacle {
	my ($actor, $obstacle, $type) = @_;
	
	if (exists $removed_obstacle_still_in_list{$actor->{ID}}) {
		warning "[".PLUGIN_NAME."] New obstacle $actor on location ".$actor->{pos_to}{x}." ".$actor->{pos_to}{y}." already exists in removed_obstacle_still_in_list, deleting from it and updating position.\n";
		delete $obstaclesList{$actor->{ID}};
		delete $removed_obstacle_still_in_list{$actor->{ID}};
	}
	
	warning "[".PLUGIN_NAME."] Adding obstacle $actor on location ".$actor->{pos_to}{x}." ".$actor->{pos_to}{y}.".\n";
	
	my $weight_changes = create_changes_array($actor->{pos_to}, $obstacle);
	
	$obstaclesList{$actor->{ID}}{pos_to} = $actor->{pos_to};
	$obstaclesList{$actor->{ID}}{weight} = $weight_changes;
	$obstaclesList{$actor->{ID}}{type} = $type;
	$obstaclesList{$actor->{ID}}{name} = $actor->name;
	if ($type eq 'monster') {
		$obstaclesList{$actor->{ID}}{nameID} = $actor->{nameID};
	}
	
	define_extras($actor->{ID}, $obstacle);
	
	$mustRePath = 1;
}

sub define_extras {
	my ($ID, $obstacle) = @_;
	
	if (exists $obstacle->{drop_target_near} && defined $obstacle->{drop_target_near} && $obstacle->{drop_target_near} == 1) {
		$obstaclesList{$ID}{drop_target_near} = 1;
	} else {
		$obstaclesList{$ID}{drop_target_near} = 0;
	}
	
	if (exists $obstacle->{drop_dest_near} && defined $obstacle->{drop_dest_near} && $obstacle->{drop_dest_near} == 1) {
		$obstaclesList{$ID}{drop_dest_near} = 1;
	} else {
		$obstaclesList{$ID}{drop_dest_near} = 0;
	}
}

sub move_obstacle {
	my ($actor, $obstacle, $type) = @_;
	
	return unless (ENABLE_MOVE);
	
	warning "[".PLUGIN_NAME."] Moving obstacle $actor (from ".$actor->{pos}{x}." ".$actor->{pos}{y}." to ".$actor->{pos_to}{x}." ".$actor->{pos_to}{y}.").\n";
	
	my $weight_changes = create_changes_array($actor->{pos_to}, $obstacle);
	
	$obstaclesList{$actor->{ID}}{pos_to} = $actor->{pos_to};
	$obstaclesList{$actor->{ID}}{weight} = $weight_changes;
	
	$mustRePath = 1;
}

sub remove_obstacle {
	my ($actor, $type, $reason) = @_;
	
	return unless (ENABLE_REMOVE);
	
	if (($type eq 'monster' || $type eq 'player') && $reason eq 'outofsight') {
		$removed_obstacle_still_in_list{$actor->{ID}} = 1;
		warning "[".PLUGIN_NAME."] Putting obstacle $actor from ".$actor->{pos_to}{x}." ".$actor->{pos_to}{y}." in to the removed_obstacle_still_in_list.\n";
	
	} else {
		warning "[".PLUGIN_NAME."] Removing obstacle $actor from ".$actor->{pos_to}{x}." ".$actor->{pos_to}{y}.".\n"; 
		delete $obstaclesList{$actor->{ID}};
		$mustRePath = 1;
	}
}

###################################################
######## Tecnical subs
###################################################

sub on_AI_pre_manual {
	on_AI_pre_manual_drop_target_near_Obstacle();
	on_AI_pre_manual_teleport_soon();
	on_AI_pre_manual_drop_route_dest_near_Obstacle();
	on_AI_pre_manual_removed_obstacle_still_in_list();
	on_AI_pre_manual_repath();
}

sub on_AI_pre_manual_removed_obstacle_still_in_list {
	my @obstacles = keys(%removed_obstacle_still_in_list);
	return unless (@obstacles > 0);
	
	#warning "[".PLUGIN_NAME."] removed_obstacle_still_in_list: ".(scalar @obstacles)."\n";
	
	OBSTACLE: foreach my $obstacle_ID (@obstacles) {
		my $obstacle = $obstaclesList{$obstacle_ID};
		
		my $realMyPos = calcPosition($char);
		
		my $dist = blockDistance($realMyPos, $obstacle->{pos_to});
		my $sight = ($config{clientSight}-2); # 2 cell leeway?
		
		next OBSTACLE unless ($dist < $sight);
		
		my $target;
		#LIST: foreach my $list ($playersList, $monstersList, $npcsList, $petsList, $portalsList, $slavesList, $elementalsList) {
		
		if ($obstacle->{type} eq 'monster') {
			my $actor = $monstersList->getByID($obstacle_ID);
			if ($actor) {
				$target = $actor;
			}
		} elsif ($obstacle->{type} eq 'player') {
			my $actor = $playersList->getByID($obstacle_ID);
			if ($actor) {
				$target = $actor;
			}
		}
		
		# Should never happen
		if ($target) {
			warning "[REMOVING TEST] wwwwttttffffff 1.\n";
		} else {
			warning "[removed_obstacle_still_in_list] Removing obstacle ".$obstacle->{name}." (".$obstacle->{type}.") from ".$obstacle->{pos_to}{x}." ".$obstacle->{pos_to}{y}." we at ($realMyPos->{x} $realMyPos->{y}) dist:$dist, sight:$sight.\n";
			delete $obstaclesList{$obstacle_ID};
			delete $removed_obstacle_still_in_list{$obstacle_ID};
			$mustRePath = 1;
		}
	}
}

sub on_AI_pre_manual_repath {
	return unless ($mustRePath);
	
	my $arg_i;
	my $arg_i2;
	
	if (AI::is("route")) {
		$arg_i = 0;
		if (AI::action (1) eq "attack") {
			if (AI::action (2) eq "route") {
				$arg_i2 = 2;
			} elsif (AI::action (3) eq "route") {
				$arg_i2 = 3;
			}
		}
	} elsif (AI::is("move") && AI::action (1) eq "route") {
		$arg_i = 1;
		if (AI::action (2) eq "attack") {
			if (AI::action (3) eq "route") {
				$arg_i2 = 3;
			} elsif (AI::action (4) eq "route") {
				$arg_i2 = 4;
			}
		}
	} else {
		return;
	}
	
	$mustRePath = 0;
	
	my $args = AI::args($arg_i);
	my $task = get_task($args);
	if (defined $task) {
		if (scalar @{$task->{solution}} == 0) {
			Log::warning "[test1] Route already reseted.\n";
		} else {
			Log::warning "[test2] Reseting route.\n";
			$task->resetRoute;
		}
	}
	
	return unless (defined $arg_i2);
	
	my $args2 = AI::args($arg_i2);
	my $task2 = get_task($args2);
	if (defined $task2) {
		if (scalar @{$task2->{solution}} == 0) {
			Log::warning "[test3] Route second already reseted.\n";
		} else {
			Log::warning "[test4] Reseting second route.\n";
			$task2->resetRoute;
		}
	}
}

sub get_task {
	my ($args) = @_;
	if (UNIVERSAL::isa($args, 'Task::Route')) {
		return $args;
	} elsif (UNIVERSAL::isa($args, 'Task::MapRoute') && $args->getSubtask && UNIVERSAL::isa($args->getSubtask, 'Task::Route')) {
		return $args->getSubtask;
	} else {
		return undef;
	}
}

sub on_PathFindingReset {
	my (undef, $hookargs) = @_;
	
	return unless (exists $hookargs->{args}{getRoute} && $hookargs->{args}{getRoute} == 1);
	
	my @obstacles = keys(%obstaclesList);
	
	#warning "[".PLUGIN_NAME."] on_PathFindingReset before check, there are ".@obstacles." obstacles.\n";
	
	return unless (@obstacles > 0);
	
	my $args = $hookargs->{args};

	return if ($args->{field}->name ne $field->name);
	
	#Log::warning "[test] on_PathFindingReset: Using grided info for ".@obstacles." obstacles.\n";
	
	$args->{customWeights} = 1;
	$args->{secondWeightMap} = get_final_grid();
	
	$args->{avoidWalls} = 1 unless (defined $args->{avoidWalls});
	$args->{weight_map} = \($args->{field}->{weightMap}) unless (defined $args->{weight_map});
	
	$args->{randomFactor} = 0 unless (defined $args->{randomFactor});
	$args->{useManhattan} = 0 unless (defined $args->{useManhattan});
	
	$args->{timeout} = 1500 unless ($args->{timeout});
	$args->{width} = $args->{field}{width} unless ($args->{width});
	$args->{height} = $args->{field}{height} unless ($args->{height});
	$args->{min_x} = 0 unless (defined $args->{min_x});
	$args->{max_x} = ($args->{width}-1) unless (defined $args->{max_x});
	$args->{min_y} = 0 unless (defined $args->{min_y});
	$args->{max_y} = ($args->{height}-1) unless (defined $args->{max_y});
	
	$hookargs->{return} = 0;
}

sub getOffset {
	my ($x, $width, $y) = @_;
	return (($y * $width) + $x);
}

sub get_final_grid {
	my $changes = sum_all_changes();
	return $changes;
}

sub get_weight_for_block {
	my ($ratio, $dist) = @_;
	if ($dist == 0) {
		$dist = 1;
	}
	my $weight = int($ratio/($dist*$dist));
	if ($weight >= $weight_limit) {
		$weight = $weight_limit;
	}
	return $weight;
}

sub create_changes_array {
	my ($obstacle_pos, $obstacle) = @_;
	
	my %obstacle = %{$obstacle};
	
	my $max_distance = $obstacle{dist};
	my $ratio = $obstacle{weight};
	
	my @changes_array;
	
	my ($min_x, $min_y, $max_x, $max_y) = $field->getSquareEdgesFromCoord($obstacle_pos, $max_distance);
	
	my @y_range = ($min_y..$max_y);
	my @x_range = ($min_x..$max_x);
	
	foreach my $y (@y_range) {
		foreach my $x (@x_range) {
			next unless ($field->isWalkable($x, $y));
			my $pos = {
				x => $x,
				y => $y
			};
			
			my $distance = adjustedBlockDistance($pos, $obstacle_pos);
			my $delta_weight = get_weight_for_block($ratio, $distance);
			#warning "[".PLUGIN_NAME."] $x $y ($distance) -> $delta_weight.\n";
			push(@changes_array, {
				x => $x,
				y => $y,
				weight => $delta_weight
			});
		}
	}
	
	@changes_array = sort { $b->{weight} <=> $a->{weight} } @changes_array;
	
	return \@changes_array;
}

sub sum_all_changes {
	my %changes_hash;
	
	#warning "[".PLUGIN_NAME."] 1 obstaclesList: ". Data::Dumper::Dumper \%obstaclesList;
	
	foreach my $key (keys %obstaclesList) {
		#warning "[".PLUGIN_NAME."] sum_all_avoid - testing obstacle at $obstaclesList{$key}{pos_to}{x} $obstaclesList{$key}{pos_to}{y}.\n";
		foreach my $change (@{$obstaclesList{$key}{weight}}) {
			my $x = $change->{x};
			my $y = $change->{y};
			my $changed = $change->{weight};
			$changes_hash{$x}{$y} += $changed;
		}
	}
	
	my @rebuilt_array;
	foreach my $x_keys (keys %changes_hash) {
		foreach my $y_keys (keys %{$changes_hash{$x_keys}}) {
			next if ($changes_hash{$x_keys}{$y_keys} == 0);
			push(@rebuilt_array, { x => $x_keys, y => $y_keys, weight => $changes_hash{$x_keys}{$y_keys} });
		}
	}
	
	#warning "[".PLUGIN_NAME."] 2 rebuilt: ". Data::Dumper::Dumper \@rebuilt_array;
	
	return \@rebuilt_array;
}

###################################################
######## Player avoiding
###################################################

sub on_add_player_list {
	return unless (ENABLE_AVOID_PLAYERS);
	my (undef, $args) = @_;
	my $actor = $args;
	
	return unless (exists $player_name_obstacles{$actor->{name}});
	
	my %obstacle = %{$player_name_obstacles{$actor->{name}}};
	
	add_obstacle($actor, \%obstacle, 'player');
}

sub on_player_moved {
	return unless (ENABLE_AVOID_PLAYERS);
	my (undef, $args) = @_;
	my $actor = $args;
	
	return unless (exists $obstaclesList{$actor->{ID}});
	
	my %obstacle = %{$player_name_obstacles{$actor->{name}}};
	
	move_obstacle($actor, \%obstacle, 'player');
}

sub on_player_disappeared {
	return unless (ENABLE_AVOID_PLAYERS);
	my (undef, $args) = @_;
	my $actor = $args->{player};
	
	return unless (exists $obstaclesList{$actor->{ID}});
	
	remove_obstacle($actor, 'player');
}

###################################################
######## Mob avoiding
###################################################

sub on_add_monster_list {
	return unless (ENABLE_AVOID_MONSTERS);
	my (undef, $args) = @_;
	my $actor = $args;
	
	return unless (exists $mob_nameID_obstacles{$actor->{nameID}});
	
	my %obstacle = %{$mob_nameID_obstacles{$actor->{nameID}}};
	
	add_obstacle($actor, \%obstacle, 'monster');
}

sub on_monster_moved {
	return unless (ENABLE_AVOID_MONSTERS);
	my (undef, $args) = @_;
	my $actor = $args;

	return unless (exists $obstaclesList{$actor->{ID}});
	
	my %obstacle = %{$mob_nameID_obstacles{$actor->{nameID}}};
	
	move_obstacle($actor, \%obstacle, 'monster');
}

sub on_monster_disappeared {
	return unless (ENABLE_AVOID_MONSTERS);
	my (undef, $args) = @_;
	my $actor = $args->{monster};
	
	return unless (exists $obstaclesList{$actor->{ID}});
	
	my $reason;
	if ($args->{type} == 0) {
		$reason = 'outofsight';
	} else {
		$reason = 'gone';
	}
	message ("[on_monster_disappeared] $actor type $args->{type} | reason $reason\n", "route");
	remove_obstacle($actor, 'monster', $reason);
}

###################################################
######## Spell avoiding
###################################################

# TODO: Add fail flag check

sub on_add_areaSpell_list {
	return unless (ENABLE_AVOID_AREASPELLS);
	my (undef, $args) = @_;
	my $ID = $args->{ID};
	my $spell = $spells{$ID};
	
	return unless (exists $area_spell_type_obstacles{$spell->{type}});
	
	my %obstacle = %{$area_spell_type_obstacles{$spell->{type}}};
	
	add_obstacle($spell, \%obstacle, 'spell');
}

sub on_areaSpell_disappeared {
	return unless (ENABLE_AVOID_AREASPELLS);
	my (undef, $args) = @_;
	my $ID = $args->{ID};
	my $spell = $spells{$ID};
	
	return unless (exists $obstaclesList{$spell->{ID}});
	
	remove_obstacle($spell, 'spell');
}

###################################################
######## portals avoiding
###################################################

sub on_add_portal_list {
	return unless (ENABLE_AVOID_PORTALS);
	my (undef, $args) = @_;
	my $actor = $args;
	
	add_obstacle($actor, \%portals_obstacles, 'portal');
}

sub on_portal_disappeared {
	return unless (ENABLE_AVOID_PORTALS);
	my (undef, $args) = @_;
	my $actor = $args->{portal};
	
	#remove_obstacle($actor, 'portal');
}

return 1;