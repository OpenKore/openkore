#########################################################################
#  avoidObstacles plugin for OpenKore
#
#  Author: Henrybk
#
#  Config-driven dynamic obstacle avoidance for routing and target
#  selection using per-distance penalty and danger profiles.
#  Configure behavior in control/config.txt.
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
	penalty_dist 2000, 2000, 500, 222, 125, 80, 55, 40, 31, 24, 20, 16, 13
	danger_dist 1, 1
	drop_destination_when_near_dist 13
}

avoidObstaclesMonster 1780 {
	enabled 1
	penalty_dist 2000, 2000, 500, 222, 125, 80, 55, 40, 31, 24, 20, 16, 13
	danger_dist 1, 1
	drop_destination_when_near_dist 13
}

avoidObstaclesMonster 1781 {
	enabled 1
	penalty_dist 2000, 2000, 500, 222, 125, 80, 55, 40, 31, 24, 20, 16, 13
	danger_dist 1, 1
	drop_destination_when_near_dist 13
}

avoidObstaclesSpell 135 {
	enabled 1
	penalty_dist 2000, 2000, 500, 222, 125, 80, 55, 40, 31, 24, 20, 16, 13
	danger_dist 1, 1
	drop_destination_when_near_dist 13
}

avoidObstaclesSpell 136 {
	enabled 1
	penalty_dist 2000, 2000, 500, 222, 125, 80, 55, 40, 31, 24, 20, 16, 13
	danger_dist 1, 1
	drop_destination_when_near_dist 13
}

avoidObstaclesDefaultPortals {
	enabled 1
	penalty_dist 10000, 10000, 2500, 1111, 625, 400, 277, 204, 156, 123, 100, 82, 69
	danger_dist 1, 1, 1, 1, 1
	prohibited_dist 2
	drop_target_when_near_dist 13
	drop_destination_when_near_dist 13
}

avoidObstaclesCellsInMap job_hunte {
	enabled 1
	cells 52 140, 53 140
	penalty_dist 500, 500, 125
	danger_dist 1, 1, 1
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
use Log qw(error message debug warning);
use Data::Dumper;
use Scalar::Util qw(refaddr);

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
	['add_dropDestinationCells', \&on_add_drop_destination_cells, undef],
	['packet_mapChange', \&on_packet_mapChange, undef],
	['undefined_object_id', \&use_dump, undef],
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
	['shouldDropTarget', \&on_shouldDropTarget, undef],
	['getBestTarget', \&on_getBestTarget, undef],
);

my $pathfinding_weight_map_override;
my $cached_weight_map_field_name;
my $cached_weight_map_with_prohibited;
my $cached_final_grid = [];
my %cached_final_grid_index;

my $chooks = Commands::register(
	['avoid', 'avoidObstacles controls: od [dump|reload|status]', \&command_avoid],
);

my %plugin_settings;
my %mob_nameID_obstacles;
my %player_name_obstacles;
my %area_spell_type_obstacles;
my %cells_in_map_obstacles;
my %default_portal_obstacle;

my %obstaclesList;
my %removed_obstacle_still_in_list;
my %cached_prohibited_distance_counts;
my %cached_prohibited_cells;
my %cached_prohibited_cell_counts;
my %cached_danger_cells;
my %cached_weight_map;

my $mustRePath = 0;

## LIMITATIONS:
# 1 - Will drop a randomwalk if there is an aobstacle near the destination, but not if the route to the destination crosses one
# TODO: This functionality can be added by defining a max danger accepted by randomwalk route and then asserting the randomwalk solution
# Eg: avoidObstacles_maxRandomWalkDanger 10 - if the summed up danger of all cells in solution is greater than 10, drop this route
# 2 - Chars with ranged attacks can have issues when you are in a valid spot, target is in a valid spot and not moving to a bad spot but between you and the target there is an obstacle
# because the target might start walking to you and cross a prohibited area, which will make Attack.pm drop the target
# Could be averted by running a get_solution or checklos between char and target and excluding prohibited spots
# 3 - Openkore has no knowlodge of the 'cost' we calculate here, it only knows route cell length, if we want to a diferent path because of the obstacles
# Eg: There is an obstacle blocking the bridge, we could route through another map or try teleporting to the other side instead of walking there
# Then we would need a way of sending this information to openkore and actually making the decision there

## Purpose: Clears derived pathfinding caches that depend on field/base-map identity.
## Args: none.
## Returns: nothing.
## Notes: The incremental cell caches stay live and current. This helper only drops
## the canonical blocked weight-map cache that depends on the current field/base map.
sub invalidate_pathfinding_caches {
	undef $cached_weight_map_field_name;
	undef $cached_weight_map_with_prohibited;
	undef $pathfinding_weight_map_override;
}

## Purpose: Resets the incremental obstacle caches kept for the current map.
## Args: none.
## Returns: nothing.
## Notes: This wipes the summed per-cell caches and their supporting indexes so the
## plugin can rebuild the current field state from scratch safely.
sub reset_live_aggregate_state {
	%cached_prohibited_distance_counts = ();
	%cached_prohibited_cells = ();
	%cached_prohibited_cell_counts = ();
	%cached_danger_cells = ();
	%cached_weight_map = ();
	$cached_final_grid = [];
	%cached_final_grid_index = ();
	invalidate_pathfinding_caches();
}

## Purpose: Checks whether a local path crosses prohibited cells in an unsafe way.
## Args: `($solution, $prohibited_cells)`.
## Returns: `1` when the path must be rejected, otherwise `0`.
## Notes: A path is rejected if it enters a prohibited zone from outside, leaves and
## re-enters one, or moves deeper into the initial prohibited zone instead of escaping.
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

## Purpose: Returns the built-in plugin settings used when config.txt has no overrides.
## Args: none.
## Returns: A flat key/value list suitable for assigning into `%plugin_settings`.
## Notes: This centralizes the default runtime policy so config reloads always start
## from a known baseline before user overrides are applied.
sub default_settings {
	return (
		enable_move => 0,
		enable_remove => 0,
		enable_avoid_portals => 0,
		adjust_route_step => 0,
		weight_limit => 65000,
	);
}

## Purpose: Restores every plugin configuration table to its built-in defaults.
## Args: none.
## Returns: nothing.
## Notes: Reload code calls this first so stale config values from a prior parse do
## not survive after options are removed or changed in `config.txt`.
sub reset_plugin_configuration {
	%plugin_settings = default_settings();
	%mob_nameID_obstacles = ();
	%player_name_obstacles = ();
	%area_spell_type_obstacles = ();
	%cells_in_map_obstacles = ();
	%default_portal_obstacle = default_portal_obstacle_entry();
}

## Purpose: Converts a short internal setting name into the corresponding config key.
## Args: `($key)` where `$key` is the short setting name such as `enable_move`.
## Returns: The full `config.txt` key string, for example `avoidObstacles_enable_move`.
## Notes: This avoids hard-coding the plugin prefix in multiple config-parsing loops.
sub plugin_config_key {
	my ($key) = @_;
	return 'avoidObstacles_' . $key;
}

## Purpose: Checks whether a config key belongs to this plugin.
## Args: `($key)` which may be a flat setting key or a block-scoped obstacle key.
## Returns: `1` when the key belongs to avoidObstacles, otherwise `0`.
## Notes: Runtime config hooks use this to avoid unnecessary full plugin reloads.
sub is_plugin_config_key {
	my ($key) = @_;

	return 0 unless defined $key && $key ne '';
	return 1 if $key =~ /^avoidObstacles_/;
	return 1 if $key =~ /^avoidObstacles(?:Monster|Player|Spell|CellsInMap)_/;
	return 1 if $key =~ /^avoidObstaclesDefaultPortals(?:_|$)/;

	return 0;
}

## Purpose: Detects whether a bulk config change touched any avoidObstacles key.
## Args: `($keys)` where `$keys` is the hashref provided by the bulk config hook.
## Returns: `1` if any key belongs to the plugin, otherwise `0`.
## Notes: This lets the plugin reload once at the end of a bulk update instead of
## reloading on every individual key change.
sub bulk_includes_plugin_config_keys {
	my ($keys) = @_;

	return 0 unless $keys;
	foreach my $key (keys %{$keys}) {
		return 1 if is_plugin_config_key($key);
	}

	return 0;
}

## Purpose: Loads the plugin's flat top-level settings from `config.txt`.
## Args: none.
## Returns: nothing.
## Notes: It only overwrites keys that are explicitly present and keeps built-in
## defaults for anything the user omitted.
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

## Purpose: Loads repeated obstacle blocks from `config.txt` into one obstacle table.
## Args: `($prefix, $type, $target_hash)` describing the block prefix, identifier
## normalization type, and destination hashref.
## Returns: nothing.
## Notes: This is shared by monster, player, and spell obstacle blocks so their
## parsing stays consistent and uses the same normalization rules.
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

		foreach my $option (qw(enabled penalty_dist danger_dist prohibited_dist drop_target_when_near_dist drop_destination_when_near_dist)) {
			my $option_key = "${block_key}_${option}";
			next unless defined $config{$option_key} && $config{$option_key} ne '';

			if ($option eq 'enabled') {
				$entry{$option} = normalize_bool($config{$option_key}, 'config.txt', $option_key);
			} else {
				$entry{$option} = normalize_obstacle_number_or_profile($option, $config{$option_key}, 'config.txt', $option_key);
			}
		}

		$target_hash->{$identifier} = \%entry;
	}
}

## Purpose: Parses one comma-separated `x y` cell list from a CellsInMap config block.
## Args: `($cells_text, $map_name, $block_key)` from the current config entry.
## Returns: A list of `{ x => ..., y => ... }` hashes.
## Notes: Invalid or duplicate cells are skipped with warnings so a bad entry does
## not abort the rest of the block.
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

## Purpose: Loads all configured static cell obstacle blocks from `config.txt`.
## Args: none.
## Returns: nothing.
## Notes: The result is grouped by map name so the plugin can rebuild only the
## current map's static cell obstacles when a field is entered or reloaded.
sub load_cells_in_map_obstacles_from_config {
	foreach my $block_key (sort keys %config) {
		next unless $block_key =~ /^avoidObstaclesCellsInMap_\d+$/;

		my $map_name = $config{$block_key};
		next unless defined $map_name && $map_name ne '';

		my %entry = default_obstacle_entry();

		foreach my $option (qw(enabled penalty_dist danger_dist prohibited_dist drop_target_when_near_dist drop_destination_when_near_dist)) {
			my $option_key = "${block_key}_${option}";
			next unless defined $config{$option_key} && $config{$option_key} ne '';

			if ($option eq 'enabled') {
				$entry{$option} = normalize_bool($config{$option_key}, 'config.txt', $option_key);
			} else {
				$entry{$option} = normalize_obstacle_number_or_profile($option, $config{$option_key}, 'config.txt', $option_key);
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

## Purpose: Loads the default portal obstacle profile from `config.txt`.
## Args: none.
## Returns: nothing.
## Notes: Portals do not have per-portal custom blocks, so this reads one shared
## profile that is later cloned for every live portal obstacle.
sub load_default_portal_obstacle_from_config {
	my %entry = default_portal_obstacle_entry();

	foreach my $block_key (sort keys %config) {
		next unless $block_key =~ /^avoidObstaclesDefaultPortals_\d+$/;

		foreach my $option (qw(enabled penalty_dist danger_dist prohibited_dist drop_target_when_near_dist drop_destination_when_near_dist)) {
			my $option_key = "${block_key}_${option}";
			next unless defined $config{$option_key} && $config{$option_key} ne '';

			if ($option eq 'enabled') {
				$entry{$option} = normalize_bool($config{$option_key}, 'config.txt', $option_key);
			} else {
				$entry{$option} = normalize_obstacle_number_or_profile($option, $config{$option_key}, 'config.txt', $option_key);
			}
		}
	}

	%default_portal_obstacle = %entry;
}

## Purpose: Reloads plugin configuration and rebuilds runtime obstacle state from it.
## Args: none.
## Returns: nothing.
## Notes: This is the main configuration entry point. It resets defaults, parses
## config tables, and then rebuilds live obstacles from the currently visible world.
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

## Purpose: Reacts to the full config load hook.
## Args: Hook arguments are ignored.
## Returns: nothing.
## Notes: It exists as a tiny hook adapter that funnels the event into the shared
## reload routine used by every config-related entry point.
sub on_config_file_loaded {
	reload_plugin_configuration();
}

## Purpose: Reacts to a single runtime config modification.
## Args: `(undef, $args)` from `post_configModify`.
## Returns: nothing.
## Notes: It ignores unrelated keys and bulk operations, and reloads the plugin only
## when an avoidObstacles key changed.
sub on_post_config_modify {
	my (undef, $args) = @_;

	return unless $args && is_plugin_config_key($args->{key});
	return if $args->{bulk};
	reload_plugin_configuration();
}

## Purpose: Reacts once after a bulk runtime config update finishes.
## Args: `(undef, $args)` from `post_bulkConfigModify`.
## Returns: nothing.
## Notes: This prevents redundant reloads during bulk edits while still rebuilding
## once if any avoidObstacles key was part of the batch.
sub on_post_bulk_config_modify {
	my (undef, $args) = @_;

	return unless $args && bulk_includes_plugin_config_keys($args->{keys});
	reload_plugin_configuration();
}

## Purpose: Unregisters plugin hooks and commands during unload.
## Args: none.
## Returns: nothing.
## Notes: This exists so disabling or reloading the plugin leaves no stale hooks
## registered in the OpenKore runtime.
sub onUnload {
	Plugins::delHooks($hooks) if $hooks;
	Plugins::delHooks($obstacle_hooks) if $obstacle_hooks;
	Plugins::delHooks($mobhooks) if $mobhooks;
	Commands::unregister($chooks) if $chooks;
}

## Purpose: Normalizes obstacle identifiers before storing or looking them up.
## Args: `($type, $identifier)` where `$type` controls the normalization strategy.
## Returns: The normalized identifier string.
## Notes: Player names are lowercased so lookups are case-insensitive, while numeric
## or spell identifiers are preserved as-is.
sub normalize_identifier {
	my ($type, $identifier) = @_;

	if ($type eq 'player') {
		return lc $identifier;
	}

	return $identifier;
}

## Purpose: Returns the default structure for one obstacle configuration entry.
## Args: none.
## Returns: A flat key/value list for one obstacle profile.
## Notes: Shared defaults keep monster, player, spell, and cell obstacles aligned on
## the same option names and sentinel values.
sub default_obstacle_entry {
	return (
		enabled => 1,
		penalty_dist => -1,
		danger_dist => -1,
		prohibited_dist => -1,
		drop_target_when_near_dist => -1,
		drop_destination_when_near_dist => -1,
	);
}

## Purpose: Returns the built-in portal obstacle configuration.
## Args: none.
## Returns: A flat key/value list describing the default portal profile.
## Notes: Portals use stronger defaults than regular obstacles because stepping onto
## them can teleport or otherwise disrupt routeing.
sub default_portal_obstacle_entry {
	return (
		enabled => 1,
		penalty_dist => build_default_penalty_profile(10000, 12),
		danger_dist => build_uniform_profile(4, 1),
		prohibited_dist => 2,
		drop_target_when_near_dist => 2,
		drop_destination_when_near_dist => 2,
	);
}

## Purpose: Normalizes a config value into a boolean.
## Args: `($value, $line_no, $key)` for diagnostics and parsing.
## Returns: `1` or `0`.
## Notes: Invalid values warn and fall back to `0` so parsing can continue safely.
sub normalize_bool {
	my ($value, $line_no, $key) = @_;
	return 1 if defined $value && $value =~ /^(?:1|true|yes|on)$/i;
	return 0 if defined $value && $value =~ /^(?:0|false|no|off)$/i;
	warning "[" . PLUGIN_NAME . "] Invalid boolean '$value' for $key on line $line_no. Using 0.\n";
	return 0;
}

## Purpose: Normalizes a config value into a numeric scalar.
## Args: `($value, $line_no, $key)` for diagnostics and parsing.
## Returns: The numeric value, or `0` when invalid.
## Notes: This helper keeps numeric validation and warning format consistent across
## all plugin config parsing paths.
sub normalize_number {
	my ($value, $line_no, $key) = @_;
	if (defined $value && $value =~ /^-?(?:\d+(?:\.\d*)?|\.\d+)$/) {
		return 0 + $value;
	}
	warning "[" . PLUGIN_NAME . "] Invalid numeric value '$value' for $key on line $line_no. Using 0.\n";
	return 0;
}

## Purpose: Parses either a scalar distance or a per-distance profile from config.
## Args: `($option, $value, $line_no, $key)` describing the option being parsed.
## Returns: A numeric scalar for single-value options, or an arrayref profile for
## `penalty_dist` and `danger_dist`.
## Notes: The plugin allows profile options to define one value per block distance,
## so this helper centralizes the split-and-validate logic.
sub normalize_obstacle_number_or_profile {
	my ($option, $value, $line_no, $key) = @_;

	if ($option eq 'penalty_dist' || $option eq 'danger_dist') {
		my @parts = split /\s*,\s*/, $value;
		my @profile;

		for (my $i = 0; $i < @parts; $i++) {
			if (!defined $parts[$i] || $parts[$i] eq '') {
				warning "[" . PLUGIN_NAME . "] Invalid empty profile value for $key\[$i\] on line $line_no. Using 0.\n";
				push @profile, 0;
				next;
			}
			push @profile, normalize_number($parts[$i], $line_no, "$key\[$i\]");
		}

		return \@profile;
	}

	return normalize_number($value, $line_no, $key);
}

## Purpose: Builds a fixed-size profile where every distance has the same value.
## Args: `($max_distance, $value)`.
## Returns: An arrayref profile indexed by block distance.
## Notes: This is mainly used for convenience defaults such as uniform danger zones.
sub build_uniform_profile {
	my ($max_distance, $value) = @_;
	my @profile = map { $value } (0 .. $max_distance);
	return \@profile;
}

## Purpose: Builds the default inverse-square-style penalty profile.
## Args: `($ratio, $max_distance)` controlling the strength and maximum radius.
## Returns: An arrayref penalty profile indexed by block distance.
## Notes: It delegates per-cell math to `get_weight_for_block` so default profiles
## use the same weight clamping logic as custom obstacle contributions.
sub build_default_penalty_profile {
	my ($ratio, $max_distance) = @_;
	my @profile = map { get_weight_for_block($ratio, $_) } (0 .. $max_distance);
	return \@profile;
}

## Purpose: Returns the farthest distance represented by a profile.
## Args: `($profile)` which should be an arrayref.
## Returns: The maximum valid distance index, or `undef` for invalid input.
## Notes: Many obstacle builders use this to derive the square bounds they must scan.
sub profile_max_distance {
	my ($profile) = @_;
	return undef unless $profile && ref($profile) eq 'ARRAY';
	return $#{$profile};
}

## Purpose: Reads the danger value for one distance from a danger profile.
## Args: `($profile, $distance)`.
## Returns: The configured value at that distance, or `0` when out of range.
## Notes: Returning zero for invalid distances makes downstream danger accumulation
## code simpler because callers can just sum the result.
sub danger_profile_value_at_distance {
	my ($profile, $distance) = @_;
	return 0 unless $profile && ref($profile) eq 'ARRAY';
	return 0 unless defined $distance && $distance >= 0;
	return 0 if $distance > $#{$profile};
	return $profile->[$distance] || 0;
}

## Purpose: Reads the penalty value for one distance from a penalty profile.
## Args: `($profile, $distance)`.
## Returns: The configured value at that distance, or `undef` when out of range.
## Notes: Unlike danger values, penalty callers need to distinguish "no configured
## value" from zero, so this helper preserves `undef`.
sub penalty_profile_value_at_distance {
	my ($profile, $distance) = @_;
	return undef unless $profile && ref($profile) eq 'ARRAY';
	return undef unless defined $distance && $distance >= 0;
	return undef if $distance > $#{$profile};
	return $profile->[$distance];
}

## Purpose: Rebuilds the full live obstacle list from the currently visible world.
## Args: none.
## Returns: nothing.
## Notes: This is used after config reloads and map resets so every visible monster,
## player, spell, portal, and configured static cell obstacle is re-applied cleanly.
sub rebuild_obstacles_from_world {
	my $had_obstacles = scalar keys %obstaclesList;

	%obstaclesList = ();
	%removed_obstacle_still_in_list = ();
	reset_live_aggregate_state();
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

## Purpose: Adds all configured static cell obstacles for the current map.
## Args: none.
## Returns: nothing.
## Notes: Static cells are stored in config rather than discovered from actors, so
## they are rebuilt separately whenever the active field changes.
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

## Purpose: Implements the `od` console command for this plugin.
## Args: `($cmd, $args)` from the command dispatcher.
## Returns: nothing.
## Notes: This command is intentionally small and operational: dump internals,
## reload config, or print a compact status summary.
sub command_avoid {
	my ($cmd, $args) = @_;
	$args ||= '';
	$args =~ s/^\s+|\s+$//g;

	if ($args eq '' || $args eq 'dump') {
		use_dump();
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

## Purpose: Dumps the main live obstacle caches for debugging.
## Args: none.
## Returns: nothing.
## Notes: This writes the raw structures to the log so debugging can inspect cached
## obstacle state without attaching a debugger.
sub use_dump {
	warning "[" . PLUGIN_NAME . "] obstaclesList Dump: " . Dumper(\%obstaclesList);
	warning "[" . PLUGIN_NAME . "] removed_obstacle_still_in_list Dump: " . Dumper(\%removed_obstacle_still_in_list);
}

## Purpose: Clears live obstacle state when the map changes.
## Args: Hook arguments are ignored.
## Returns: nothing.
## Notes: Map change invalidates every live actor-based obstacle, so this resets
## state, clears caches, and rebuilds only static cell obstacles for the new field.
sub on_packet_mapChange {
	%obstaclesList = ();
	%removed_obstacle_still_in_list = ();
	$mustRePath = 0;
	reset_live_aggregate_state();
	rebuild_static_cell_obstacles_for_current_map();
}

## Purpose: Checks whether a target should be dropped because an obstacle is nearby.
## Args: `($hook, $target, $drop_string)` for logging and target inspection.
## Returns: `1` if the target should be dropped, otherwise `0`.
## Notes: It tests both the target's current pathfinding position and destination so
## fast-moving targets cannot slip through just because one position is stale.
sub should_drop_target_from_obstacle {
	my ($hook, $target, $drop_string) = @_;
	return 0 unless $target;
	return 0 unless $field;

	my @target_positions;
	my $target_calc_pos = calcPosFromPathfinding($field, $target);
	push @target_positions, $target_calc_pos if $target_calc_pos;

	my $same_as_calc = $target_calc_pos
		&& $target_calc_pos->{x} == $target->{pos_to}{x}
		&& $target_calc_pos->{y} == $target->{pos_to}{y};
	push (@target_positions, $target->{pos_to}) unless $same_as_calc;

	my $is_dropped = isTargetDroppedObstacle($target);
	foreach my $target_pos (@target_positions) {
		my $obstacle = is_there_an_obstacle_near_pos($target_pos, 1);
		if ($obstacle) {
			warning "[" . PLUGIN_NAME . "] [$hook] $drop_string target $target because there is an obstacle nearby (" . ($obstacle->{name}) . ").\n" if !$is_dropped;
			$target->{attackFailedObstacle} = 1;
			return 1;
		}
	}

	if ($is_dropped) {
		warning "[" . PLUGIN_NAME . "] [$hook] Releasing target $target from obstacle block.\n";
		$target->{attackFailedObstacle} = 0;
	}

	return 0;
}

## Purpose: Hook callback that forces the current attack target to be dropped.
## Args: `(undef, $args)` from `shouldDropTarget`.
## Returns: nothing directly; writes to `$args->{return}` when dropping.
## Notes: This keeps the core attack AI from tunneling into a target that has moved
## into an obstacle zone.
sub on_shouldDropTarget {
	my ($hook, $args) = @_;
	return unless $args->{target};

	if (should_drop_target_from_obstacle($hook, $args->{target}, 'Dropping')) {
		$args->{return} = 1;
	}
}

## Purpose: Filters obstacle-blocked targets out of the candidate target list.
## Args: `(undef, $args)` from `getBestTarget`.
## Returns: nothing directly; mutates `$args->{possibleTargets}`.
## Notes: This is the earlier, cheaper target-selection gate that prevents bad
## targets from being scored in the first place.
sub on_getBestTarget {
	my ($hook, $args) = @_;
	return unless $args->{possibleTargets} && ref $args->{possibleTargets} eq 'ARRAY';

	my @filtered_targets;
	foreach my $target_ID (@{ $args->{possibleTargets} }) {
		my $target = $monsters{$target_ID};
		if ($target && should_drop_target_from_obstacle($hook, $target, 'Not picking')) {
			next;
		}

		push @filtered_targets, $target_ID;
	}

	@{ $args->{possibleTargets} } = @filtered_targets;
}

## Purpose: Produces a readable obstacle name for logs and debug output.
## Args: `($obstacle)` which may be an actor, spell-like object, static-cell entry,
## or plain value.
## Returns: A best-effort human-readable name string.
## Notes: Many obstacle sources look different internally, so this helper keeps log
## messages understandable without leaking raw object structure details.
sub getObstacleName {
	my ($obstacle) = @_;
	return 'Unknown obstacle' unless $obstacle;
	return $obstacle unless ref $obstacle;

	my $pos = get_actor_position($obstacle);
	my $type = $obstacle->{type};

	if (defined $type && $type eq 'cell') {
		my $map_name = $obstacle->{map} || ($field ? $field->baseName : 'unknownField');
		return "CellsInMap $map_name $pos->{x} $pos->{y}";
	}

	if (defined $type && $type eq 'portal') {
		return "Portal $pos->{x} $pos->{y}";
	}

	if (defined $obstacle->{name} && $obstacle->{name} ne '' && $obstacle->{name} !~ /^Unknown \#/) {
		return $obstacle->{name};
	}

	if (UNIVERSAL::can($obstacle, 'name')) {
		my $name = eval { $obstacle->name };
		return $name if defined $name && $name ne '' && $name !~ /^Unknown \#/;
	}

	if (defined $obstacle->{type} && !ref $obstacle->{type} && $obstacle->{type} ne '') {
		return "Spell $obstacle->{type}" if $obstacle->{type} =~ /^\d+$/;
		return $obstacle->{type};
	}

	return "Unknown at $pos->{x} $pos->{y}" if $pos;
	return $obstacle->{name} if defined $obstacle->{name} && $obstacle->{name} ne '';
	return 'Unknown obstacle';
}

## Purpose: Checks whether a target is currently flagged as obstacle-blocked.
## Args: `($target)`.
## Returns: `1` if the plugin previously marked it as blocked, otherwise `0`.
## Notes: This is used to avoid duplicate warnings and to release the flag once the
## target becomes safe again.
sub isTargetDroppedObstacle {
	my ($target) = @_;
	return 1 if exists $target->{attackFailedObstacle} && $target->{attackFailedObstacle} == 1;
	return 0;
}

## Purpose: Finds the first obstacle close enough to reject a target or destination.
## Args: `($pos, $type)` where `$type` selects target-drop or destination-drop rules.
## Returns: The matching obstacle hashref, or `undef` when none applies.
## Notes: This centralizes the distance checks used by both target filtering and
## destination/route validation logic.
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

## Purpose: Returns the current prohibited-cell map for the live field.
## Args: none.
## Returns: A hashref of prohibited cells keyed by x/y with nearest-distance values.
## Notes: The implementation currently delegates to the live aggregate table, but
## keeping this wrapper makes the calling code independent from storage details.
sub build_prohibited_cells {
	return \%cached_prohibited_cells;
}

## Purpose: Returns the cached prohibited-cell map for the current field.
## Args: none.
## Returns: A prohibited-cell hashref, or an empty hashref when no field exists.
## Notes: The plugin invalidates this cache whenever obstacle contributions change,
## so callers can safely reuse it inside one routing cycle.
sub get_cached_prohibited_cells {
	return {} unless $field;
	return build_prohibited_cells();
}

## Purpose: Returns a cached copy of the field weight map with prohibited cells blocked.
## Args: `($base_weight_map_ref, $target_field, $prohibited_cells)`.
## Returns: A modified weight-map string, or `undef` when inputs are invalid.
## Notes: The canonical cache is only used for the current full prohibited-cell set.
## Route-specific filtered prohibited sets get their own uncached temporary clone so
## task-local filtering never reuses a stale blocked-map variant.
sub get_cached_weight_map_with_prohibited_cells {
	my ($base_weight_map_ref, $target_field, $prohibited_cells) = @_;
	return unless $base_weight_map_ref && $target_field && $prohibited_cells;

	my $canonical_prohibited_refaddr = refaddr(\%cached_prohibited_cells);
	my $requested_prohibited_refaddr = refaddr($prohibited_cells);
	if (!defined $canonical_prohibited_refaddr || !defined $requested_prohibited_refaddr || $canonical_prohibited_refaddr != $requested_prohibited_refaddr) {
		return build_weight_map_with_prohibited_cells($base_weight_map_ref, $target_field->{width}, $prohibited_cells);
	}

	my $field_name = $target_field->name;
	if (
		!defined $cached_weight_map_with_prohibited
		|| !defined $cached_weight_map_field_name
		|| $cached_weight_map_field_name ne $field_name
	) {
		$cached_weight_map_with_prohibited = ${$base_weight_map_ref};
		foreach my $x (keys %cached_prohibited_cells) {
			foreach my $y (keys %{ $cached_prohibited_cells{$x} }) {
				my $offset = getOffset($x, $target_field->{width}, $y);
				substr($cached_weight_map_with_prohibited, $offset, 1) = pack('c', -1);
			}
		}
		$cached_weight_map_field_name = $field_name;
	}

	return $cached_weight_map_with_prohibited;
}

## Purpose: Returns the merged danger-cell table for the live field.
## Args: none.
## Returns: A hashref of live danger values keyed by x/y.
## Notes: Like `build_prohibited_cells`, this wrapper hides the storage detail that
## danger cells are maintained incrementally in a live aggregate hash.
sub build_danger_cells {
	return \%cached_danger_cells;
}

## Purpose: Returns the cached danger-cell map for the current field.
## Args: none.
## Returns: A danger-cell hashref, or an empty hashref when no field exists.
## Notes: The danger table is already maintained live, so this wrapper mainly gives
## call sites a symmetric API with the prohibited-cell cache helpers.
sub get_cached_danger_cells {
	return {} unless $field;
	return build_danger_cells();
}

## Purpose: Sums the danger score of every node in a path solution.
## Args: `($solution, $danger_cells)`.
## Returns: The total numeric danger score for that path.
## Notes: Danger values are additive, so this is the shared primitive used for local
## path scoring, lag compensation, and route-slice comparison.
sub route_danger_score_from_cells {
	my ($solution, $danger_cells) = @_;
	return 0 unless $solution && @{$solution};
	return 0 unless $danger_cells;

	my $score = 0;

	foreach my $node (@{$solution}) {
		next unless $node;
		$score += ($danger_cells->{$node->{x}} && $danger_cells->{$node->{x}}{$node->{y}}) || 0;
	}

	return $score;
}

## Purpose: Sums danger only for a slice of a route solution.
## Args: `($solution, $danger_cells, $from_idx, $to_idx)`.
## Returns: The numeric danger score for that inclusive slice.
## Notes: This exists so route-step scoring can compare a partial local path with the
## remaining danger still present in the original route plan.
sub route_danger_score_for_slice {
	my ($solution, $danger_cells, $from_idx, $to_idx) = @_;
	return 0 unless $solution && @{$solution};
	return 0 unless defined $from_idx && defined $to_idx;
	return 0 if $from_idx > $to_idx;

	my $slice = [ @{$solution}[$from_idx .. $to_idx] ];
	return route_danger_score_from_cells($slice, $danger_cells);
}

## Purpose: Builds the candidate route_step indices that should be evaluated.
## Args: `($solution, $max_route_step)`.
## Returns: An arrayref of candidate route-step indices.
## Notes: It prefers step boundaries where movement direction changes, plus the full
## maximum step, because those are the most meaningful places to rescore local paths.
sub build_route_step_candidates {
	my ($solution, $max_route_step) = @_;
	my @candidates;
	return \@candidates unless $solution && @{$solution};
	return \@candidates unless defined $max_route_step && $max_route_step >= 1;

	my %seen;
	my $last_index = @{$solution} - 1;
	$max_route_step = $last_index if $max_route_step > $last_index;
	return \@candidates if $max_route_step < 1;

	if ($max_route_step >= 2) {
		my $prev_dx = $solution->[1]{x} - $solution->[0]{x};
		my $prev_dy = $solution->[1]{y} - $solution->[0]{y};

		for (my $i = 2; $i <= $max_route_step; $i++) {
			my $dx = $solution->[$i]{x} - $solution->[$i - 1]{x};
			my $dy = $solution->[$i]{y} - $solution->[$i - 1]{y};
			if ($dx != $prev_dx || $dy != $prev_dy) {
				my $boundary = $i - 1;
				if ($boundary >= 1 && !$seen{$boundary}) {
					push @candidates, $boundary;
					$seen{$boundary} = 1;
				}
			}
			$prev_dx = $dx;
			$prev_dy = $dy;
		}
	}

	if (!$seen{$max_route_step}) {
		push @candidates, $max_route_step;
	}

	return \@candidates;
}

## Purpose: Chooses the safest route_step by simulating local movement to each candidate.
## Args: `($current_pos, $solution, $max_route_step, $prohibited_cells, $danger_cells)`.
## Returns: `($best_step, $best_score)` when a safe candidate exists, otherwise empty.
## Notes: This is the heart of the plugin's route-step adjustment. It compares the
## local client path against prohibited cells and danger scores, and can force a
## repath when lag makes the live local path more dangerous than the planned route.
sub choose_best_route_step {
	my ($current_pos, $solution, $max_route_step, $prohibited_cells, $danger_cells) = @_;
	return unless $current_pos && $solution && @{$solution};
	return unless defined $max_route_step && $max_route_step >= 1;

	my $last_index = @{$solution} - 1;
	$max_route_step = $last_index if $max_route_step > $last_index;
	return unless $max_route_step >= 1;
	
	my ($best_step, $best_score, $best_solution, $best_pos);
	my $route_start_lag = blockDistance($current_pos, $solution->[0]);
	my $candidate_steps = build_route_step_candidates($solution, $max_route_step);

	my $expected_route_danger = route_danger_score_for_slice($solution, $danger_cells, 0, $max_route_step);

	#message "[" . PLUGIN_NAME . "] >>>>> Before best step candidates ". (scalar @{$candidate_steps}) ."\n", 'route';
	#message "[" . PLUGIN_NAME . "] max_route_step $max_route_step | expected_route_danger $expected_route_danger\n", 'route';

	foreach my $candidate_step (reverse @{$candidate_steps}) {
		my $candidate_pos = $solution->[$candidate_step];
		next unless $candidate_pos;

		my $client_solution = get_client_solution($field, $current_pos, $candidate_pos);
		next unless $client_solution && @{$client_solution};

		if (route_crosses_prohibited_cells($client_solution, $prohibited_cells)) {
			#message "[" . PLUGIN_NAME . "] Dropped [step $candidate_step] [$candidate_pos->{x} $candidate_pos->{y}] bc prohibited_cells \n", 'route';
			next;
		}

		my $score = route_danger_score_from_cells($client_solution, $danger_cells);
		if ($candidate_step < $max_route_step) {
			$score += route_danger_score_for_slice($solution, $danger_cells, $candidate_step + 1, $max_route_step);
		}

		#message "[" . PLUGIN_NAME . "] [step $candidate_step] [$candidate_pos->{x} $candidate_pos->{y}] Danger $score\n", 'route';
		if (!defined $best_score || $score < $best_score) {
			$best_step = $candidate_step;
			$best_score = $score;
			$best_solution = $client_solution;
			$best_pos = $candidate_pos;
		}
	}

	if (defined $best_score) {
		debug "[" . PLUGIN_NAME . "] chose route_step $best_step (max $max_route_step [same? ". (($best_step == $max_route_step) ? 1 : 0) ."]) at [$best_pos->{x} $best_pos->{y}].\n", 'route', 2;
		debug "[" . PLUGIN_NAME . "] Danger score $best_score (expected route danger $expected_route_danger).\n", 'route';
		debug "[choose_best_route_step] [$current_pos->{x} $current_pos->{y}] [$best_pos->{x} $best_pos->{y}] Route Sol  == ". join(' >> ', map { "$_->{x} $_->{y}" } @{$solution}[0..$best_step]) ."\n", 'route', 3;

		if ($expected_route_danger || $route_start_lag) {
			debug "[choose_best_route_step] [$current_pos->{x} $current_pos->{y}] [$best_pos->{x} $best_pos->{y}] Best  Sol == ". join(' >> ', map { "$_->{x} $_->{y}" } @{$best_solution}) ."\n", 'route', 3;
		}

		if ($route_start_lag) {
			my $fix_lag_solution = get_client_solution($field, $current_pos, $solution->[0]);
			my $fix_lag_danger = route_danger_score_from_cells($fix_lag_solution, $danger_cells);
			$fix_lag_danger -= ($danger_cells->{$solution->[0]{x}} && $danger_cells->{$solution->[0]{x}}{$solution->[0]{y}}) || 0;
			my $ideal_danger = $expected_route_danger + $fix_lag_danger;
			debug "[choose_best_route_step] [$current_pos->{x} $current_pos->{y}] [$best_pos->{x} $best_pos->{y}] Lag   Sol == ". join(' >> ', map { "$_->{x} $_->{y}" } @{$fix_lag_solution}) ."\n", 'route', 2;
			debug "[" . PLUGIN_NAME . "] Route_start_lag [$route_start_lag] | lag_danger [$fix_lag_danger] | predicted no lag danger [$ideal_danger]\n", 'route', 3;
			

			if ($route_start_lag > 0 && $best_score > $expected_route_danger) {
				debug "[" . PLUGIN_NAME . "] route_step reset requested: current_calc_pos lags $route_start_lag cells behind planned route start and local danger $best_score exceeds expected route danger $expected_route_danger.\n", 'route', 1;
				return;
			}
		}
	}

	return ($best_step, $best_score);
}

## Purpose: Removes one obstacle's prohibited zone from a cell set.
## Args: `($filtered, $target_field, $center, $prohibited_dist)`.
## Returns: nothing; mutates `$filtered` in place.
## Notes: Route destinations sometimes intentionally land inside a portal or other
## special zone, so this helper carves out just that obstacle's hard zone.
sub remove_prohibited_zone_from_cells {
	my ($filtered, $target_field, $center, $prohibited_dist) = @_;
	return unless $filtered && $target_field && $center;
	return unless defined $prohibited_dist && $prohibited_dist >= 0;

	my ($min_x, $min_y, $max_x, $max_y) = $target_field->getSquareEdgesFromCoord($center, $prohibited_dist);
	foreach my $y ($min_y .. $max_y) {
		foreach my $x ($min_x .. $max_x) {
			next unless exists $filtered->{$x} && exists $filtered->{$x}{$y};
			my $distance = blockDistance({ x => $x, y => $y }, $center);
			next if $distance > $prohibited_dist;
			delete $filtered->{$x}{$y};
			delete $filtered->{$x} unless scalar keys %{ $filtered->{$x} };
		}
	}
}

## Purpose: Loosens prohibited cells around a route destination when needed.
## Args: `($task, $prohibited_cells, $target_field)`.
## Returns: The original or filtered prohibited-cell hashref.
## Notes: This exists so route tasks can still finish at destinations such as portals
## while keeping danger scoring and all other obstacle penalties intact.
sub filter_prohibited_cells_for_route_task {
	my ($task, $prohibited_cells, $target_field) = @_;
	return $prohibited_cells unless $task && $prohibited_cells && $target_field;
	return $prohibited_cells unless $task->{dest} && $task->{dest}{pos};

	my $dest = $task->{dest}{pos};
	my @matching_portals = grep {
		my $obstacle = $obstaclesList{$_};
		my $match_dist = 7;
		my $danger_distance = profile_max_distance($obstacle->{danger_dist});
		$match_dist = $danger_distance if defined $danger_distance && $danger_distance > $match_dist;
		$match_dist = $obstacle->{prohibited_dist} if defined $obstacle->{prohibited_dist} && $obstacle->{prohibited_dist} > $match_dist;
		$obstacle
			&& $obstacle->{type}
			&& $obstacle->{type} eq 'portal'
			&& $obstacle->{pos_to}
			&& blockDistance($obstacle->{pos_to}, $dest) <= $match_dist
	} keys %obstaclesList;

	my $destination_is_portal_route = 0;
	my $portal_lut_key = $target_field->baseName . " $dest->{x} $dest->{y}";
	$destination_is_portal_route = 1 if $portals_lut{$portal_lut_key} && $portals_lut{$portal_lut_key}{source};

	my $needs_filter = 0;

	my %filtered = map {
		my $x = $_;
		$x => { %{ $prohibited_cells->{$x} } }
	} keys %{$prohibited_cells};

	foreach my $obstacle_id (keys %obstaclesList) {
		my $obstacle = $obstaclesList{$obstacle_id};
		next unless defined $obstacle->{prohibited_dist} && $obstacle->{prohibited_dist} >= 0;
		my $obstacle_pos = get_actor_position($obstacle);
		next unless $obstacle_pos;
		next if blockDistance($obstacle_pos, $dest) > $obstacle->{prohibited_dist};

		remove_prohibited_zone_from_cells(\%filtered, $target_field, $obstacle_pos, $obstacle->{prohibited_dist});
		$needs_filter = 1;
	}

	return $prohibited_cells unless $needs_filter || ($destination_is_portal_route && @matching_portals);

	foreach my $portal_id (@matching_portals) {
		my $portal = $obstaclesList{$portal_id};
		next unless $destination_is_portal_route;
		remove_prohibited_zone_from_cells(\%filtered, $target_field, $portal->{pos_to}, $portal->{prohibited_dist});
	}

	return \%filtered;
}

## Purpose: Hook callback that adjusts `route_step` before Task::Route sends movement.
## Args: `(undef, $args)` from the `route_step` hook.
## Returns: nothing directly; mutates `$args->{route_step}` or requests repath.
## Notes: This is where the plugin injects local danger-aware route-step selection
## into the core movement loop.
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

	my $prohibited_cells = get_cached_prohibited_cells();
	$prohibited_cells = filter_prohibited_cells_for_route_task($args->{task}, $prohibited_cells, $field);
	my $danger_cells = get_cached_danger_cells();
	my ($best_step, $best_score) = choose_best_route_step($args->{current_calc_pos}, $args->{solution}, $max_route_step, $prohibited_cells, $danger_cells);
	if (!defined $best_step) {
		warning "[" . PLUGIN_NAME . "] No safe local route_step found; local client path would cross a prohibited cell. Requesting repath.\n";
		$args->{task}{resetRoute} = 1;
		return;
	}

	if ($best_step != $args->{route_step}) {
		debug "[" . PLUGIN_NAME . "] route_step adjusted from $args->{route_step} to $best_step (danger score $best_score).\n", 'route';
		$args->{route_step} = $best_step;
	}
}

## Purpose: Adds or refreshes one live obstacle entry.
## Args: `($actor, $obstacle, $type)` describing the source actor, obstacle profile,
## and logical obstacle type.
## Returns: nothing.
## Notes: This builds the obstacle's weight, danger, and prohibited contributions,
## handles cached re-adds safely, and marks routes for repath if the world changed.
sub add_obstacle {
	my ($actor, $obstacle, $type) = @_;
	return unless $actor && $obstacle;

	my $pos = get_actor_position($actor);
	return unless $pos;

	if (exists $removed_obstacle_still_in_list{$actor->{ID}}) {
		debug "[" . PLUGIN_NAME . "] Re-adding obstacle $actor after it returned to view.\n";
		remove_obstacle_contributions($actor->{ID}) if exists $obstaclesList{$actor->{ID}};
		delete $obstaclesList{$actor->{ID}};
		delete $removed_obstacle_still_in_list{$actor->{ID}};
	}

	debug "[" . PLUGIN_NAME . "] Adding obstacle $actor on location $pos->{x} $pos->{y}.\n";

	remove_obstacle_contributions($actor->{ID}) if exists $obstaclesList{$actor->{ID}};

	my $weight_changes = create_changes_array($pos, $obstacle);

	$obstaclesList{$actor->{ID}}{pos_to} = $pos;
	$obstaclesList{$actor->{ID}}{weight} = $weight_changes;
	$obstaclesList{$actor->{ID}}{prohibited_cells} = build_prohibited_cells_contribution($pos, $obstacle, $field);
	$obstaclesList{$actor->{ID}}{danger_cells} = build_danger_cells_contribution($pos, $obstacle, $field);
	$obstaclesList{$actor->{ID}}{type} = $type;
	$obstaclesList{$actor->{ID}}{name} = getObstacleName($actor);
	if ($type eq 'monster') {
		$obstaclesList{$actor->{ID}}{nameID} = $actor->{nameID};
	}

	define_extras($actor->{ID}, $obstacle);
	apply_obstacle_contributions($actor->{ID});
	$mustRePath = 1;
}

## Purpose: Adds one configured static cell obstacle to the live cache.
## Args: `($map_name, $block_index, $cell_index, $pos, $obstacle)`.
## Returns: nothing.
## Notes: Static cell obstacles do not have actor objects, so they receive a stable
## synthetic ID derived from map, block, and coordinate.
sub add_static_cell_obstacle {
	my ($map_name, $block_index, $cell_index, $pos, $obstacle) = @_;
	return unless $field && $pos && $obstacle;

	my $id = join(':', 'cell', $map_name, $block_index, $cell_index, $pos->{x}, $pos->{y});
	my $weight_changes = create_changes_array($pos, $obstacle);

	$obstaclesList{$id}{pos_to} = { x => $pos->{x}, y => $pos->{y} };
	$obstaclesList{$id}{weight} = $weight_changes;
	$obstaclesList{$id}{prohibited_cells} = build_prohibited_cells_contribution($pos, $obstacle, $field);
	$obstaclesList{$id}{danger_cells} = build_danger_cells_contribution($pos, $obstacle, $field);
	$obstaclesList{$id}{type} = 'cell';
	$obstaclesList{$id}{map} = $map_name;
	$obstaclesList{$id}{name} = getObstacleName($obstaclesList{$id});

	define_extras($id, $obstacle);
	apply_obstacle_contributions($id);
}

## Purpose: Copies frequently used obstacle metadata into the live obstacle entry.
## Args: `($ID, $obstacle)`.
## Returns: nothing.
## Notes: This keeps later lookups simple by storing the parsed drop, danger,
## prohibited, and penalty settings directly on the live entry.
sub define_extras {
	my ($ID, $obstacle) = @_;
	$obstaclesList{$ID}{drop_target_when_near_dist} = defined $obstacle->{drop_target_when_near_dist} ? $obstacle->{drop_target_when_near_dist} : -1;
	$obstaclesList{$ID}{drop_destination_when_near_dist} = defined $obstacle->{drop_destination_when_near_dist} ? $obstacle->{drop_destination_when_near_dist} : -1;
	$obstaclesList{$ID}{danger_dist} = defined $obstacle->{danger_dist} ? $obstacle->{danger_dist} : -1;
	$obstaclesList{$ID}{prohibited_dist} = defined $obstacle->{prohibited_dist} ? $obstacle->{prohibited_dist} : -1;
	$obstaclesList{$ID}{penalty_dist} = defined $obstacle->{penalty_dist} ? $obstacle->{penalty_dist} : -1;
}

## Purpose: Updates one live obstacle after its source actor moved.
## Args: `($actor, $obstacle, $type)`.
## Returns: nothing.
## Notes: Movement handling is optional by config. When enabled, this removes the old
## contributions, rebuilds them at the new position, and requests a repath.
sub move_obstacle {
	my ($actor, $obstacle, $type) = @_;
	return unless $plugin_settings{enable_move};
	return unless $actor && $obstacle && exists $obstaclesList{$actor->{ID}};

	my $pos = get_actor_position($actor);
	return unless $pos;

	debug "[" . PLUGIN_NAME . "] Moving obstacle $actor to $pos->{x} $pos->{y}.\n";

	remove_obstacle_contributions($actor->{ID});

	my $weight_changes = create_changes_array($pos, $obstacle);
	$obstaclesList{$actor->{ID}}{pos_to} = $pos;
	$obstaclesList{$actor->{ID}}{weight} = $weight_changes;
	$obstaclesList{$actor->{ID}}{prohibited_cells} = build_prohibited_cells_contribution($pos, $obstacle, $field);
	$obstaclesList{$actor->{ID}}{danger_cells} = build_danger_cells_contribution($pos, $obstacle, $field);
	apply_obstacle_contributions($actor->{ID});
	$mustRePath = 1;
}

## Purpose: Removes an obstacle immediately or parks it in the hidden-obstacle cache.
## Args: `($actor, $type, $reason)`.
## Returns: nothing.
## Notes: Monsters and players that simply leave sight are kept cached temporarily so
## the bot does not instantly assume the danger vanished just because visibility did.
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
		remove_obstacle_contributions($actor->{ID});
		delete $obstaclesList{$actor->{ID}};
		delete $removed_obstacle_still_in_list{$actor->{ID}};
		$mustRePath = 1;
	}
}

## Purpose: Returns the best-known position for an actor-like obstacle source.
## Args: `($actor)`.
## Returns: A `{ x => ..., y => ... }` hashref, or `undef`.
## Notes: Different object types expose either `pos_to` or `pos`, so this helper
## gives the rest of the plugin one consistent position accessor.
sub get_actor_position {
	my ($actor) = @_;
	return unless $actor;
	return $actor->{pos_to} if $actor->{pos_to};
	return $actor->{pos} if $actor->{pos};
	return;
}

## Purpose: Runs the plugin's periodic AI maintenance tasks.
## Args: Hook arguments are ignored.
## Returns: nothing.
## Notes: This keeps all per-tick maintenance in one place: route destination drops,
## stale hidden-obstacle cleanup, and repath dispatch.
sub on_AI_pre_manual {
	on_AI_pre_manual_drop_route_dest_near_Obstacle();
	on_AI_pre_manual_removed_obstacle_still_in_list();
	on_AI_pre_manual_repath();
}

## Purpose: Drops route destinations that became unsafe because of nearby obstacles.
## Args: none.
## Returns: nothing.
## Notes: This mainly protects random-walk and lock-map routes from continuing toward
## a destination that is now effectively guarded by an obstacle.
sub on_AI_pre_manual_drop_route_dest_near_Obstacle {
	return unless scalar keys %obstaclesList;

	my $skip = 0;
	while (1) {
		my $index = AI::findAction ('route', $skip);
		last unless (defined $index);
		my $args = AI::args($index);
		my $task = get_task($args);
		next unless $task;
		next unless $task->{isRandomWalk} || ($task->{isToLockMap} && $field->baseName eq $config{lockMap});
		my $obstacle = is_there_an_obstacle_near_pos($task->{dest}{pos}, 2);
		next unless $obstacle;
		warning "[" . PLUGIN_NAME . "] Dropping current route because an obstacle appeared near its destination ($task->{dest}{pos}{x} $task->{dest}{pos}{y}) close to (" . ($obstacle->{name}) . ").\n";
		AI::clear('move', 'route');
		last;
	} continue {
		$skip++;
	}
}

## Purpose: Purges hidden cached obstacles once they should be visible again.
## Args: none.
## Returns: nothing.
## Notes: This solves the classic "left sight but may still exist" problem by keeping
## obstacles cached until the player gets close enough that the actor should reappear.
sub on_AI_pre_manual_removed_obstacle_still_in_list {
	my @obstacles = keys %removed_obstacle_still_in_list;
	return unless @obstacles;

	my $sight = ($config{clientSight} || 17) - 2;
	my $realMyPos = calcPosFromPathfinding($field, $char);
	return unless $realMyPos;

	OBSTACLE: foreach my $obstacle_ID (@obstacles) {
		my $obstacle = $obstaclesList{$obstacle_ID};
		next OBSTACLE unless $obstacle && $obstacle->{pos_to};

		my $dist = blockDistance($realMyPos, $obstacle->{pos_to});
		next OBSTACLE unless $dist < $sight;

		my $target = Actor::get($obstacle_ID);
		next OBSTACLE if $target;

		debug "[" . PLUGIN_NAME . "] Removing cached obstacle $obstacle->{name} ($obstacle->{type}) from $obstacle->{pos_to}{x} $obstacle->{pos_to}{y}.\n";
		remove_obstacle_contributions($obstacle_ID);
		delete $obstaclesList{$obstacle_ID};
		delete $removed_obstacle_still_in_list{$obstacle_ID};
		$mustRePath = 1;
	}
}

## Purpose: Triggers a route repath when obstacle changes marked routing as dirty.
## Args: none.
## Returns: nothing.
## Notes: Obstacle add/move/remove code only sets a flag; this helper emits the hook
## once per AI tick so repaths stay centralized and cheap.
sub on_AI_pre_manual_repath {
	return unless $mustRePath;
	debug "[" . PLUGIN_NAME . "] Requesting route repath if routing.\n";
	Plugins::callHook('routeRepath', { source => PLUGIN_NAME });
	$mustRePath = 0;
}

## Purpose: Infers why an actor disappeared from view.
## Args: `($actor)`.
## Returns: One of `dead`, `teleported`, `disconnected`, `disappeared`, or `gone`.
## Notes: Removal policy depends on why the actor vanished, so this helper translates
## Network::Receive state flags into one plugin-specific reason string.
sub get_actor_disappearance_reason {
	my ($actor) = @_;
	return 'gone' unless $actor;
	return 'dead' if $actor->{dead};
	return 'teleported' if $actor->{teleported};
	return 'disconnected' if $actor->{disconnected};
	return 'disappeared' if $actor->{disappeared};
	return 'gone';
}
## Purpose: Extracts a concrete `Task::Route` from different AI containers.
## Args: `($args)` which may already be a route or a map-route wrapper.
## Returns: A `Task::Route` object, or `undef`.
## Notes: Different hooks hand route tasks to the plugin in different wrappers, so
## this helper normalizes that shape before route-specific logic runs.
sub get_task {
	my ($args) = @_;
	if (UNIVERSAL::isa($args, 'Task::Route')) {
		return $args;
	} elsif (UNIVERSAL::isa($args, 'Task::MapRoute') && $args->getSubtask && UNIVERSAL::isa($args->getSubtask, 'Task::Route')) {
		return $args->getSubtask;
	}
	return;
}

## Purpose: Injects obstacle weights and prohibited cells into live pathfinding calls.
## Args: `(undef, $args)` from `getRoute`.
## Returns: nothing directly; mutates route arguments in place.
## Notes: This is the main integration point with pathfinding. It overlays blocked
## cells and the live weight grid only for routes on the current live field.
sub on_getRoute {
	my (undef, $args) = @_;
	return unless scalar keys %obstaclesList;
	return if !$field || $args->{field}->name ne $field->name;

	return unless ($args->{liveRoute});

	my $prohibited_cells = get_cached_prohibited_cells();
	if ($args->{self} && ref $args->{self}) {
		$prohibited_cells = filter_prohibited_cells_for_route_task($args->{self}, $prohibited_cells, $args->{field});
	}
	my $base_weight_map_ref = defined $args->{weight_map} ? $args->{weight_map} : \($args->{field}->{weightMap});
	if ($prohibited_cells && scalar keys %{$prohibited_cells} && !pos_is_prohibited($args->{start}, $prohibited_cells) && !pos_is_prohibited($args->{dest}, $prohibited_cells)) {
		if (defined $args->{weight_map}) {
			$pathfinding_weight_map_override = build_weight_map_with_prohibited_cells($base_weight_map_ref, $args->{field}->{width}, $prohibited_cells);
		} else {
			$pathfinding_weight_map_override = get_cached_weight_map_with_prohibited_cells($base_weight_map_ref, $args->{field}, $prohibited_cells);
		}
		$args->{weight_map} = \$pathfinding_weight_map_override if defined $pathfinding_weight_map_override;
	}

	$args->{customWeights} = 1;
	$args->{secondWeightMap} = get_final_grid();
}

## Purpose: Converts an `(x, y)` coordinate into a linear weight-map offset.
## Args: `($x, $width, $y)`.
## Returns: The numeric byte offset into the field weight map.
## Notes: OpenKore weight maps are packed strings, so callers need this to edit a
## single cell in the cloned blocked weight map.
sub getOffset {
	my ($x, $width, $y) = @_;
	return (($y * $width) + $x);
}

## Purpose: Returns the merged live obstacle weight grid used by pathfinding.
## Args: none.
## Returns: An arrayref of `{ x, y, weight }` entries.
## Notes: The result is cached per field and rebuilt from live aggregated weight
## sums only when obstacle state changed.
sub get_final_grid {
	return [] unless $field;
	return $cached_final_grid;
}

## Purpose: Checks whether a coordinate lies inside a prohibited-cell set.
## Args: `($pos, $prohibited_cells)`.
## Returns: `1` if the coordinate is prohibited, otherwise `0`.
## Notes: This is used before overriding the route weight map so start/destination
## cells are not made impossible by mistake.
sub pos_is_prohibited {
	my ($pos, $prohibited_cells) = @_;
	return 0 unless $pos && $prohibited_cells;
	return 0 unless exists $prohibited_cells->{$pos->{x}};
	return exists $prohibited_cells->{$pos->{x}}{$pos->{y}} ? 1 : 0;
}

## Purpose: Clones a weight map and turns prohibited cells into hard blocks.
## Args: `($base_weight_map_ref, $width, $prohibited_cells)`.
## Returns: A modified packed weight-map string.
## Notes: Prohibited cells are represented by `-1` in the cloned map so core
## pathfinding treats them as unwalkable instead of merely expensive.
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

## Purpose: Hook callback that contributes prohibited cells to external callers.
## Args: `(undef, $args)` containing `cells`, optional `field`, and optional `caller`.
## Returns: nothing directly; mutates `$args->{cells}`.
## Notes: This is used by systems such as route destination filtering and
## `meetingPosition`, including the special rule that dangerous meeting cells are also banned.
sub on_add_prohibited_cells {
	my (undef, $args) = @_;
	return unless $args && $args->{cells} && ref $args->{cells} eq 'HASH';

	my $target_field = $args->{field};
	$target_field = $field if !$target_field || !UNIVERSAL::isa($target_field, 'Field');
	return unless $target_field;

	if ($field && $target_field->name eq $field->name) {
		merge_prohibited_cells($args->{cells}, get_cached_prohibited_cells());

		# Meeting-position targets must never land on a cell that is only marked as
		# dangerous, otherwise we can deliberately run into ranged obstacle threat zones.
		if (defined $args->{caller} && $args->{caller} eq 'meetingPosition') {
			merge_marked_cells($args->{cells}, get_cached_danger_cells());
		}
	} else {
		merge_prohibited_cells($args->{cells}, build_prohibited_cells_for_field($target_field));
	}
}

## Purpose: Merges one boolean cell-mark map into another.
## Args: `($target, $source)`.
## Returns: nothing; mutates `$target`.
## Notes: Unlike prohibited-cell merging, this treats presence as a simple mark and
## does not preserve any distance or weighted value metadata.
sub merge_marked_cells {
	my ($target, $source) = @_;
	return unless $target && $source;

	foreach my $x (keys %{$source}) {
		foreach my $y (keys %{ $source->{$x} }) {
			$target->{$x}{$y} = 1;
		}
	}
}

## Purpose: Builds a boolean cell set around one center for destination dropping.
## Args: `($target_field, $center, $distance)`.
## Returns: A hashref of marked cells.
## Notes: This is used for "drop destination when near" logic, so it marks every
## walkable cell inside the configured block-distance radius.
sub build_drop_destination_cells_around_pos {
	my ($target_field, $center, $distance) = @_;
	return {} unless $target_field && $center;
	return {} unless defined $distance && $distance >= 0;

	my %cells;
	my ($min_x, $min_y, $max_x, $max_y) = $target_field->getSquareEdgesFromCoord($center, $distance);
	foreach my $y ($min_y .. $max_y) {
		foreach my $x ($min_x .. $max_x) {
			next unless $target_field->isWalkable($x, $y);
			next if blockDistance({ x => $x, y => $y }, $center) > $distance;
			$cells{$x}{$y} = 1;
		}
	}

	return \%cells;
}

## Purpose: Builds the full destination-drop cell set for a field.
## Args: `($target_field)`.
## Returns: A hashref of marked cells.
## Notes: On the live field it uses live obstacles; on other fields it falls back to
## configured static cell blocks only.
sub build_drop_destination_cells_for_field {
	my ($target_field) = @_;
	return {} unless $target_field;

	my %cells;
	if ($field && $target_field->name eq $field->name) {
		foreach my $obstacle_id (keys %obstaclesList) {
			my $obstacle = $obstaclesList{$obstacle_id};
			next unless defined $obstacle->{drop_destination_when_near_dist} && $obstacle->{drop_destination_when_near_dist} >= 0;
			my $obstacle_pos = get_actor_position($obstacle);
			next unless $obstacle_pos;
			merge_marked_cells(\%cells, build_drop_destination_cells_around_pos($target_field, $obstacle_pos, $obstacle->{drop_destination_when_near_dist}));
		}
		return \%cells;
	}

	my $map_name = $target_field->baseName;
	return \%cells unless defined $map_name && exists $cells_in_map_obstacles{$map_name};
	foreach my $block (@{ $cells_in_map_obstacles{$map_name} }) {
		next unless $block->{config} && $block->{config}{enabled};
		next unless defined $block->{config}{drop_destination_when_near_dist} && $block->{config}{drop_destination_when_near_dist} >= 0;
		foreach my $pos (@{ $block->{cells} || [] }) {
			merge_marked_cells(\%cells, build_drop_destination_cells_around_pos($target_field, $pos, $block->{config}{drop_destination_when_near_dist}));
		}
	}

	return \%cells;
}

## Purpose: Hook callback that contributes destination-drop cells to callers.
## Args: `(undef, $args)` containing `cells` and optional `field`.
## Returns: nothing directly; mutates `$args->{cells}`.
## Notes: This keeps destination filtering for other systems in sync with the same
## obstacle definitions used by routing.
sub on_add_drop_destination_cells {
	my (undef, $args) = @_;
	return unless $args && $args->{cells} && ref $args->{cells} eq 'HASH';

	my $target_field = $args->{field};
	$target_field = $field if !$target_field || !UNIVERSAL::isa($target_field, 'Field');
	return unless $target_field;

	merge_marked_cells($args->{cells}, build_drop_destination_cells_for_field($target_field));
}

## Purpose: Builds the prohibited-cell map for an arbitrary field.
## Args: `($target_field)`.
## Returns: A prohibited-cell hashref for that field.
## Notes: The current live field can use live dynamic obstacles, while non-current
## fields can only rely on configured static cell obstacles.
sub build_prohibited_cells_for_field {
	my ($target_field) = @_;
	return {} unless $target_field;

	my %prohibited;

	if ($field && $target_field->name eq $field->name) {
		merge_prohibited_cells(\%prohibited, \%cached_prohibited_cells);
	} else {
		merge_prohibited_cells(\%prohibited, build_static_prohibited_cells_for_field($target_field));
	}
	return \%prohibited;
}

## Purpose: Builds prohibited cells from configured static cell blocks for a field.
## Args: `($target_field)`.
## Returns: A prohibited-cell hashref.
## Notes: This is the fallback path for non-current maps where no live actor obstacle
## state exists and only config-defined cells can be considered.
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

## Purpose: Merges one prohibited-cell map into another.
## Args: `($target, $source)`.
## Returns: nothing; mutates `$target`.
## Notes: If multiple obstacles cover the same cell, the merge keeps the nearest
## obstacle distance because that is the strongest prohibited-zone meaning.
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

## Purpose: Calculates one inverse-square-like weight value for an obstacle distance.
## Args: `($ratio, $dist)`.
## Returns: The clamped weight contribution for that distance.
## Notes: Distance zero is treated as one to avoid division by zero and to ensure the
## obstacle center receives the strongest weight.
sub get_weight_for_block {
	my ($ratio, $dist) = @_;
	$dist = 1 if !$dist;
	my $weight = int($ratio / ($dist * $dist));
	$weight = assertWeightBelowLimit($weight, $plugin_settings{weight_limit});
	return $weight;
}

## Purpose: Caps a computed weight at the configured safety limit.
## Args: `($weight, $weight_limit)`.
## Returns: The original or capped weight value.
## Notes: Pathfinding weights have practical limits, so this keeps large penalty
## profiles from exploding the final grid.
sub assertWeightBelowLimit {
	my ($weight, $weight_limit) = @_;
	return $weight_limit if $weight >= $weight_limit;
	return $weight;
}

## Purpose: Builds the weighted influence area for one obstacle position.
## Args: `($obstacle_pos, $obstacle)`.
## Returns: An arrayref of `{ x, y, weight }` contributions.
## Notes: It scans the square covering the obstacle's penalty profile radius and
## records only positive walkable-cell contributions.
sub create_changes_array {
	my ($obstacle_pos, $obstacle) = @_;
	return [] unless $field && $obstacle_pos && $obstacle;

	my %local_obstacle = %{$obstacle};
	my $penalty_profile = $local_obstacle{penalty_dist};
	my $max_distance = profile_max_distance($penalty_profile);
	return [] unless defined $max_distance && $max_distance >= 0;

	my @changes_array;
	my ($min_x, $min_y, $max_x, $max_y) = $field->getSquareEdgesFromCoord($obstacle_pos, $max_distance);

	foreach my $y ($min_y .. $max_y) {
		foreach my $x ($min_x .. $max_x) {
			next unless $field->isWalkable($x, $y);
			my $pos = { x => $x, y => $y };
			my $distance = blockDistance($pos, $obstacle_pos);
			my $delta_weight = penalty_profile_value_at_distance($penalty_profile, $distance);
			next unless defined $delta_weight && $delta_weight > 0;
			$delta_weight = assertWeightBelowLimit($delta_weight, $plugin_settings{weight_limit});
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

## Purpose: Builds the prohibited-cell contribution produced by one obstacle.
## Args: `($obstacle_pos, $obstacle, $target_field)`.
## Returns: A prohibited-cell hashref for just that obstacle.
## Notes: Distances are stored so later merges can preserve the nearest covering
## obstacle when multiple prohibited zones overlap.
sub build_prohibited_cells_contribution {
	my ($obstacle_pos, $obstacle, $target_field) = @_;
	return {} unless $obstacle_pos && $obstacle && $target_field;
	return {} unless defined $obstacle->{prohibited_dist} && $obstacle->{prohibited_dist} >= 0;

	my %prohibited;
	my ($min_x, $min_y, $max_x, $max_y) = $target_field->getSquareEdgesFromCoord($obstacle_pos, $obstacle->{prohibited_dist});
	foreach my $y ($min_y .. $max_y) {
		foreach my $x ($min_x .. $max_x) {
			next unless $target_field->isWalkable($x, $y);
			my $distance = blockDistance({ x => $x, y => $y }, $obstacle_pos);
			next if $distance > $obstacle->{prohibited_dist};
			$prohibited{$x}{$y} = $distance;
		}
	}

	return \%prohibited;
}

## Purpose: Builds the danger-cell contribution produced by one obstacle.
## Args: `($obstacle_pos, $obstacle, $target_field)`.
## Returns: A danger-cell hashref for just that obstacle.
## Notes: Danger values are additive, so overlapping obstacles can later be summed
## cell by cell in the live aggregate table.
sub build_danger_cells_contribution {
	my ($obstacle_pos, $obstacle, $target_field) = @_;
	return {} unless $obstacle_pos && $obstacle && $target_field;

	my $max_distance = profile_max_distance($obstacle->{danger_dist});
	return {} unless defined $max_distance && $max_distance >= 0;

	my %danger;
	my ($min_x, $min_y, $max_x, $max_y) = $target_field->getSquareEdgesFromCoord($obstacle_pos, $max_distance);
	foreach my $y ($min_y .. $max_y) {
		foreach my $x ($min_x .. $max_x) {
			next unless $target_field->isWalkable($x, $y);
			my $distance = blockDistance({ x => $x, y => $y }, $obstacle_pos);
			my $value = danger_profile_value_at_distance($obstacle->{danger_dist}, $distance);
			next unless $value > 0;
			$danger{$x}{$y} = $value;
		}
	}

	return \%danger;
}

## Purpose: Adds one obstacle's weight contributions into the live aggregate table.
## Args: `($changes)` as built by `create_changes_array`.
## Returns: nothing.
## Notes: The live aggregate tables let the plugin update incrementally instead of
## rebuilding every cell contribution from scratch on each change.
sub add_weight_contribution {
	my ($changes) = @_;
	return unless $changes;

	foreach my $change (@{$changes}) {
		next unless $change;
		$cached_weight_map{$change->{x}}{$change->{y}} += $change->{weight};
		my $cell_key = "$change->{x},$change->{y}";
		my $clamped_weight = assertWeightBelowLimit($cached_weight_map{$change->{x}}{$change->{y}}, $plugin_settings{weight_limit});
		if (exists $cached_final_grid_index{$cell_key}) {
			$cached_final_grid->[$cached_final_grid_index{$cell_key}]{weight} = $clamped_weight;
		} else {
			push @{$cached_final_grid}, {
				x => $change->{x},
				y => $change->{y},
				weight => $clamped_weight
			};
			$cached_final_grid_index{$cell_key} = $#{$cached_final_grid};
		}
	}
}

## Purpose: Removes one obstacle's weight contributions from the live aggregate table.
## Args: `($changes)` as previously added to the live aggregate.
## Returns: nothing.
## Notes: Empty cells are pruned as sums drop to zero so caches stay compact.
sub remove_weight_contribution {
	my ($changes) = @_;
	return unless $changes;

	foreach my $change (@{$changes}) {
		next unless $change;
		next unless exists $cached_weight_map{$change->{x}} && exists $cached_weight_map{$change->{x}}{$change->{y}};
		$cached_weight_map{$change->{x}}{$change->{y}} -= $change->{weight};

		my $cell_key = "$change->{x},$change->{y}";
		if ($cached_weight_map{$change->{x}}{$change->{y}} <= 0) {
			delete $cached_weight_map{$change->{x}}{$change->{y}};
			delete $cached_weight_map{$change->{x}} unless scalar keys %{ $cached_weight_map{$change->{x}} };

			if (exists $cached_final_grid_index{$cell_key}) {
				my $remove_index = delete $cached_final_grid_index{$cell_key};
				my $last_index = $#{$cached_final_grid};
				if ($remove_index != $last_index) {
					my $moved = $cached_final_grid->[$last_index];
					$cached_final_grid->[$remove_index] = $moved;
					$cached_final_grid_index{"$moved->{x},$moved->{y}"} = $remove_index;
				}
				pop @{$cached_final_grid};
			}
		} elsif (exists $cached_final_grid_index{$cell_key}) {
			$cached_final_grid->[$cached_final_grid_index{$cell_key}]{weight} = assertWeightBelowLimit($cached_weight_map{$change->{x}}{$change->{y}}, $plugin_settings{weight_limit});
		}
	}
}

## Purpose: Adds one numeric x/y grid into another by summing cell values.
## Args: `($target, $source)`.
## Returns: nothing; mutates `$target`.
## Notes: This generic helper is currently used for additive danger grids.
sub add_grid_sum_contribution {
	my ($target, $source) = @_;
	return unless $target && $source;

	foreach my $x (keys %{$source}) {
		foreach my $y (keys %{ $source->{$x} }) {
			$target->{$x}{$y} += $source->{$x}{$y};
		}
	}
}

## Purpose: Removes one numeric x/y grid from another.
## Args: `($target, $source)`.
## Returns: nothing; mutates `$target`.
## Notes: Cells and rows are deleted once their summed value reaches zero so the
## aggregate grid stays sparse.
sub remove_grid_sum_contribution {
	my ($target, $source) = @_;
	return unless $target && $source;

	foreach my $x (keys %{$source}) {
		next unless exists $target->{$x};
		foreach my $y (keys %{ $source->{$x} }) {
			next unless exists $target->{$x}{$y};
			$target->{$x}{$y} -= $source->{$x}{$y};
			delete $target->{$x}{$y} if $target->{$x}{$y} <= 0;
		}
		delete $target->{$x} unless scalar keys %{ $target->{$x} };
	}
}

## Purpose: Adds one obstacle's prohibited contribution into the live aggregate state.
## Args: `($source)` prohibited-cell hashref for one obstacle.
## Returns: nothing.
## Notes: This tracks counts by distance so removing one obstacle later can restore
## the next-nearest distance if multiple prohibited zones overlap.
sub add_prohibited_contribution {
	my ($source) = @_;
	return unless $source;

	my $can_update_blocked_weight_map = $field
		&& defined $cached_weight_map_with_prohibited
		&& defined $cached_weight_map_field_name
		&& $cached_weight_map_field_name eq $field->name;

	foreach my $x (keys %{$source}) {
		foreach my $y (keys %{ $source->{$x} }) {
			my $distance = $source->{$x}{$y};
			my $was_prohibited = exists $cached_prohibited_cells{$x} && exists $cached_prohibited_cells{$x}{$y};
			$cached_prohibited_distance_counts{$x}{$y}{$distance}++;
			$cached_prohibited_cell_counts{$x}{$y}++;
			if (!exists $cached_prohibited_cells{$x}{$y} || $distance < $cached_prohibited_cells{$x}{$y}) {
				$cached_prohibited_cells{$x}{$y} = $distance;
			}
			if ($can_update_blocked_weight_map && !$was_prohibited) {
				my $offset = getOffset($x, $field->{width}, $y);
				substr($cached_weight_map_with_prohibited, $offset, 1) = pack('c', -1);
			}
		}
	}
}

## Purpose: Removes one obstacle's prohibited contribution from the live aggregate state.
## Args: `($source)` prohibited-cell hashref for one obstacle.
## Returns: nothing.
## Notes: Distance counters allow the plugin to recompute the nearest remaining
## prohibited distance at each cell without rebuilding everything.
sub remove_prohibited_contribution {
	my ($source) = @_;
	return unless $source;

	my $can_update_blocked_weight_map = $field
		&& defined $cached_weight_map_with_prohibited
		&& defined $cached_weight_map_field_name
		&& $cached_weight_map_field_name eq $field->name;

	foreach my $x (keys %{$source}) {
		next unless exists $cached_prohibited_distance_counts{$x};
		foreach my $y (keys %{ $source->{$x} }) {
			next unless exists $cached_prohibited_distance_counts{$x}{$y};
			my $distance = $source->{$x}{$y};
			next unless exists $cached_prohibited_distance_counts{$x}{$y}{$distance};
			$cached_prohibited_distance_counts{$x}{$y}{$distance}--;
			delete $cached_prohibited_distance_counts{$x}{$y}{$distance} if $cached_prohibited_distance_counts{$x}{$y}{$distance} <= 0;
			$cached_prohibited_cell_counts{$x}{$y}-- if exists $cached_prohibited_cell_counts{$x} && exists $cached_prohibited_cell_counts{$x}{$y};
			delete $cached_prohibited_cell_counts{$x}{$y} if exists $cached_prohibited_cell_counts{$x} && exists $cached_prohibited_cell_counts{$x}{$y} && $cached_prohibited_cell_counts{$x}{$y} <= 0;
			delete $cached_prohibited_cell_counts{$x} if exists $cached_prohibited_cell_counts{$x} && !scalar keys %{ $cached_prohibited_cell_counts{$x} };

			if (!scalar keys %{ $cached_prohibited_distance_counts{$x}{$y} }) {
				delete $cached_prohibited_distance_counts{$x}{$y};
				delete $cached_prohibited_cells{$x}{$y} if exists $cached_prohibited_cells{$x};
				if ($can_update_blocked_weight_map) {
					my $offset = getOffset($x, $field->{width}, $y);
					substr($cached_weight_map_with_prohibited, $offset, 1) = substr($field->{weightMap}, $offset, 1);
				}
			} elsif (exists $cached_prohibited_cells{$x} && exists $cached_prohibited_cells{$x}{$y} && $cached_prohibited_cells{$x}{$y} == $distance) {
				my ($nearest) = sort { $a <=> $b } keys %{ $cached_prohibited_distance_counts{$x}{$y} };
				$cached_prohibited_cells{$x}{$y} = $nearest;
			}

			delete $cached_prohibited_distance_counts{$x} unless scalar keys %{ $cached_prohibited_distance_counts{$x} };
			delete $cached_prohibited_cells{$x} if exists $cached_prohibited_cells{$x} && !scalar keys %{ $cached_prohibited_cells{$x} };
		}
	}
}

## Purpose: Applies one live obstacle's cached contributions to every aggregate table.
## Args: `($obstacle_id)`.
## Returns: nothing.
## Notes: This is the one place where a live obstacle becomes visible to routing:
## prohibited cells, danger cells, and weights are all merged here together.
sub apply_obstacle_contributions {
	my ($obstacle_id) = @_;
	my $obstacle = $obstaclesList{$obstacle_id};
	return unless $obstacle;

	add_prohibited_contribution($obstacle->{prohibited_cells});
	add_grid_sum_contribution(\%cached_danger_cells, $obstacle->{danger_cells});
	add_weight_contribution($obstacle->{weight});
}

## Purpose: Removes one live obstacle's cached contributions from aggregate tables.
## Args: `($obstacle_id)`.
## Returns: nothing.
## Notes: This is the exact inverse of `apply_obstacle_contributions` and is called
## before moving, deleting, or rebuilding an obstacle entry.
sub remove_obstacle_contributions {
	my ($obstacle_id) = @_;
	my $obstacle = $obstaclesList{$obstacle_id};
	return unless $obstacle;

	remove_prohibited_contribution($obstacle->{prohibited_cells});
	remove_grid_sum_contribution(\%cached_danger_cells, $obstacle->{danger_cells});
	remove_weight_contribution($obstacle->{weight});
}

## Purpose: Returns the incrementally maintained final obstacle weight grid.
## Args: none.
## Returns: An arrayref of `{ x, y, weight }` entries.
## Notes: Pathfinding consumes this sparse list as the second weight map layered on
## top of the field's normal weights. The list is updated cell-by-cell as obstacles change.
sub sum_all_changes {
	return $cached_final_grid;
}

## Purpose: Returns the configured obstacle profile for a player actor.
## Args: `($actor)`.
## Returns: The player obstacle config hashref, or `undef`.
## Notes: Player lookup is name-based and case-insensitive because player IDs are not
## stable configuration identifiers.
sub get_player_obstacle {
	my ($actor) = @_;
	return unless $actor && defined $actor->{name};

	my $obstacle = $player_name_obstacles{lc $actor->{name}};
	return unless $obstacle && $obstacle->{enabled};
	return $obstacle;
}

## Purpose: Hook callback that adds configured player obstacles when players appear.
## Args: `(undef, $actor)`.
## Returns: nothing.
## Notes: This is a thin hook adapter around `get_player_obstacle` and `add_obstacle`.
sub on_add_player_list {
	my (undef, $actor) = @_;
	my $obstacle = get_player_obstacle($actor);
	add_obstacle($actor, $obstacle, 'player') if $obstacle;
}

## Purpose: Hook callback that updates configured player obstacles on movement.
## Args: `(undef, $actor)`.
## Returns: nothing.
## Notes: Only already-tracked player obstacles are updated, which avoids needless
## work for unrelated players.
sub on_player_moved {
	my (undef, $actor) = @_;
	return unless $actor && exists $obstaclesList{$actor->{ID}};

	my $obstacle = get_player_obstacle($actor);
	move_obstacle($actor, $obstacle, 'player') if $obstacle;
}

## Purpose: Hook callback that removes configured player obstacles on disappearance.
## Args: `(undef, $args)` containing the disappearing player.
## Returns: nothing.
## Notes: The actual removal policy is delegated to `remove_obstacle`, which may
## cache the obstacle instead of deleting it immediately.
sub on_player_disappeared {
	my (undef, $args) = @_;
	my $actor = $args->{player};
	return unless $actor && exists $obstaclesList{$actor->{ID}};
	remove_obstacle($actor, 'player', get_actor_disappearance_reason($actor));
}

## Purpose: Returns the configured obstacle profile for a monster actor.
## Args: `($actor)`.
## Returns: The monster obstacle config hashref, or `undef`.
## Notes: Monster lookup is keyed by `nameID`, which is stable across instances.
sub get_monster_obstacle {
	my ($actor) = @_;
	return unless $actor && defined $actor->{nameID};

	my $obstacle = $mob_nameID_obstacles{$actor->{nameID}};
	return unless $obstacle && $obstacle->{enabled};
	return $obstacle;
}

## Purpose: Hook callback that adds configured monster obstacles when monsters appear.
## Args: `(undef, $actor)`.
## Returns: nothing.
## Notes: This is a thin adapter that keeps the monster hook path parallel to player
## and spell obstacle registration.
sub on_add_monster_list {
	my (undef, $actor) = @_;
	my $obstacle = get_monster_obstacle($actor);
	add_obstacle($actor, $obstacle, 'monster') if $obstacle;
}

## Purpose: Hook callback that updates configured monster obstacles on movement.
## Args: `(undef, $actor)`.
## Returns: nothing.
## Notes: Only tracked monster obstacles are updated, and actual movement handling is
## still gated by the plugin's `enable_move` setting.
sub on_monster_moved {
	my (undef, $actor) = @_;
	return unless $actor && exists $obstaclesList{$actor->{ID}};

	my $obstacle = get_monster_obstacle($actor);
	move_obstacle($actor, $obstacle, 'monster') if $obstacle;
}

## Purpose: Hook callback that removes configured monster obstacles on disappearance.
## Args: `(undef, $args)` containing the disappearing monster.
## Returns: nothing.
## Notes: Hidden monsters may be cached briefly depending on disappearance reason and
## plugin settings.
sub on_monster_disappeared {
	my (undef, $args) = @_;
	my $actor = $args->{monster};
	return unless $actor && exists $obstaclesList{$actor->{ID}};
	remove_obstacle($actor, 'monster', get_actor_disappearance_reason($actor));
}

## Purpose: Returns the configured obstacle profile for an area spell instance.
## Args: `($spell)`.
## Returns: The spell obstacle config hashref, or `undef`.
## Notes: Spell avoidance is keyed by spell type rather than by unique spell ID.
sub get_spell_obstacle {
	my ($spell) = @_;
	return unless $spell && defined $spell->{type};

	my $obstacle = $area_spell_type_obstacles{$spell->{type}};
	return unless $obstacle && $obstacle->{enabled};
	return $obstacle;
}

## Purpose: Hook callback that adds configured spell obstacles when spells appear.
## Args: `(undef, $args)` from `packet_areaSpell`.
## Returns: nothing.
## Notes: The hook provides the spell ID, so this helper resolves the live spell
## object before attempting to add the obstacle.
sub on_add_areaSpell_list {
	my (undef, $args) = @_;
	my $ID = $args->{ID};
	my $spell = $spells{$ID};
	return unless $spell;

	my $obstacle = get_spell_obstacle($spell);
	add_obstacle($spell, $obstacle, 'spell') if $obstacle;
}

## Purpose: Hook callback that removes spell obstacles when spells disappear.
## Args: `(undef, $args)` containing the spell ID.
## Returns: nothing.
## Notes: The live spell object may already be missing, so the helper falls back to a
## minimal stub object carrying the ID.
sub on_areaSpell_disappeared {
	my (undef, $args) = @_;
	my $ID = $args->{ID};
	return unless $ID && exists $obstaclesList{$ID};

	my $spell = $spells{$ID} || { ID => $ID };
	remove_obstacle($spell, 'spell', 'gone');
}

## Purpose: Returns the active portal obstacle profile when portal avoidance is enabled.
## Args: none.
## Returns: A cloned portal obstacle config hashref, or `undef`.
## Notes: The config is cloned so per-portal live entries can be modified safely
## without mutating the shared default profile.
sub get_portal_obstacle {
	return unless $plugin_settings{enable_avoid_portals};
	my %obstacle = %default_portal_obstacle;
	return \%obstacle if $obstacle{enabled};
	return;
}

## Purpose: Hook callback that adds portal obstacles when portals appear.
## Args: `(undef, $actor)`.
## Returns: nothing.
## Notes: Portal obstacles are opt-in via config and use the shared default portal
## profile returned by `get_portal_obstacle`.
sub on_add_portal_list {
	my (undef, $actor) = @_;
	my $obstacle = get_portal_obstacle();
	add_obstacle($actor, $obstacle, 'portal') if $obstacle;
}

## Purpose: Ignores portal disappearance events.
## Args: none.
## Returns: nothing.
## Notes: Portal obstacles are fully rebuilt on map change, so individual disappear
## handling is intentionally unnecessary.
sub on_portal_disappeared {
	return;
}

## Purpose: Marks player or monster obstacles as temporarily hidden.
## Args: `(undef, $args)` containing the actor about to be avoided for removal.
## Returns: nothing.
## Notes: This hook exists so the plugin can preserve obstacle influence briefly when
## an actor leaves view, then purge it later only if it truly should have reappeared.
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
