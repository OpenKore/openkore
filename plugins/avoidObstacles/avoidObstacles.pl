#########################################################################
#  avoidObstacles plugin for OpenKore
#
#  Author: Henrybk
#
#  Config-driven dynamic obstacle avoidance for routing and target
#  selection. Configure behavior in control/config.txt.
#########################################################################
=pod
######## avoidObstacles ########

avoidObstacles_enable_move 0
avoidObstacles_enable_remove 1
avoidObstacles_enable_avoid_portals 1
avoidObstacles_adjust_route_step 1
avoidObstacles_weight_limit 65000

avoidObstaclesMonster 1368 {
	enabled 1
	weight 2000
	penalty_dist 12
	danger_dist 1
	drop_destination_when_near_dist 13
}

avoidObstaclesMonster 1780 {
	enabled 1
	weight 2000
	penalty_dist 12
	danger_dist 1
	drop_destination_when_near_dist 13
}

avoidObstaclesMonster 1781 {
	enabled 1
	weight 2000
	penalty_dist 12
	danger_dist 1
	drop_destination_when_near_dist 13
}

avoidObstaclesSpell 135 {
	enabled 1
	weight 2000
	penalty_dist 12
	danger_dist 1
	drop_destination_when_near_dist 13
}

avoidObstaclesSpell 136 {
	enabled 1
	weight 2000
	penalty_dist 12
	danger_dist 1
	drop_destination_when_near_dist 13
}

avoidObstaclesDefaultPortals {
	enabled 1
	weight 10000
	penalty_dist 12
	danger_dist 4
	prohibited_dist 2
	drop_target_when_near_dist 13
	drop_destination_when_near_dist 13
}

avoidObstaclesCellsInMap job_hunte {
	enabled 1
	cells 52 140, 53 140
	weight 500
	penalty_dist 2
	danger_dist 2
	prohibited_dist 1
	drop_target_when_near_dist 13
	drop_destination_when_near_dist 13
}
=cut

package avoidObstacles;

use strict;
use AI;
use Globals;
use Misc;
use Plugins;
use Utils;
use Log qw(message debug warning);
use Data::Dumper;

$Data::Dumper::Sortkeys = 1;

use constant {
	PLUGIN_NAME => 'avoidObstacles',
};

Plugins::register(PLUGIN_NAME, 'Enables smart pathing using config-driven dynamic obstacles', \&onUnload);

my $hooks = Plugins::addHooks(
	['pos_load_config.txt', \&on_config_file_loaded, undef],
	['post_configModify', \&on_post_config_modify, undef],
	['post_bulkConfigModify', \&on_post_bulk_config_modify, undef],
	['getRoute', \&on_getRoute, undef],
	['route_step', \&on_route_step, undef],
	['AI_pre/manual', \&on_AI_pre_manual, undef],
	['add_prohibitedCells', \&on_add_prohibited_cells, undef],
	['packet_mapChange', \&on_packet_mapChange, undef],
	['undefined_object_id', \&use_od, undef],
);

my $obstacle_hooks = Plugins::addHooks(
	['add_monster_list', \&on_add_monster_list, undef],
	['monster_disappeared', \&on_monster_disappeared, undef],
	['monster_moved', \&on_monster_moved, undef],
	['add_player_list', \&on_add_player_list, undef],
	['player_disappeared', \&on_player_disappeared, undef],
	['player_moved', \&on_player_moved, undef],
	['packet_areaSpell', \&on_add_areaSpell_list, undef],
	['packet_pre/area_spell_disappears', \&on_areaSpell_disappeared, undef],
	['add_portal_list', \&on_add_portal_list, undef],
	['portal_disappeared', \&on_portal_disappeared, undef],
	['actor_avoid_removal', \&on_actor_avoid_removal, undef],
);

my $mobhooks = Plugins::addHooks(
	['AI::Attack::process', \&on_getBestTarget, undef],
	['getBestTarget', \&on_getBestTarget, undef],
);

my $pathfinding_weight_map_override;

my $chooks = Commands::register(
	['od', 'avoidObstacles controls: od [dump|reload|status]', \&command_od],
);

my %plugin_settings;
my %mob_nameID_obstacles;
my %player_name_obstacles;
my %area_spell_type_obstacles;
my %cells_in_map_obstacles;
my %default_portal_obstacle;

my %obstaclesList;
my %removed_obstacle_still_in_list;

my $mustRePath = 0;


# Fast path-level guard: spots outside melee range are still penalized if the route cuts through threat range.
sub route_crosses_target_danger_zone_fast {
	my ($solution, $obstacle_pos, $danger_dist) = @_;

	return 0 unless $solution && @{$solution};
	return 0 unless $obstacle_pos;
	$danger_dist = 1 unless defined $danger_dist;

	my $left_initial_danger_zone = 0;
	foreach my $node (@{$solution}) {
		my $d = blockDistance($node, $obstacle_pos);
		if ($d <= $danger_dist) {
			# Allow routes that start inside threat range and immediately step out of it.
			return 1 if $left_initial_danger_zone;
		} else {
			$left_initial_danger_zone = 1;
		}
	}

	return 0;
}

# Rejects a route that enters a hard zone, re-enters after leaving,
# or moves deeper while trying to escape from inside the initial hard zone.
sub route_crosses_prohibited_cells {
	my ($solution, $prohibited_cells) = @_;

	return 0 unless $solution && @{$solution};
	return 0 unless $prohibited_cells;

	my $started_inside;
	my $left_initial_zone = 0;
	my $previous_inside_distance;
	foreach my $node (@{$solution}) {
		next unless $node;

		my $cell_distance = $prohibited_cells->{$node->{x}} && $prohibited_cells->{$node->{x}}{$node->{y}};
		my $inside = defined $cell_distance;

		if (!defined $started_inside) {
			$started_inside = $inside ? 1 : 0;
			if ($inside) {
				$previous_inside_distance = $cell_distance;
			} else {
				$left_initial_zone = 1;
			}
			next;
		}

		if ($inside) {
			return 1 if !$started_inside || $left_initial_zone;
			return 1 if defined $previous_inside_distance && $cell_distance < $previous_inside_distance;
			$previous_inside_distance = $cell_distance;
		} else {
			$left_initial_zone = 1 if $started_inside;
		}
	}

	return 0;
}

## Returns the built-in plugin settings used when the control file is absent.
sub default_settings {
	return (
		enable_move => 0,
		enable_remove => 1,
		enable_avoid_portals => 1,
		adjust_route_step => 1,
		weight_limit => 65000,
	);
}

## Restores the plugin configuration to defaults before parsing overrides.
sub reset_plugin_configuration {
	%plugin_settings = default_settings();
	%mob_nameID_obstacles = ();
	%player_name_obstacles = ();
	%area_spell_type_obstacles = ();
	%cells_in_map_obstacles = ();
	%default_portal_obstacle = default_portal_obstacle_entry();
}

## Converts a short plugin setting name into its config.txt key.
sub plugin_config_key {
	my ($key) = @_;
	return 'avoidObstacles_' . $key;
}

## Returns whether a config key belongs to this plugin's flat settings or obstacle blocks.
sub is_plugin_config_key {
	my ($key) = @_;

	return 0 unless defined $key && $key ne '';
	return 1 if $key =~ /^avoidObstacles_/;
	return 1 if $key =~ /^avoidObstacles(?:Monster|Player|Spell|CellsInMap)_/;
	return 1 if $key =~ /^avoidObstaclesDefaultPortals(?:_|$)/;

	return 0;
}

## Returns whether a bulk config change set includes any avoidObstacles key.
sub bulk_includes_plugin_config_keys {
	my ($keys) = @_;

	return 0 unless $keys;
	foreach my $key (keys %{$keys}) {
		return 1 if is_plugin_config_key($key);
	}

	return 0;
}

## Loads flat plugin settings from config.txt, falling back to built-in defaults when missing.
sub load_settings_from_config {
	foreach my $key (keys %plugin_settings) {
		my $config_key = plugin_config_key($key);
		next unless defined $config{$config_key} && $config{$config_key} ne '';

		if ($key =~ /^enable_|^adjust_route_step$/) {
			$plugin_settings{$key} = normalize_bool($config{$config_key}, 'config.txt', $config_key);
		} else {
			$plugin_settings{$key} = normalize_number($config{$config_key}, 'config.txt', $config_key);
		}
	}
}

## Loads repeated obstacle blocks from config.txt into the requested obstacle table.
sub load_obstacle_blocks_from_config {
	my ($prefix, $type, $target_hash) = @_;

	foreach my $block_key (sort keys %config) {
		next unless $block_key =~ /^\Q$prefix\E_\d+$/;

		my $identifier_raw = $config{$block_key};
		next unless defined $identifier_raw && $identifier_raw ne '';

		my $identifier = normalize_identifier($type, $identifier_raw);
		my %entry = exists $target_hash->{$identifier}
			? %{ $target_hash->{$identifier} }
			: default_obstacle_entry();

		foreach my $option (qw(enabled weight penalty_dist danger_dist prohibited_dist drop_target_when_near_dist drop_destination_when_near_dist)) {
			my $option_key = "${block_key}_${option}";
			next unless defined $config{$option_key} && $config{$option_key} ne '';

			if ($option eq 'enabled') {
				$entry{$option} = normalize_bool($config{$option_key}, 'config.txt', $option_key);
			} else {
				$entry{$option} = normalize_number($config{$option_key}, 'config.txt', $option_key);
			}
		}

		$target_hash->{$identifier} = \%entry;
	}
}

## Parses a comma-separated `x y` cell list from one avoidObstaclesCellsInMap block.
sub parse_cells_in_map_list {
	my ($cells_text, $map_name, $block_key) = @_;

	my @cells;
	my %seen_cells;
	return @cells unless defined $cells_text && $cells_text ne '';

	foreach my $cell_text (split /\s*,\s*/, $cells_text) {
		next unless defined $cell_text && $cell_text ne '';

		my ($x, $y) = $cell_text =~ /^\s*(\d+)\s+(\d+)\s*$/;
		if (!defined $x || !defined $y) {
			warning "[" . PLUGIN_NAME . "] Invalid cell '$cell_text' in block $block_key for map $map_name. Expected 'x y'.\n";
			next;
		}

		my $cell_key = "$x,$y";
		next if $seen_cells{$cell_key}++;
		push @cells, { x => 0 + $x, y => 0 + $y };
	}

	return @cells;
}

## Loads static cell obstacles keyed by map name from config.txt.
sub load_cells_in_map_obstacles_from_config {
	foreach my $block_key (sort keys %config) {
		next unless $block_key =~ /^avoidObstaclesCellsInMap_\d+$/;

		my $map_name = $config{$block_key};
		next unless defined $map_name && $map_name ne '';

		my %entry = default_obstacle_entry();

		foreach my $option (qw(enabled weight penalty_dist danger_dist prohibited_dist drop_target_when_near_dist drop_destination_when_near_dist)) {
			my $option_key = "${block_key}_${option}";
			next unless defined $config{$option_key} && $config{$option_key} ne '';

			if ($option eq 'enabled') {
				$entry{$option} = normalize_bool($config{$option_key}, 'config.txt', $option_key);
			} else {
				$entry{$option} = normalize_number($config{$option_key}, 'config.txt', $option_key);
			}
		}

		my @cells = parse_cells_in_map_list($config{"${block_key}_cells"}, $map_name, $block_key);
		next unless @cells;

		push @{ $cells_in_map_obstacles{$map_name} }, {
			config => \%entry,
			cells => \@cells,
		};
	}
}

## Loads the default portal obstacle configuration from config.txt.
sub load_default_portal_obstacle_from_config {
	my %entry = default_portal_obstacle_entry();

	foreach my $block_key (sort keys %config) {
		next unless $block_key =~ /^avoidObstaclesDefaultPortals_\d+$/;

		foreach my $option (qw(enabled weight penalty_dist danger_dist prohibited_dist drop_target_when_near_dist drop_destination_when_near_dist)) {
			my $option_key = "${block_key}_${option}";
			next unless defined $config{$option_key} && $config{$option_key} ne '';

			if ($option eq 'enabled') {
				$entry{$option} = normalize_bool($config{$option_key}, 'config.txt', $option_key);
			} else {
				$entry{$option} = normalize_number($config{$option_key}, 'config.txt', $option_key);
			}
		}
	}

	%default_portal_obstacle = %entry;
}

## Loads or reloads the plugin configuration from config.txt and rebuilds runtime obstacles from the visible world.
sub reload_plugin_configuration {
	reset_plugin_configuration();
	load_settings_from_config();
	load_obstacle_blocks_from_config('avoidObstaclesMonster', 'monster', \%mob_nameID_obstacles);
	load_obstacle_blocks_from_config('avoidObstaclesPlayer', 'player', \%player_name_obstacles);
	load_obstacle_blocks_from_config('avoidObstaclesSpell', 'spell', \%area_spell_type_obstacles);
	load_cells_in_map_obstacles_from_config();
	load_default_portal_obstacle_from_config();

	rebuild_obstacles_from_world();
}

## Rebuilds plugin settings after config.txt is reloaded.
sub on_config_file_loaded {
	reload_plugin_configuration();
}

## Rebuilds plugin settings after config keys are modified at runtime.
sub on_post_config_modify {
	my (undef, $args) = @_;

	return unless $args && is_plugin_config_key($args->{key});
	return if $args->{bulk};
	reload_plugin_configuration();
}

## Rebuilds plugin settings once after a bulk runtime config update completes.
sub on_post_bulk_config_modify {
	my (undef, $args) = @_;

	return unless $args && bulk_includes_plugin_config_keys($args->{keys});
	reload_plugin_configuration();
}

## Removes hooks and commands on unload.
sub onUnload {
	Plugins::delHooks($hooks) if $hooks;
	Plugins::delHooks($obstacle_hooks) if $obstacle_hooks;
	Plugins::delHooks($mobhooks) if $mobhooks;
	Commands::unregister($chooks) if $chooks;
}

## Normalizes config identifiers so lookups are case-safe and consistent.
sub normalize_identifier {
	my ($type, $identifier) = @_;

	if ($type eq 'player') {
		return lc $identifier;
	}

	return $identifier;
}

## Returns the default shape for one obstacle entry.
sub default_obstacle_entry {
	return (
		enabled => 1,
		weight => 2000,
		penalty_dist => 9,
		danger_dist => 3,
		prohibited_dist => -1,
		drop_target_when_near_dist => -1,
		drop_destination_when_near_dist => -1,
	);
}

## Returns the built-in portal obstacle configuration used when portal avoidance is enabled.
sub default_portal_obstacle_entry {
	return (
		enabled => 1,
		weight => 10000,
		penalty_dist => 12,
		danger_dist => 4,
		prohibited_dist => 2,
		drop_target_when_near_dist => 2,
		drop_destination_when_near_dist => 2,
	);
}

## Converts a config value to a boolean and warns when the value is invalid.
sub normalize_bool {
	my ($value, $line_no, $key) = @_;
	return 1 if defined $value && $value =~ /^(?:1|true|yes|on)$/i;
	return 0 if defined $value && $value =~ /^(?:0|false|no|off)$/i;
	warning "[" . PLUGIN_NAME . "] Invalid boolean '$value' for $key on line $line_no. Using 0.\n";
	return 0;
}

## Converts a config value to a number and warns when the value is invalid.
sub normalize_number {
	my ($value, $line_no, $key) = @_;
	if (defined $value && $value =~ /^-?(?:\d+(?:\.\d*)?|\.\d+)$/) {
		return 0 + $value;
	}
	warning "[" . PLUGIN_NAME . "] Invalid numeric value '$value' for $key on line $line_no. Using 0.\n";
	return 0;
}

## Rebuilds the active obstacle list from actors that are currently visible in the world.
sub rebuild_obstacles_from_world {
	my $had_obstacles = scalar keys %obstaclesList;

	%obstaclesList = ();
	%removed_obstacle_still_in_list = ();
	return unless $field;

	rebuild_static_cell_obstacles_for_current_map();

	foreach my $monster (@{ $monstersList ? $monstersList->getItems : [] }) {
		my $obstacle = get_monster_obstacle($monster);
		add_obstacle($monster, $obstacle, 'monster') if $obstacle;
	}

	foreach my $player (@{ $playersList ? $playersList->getItems : [] }) {
		my $obstacle = get_player_obstacle($player);
		add_obstacle($player, $obstacle, 'player') if $obstacle;
	}

	foreach my $spell_id (@spellsID) {
		next unless $spell_id && $spells{$spell_id};
		my $obstacle = get_spell_obstacle($spells{$spell_id});
		add_obstacle($spells{$spell_id}, $obstacle, 'spell') if $obstacle;
	}

	foreach my $portal_id (@portalsID) {
		next unless $portal_id && $portals{$portal_id};
		my $obstacle = get_portal_obstacle();
		add_obstacle($portals{$portal_id}, $obstacle, 'portal') if $obstacle;
	}

	$mustRePath = 1 if $had_obstacles || scalar keys %obstaclesList;
}

## Adds all configured static cell obstacles for the current map into the live obstacle cache.
sub rebuild_static_cell_obstacles_for_current_map {
	return unless $field;

	my $map_name = $field->baseName;
	return unless defined $map_name && exists $cells_in_map_obstacles{$map_name};

	my $block_index = 0;
	foreach my $block (@{ $cells_in_map_obstacles{$map_name} }) {
		next unless $block->{config} && $block->{config}{enabled};

		my $cell_index = 0;
		foreach my $pos (@{ $block->{cells} || [] }) {
			add_static_cell_obstacle($map_name, $block_index, $cell_index, $pos, $block->{config});
			$cell_index++;
		}

		$block_index++;
	}
}

## Handles the `od` console command for dumping, reloading, and summarizing plugin state.
sub command_od {
	my ($cmd, $args) = @_;
	$args ||= '';
	$args =~ s/^\s+|\s+$//g;

	if ($args eq '' || $args eq 'dump') {
		use_od();
		return;
	}

	if ($args eq 'reload') {
		Misc::parseReload('config\.txt');
		message "[" . PLUGIN_NAME . "] Reloaded settings from config.txt.\n", 'success';
		return;
	}

	if ($args eq 'status') {
		message sprintf(
			"[%s] obstacles=%d removed-cache=%d monsters=%d players=%d spells=%d portals=%d config=config.txt\n",
			PLUGIN_NAME,
			scalar keys %obstaclesList,
			scalar keys %removed_obstacle_still_in_list,
			scalar keys %mob_nameID_obstacles,
			scalar keys %player_name_obstacles,
			scalar keys %area_spell_type_obstacles,
			$plugin_settings{enable_avoid_portals} ? 1 : 0
		), 'info';
		return;
	}

	message "[" . PLUGIN_NAME . "] Usage: od [dump|reload|status]\n", 'list';
}

## Dumps the live obstacle caches for debugging.
sub use_od {
	warning "[" . PLUGIN_NAME . "] obstaclesList Dump: " . Dumper(\%obstaclesList);
	warning "[" . PLUGIN_NAME . "] removed_obstacle_still_in_list Dump: " . Dumper(\%removed_obstacle_still_in_list);
}

## Clears live obstacle state on map changes and restores any temporary route-step override.
sub on_packet_mapChange {
	%obstaclesList = ();
	%removed_obstacle_still_in_list = ();
	$mustRePath = 0;
	rebuild_static_cell_obstacles_for_current_map();
}

## Blocks targets that are too close to configured obstacles and releases them once the danger is gone.
sub on_getBestTarget {
	my ($hook, $args) = @_;
	return unless $args->{target};
	return unless $field;

	my $target = $args->{target};
	my $targetPos = calcPosFromPathfinding($field, $target);
	return unless $targetPos;

	my $is_dropped = isTargetDroppedObstacle($target);
	my $drop_string = ($hook eq 'AI::Attack::process') ? 'Dropping' : 'Not picking';
	my $obstacle = is_there_an_obstacle_near_pos($targetPos, 1);
	if ($obstacle) {
		warning "[" . PLUGIN_NAME . "] [$hook] $drop_string target $target because there is an obstacle nearby.\n" if !$is_dropped;
		if ($hook eq 'AI::Attack::process') {
			AI::dequeue() while AI::inQueue('attack');
		}
		$target->{attackFailedObstacle} = 1;
		$args->{return} = 1;
		return;
	}

	if ($is_dropped) {
		warning "[" . PLUGIN_NAME . "] [$hook] Releasing target $target from obstacle block.\n";
		$target->{attackFailedObstacle} = 0;
	}
}

## Returns whether a target was previously rejected because of nearby obstacles.
sub isTargetDroppedObstacle {
	my ($target) = @_;
	return 1 if exists $target->{attackFailedObstacle} && $target->{attackFailedObstacle} == 1;
	return 0;
}

## Returns the first obstacle that is close enough to reject a target or a destination.
sub is_there_an_obstacle_near_pos {
	my ($pos, $type) = @_;
	return unless $pos;

	foreach my $obstacle_ID (keys %obstaclesList) {
		my $obstacle = $obstaclesList{$obstacle_ID};
		next unless $obstacle->{pos_to};

		my $dist = blockDistance($pos, $obstacle->{pos_to});
		if ($type == 1) {
			next unless defined $obstacle->{drop_target_when_near_dist} && $obstacle->{drop_target_when_near_dist} >= 0;
			next unless $dist <= $obstacle->{drop_target_when_near_dist};
			return $obstacle;
		} else {
			next unless defined $obstacle->{drop_destination_when_near_dist} && $obstacle->{drop_destination_when_near_dist} >= 0;
			next unless $dist <= $obstacle->{drop_destination_when_near_dist};
			return $obstacle;
		}
	}

	return;
}

## Builds a hash of hard-zone cells keyed by their nearest obstacle distance.
sub build_prohibited_cells {
	my %prohibited;
	merge_prohibited_cells(\%prohibited, build_live_prohibited_cells());
	merge_prohibited_cells(\%prohibited, build_static_prohibited_cells_for_field($field));
	return \%prohibited;
}

## Scores one client-side move solution based on danger zones and hard prohibited cells.
sub score_client_solution {
	my ($client_solution, $prohibited_cells) = @_;
	return 999999 unless $client_solution && @{$client_solution};

	my $score = 0;

	$score += 1000 if route_crosses_prohibited_cells($client_solution, $prohibited_cells);

	foreach my $obstacle_ID (keys %obstaclesList) {
		my $obstacle = $obstaclesList{$obstacle_ID};
		next unless $obstacle->{pos_to};

		my $danger_dist = defined $obstacle->{danger_dist} ? $obstacle->{danger_dist} : 1;
		next if $danger_dist < 0;

		$score++ if route_crosses_target_danger_zone_fast($client_solution, $obstacle->{pos_to}, $danger_dist);
	}

	return $score;
}

## Chooses the safest route_step by simulating the client's local move path for each candidate.
sub choose_best_route_step {
	my ($current_pos, $solution, $max_route_step) = @_;
	return unless $current_pos && $solution && @{$solution};
	return unless defined $max_route_step && $max_route_step >= 1;

	my $prohibited_cells = build_prohibited_cells();
	my ($best_step, $best_score);

	for (my $candidate_step = $max_route_step; $candidate_step >= 1; $candidate_step--) {
		my $candidate_pos = $solution->[$candidate_step];
		next unless $candidate_pos;

		my $client_solution = get_client_solution($field, $current_pos, $candidate_pos);
		next unless $client_solution && @{$client_solution};

		my $score = score_client_solution($client_solution, $prohibited_cells);
		if (!defined $best_score || $score < $best_score) {
			$best_step = $candidate_step;
			$best_score = $score;
		}

		last if defined $best_score && $best_score == 0;
	}

	return ($best_step, $best_score);
}

## Adjusts the current route_step before Task::Route selects the next move packet target.
sub on_route_step {
	my (undef, $args) = @_;
	return unless $plugin_settings{adjust_route_step};
	return unless scalar keys %obstaclesList;
	return unless $args->{task};
	return unless $args->{solution} && @{ $args->{solution} };
	return unless $args->{current_calc_pos};
	return unless defined $args->{route_step};

	my $max_route_step = $args->{route_step};
	my $max_index = @{ $args->{solution} } - 1;
	$max_route_step = $max_index if $max_route_step > $max_index;
	return if $max_route_step < 1;

	my ($best_step, $best_score) = choose_best_route_step($args->{current_calc_pos}, $args->{solution}, $max_route_step);
	return unless defined $best_step;

	if ($best_step != $args->{route_step}) {
		debug "[" . PLUGIN_NAME . "] route_step adjusted from $args->{route_step} to $best_step (danger score $best_score).\n", 'route';
		$args->{route_step} = $best_step;
	}
}

## Drops random-walk or lock-map route destinations when an obstacle appears too close to them.
sub on_AI_pre_manual_drop_route_dest_near_Obstacle {
	return unless scalar keys %obstaclesList;

	my $arg_i;
	if (AI::is('route')) {
		$arg_i = 0;
		return if AI::action(1) eq 'attack';
	} elsif (AI::action() eq 'move' && AI::action(1) eq 'route') {
		$arg_i = 1;
		return if AI::action(2) eq 'attack';
	} else {
		return;
	}

	my $args = AI::args($arg_i);
	my $task = get_task($args);
	return unless $task;
	return unless $task->{isRandomWalk} || ($task->{isToLockMap} && $field->baseName eq $config{lockMap});

	my $obstacle = is_there_an_obstacle_near_pos($task->{dest}{pos}, 2);
	if ($obstacle) {
		warning "[" . PLUGIN_NAME . "] Dropping current route destination because an obstacle appeared near it.\n";
		AI::clear('move', 'route');
	}
}

## Adds or refreshes an obstacle entry in the live obstacle cache.
sub add_obstacle {
	my ($actor, $obstacle, $type) = @_;
	return unless $actor && $obstacle;

	my $pos = get_actor_position($actor);
	return unless $pos;

	if (exists $removed_obstacle_still_in_list{$actor->{ID}}) {
		debug "[" . PLUGIN_NAME . "] Re-adding obstacle $actor after it returned to view.\n";
		delete $obstaclesList{$actor->{ID}};
		delete $removed_obstacle_still_in_list{$actor->{ID}};
	}

	debug "[" . PLUGIN_NAME . "] Adding obstacle $actor on location $pos->{x} $pos->{y}.\n";

	my $weight_changes = create_changes_array($pos, $obstacle);

	$obstaclesList{$actor->{ID}}{pos_to} = $pos;
	$obstaclesList{$actor->{ID}}{weight} = $weight_changes;
	$obstaclesList{$actor->{ID}}{type} = $type;
	if ($type eq 'spell') {
		$obstaclesList{$actor->{ID}}{name} = $actor->{type};
	} else {
		$obstaclesList{$actor->{ID}}{name} = $actor->name;
	}
	if ($type eq 'monster') {
		$obstaclesList{$actor->{ID}}{nameID} = $actor->{nameID};
	}

	define_extras($actor->{ID}, $obstacle);
	$mustRePath = 1;
}

## Adds one static cell obstacle to the live obstacle cache.
sub add_static_cell_obstacle {
	my ($map_name, $block_index, $cell_index, $pos, $obstacle) = @_;
	return unless $field && $pos && $obstacle;

	my $id = join(':', 'cell', $map_name, $block_index, $cell_index, $pos->{x}, $pos->{y});
	my $weight_changes = create_changes_array($pos, $obstacle);

	$obstaclesList{$id}{pos_to} = { x => $pos->{x}, y => $pos->{y} };
	$obstaclesList{$id}{weight} = $weight_changes;
	$obstaclesList{$id}{type} = 'cell';
	$obstaclesList{$id}{name} = "$map_name $pos->{x} $pos->{y}";
	$obstaclesList{$id}{map} = $map_name;

	define_extras($id, $obstacle);
}

## Copies obstacle metadata that later logic needs for dropping and route-step scoring.
sub define_extras {
	my ($ID, $obstacle) = @_;
	$obstaclesList{$ID}{drop_target_when_near_dist} = defined $obstacle->{drop_target_when_near_dist} ? $obstacle->{drop_target_when_near_dist} : -1;
	$obstaclesList{$ID}{drop_destination_when_near_dist} = defined $obstacle->{drop_destination_when_near_dist} ? $obstacle->{drop_destination_when_near_dist} : -1;
	$obstaclesList{$ID}{danger_dist} = defined $obstacle->{danger_dist} ? $obstacle->{danger_dist} : 1;
	$obstaclesList{$ID}{prohibited_dist} = defined $obstacle->{prohibited_dist} ? $obstacle->{prohibited_dist} : -1;
	$obstaclesList{$ID}{penalty_dist} = defined $obstacle->{penalty_dist} ? $obstacle->{penalty_dist} : -1;
}

## Updates the position and weight grid of a moving obstacle when that mode is enabled.
sub move_obstacle {
	my ($actor, $obstacle, $type) = @_;
	return unless $plugin_settings{enable_move};
	return unless $actor && $obstacle && exists $obstaclesList{$actor->{ID}};

	my $pos = get_actor_position($actor);
	return unless $pos;

	debug "[" . PLUGIN_NAME . "] Moving obstacle $actor to $pos->{x} $pos->{y}.\n";

	my $weight_changes = create_changes_array($pos, $obstacle);
	$obstaclesList{$actor->{ID}}{pos_to} = $pos;
	$obstaclesList{$actor->{ID}}{weight} = $weight_changes;

	$mustRePath = 1;
}

## Removes an obstacle immediately or parks it in the out-of-sight cache until the map confirms it is gone.
sub remove_obstacle {
	my ($actor, $type, $reason) = @_;
	return unless $plugin_settings{enable_remove};
	return unless $actor;
	return if $type eq 'portal';

	my $pos = get_actor_position($actor) || $obstaclesList{$actor->{ID}}{pos_to};

	if (($type eq 'monster' || $type eq 'player') && defined $reason && $reason eq 'disappeared') {
		$removed_obstacle_still_in_list{$actor->{ID}} = 1;
		debug "[" . PLUGIN_NAME . "] Keeping obstacle $actor cached after it moved out of sight.\n";
	} else {
		debug "[" . PLUGIN_NAME . "] Removing obstacle $actor from " . ($pos ? "$pos->{x} $pos->{y}" : 'unknown position') . ".\n";
		delete $obstaclesList{$actor->{ID}};
		delete $removed_obstacle_still_in_list{$actor->{ID}};
		$mustRePath = 1;
	}
}

## Returns the best-known position for an actor or spell-like obstacle object.
sub get_actor_position {
	my ($actor) = @_;
	return unless $actor;
	return $actor->{pos_to} if $actor->{pos_to};
	return $actor->{pos} if $actor->{pos};
	return;
}

## Runs the plugin's AI maintenance steps once per manual AI tick.
sub on_AI_pre_manual {
	on_AI_pre_manual_drop_route_dest_near_Obstacle();
	on_AI_pre_manual_removed_obstacle_still_in_list();
	on_AI_pre_manual_repath();
}

## Purges cached out-of-sight obstacles once they should be visible again but are no longer present.
sub on_AI_pre_manual_removed_obstacle_still_in_list {
	my @obstacles = keys %removed_obstacle_still_in_list;
	return unless @obstacles;

	my $sight = ($config{clientSight} || 17) - 3;
	my $realMyPos = calcPosition($char);
	return unless $realMyPos;

	OBSTACLE: foreach my $obstacle_ID (@obstacles) {
		my $obstacle = $obstaclesList{$obstacle_ID};
		next OBSTACLE unless $obstacle && $obstacle->{pos_to};

		my $dist = blockDistance($realMyPos, $obstacle->{pos_to});
		next OBSTACLE unless $dist < $sight;

		my $target = findObstacleObjectUsingID($obstacle, $obstacle_ID);
		next OBSTACLE if $target;

		debug "[" . PLUGIN_NAME . "] Removing cached obstacle $obstacle->{name} ($obstacle->{type}) from $obstacle->{pos_to}{x} $obstacle->{pos_to}{y}.\n";
		delete $obstaclesList{$obstacle_ID};
		delete $removed_obstacle_still_in_list{$obstacle_ID};
		$mustRePath = 1;
	}
}

## Looks up a live actor for an obstacle that is still cached after leaving sight.
sub findObstacleObjectUsingID {
	my ($obstacle, $obstacle_ID) = @_;
	return unless $obstacle;

	if ($obstacle->{type} eq 'monster') {
		return $monstersList->getByID($obstacle_ID);
	} elsif ($obstacle->{type} eq 'player') {
		return $playersList->getByID($obstacle_ID);
	}

	return;
}

## Infers why an actor left view based on the flags populated by Network::Receive.
sub get_actor_disappearance_reason {
	my ($actor) = @_;
	return 'gone' unless $actor;
	return 'dead' if $actor->{dead};
	return 'teleported' if $actor->{teleported};
	return 'disconnected' if $actor->{disconnected};
	return 'disappeared' if $actor->{disappeared};
	return 'gone';
}

## Resets active route tasks whenever obstacle changes require a fresh path calculation.
sub on_AI_pre_manual_repath {
	return unless $mustRePath;
	debug "[" . PLUGIN_NAME . "] Requesting route repath if routing.\n";
	Plugins::callHook('routeRepath', { source => PLUGIN_NAME });
	$mustRePath = 0;
}

## Extracts the concrete Task::Route object from different AI task containers.
sub get_task {
	my ($args) = @_;
	if (UNIVERSAL::isa($args, 'Task::Route')) {
		return $args;
	} elsif (UNIVERSAL::isa($args, 'Task::MapRoute') && $args->getSubtask && UNIVERSAL::isa($args->getSubtask, 'Task::Route')) {
		return $args->getSubtask;
	}
	return;
}

## Injects the obstacle weight grid into getRoute pathfinding calls for the current map.
sub on_getRoute {
	my (undef, $args) = @_;
	return unless scalar keys %obstaclesList;
	return if !$field || $args->{field}->name ne $field->name;

	my $prohibited_cells = build_prohibited_cells();
	my $base_weight_map_ref = defined $args->{weight_map} ? $args->{weight_map} : \($args->{field}->{weightMap});
	if ($prohibited_cells && scalar keys %{$prohibited_cells} && !pos_is_prohibited($args->{start}, $prohibited_cells) && !pos_is_prohibited($args->{dest}, $prohibited_cells)) {
		$pathfinding_weight_map_override = build_weight_map_with_prohibited_cells($base_weight_map_ref, $args->{field}{width}, $prohibited_cells);
		$args->{weight_map} = \$pathfinding_weight_map_override;
	}

	$args->{customWeights} = 1;
	$args->{secondWeightMap} = get_final_grid();
}

## Converts a 2D coordinate into a linear offset for weight maps.
sub getOffset {
	my ($x, $width, $y) = @_;
	return (($y * $width) + $x);
}

## Builds the final merged obstacle grid that pathfinding will consume.
sub get_final_grid {
	return sum_all_changes();
}

## Returns whether a coordinate is inside the current prohibited-cell set.
sub pos_is_prohibited {
	my ($pos, $prohibited_cells) = @_;
	return 0 unless $pos && $prohibited_cells;
	return 0 unless exists $prohibited_cells->{$pos->{x}};
	return exists $prohibited_cells->{$pos->{x}}{$pos->{y}} ? 1 : 0;
}

## Clones a base weight map and turns prohibited cells into true unwalkable nodes for pathfinding.
sub build_weight_map_with_prohibited_cells {
	my ($base_weight_map_ref, $width, $prohibited_cells) = @_;
	return unless $base_weight_map_ref && $width && $prohibited_cells;

	my $blocked_weight_map = ${$base_weight_map_ref};

	foreach my $x (keys %{$prohibited_cells}) {
		foreach my $y (keys %{ $prohibited_cells->{$x} }) {
			my $offset = getOffset($x, $width, $y);
			substr($blocked_weight_map, $offset, 1) = pack('c', -1);
		}
	}

	return $blocked_weight_map;
}

## Adds prohibited cells for the requested field to callers that need destination/meeting-position filtering.
sub on_add_prohibited_cells {
	my (undef, $args) = @_;
	return unless $args && $args->{cells} && ref $args->{cells} eq 'HASH';

	my $target_field = $args->{field};
	$target_field = $field if !$target_field || !UNIVERSAL::isa($target_field, 'Field');
	return unless $target_field;

	merge_prohibited_cells($args->{cells}, build_prohibited_cells_for_field($target_field));
}

## Builds the prohibited-cell map for a specific field, using live obstacles on the current map and static configured cells anywhere.
sub build_prohibited_cells_for_field {
	my ($target_field) = @_;
	return {} unless $target_field;

	my %prohibited;

	if ($field && $target_field->name eq $field->name) {
		merge_prohibited_cells(\%prohibited, build_live_prohibited_cells());
	}

	merge_prohibited_cells(\%prohibited, build_static_prohibited_cells_for_field($target_field));
	return \%prohibited;
}

## Builds prohibited cells from live dynamic obstacles on the current map only.
sub build_live_prohibited_cells {
	my %prohibited;
	return \%prohibited unless $field;

	foreach my $obstacle_ID (keys %obstaclesList) {
		my $obstacle = $obstaclesList{$obstacle_ID};
		next if $obstacle->{type} && $obstacle->{type} eq 'cell';
		next unless defined $obstacle->{prohibited_dist} && $obstacle->{prohibited_dist} >= 0;
		my $obstacle_pos = get_actor_position($obstacle);
		next unless $obstacle_pos;
		my ($min_x, $min_y, $max_x, $max_y) = $field->getSquareEdgesFromCoord($obstacle_pos, $obstacle->{prohibited_dist});
		foreach my $y ($min_y .. $max_y) {
			foreach my $x ($min_x .. $max_x) {
				next unless $field->isWalkable($x, $y);
				my $distance = blockDistance({ x => $x, y => $y }, $obstacle_pos);
				next if $distance > $obstacle->{prohibited_dist};
				if (!defined $prohibited{$x}{$y} || $distance < $prohibited{$x}{$y}) {
					$prohibited{$x}{$y} = $distance;
				}
			}
		}
	}

	return \%prohibited;
}

## Builds prohibited cells from configured static cell blocks for the given field.
sub build_static_prohibited_cells_for_field {
	my ($target_field) = @_;
	return {} unless $target_field;

	my %prohibited;
	my $map_name = $target_field->baseName;
	return \%prohibited unless defined $map_name && exists $cells_in_map_obstacles{$map_name};

	foreach my $block (@{ $cells_in_map_obstacles{$map_name} }) {
		next unless $block->{config} && $block->{config}{enabled};
		next unless defined $block->{config}{prohibited_dist} && $block->{config}{prohibited_dist} >= 0;

		foreach my $pos (@{ $block->{cells} || [] }) {
			my ($min_x, $min_y, $max_x, $max_y) = $target_field->getSquareEdgesFromCoord($pos, $block->{config}{prohibited_dist});
			foreach my $y ($min_y .. $max_y) {
				foreach my $x ($min_x .. $max_x) {
					next unless $target_field->isWalkable($x, $y);
					my $distance = blockDistance({ x => $x, y => $y }, $pos);
					next if $distance > $block->{config}{prohibited_dist};
					if (!defined $prohibited{$x}{$y} || $distance < $prohibited{$x}{$y}) {
						$prohibited{$x}{$y} = $distance;
					}
				}
			}
		}
	}

	return \%prohibited;
}

## Merges one prohibited-cell hash into another, preserving the nearest obstacle distance.
sub merge_prohibited_cells {
	my ($target, $source) = @_;
	return unless $target && $source;

	foreach my $x (keys %{$source}) {
		foreach my $y (keys %{ $source->{$x} }) {
			my $distance = $source->{$x}{$y};
			if (!exists $target->{$x}{$y} || $distance < $target->{$x}{$y}) {
				$target->{$x}{$y} = $distance;
			}
		}
	}
}

## Calculates the extra weight contributed by a single obstacle cell at a given distance.
sub get_weight_for_block {
	my ($ratio, $dist) = @_;
	$dist = 1 if !$dist;
	my $weight = int($ratio / ($dist * $dist));
	$weight = assertWeightBelowLimit($weight, $plugin_settings{weight_limit});
	return $weight;
}

## Caps a computed weight so it never exceeds the configured limit.
sub assertWeightBelowLimit {
	my ($weight, $weight_limit) = @_;
	return $weight_limit if $weight >= $weight_limit;
	return $weight;
}

## Creates the weighted influence area around one obstacle position.
sub create_changes_array {
	my ($obstacle_pos, $obstacle) = @_;
	return [] unless $field && $obstacle_pos && $obstacle;

	my %local_obstacle = %{$obstacle};
	my $max_distance = $local_obstacle{penalty_dist};
	return [] unless defined $max_distance && $max_distance >= 0;
	my $ratio = $local_obstacle{weight};

	my @changes_array;
	my ($min_x, $min_y, $max_x, $max_y) = $field->getSquareEdgesFromCoord($obstacle_pos, $max_distance);

	foreach my $y ($min_y .. $max_y) {
		foreach my $x ($min_x .. $max_x) {
			next unless $field->isWalkable($x, $y);
			my $pos = { x => $x, y => $y };
			my $distance = adjustedBlockDistance($pos, $obstacle_pos);
			my $delta_weight = get_weight_for_block($ratio, $distance);
			push @changes_array, {
				x => $x,
				y => $y,
				weight => $delta_weight
			};
		}
	}

	@changes_array = sort { $b->{weight} <=> $a->{weight} } @changes_array;
	return \@changes_array;
}

## Sums the influence of all live obstacles into one consolidated weight map.
sub sum_all_changes {
	my %changes_hash;

	foreach my $key (keys %obstaclesList) {
		foreach my $change (@{ $obstaclesList{$key}{weight} || [] }) {
			$changes_hash{$change->{x}}{$change->{y}} += $change->{weight};
		}
	}

	my @rebuilt_array;
	foreach my $x_keys (keys %changes_hash) {
		foreach my $y_keys (keys %{ $changes_hash{$x_keys} }) {
			next if $changes_hash{$x_keys}{$y_keys} == 0;
			my $weight = assertWeightBelowLimit($changes_hash{$x_keys}{$y_keys}, $plugin_settings{weight_limit});
			push @rebuilt_array, {
				x => $x_keys,
				y => $y_keys,
				weight => $weight
			};
		}
	}

	return \@rebuilt_array;
}

## Returns the configured obstacle entry for a player, if that player should be avoided.
sub get_player_obstacle {
	my ($actor) = @_;
	return unless $actor && defined $actor->{name};

	my $obstacle = $player_name_obstacles{lc $actor->{name}};
	return unless $obstacle && $obstacle->{enabled};
	return $obstacle;
}

## Adds player obstacles when configured players enter view.
sub on_add_player_list {
	my (undef, $actor) = @_;
	my $obstacle = get_player_obstacle($actor);
	add_obstacle($actor, $obstacle, 'player') if $obstacle;
}

## Moves configured player obstacles when those players move.
sub on_player_moved {
	my (undef, $actor) = @_;
	return unless $actor && exists $obstaclesList{$actor->{ID}};

	my $obstacle = get_player_obstacle($actor);
	move_obstacle($actor, $obstacle, 'player') if $obstacle;
}

## Removes configured player obstacles when a player truly disappears from the map.
sub on_player_disappeared {
	my (undef, $args) = @_;
	my $actor = $args->{player};
	return unless $actor && exists $obstaclesList{$actor->{ID}};
	remove_obstacle($actor, 'player', get_actor_disappearance_reason($actor));
}

## Returns the configured obstacle entry for a monster, if that monster should be avoided.
sub get_monster_obstacle {
	my ($actor) = @_;
	return unless $actor && defined $actor->{nameID};

	my $obstacle = $mob_nameID_obstacles{$actor->{nameID}};
	return unless $obstacle && $obstacle->{enabled};
	return $obstacle;
}

## Adds monster obstacles when configured monsters enter view.
sub on_add_monster_list {
	my (undef, $actor) = @_;
	my $obstacle = get_monster_obstacle($actor);
	add_obstacle($actor, $obstacle, 'monster') if $obstacle;
}

## Moves configured monster obstacles when those monsters move.
sub on_monster_moved {
	my (undef, $actor) = @_;
	return unless $actor && exists $obstaclesList{$actor->{ID}};

	my $obstacle = get_monster_obstacle($actor);
	move_obstacle($actor, $obstacle, 'monster') if $obstacle;
}

## Removes configured monster obstacles when a monster truly disappears from the map.
sub on_monster_disappeared {
	my (undef, $args) = @_;
	my $actor = $args->{monster};
	return unless $actor && exists $obstaclesList{$actor->{ID}};
	remove_obstacle($actor, 'monster', get_actor_disappearance_reason($actor));
}

## Returns the configured obstacle entry for an area spell, if that spell type should be avoided.
sub get_spell_obstacle {
	my ($spell) = @_;
	return unless $spell && defined $spell->{type};

	my $obstacle = $area_spell_type_obstacles{$spell->{type}};
	return unless $obstacle && $obstacle->{enabled};
	return $obstacle;
}

## Adds area-spell obstacles when configured spell types appear on the map.
sub on_add_areaSpell_list {
	my (undef, $args) = @_;
	my $ID = $args->{ID};
	my $spell = $spells{$ID};
	return unless $spell;

	my $obstacle = get_spell_obstacle($spell);
	add_obstacle($spell, $obstacle, 'spell') if $obstacle;
}

## Removes area-spell obstacles safely even if the live spell object is already gone.
sub on_areaSpell_disappeared {
	my (undef, $args) = @_;
	my $ID = $args->{ID};
	return unless $ID && exists $obstaclesList{$ID};

	my $spell = $spells{$ID} || { ID => $ID };
	remove_obstacle($spell, 'spell', 'gone');
}

## Returns the configured obstacle entry for portals when portal avoidance is enabled.
sub get_portal_obstacle {
	return unless $plugin_settings{enable_avoid_portals};
	my %obstacle = %default_portal_obstacle;
	return \%obstacle if $obstacle{enabled};
	return;
}

## Adds portal obstacles when portals enter view.
sub on_add_portal_list {
	my (undef, $actor) = @_;
	my $obstacle = get_portal_obstacle();
	add_obstacle($actor, $obstacle, 'portal') if $obstacle;
}

## Ignores portal disappearance because portals are fully reset on map change.
sub on_portal_disappeared {
	return;
}

## Marks player or monster obstacles as out-of-sight so they can be purged safely later.
sub on_actor_avoid_removal {
	my (undef, $args) = @_;
	my $actor = $args->{actor};
	return unless $actor && exists $obstaclesList{$actor->{ID}};

	my $type;
	if ($actor->isa('Actor::Player')) {
		$type = 'player';
	} elsif ($actor->isa('Actor::Monster')) {
		$type = 'monster';
	} else {
		return;
	}

	debug "[" . PLUGIN_NAME . "] [on_actor_avoid_removal] $actor\n", 'route';
	remove_obstacle($actor, $type, 'disappeared');
}

1;
