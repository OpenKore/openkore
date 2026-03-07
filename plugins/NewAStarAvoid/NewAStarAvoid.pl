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

Plugins::register('NewAStarAvoid', 'Enables smart pathing using the dynamic aspect of A* Lite pathfinding', \&onUnload);

use constant {
	PLUGIN_NAME => 'NewAStarAvoid',
	ENABLE_MOVE => 0,
	ENABLE_REMOVE => 1,
};

use constant {
	ENABLE_AVOID_MONSTERS => 1,
	ENABLE_AVOID_PLAYERS => 0,
	ENABLE_AVOID_AREASPELLS => 1,
	ENABLE_AVOID_PORTALS => 1,
};

my $hooks = Plugins::addHooks(
	['PathFindingReset', \&on_PathFindingReset], # Changes args
	['AI_pre/manual', \&on_AI_pre_manual],    # Recalls routing
	['packet_mapChange', \&on_packet_mapChange],
	['undefined_object_id', \&use_od],
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
	
	['actor_avoid_removal',	\&on_actor_avoid_removal],
);

my $mobhooks = Plugins::addHooks(
	['AI::Attack::process', \&on_getBestTarget, undef],
	['getBestTarget',	\&on_getBestTarget],
);

my $chooks = Commands::register(
	['od', 'obstacles dump', \&use_od],
);

sub onUnload {
    Plugins::delHooks($hooks);
	Plugins::delHooks($obstacle_hooks);
    Plugins::delHooks($mobhooks);
	Commands::unregister($chooks);
}

my %mob_nameID_obstacles = (
	# Geographer
	1368 => {
		weight => 2000,
		dist => 12,
		drop_target_near => 0,
		drop_dest_near => 1,
	},
	
	# Muscipular
	1780 => {
		weight => 2000,
		dist => 12,
		drop_target_near => 0,
		drop_dest_near => 1,
	},

	# Drosera
	1781 => {
		weight => 2000,
		dist => 12,
		drop_target_near => 0,
		drop_dest_near => 1,
	},
);

my %player_name_obstacles = (
	
);

my %area_spell_type_obstacles = (
	135 => {
		weight => 2000,
		dist => 12,
		drop_target_near => 0,
		drop_dest_near => 1,
	},
	136 => {
		weight => 2000,
		dist => 12,
		drop_target_near => 0,
		drop_dest_near => 1,
	},
);

my %portals_obstacles = (
	weight => 5000,
	dist => 12,
);

my %obstaclesList;

my %removed_obstacle_still_in_list;

my $mustRePath = 0;

my $weight_limit = 65000;

sub use_od {
	warning "[NewAStarAvoid] [use_od] obstaclesList Dump: " . Dumper(\%obstaclesList);
	warning "[NewAStarAvoid] [use_od] removed_obstacle_still_in_list Dump: " . Dumper(\%removed_obstacle_still_in_list);
}

sub on_packet_mapChange {
	undef %obstaclesList;
	undef %removed_obstacle_still_in_list;
	$mustRePath = 0;
}

sub on_getBestTarget {
	my ($hook, $args) = @_;

	my $target = $args->{target};
	my $targetPos = calcPosFromPathfinding($field, $target);

	my $is_dropped = isTargetDroppedObstacle($target);
	
	my $drop_string;
	if ($hook eq 'AI::Attack::process') {
		$drop_string = 'Dropping';
	} elsif ($hook eq 'getBestTarget') {
		$drop_string = 'Not picking';
	}
	
	my $obstacle = is_there_an_obstacle_near_pos($targetPos, 1);
	if (defined $obstacle) {
		warning "[NewAStarAvoid] [$hook] $drop_string target ".$args->{target}." because there is an Obstacle nearby.\n" if (!$is_dropped);;
		if ($hook eq 'AI::Attack::process') {
			AI::dequeue while (AI::inQueue("attack"))
		}
		$target->{attackFailedObstacle} = 1;
		$args->{return} = 1;
		return;
	}
	
	if ($is_dropped) {
		# Release mobs that are no longer near obstacles, we can do this to any mobs because we keep a list of distant obstacles saved
		warning "[NewAStarAvoid] [$hook] Releasing target $target from block, it no longer meets blocking criteria.\n";
		$target->{attackFailedObstacle} = 0;
	}
}

sub isTargetDroppedObstacle {
	my ($target) = @_;
	return 1 if (exists $target->{attackFailedObstacle} && $target->{attackFailedObstacle} == 1);
	return 0;
}

# 1 => target
# 2 => dest
sub is_there_an_obstacle_near_pos {
	#warning "[".PLUGIN_NAME."] [is_there_an_obstacle_near_pos]\n";
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

sub on_AI_pre_manual_adjust_route_step_near_obstacle {
	return unless (scalar keys(%obstaclesList));

	my $pos = calcPosFromPathfinding($field, $char);

	my $min_found;

	foreach my $obstacle_ID (keys %obstaclesList) {
		my $obstacle = $obstaclesList{$obstacle_ID};
		#next unless ($obstacle->{type} eq 'portal');

		my $dist = blockDistance($pos, $obstacle->{pos_to});
		if (!defined $min_found || $min_found > $dist) {
			$min_found = $dist;
		}
	}

	if ($min_found > 10) {
		check_and_change_config_if_necessary('route_step', 13);

	} elsif ($min_found <= 3) {
		check_and_change_config_if_necessary('route_step', 5);

	} else {
		check_and_change_config_if_necessary('route_step', $min_found);
	}

}

sub check_and_change_config_if_necessary {
	my ($key, $value) = @_;
	if ($config{$key} ne $value) {
		Misc::configModify($key, $value, 1);
	}
}

sub on_AI_pre_manual_drop_route_dest_near_Obstacle {
	#warning "[".PLUGIN_NAME."] [on_AI_pre_manual_drop_route_dest_near_Obstacle]\n";
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
	#warning "[".PLUGIN_NAME."] [add_obstacle]\n";
	
	if (exists $removed_obstacle_still_in_list{$actor->{ID}}) {
		debug "[".PLUGIN_NAME."] New obstacle $actor on location ".$actor->{pos_to}{x}." ".$actor->{pos_to}{y}." already exists in removed_obstacle_still_in_list, deleting from it and updating position.\n";
		delete $obstaclesList{$actor->{ID}};
		delete $removed_obstacle_still_in_list{$actor->{ID}};
	}
	
	debug "[".PLUGIN_NAME."] Adding obstacle $actor on location ".$actor->{pos_to}{x}." ".$actor->{pos_to}{y}.".\n";
	
	my $weight_changes = create_changes_array($actor->{pos_to}, $obstacle);
	
	$obstaclesList{$actor->{ID}}{pos_to} = $actor->{pos_to};
	$obstaclesList{$actor->{ID}}{weight} = $weight_changes;
	$obstaclesList{$actor->{ID}}{type} = $type;
	if ($type eq 'spell') {
		$obstaclesList{$actor->{ID}}{name} = $actor->{'type'};
	} else {
		$obstaclesList{$actor->{ID}}{name} = $actor->name;
	}
	if ($type eq 'monster') {
		$obstaclesList{$actor->{ID}}{nameID} = $actor->{nameID};
	}
	
	define_extras($actor->{ID}, $obstacle);
	
	$mustRePath = 1;
}

sub define_extras {
	#warning "[".PLUGIN_NAME."] [define_extras]\n";
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
	#warning "[".PLUGIN_NAME."] [move_obstacle]\n";
	my ($actor, $obstacle, $type) = @_;
	
	return unless (ENABLE_MOVE);
	
	debug "[".PLUGIN_NAME."] Moving obstacle $actor (from ".$actor->{pos}{x}." ".$actor->{pos}{y}." to ".$actor->{pos_to}{x}." ".$actor->{pos_to}{y}.").\n";
	
	my $weight_changes = create_changes_array($actor->{pos_to}, $obstacle);
	
	$obstaclesList{$actor->{ID}}{pos_to} = $actor->{pos_to};
	$obstaclesList{$actor->{ID}}{weight} = $weight_changes;
	
	$mustRePath = 1;
}

sub remove_obstacle {
	#warning "[".PLUGIN_NAME."] [remove_obstacle]\n";
	my ($actor, $type, $reason) = @_;
	
	return unless (ENABLE_REMOVE);
	return if ($type eq 'portal');
	
	if (($type eq 'monster' || $type eq 'player') && $reason eq 'outofsight') {
		$removed_obstacle_still_in_list{$actor->{ID}} = 1;
		debug "[".PLUGIN_NAME."] Putting obstacle $actor from ".$actor->{pos_to}{x}." ".$actor->{pos_to}{y}." in to the removed_obstacle_still_in_list.\n";
	
	} else {
		debug "[".PLUGIN_NAME."] Removing obstacle $actor from ".$actor->{pos_to}{x}." ".$actor->{pos_to}{y}.".\n"; 
		delete $obstaclesList{$actor->{ID}};
		$mustRePath = 1;
	}
}

###################################################
######## Tecnical subs
###################################################

sub on_AI_pre_manual {
	on_AI_pre_manual_adjust_route_step_near_obstacle();
	on_AI_pre_manual_drop_route_dest_near_Obstacle();
	on_AI_pre_manual_removed_obstacle_still_in_list();
	on_AI_pre_manual_repath();
}

sub on_AI_pre_manual_removed_obstacle_still_in_list {
	#warning "[".PLUGIN_NAME."] [on_AI_pre_manual_removed_obstacle_still_in_list]\n";
	my @obstacles = keys(%removed_obstacle_still_in_list);
	return unless (@obstacles > 0);

	my $sight = ($config{clientSight}-3); # 3 cell leeway?
	
	#warning "[".PLUGIN_NAME."] removed_obstacle_still_in_list: ".(scalar @obstacles)."\n";

	my $realMyPos = calcPosition($char);
	
	OBSTACLE: foreach my $obstacle_ID (@obstacles) {
		my $obstacle = $obstaclesList{$obstacle_ID};
		
		my $dist = blockDistance($realMyPos, $obstacle->{pos_to});
		
		next OBSTACLE unless ($dist < $sight);
		
		my $target = findObstacleObjectUsingID($obstacle, $obstacle_ID);
		
		# Should never happen
		if ($target) {
			warning "[REMOVING TEST] wwwwttttffffff 1.\n";
		} else {
			debug "[removed_obstacle_still_in_list] Removing obstacle ".$obstacle->{name}." (".$obstacle->{type}.") from ".$obstacle->{pos_to}{x}." ".$obstacle->{pos_to}{y}." we at ($realMyPos->{x} $realMyPos->{y}) dist:$dist, sight:$sight.\n";
			delete $obstaclesList{$obstacle_ID};
			delete $removed_obstacle_still_in_list{$obstacle_ID};
			$mustRePath = 1;
		}
	}
}

sub findObstacleObjectUsingID {
	my ($obstacle, $obstacle_ID) = @_;

	#LIST: foreach my $list ($playersList, $monstersList, $npcsList, $petsList, $portalsList, $slavesList, $elementalsList) {

	if ($obstacle->{type} eq 'monster') {
		my $actor = $monstersList->getByID($obstacle_ID);
		return $actor if ($actor);
	
	} elsif ($obstacle->{type} eq 'player') {
		my $actor = $playersList->getByID($obstacle_ID);
		return $actor if ($actor);
	}

	return undef;
}

sub on_AI_pre_manual_repath {
	#warning "[".PLUGIN_NAME."] [on_AI_pre_manual_repath]\n";
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
			Log::debug "[NewAStarAvoid] [on_AI_pre_manual_repath] Route already reseted.\n";
		} else {
			Log::debug "[NewAStarAvoid] [on_AI_pre_manual_repath] Reseting route.\n";
			$task->resetRoute;
		}
	}
	
	return unless (defined $arg_i2);
	
	my $args2 = AI::args($arg_i2);
	my $task2 = get_task($args2);
	if (defined $task2) {
		if (scalar @{$task2->{solution}} == 0) {
			Log::debug "[NewAStarAvoid] [on_AI_pre_manual_repath] [args2] Route second already reseted.\n";
		} else {
			Log::debug "[NewAStarAvoid] [on_AI_pre_manual_repath] [args2] Reseting second route.\n";
			$task2->resetRoute;
		}
	}
}

sub get_task {
	#warning "[".PLUGIN_NAME."] [get_task]\n";
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
	#warning "[".PLUGIN_NAME."] [on_PathFindingReset]\n";
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

	#warning "DUMP on_PathFindingReset - ".Dumper($args);

	#warning "[".PLUGIN_NAME."] [end on_PathFindingReset]\n";
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
	$weight = assertWeightBellowLimit($weight, $weight_limit);
	return $weight;
}

sub assertWeightBellowLimit {
	my ($weight, $weight_limit) = @_;
	if ($weight >= $weight_limit) {
		$weight = $weight_limit;
	}
	return $weight;
}

sub create_changes_array {
	#warning "[".PLUGIN_NAME."] [create_changes_array]\n";
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
	#warning "[".PLUGIN_NAME."] [sum_all_changes]\n";
	
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
			my $weight = assertWeightBellowLimit($changes_hash{$x_keys}{$y_keys}, $weight_limit);
			push(@rebuilt_array, { x => $x_keys, y => $y_keys, weight => $weight });
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
	
	debug ("[on_monster_disappeared] $actor type $args->{type} | reason $reason\n", "route");
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

###################################################
######## portals avoiding
###################################################

sub on_actor_avoid_removal {
	my (undef, $args) = @_;
	my $actor = $args->{actor};
	
	return unless (exists $obstaclesList{$actor->{ID}});
	
	my $reason = 'outofsight';
	my $type;

	if ($actor->isa('Actor::Player')) {
		$type = 'player';

	} elsif ($actor->isa('Actor::Monster')) {
		$type = 'monster';

	} elsif ($actor->isa('Actor::Portal')) {
		return;

	} else {
		return;
	}
	
	debug ("[NewAStarAvoid] [on_actor_avoid_removal] $actor type $args->{type}\n", "route");
	remove_obstacle($actor, $type, $reason);
}

return 1;