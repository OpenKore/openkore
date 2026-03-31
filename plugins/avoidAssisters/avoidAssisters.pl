#
# avoidAssisters
# Author: Henrybk
#
# What this plugin does:
# This plugin prevents OpenKore from attacking or selecting targets that are
# likely to bring extra mobs with them. It checks the area around a candidate
# target and blocks it when there are too many nearby "assister" monsters.
#
# It supports two configuration modes:
# 1. avoidAssisters <mobID> { ... }
#    Applies the check only when the current target matches the configured mob ID.
# 2. avoidGlobalAssisters <mobID> { ... }
#    Applies the check to any target when a configured assister mob is nearby.
#
# How to configure it:
# Add blocks in config.txt using one or more
# `maxAssistersBellowDistAllowed <dist> <allowed>` lines.
#
# Per-target assister check:
# avoidAssisters 1096 {
#     maxAssistersBellowDistAllowed 9 2
# }
#
# Global assister check:
# avoidGlobalAssisters 1113 {
#     maxAssistersBellowDistAllowed 9 3
# }
#
# Meaning of each field:
# - Block value: Monster ID to watch.
# - maxAssistersBellowDistAllowed <dist> <allowed>:
#   Distance around the target to scan plus the maximum allowed assisting mobs
#   inside that distance before the target is dropped.
#
# Examples:
# 1. Avoid attacking a mob if there are more than 2 monsters of the same type
#    close enough to assist it:
#    avoidAssisters 1096 {
#        maxAssistersBellowDistAllowed 9 2
#    }
#
# 2. Avoid any target if there are more than 3 dangerous support mobs nearby:
#    avoidGlobalAssisters 1113 {
#        maxAssistersBellowDistAllowed 9 3
#    }
#
# 3. Use multiple thresholds in the same block:
#    avoidGlobalAssisters 1368 {
#        maxAssistersBellowDistAllowed 5 0
#        maxAssistersBellowDistAllowed 9 1
#    }
#
# Detailed simulation: target is NOT picked
# ----------------------------------------
# Imagine the bot is evaluating a Spore (nameID 1014, binID 2) during
# `getBestTarget`, before we have attacked it even once.
#
# Config:
# avoidGlobalAssisters 1368 {
#     maxAssistersBellowDistAllowed 5 0
#     maxAssistersBellowDistAllowed 9 1
# }
#
# Visible actors:
# - Candidate target Spore (binID 2) at pos_to (115, 113)
# - Geographer (binID 0, nameID 1368) at pos_to (112, 111)
# - Geographer (binID 5, nameID 1368) at pos_to (108, 107)
# - The Geographers are free mobs, so they count as possible assisters.
#
# Step 1:
# `getBestTarget` asks this plugin whether the candidate should be filtered out.
#
# Step 2:
# `get_target_positions()` gathers the target positions to test.
# Before engagement, we are strict and allow a single bad checked position to
# reject the target.
# Example checked positions:
# - calc_pos = (115, 113)
# - pos_to   = (115, 113)
# If both are equal, only one effective position is checked.
#
# Step 3:
# `find_assister_drop_reason_for_position()` evaluates each configured rule
# against that target position.
#
# Rule A:
# `maxAssistersBellowDistAllowed 5 0`
# - Count Geographers within 5 cells of the target.
# - Geographer at (112, 111) is within range.
# - Count = 1
# - Allowed = 0
# - Result: FAIL, because 1 > 0
#
# Rule B would not even need to run after Rule A already failed for that tested
# position, because the plugin returns the first blocking reason it finds.
#
# Step 4:
# Because this happened inside `getBestTarget`, and we have not engaged the
# target yet, the plugin immediately filters the Spore out of
# `possibleTargets`.
#
# Final decision:
# - The target is NOT picked.
# - Reason: at least one configured assister rule failed for at least one checked
#   target position before combat started.
#
# Why this is intentionally strict:
# - Before the bot commits to a target, it is cheap to discard a risky pull.
# - After the bot has already engaged the target, `shouldDropTarget` is more
#   conservative and may require both `calc_pos` and `pos_to` to fail before it
#   abandons the fight.
#
# Detailed simulation: target is DROPPED mid attack route
# -------------------------------------------------------
# Imagine the bot already picked a Spore and has started attacking it, so the
# target is now being checked by `shouldDropTarget` while we are routing or
# re-evaluating during combat.
#
# Config:
# avoidGlobalAssisters 1368 {
#     maxAssistersBellowDistAllowed 5 0
#     maxAssistersBellowDistAllowed 9 1
# }
#
# Current combat state:
# - We already committed to the Spore, so `$target->{sentAttack}` or
#   `$target->{engaged}` is set.
# - That means the target counts as "engaged by us".
#
# Visible actors:
# - Current target Spore (binID 2)
# - Geographer (binID 0, nameID 1368) at pos_to (112, 111)
# - Geographer (binID 5, nameID 1368) at pos_to (109, 108)
#
# Step 1:
# `shouldDropTarget` calls `should_drop_target_from_assisters()`.
#
# Step 2:
# `get_target_positions()` gathers both target positions because they differ:
# - calc_pos = (115, 113)
# - pos_to   = (114, 112)
#
# Step 3:
# The plugin checks whether this target has already been engaged by us.
# Because combat already started, the plugin becomes more conservative:
# it will only drop if every checked target position is bad.
#
# Step 4:
# `find_assister_drop_reason_for_position()` evaluates `calc_pos`.
# Rule A:
# `maxAssistersBellowDistAllowed 5 0`
# - Geographer at (112, 111) is within 5 cells
# - Count = 1
# - Allowed = 0
# - Result: FAIL for `calc_pos`
#
# Step 5:
# `find_assister_drop_reason_for_position()` evaluates `pos_to`.
# Rule A again:
# - Geographer at (112, 111) is also within 5 cells of (114, 112)
# - Count = 1
# - Allowed = 0
# - Result: FAIL for `pos_to`
#
# Step 6:
# Because the target was already engaged, the plugin now asks:
# "Did every checked target position fail?"
# In this example:
# - calc_pos failed
# - pos_to failed
# So the answer is YES.
#
# Step 7:
# Because the target was already engaged, the plugin starts a short
# confirmation timer instead of dropping immediately.
# - If the target stops qualifying during that grace window, the timer is reset.
# - If it is still unsafe after the configured delay, the target is dropped.
#
# Final decision:
# - The target IS dropped mid-route / mid-fight only if it remained unsafe for
#   the whole confirmation delay.
# - Reason: after engagement, both checked target positions were still inside
#   assister-danger conditions long enough that the plugin concluded the fight
#   remained unsafe.
#
# Why this is intentionally more conservative than `getBestTarget`:
# - Once combat already started, a single stale position should not be enough to
#   abandon the target.
# - Requiring both `calc_pos` and `pos_to` to fail reduces false-positive drops
#   caused by brief movement prediction mismatch.
#
# Notes:
# - The plugin ignores monsters already fighting a player.
# - If a previously blocked nearby target no longer meets the block conditions,
#   the plugin can release it and allow it to be targeted again.
#
package avoidAssisters;

use strict;
use Time::HiRes qw(time);
use Globals;
use Settings;
use Misc;
use Plugins;
use Utils;
use Log qw(message debug error warning);

use constant ENGAGED_DROP_CONFIRMATION_DELAY => 0.5;
use constant ASSISTER_DROP_RELEASE_COOLDOWN => 1.0;
use constant RELEASE_VISIBILITY_MARGIN => 2;

Plugins::register('avoidAssisters', 'enable custom conditions', \&onUnload);

my @avoidAssisters_mobs;
my %avoidAssisters_rules_by_target_nameID;

my @avoidGlobalAssisters_mobs;
my %visible_monster_count_by_nameID;
my %visible_monsters_by_nameID;

my $hooks = Plugins::addHooks(
	# Setup
	['post_configModify', \&onpost_configModify, undef],
	['post_bulkConfigModify', \&onpost_bulkConfigModify, undef],
	['pos_load_config.txt', \&reload_config, undef],
	['packet_mapChange', \&on_packet_mapChange, undef],

	# Visible monster cache
	['add_monster_list', \&on_add_monster_list, undef],
	['monster_disappeared', \&on_monster_disappeared, undef],

	# Target check
	['shouldDropTarget', \&on_shouldDropTarget, undef],
	['getBestTarget', \&on_getBestTarget, undef],
);

my $chooks = Commands::register(
	['assist', 'avoidAssisters controls: assist [conf|dump|status]', \&command_avoidAssisters],
);

reload_config();

## Purpose: Unregisters every plugin hook when the plugin is unloaded.
## Args: none.
## Returns: nothing.
## Notes: This exists so reloading or disabling the plugin does not leave stale
## hook callbacks active in the OpenKore runtime.
sub onUnload {
    Plugins::delHooks($hooks);
	Commands::unregister($chooks) if $chooks;
}

## Purpose: Rebuilds the plugin's in-memory rule tables from config.txt.
## Args: none.
## Returns: nothing.
## Notes: This is the shared reload entry point used by initial config load and
## runtime config update hooks so parsing behavior stays centralized.
sub reload_config {
	undef @avoidAssisters_mobs;
	undef %avoidAssisters_rules_by_target_nameID;
	undef @avoidGlobalAssisters_mobs;
	my $parsed_blocks = read_avoid_assisters_blocks_from_config_file();
	parse_avoidAssisters($parsed_blocks->{avoidAssisters});
	parse_avoidGlobalAssisters($parsed_blocks->{avoidGlobalAssisters});
	rebuild_visible_monster_count_cache();
}

## Purpose: Reads avoidAssisters blocks directly from the current config file.
## Args: none.
## Returns: A hashref with `avoidAssisters` and `avoidGlobalAssisters` block arrays.
## Notes: This parser exists so the plugin can support repeated keys inside one
## config block, such as multiple `maxAssistersBellowDistAllowed` entries.
sub read_avoid_assisters_blocks_from_config_file {
	my %blocks = (
		avoidAssisters => [],
		avoidGlobalAssisters => [],
	);

	my $filename = Settings::getConfigFilename();
	return \%blocks unless defined $filename && $filename ne '' && -f $filename;

	open my $fh, '<:utf8', $filename or do {
		warning "[avoidAssisters] Unable to open config file '$filename' for parsing: $!\n";
		return \%blocks;
	};

	my $current_block;
	my $block_index = 0;
	my $line_number = 0;
	while (my $line = <$fh>) {
		$line_number++;
		chomp $line;
		$line =~ s/\r$//;
		$line =~ s/\s+#.*$//;
		next if $line =~ /^\s*$/;

		if (!$current_block) {
			if ($line =~ /^\s*(avoidAssisters|avoidGlobalAssisters)(?:\s+([^\{]+?))?\s*\{\s*$/) {
				$current_block = {
					type => $1,
					identifier_raw => defined $2 ? $2 : '',
					attributes => [],
					index => $block_index++,
					line => $line_number,
				};
			}
			next;
		}

		if ($line =~ /^\s*\}\s*$/) {
			push @{ $blocks{$current_block->{type}} }, $current_block;
			undef $current_block;
			next;
		}

		if ($line =~ /^\s*([A-Za-z_]\w*)(?:\s+(.*?))?\s*$/) {
			push @{ $current_block->{attributes} }, {
				key => $1,
				value => defined $2 ? $2 : '',
				line => $line_number,
			};
			next;
		}
	}

	close $fh;
	return \%blocks;
}

## Purpose: Normalizes one numeric assister config value.
## Args: `($value, $config_key)` where `$value` is the raw config scalar and
## `$config_key` is the source key name used in warning output.
## Returns: The numeric value, or `undef` when the input is missing or invalid.
## Notes: This keeps parse-time validation centralized so malformed assister
## blocks can be skipped cleanly with one consistent warning format.
sub normalize_assister_numeric_config_value {
	my ($value, $config_key) = @_;
	return unless defined $value && $value ne '';

	if ($value =~ /^-?\d+$/) {
		return 0 + $value;
	}

	warning "[avoidAssisters] Ignoring invalid numeric value '$value' for $config_key.\n";
	return;
}

## Purpose: Rebuilds the visible monster count cache when the map changes.
## Args: Hook arguments are ignored.
## Returns: nothing.
## Notes: Monster add/disappear hooks keep the cache live incrementally, but a map
## change invalidates the whole visible actor set at once, so the cache is reset
## and allowed to repopulate from fresh add-monster events on the new map.
sub on_packet_mapChange {
	reset_visible_monster_cache();
}

## Purpose: Reacts to a single config modification that may affect this plugin.
## Args: `(undef, $args)` from `post_configModify`, where `$args->{key}` is the
## changed config key and `$args->{bulk}` marks bulk updates.
## Returns: nothing.
## Notes: This exists to avoid reparsing on unrelated config changes and to defer
## bulk updates to `onpost_bulkConfigModify`.
sub onpost_configModify {
	my (undef, $args) = @_;
	return if $args && $args->{bulk};
	return if $args && !is_plugin_config_key($args->{key});
	reload_config();
}

## Purpose: Reacts once after a bulk config update finishes.
## Args: `(undef, $args)` from `post_bulkConfigModify`, where `$args->{keys}` is
## the hashref of modified config keys.
## Returns: nothing.
## Notes: Bulk config operations may touch several plugin keys at once, so this
## hook reloads exactly once after the batch instead of once per key.
sub onpost_bulkConfigModify {
	my (undef, $args) = @_;
	return unless $args && bulk_includes_plugin_config_keys($args->{keys});
	reload_config();
}

## Purpose: Checks whether a single config key belongs to avoidAssisters.
## Args: `($key)` where `$key` is a config.txt key name.
## Returns: `1` if the key belongs to this plugin, otherwise `0`.
## Notes: This helper keeps the config hooks from reloading on unrelated config
## changes elsewhere in the bot configuration.
sub is_plugin_config_key {
	my ($key) = @_;
	return 0 unless defined $key && $key ne '';
	return 1 if $key =~ /^avoidAssisters(?:_|$)/;
	return 1 if $key =~ /^avoidGlobalAssisters(?:_|$)/;
	return 0;
}

## Purpose: Detects whether a bulk config change touched any plugin key.
## Args: `($keys)` where `$keys` is the hashref provided by the bulk config hook.
## Returns: `1` if at least one changed key belongs to this plugin, otherwise `0`.
## Notes: This is the bulk-update counterpart to `is_plugin_config_key`.
sub bulk_includes_plugin_config_keys {
	my ($keys) = @_;
	return 0 unless $keys;

	foreach my $key (keys %{$keys}) {
		return 1 if is_plugin_config_key($key);
	}

	return 0;
}


## Purpose: Parses all per-target avoidAssisters rules from config.txt.
## Args: `($blocks)` where `$blocks` is the parsed avoidAssisters block arrayref.
## Returns: nothing.
## Notes: Each block expands into one or more normalized rules and fills both the
## flat rule list and a per-target lookup table so runtime checks can grab
## matching rules in O(1).
sub parse_avoidAssisters {
	my ($blocks) = @_;
	return unless $blocks;

	foreach my $block (@{$blocks}) {
		my $target_id = get_assister_block_target_id($block);
		next unless defined $target_id;

		foreach my $rule_data (@{ expand_assister_block_rules($block) }) {
			my %mobAvoid = (
				id => $target_id,
				checkRange => $rule_data->{checkRange},
				maxMobsInRange => $rule_data->{maxMobsInRange},
				blockKey => get_assister_block_display_key($block),
				blockValue => $target_id,
				ruleScope => 'avoidAssisters',
				ruleKey => $rule_data->{ruleKey},
				ruleValue => $rule_data->{ruleValue},
			);

			push(@avoidAssisters_mobs, \%mobAvoid);
			push @{ $avoidAssisters_rules_by_target_nameID{$mobAvoid{id}} }, \%mobAvoid;
		}
	}
}

## Purpose: Parses all global assister rules from config.txt.
## Args: `($blocks)` where `$blocks` is the parsed avoidGlobalAssisters block arrayref.
## Returns: nothing.
## Notes: These rules apply to any target and may expand one config block into
## several normalized assister thresholds.
sub parse_avoidGlobalAssisters {
	my ($blocks) = @_;
	return unless $blocks;

	foreach my $block (@{$blocks}) {
		my $assister_id = get_assister_block_target_id($block);
		next unless defined $assister_id;

		foreach my $rule_data (@{ expand_assister_block_rules($block) }) {
			my %mobAvoid = (
				id => $assister_id,
				checkRange => $rule_data->{checkRange},
				maxMobsInRange => $rule_data->{maxMobsInRange},
				blockKey => get_assister_block_display_key($block),
				blockValue => $assister_id,
				ruleScope => 'avoidGlobalAssisters',
				ruleKey => $rule_data->{ruleKey},
				ruleValue => $rule_data->{ruleValue},
			);

			push(@avoidGlobalAssisters_mobs, \%mobAvoid);
		}
	}
}

## Purpose: Builds a readable identifier for one parsed config block.
## Args: `($block)` where `$block` is the parsed block hashref.
## Returns: A readable block identifier string.
## Notes: This keeps dumps and warnings stable even when one block expands into
## multiple normalized rules.
sub get_assister_block_display_key {
	my ($block) = @_;
	return 'unknownBlock' unless $block;
	return sprintf('%s[%d]', $block->{type}, $block->{index});
}

## Purpose: Resolves the target or assister mob ID for one config block.
## Args: `($block)` where `$block` is the parsed block hashref.
## Returns: The normalized numeric mob ID, or `undef` when missing.
## Notes: The block header value is preferred, but legacy inner `id` entries are
## still accepted for backward compatibility.
sub get_assister_block_target_id {
	my ($block) = @_;
	return unless $block;

	my $raw_identifier = $block->{identifier_raw};
	if ((!defined $raw_identifier || $raw_identifier eq '') && $block->{attributes}) {
		foreach my $attribute (@{ $block->{attributes} }) {
			next unless $attribute->{key} eq 'id';
			$raw_identifier = $attribute->{value};
			last;
		}
	}

	my $config_key = get_assister_block_display_key($block) . '.id';
	return normalize_assister_numeric_config_value($raw_identifier, $config_key);
}

## Purpose: Expands one parsed config block into normalized range/threshold rules.
## Args: `($block)` where `$block` is the parsed block hashref.
## Returns: An arrayref of normalized rule hashes.
## Notes: This supports repeated `maxAssistersBellowDistAllowed <dist> <allowed>`
## lines and rejects blocks that do not use the merged syntax.
sub expand_assister_block_rules {
	my ($block) = @_;
	return [] unless $block;

	my @rules;
	my @merged_attrs = grep {
		$_->{key} eq 'maxAssistersBellowDistAllowed' || $_->{key} eq 'maxAssistersBelowDistAllowed'
	} @{ $block->{attributes} || [] };

	if (@merged_attrs) {
		my $merged_index = 0;
		foreach my $attribute (@merged_attrs) {
			my ($check_range_raw, $max_allowed_raw) = ($attribute->{value} || '') =~ /^\s*(-?\d+)\s+(-?\d+)\s*$/;
			unless (defined $check_range_raw && defined $max_allowed_raw) {
				warning "[avoidAssisters] Ignoring invalid $attribute->{key} value '$attribute->{value}' in " . get_assister_block_display_key($block) . ". Expected '<dist> <allowed>'.\n";
				$merged_index++;
				next;
			}

			my $rule_config_key_prefix = get_assister_block_display_key($block) . "." . $attribute->{key} . "[$merged_index]";
			my $check_range = normalize_assister_numeric_config_value($check_range_raw, $rule_config_key_prefix . ".checkRange");
			my $max_mobs_in_range = normalize_assister_numeric_config_value($max_allowed_raw, $rule_config_key_prefix . ".maxMobsInRange");
			if (defined $check_range && defined $max_mobs_in_range) {
				push @rules, {
					checkRange => $check_range,
					maxMobsInRange => $max_mobs_in_range,
					ruleKey => $attribute->{key} . "[$merged_index]",
					ruleValue => $attribute->{value},
				};
			}
			$merged_index++;
		}

		return \@rules;
	}

	warning "[avoidAssisters] Ignoring " . get_assister_block_display_key($block) . " because it has no maxAssistersBellowDistAllowed entries.\n";
	return [];
}

## Purpose: Clears the visible-monster caches for counts and buckets.
## Args: none.
## Returns: nothing.
## Notes: This is the shared reset path used before full cache rebuilds and on map
## changes when visible actor state must be discarded immediately.
sub reset_visible_monster_cache {
	undef %visible_monster_count_by_nameID;
	undef %visible_monsters_by_nameID;
}

## Purpose: Rebuilds the visible-monster caches from the live monster list.
## Args: none.
## Returns: nothing.
## Notes: This is the authoritative reset path for the cache and is used after
## config reloads and map changes so incremental hook updates start from truth.
sub rebuild_visible_monster_count_cache {
	reset_visible_monster_cache();
	return unless $monstersList;

	foreach my $monster (@{$monstersList}) {
		next unless $monster;
		increment_visible_monster_count($monster);
	}
}

## Purpose: Updates the visible-monster count cache when a monster appears.
## Args: `(undef, $monster)` from `add_monster_list`, where `$monster` is the live actor.
## Returns: nothing.
## Notes: This keeps the nameID cache current without needing to rescan the full
## monster list every time target selection runs. If a relevant assister was kept
## cached while off screen and later returns, the cached entry is refreshed
## without double-counting it.
sub on_add_monster_list {
	my (undef, $monster) = @_;
	increment_visible_monster_count($monster);
}

## Purpose: Updates the visible-monster count cache when a monster disappears.
## Args: `(undef, $args)` from `monster_disappeared`, where `$args->{monster}` is
## the actor leaving the visible set.
## Returns: nothing.
## Notes: This is the inverse of `on_add_monster_list` and keeps the cached counts
## aligned with the currently visible monster set. When a relevant assister is
## truly removed on screen, such as by death or teleport, all currently blocked
## visible targets are rechecked immediately so they can be released without
## waiting for a later targeting pass.
sub on_monster_disappeared {
	my (undef, $args) = @_;
	my $monster = $args->{monster};
	decrement_visible_monster_count($monster) unless should_keep_disappeared_monster_in_assister_cache($monster);
	recheck_all_dropped_targets_from_assisters() if is_truly_removed_relevant_assister($monster);
}

## Purpose: Increments the cached visible count for one monster nameID.
## Args: `($monster)` where `$monster` is the live actor to account for.
## Returns: nothing.
## Notes: The helper silently ignores missing actors or actors without a defined
## `nameID` and `ID` so hook callbacks can stay tiny and safe. It updates both the
## total visible count and the per-nameID actor bucket, with the bucket acting as
## the source of truth to avoid double-counting duplicate add events.
sub increment_visible_monster_count {
	my ($monster) = @_;
	return unless $monster;
	return unless defined $monster->{nameID};
	return unless defined $monster->{ID};

	my $bucket = ($visible_monsters_by_nameID{$monster->{nameID}} ||= {});
	if (exists $bucket->{$monster->{ID}}) {
		$bucket->{$monster->{ID}} = $monster;
		return;
	}

	$bucket->{$monster->{ID}} = $monster;
	$visible_monster_count_by_nameID{$monster->{nameID}}++;
}

## Purpose: Decrements the cached visible count for one monster nameID.
## Args: `($monster)` where `$monster` is the actor being removed from visibility.
## Returns: nothing.
## Notes: Counts are clamped by deletion at zero so stale duplicate disappear
## events cannot drive the cache negative. The matching actor is also removed from
## the per-nameID bucket.
sub decrement_visible_monster_count {
	my ($monster) = @_;
	return unless $monster;
	return unless defined $monster->{nameID};
	return unless defined $monster->{ID};
	return unless exists $visible_monsters_by_nameID{$monster->{nameID}};
	return unless exists $visible_monsters_by_nameID{$monster->{nameID}}{$monster->{ID}};

	delete $visible_monsters_by_nameID{$monster->{nameID}}{$monster->{ID}};
	$visible_monster_count_by_nameID{$monster->{nameID}}--;
	delete $visible_monster_count_by_nameID{$monster->{nameID}} if $visible_monster_count_by_nameID{$monster->{nameID}} <= 0;
	delete $visible_monsters_by_nameID{$monster->{nameID}} if exists $visible_monsters_by_nameID{$monster->{nameID}} && !scalar keys %{ $visible_monsters_by_nameID{$monster->{nameID}} };
}

## Purpose: Reports whether a monster nameID participates in any assister rule.
## Args: `($name_id)` where `$name_id` is a monster nameID scalar.
## Returns: `1` when the nameID is referenced by any per-target or global rule.
## Notes: This keeps the disappearance-retention logic limited to monsters that
## can actually affect this plugin's decisions.
sub is_relevant_assister_nameID {
	my ($name_id) = @_;
	return 0 unless defined $name_id;
	return 1 if exists $avoidAssisters_rules_by_target_nameID{$name_id};

	foreach my $rule (@avoidGlobalAssisters_mobs) {
		return 1 if defined $rule->{id} && $rule->{id} == $name_id;
	}

	return 0;
}

## Purpose: Decides whether a disappeared monster should stay cached as a hidden assister.
## Args: `($monster)` where `$monster` is the actor leaving visibility.
## Returns: `1` when the monster should remain cached, otherwise `0`.
## Notes: Plain `disappeared` means the monster only moved off screen, so relevant
## assisters are kept temporarily to avoid immediate release churn. True removals
## such as death or teleport are not kept.
sub should_keep_disappeared_monster_in_assister_cache {
	my ($monster) = @_;
	return 0 unless $monster;
	return 0 if is_truly_removed_relevant_assister($monster);
	return 0 unless ($monster->{disappeared} || 0) == 1;
	return is_relevant_assister_nameID($monster->{nameID});
}

## Purpose: Reports whether a disappeared monster truly matters to assister rechecks.
## Args: `($monster)` where `$monster` is the actor that just left visibility.
## Returns: `1` when the actor was truly removed from the field by death or
## teleport and its nameID participates in any assister rule.
## Notes: `monster_disappeared` is also used for actors that merely moved off
## screen, so plain `$monster->{disappeared}` must not trigger the full recheck.
sub is_truly_removed_relevant_assister {
	my ($monster) = @_;
	return 0 unless $monster;
	return 0 unless ($monster->{dead} || $monster->{teleported});
	return is_relevant_assister_nameID($monster->{nameID});
}

## Purpose: Re-evaluates every currently blocked visible monster after assister loss.
## Args: none.
## Returns: nothing.
## Notes: A dying assister can make nearby targets safe again immediately, so this
## helper proactively runs the plugin release logic for currently blocked visible
## monsters instead of waiting for the next ordinary target-selection pass.
sub recheck_all_dropped_targets_from_assisters {
	return unless $monstersList;

	foreach my $target (@{$monstersList}) {
		next unless $target;
		next unless isTargetDroppedAssisters($target);
		should_drop_target_from_assisters('monster_disappeared_recheck', $target, 'Rechecking');
	}
}

## Purpose: Decides whether the current attack target should be dropped.
## Args: `($hook, $args)` from the `shouldDropTarget` hook, where `$args->{target}`
## is the live target actor and `$args->{return}` is the hook's decision flag.
## Returns: nothing directly; sets `$args->{return}` to `1` when the target must be dropped.
## Notes: This is the runtime safety gate for targets we are already attacking or
## routing toward.
sub on_shouldDropTarget {
	my ($hook, $args) = @_;
	return unless $field;
	return unless $args->{target};

	if (should_drop_target_from_assisters($hook, $args->{target}, 'Dropping')) {
		$args->{return} = 1;
	}
}

## Purpose: Filters blocked targets out of the target-selection candidate list.
## Args: `($hook, $args)` from the `getBestTarget` hook, where
## `$args->{possibleTargets}` is an arrayref of monster IDs.
## Returns: nothing directly; mutates `$args->{possibleTargets}` in place.
## Notes: This exists so bad targets are removed before OpenKore scores and picks
## a best target.
sub on_getBestTarget {
	my ($hook, $args) = @_;
	return unless $field;
	return unless $args->{possibleTargets} && ref $args->{possibleTargets} eq 'ARRAY';

	my @filtered_targets;
	foreach my $target_ID (@{ $args->{possibleTargets} }) {
		my $target = $monsters{$target_ID};
		if ($target && should_drop_target_from_assisters($hook, $target, 'Not picking')) {
			next;
		}

		push @filtered_targets, $target_ID;
	}

	@{ $args->{possibleTargets} } = @filtered_targets;
}

## Purpose: Handles the plugin's console command and prints the parsed rules.
## Args: `($cmd, $args)` from the command dispatcher, where `$args` is the raw
## argument string after `assist`.
## Returns: nothing.
## Notes: The command currently supports `dump` and `status`, both of which print
## the currently loaded plugin settings so runtime config state can be inspected
## without reopening `config.txt`.
sub command_avoidAssisters {
	my ($cmd, $args) = @_;
	$args = $cmd unless defined $args;
	$args = '' unless defined $args;
	$args =~ s/^\s+|\s+$//g;

	if ($args eq '' || $args eq 'conf' || $args eq 'dump' || $args eq 'status') {
		print_avoidAssisters_configuration();
		return;
	}

	message "[avoidAssisters] Usage: assist [conf|dump|status]\n";
}

## Purpose: Formats one scalar for the config dump table.
## Args: `($value)` where `$value` is the raw scalar to print.
## Returns: A printable string.
## Notes: This keeps empty values obvious in the dump instead of collapsing into
## Perl warnings or invisible blanks.
sub format_avoid_assisters_dump_value {
	my ($value) = @_;
	return '-' unless defined $value && $value ne '';
	return $value;
}

## Purpose: Builds a short readable label for one assister actor in debug logs.
## Args: `($monster)` where `$monster` is a visible assister actor.
## Returns: A single-line description including binID, nameID, and position.
## Notes: The plugin's drop warnings use this helper so the trigger list is easy
## to scan while debugging repeated target blocks.
sub format_assister_actor_debug_label {
	my ($monster) = @_;
	return 'unknown assister' unless $monster;

	my $pos = $monster->{pos_to} || {};
	my $bin_id = defined $monster->{binID} ? $monster->{binID} : '?';
	my $name_id = defined $monster->{nameID} ? $monster->{nameID} : '?';
	my $x = defined $pos->{x} ? $pos->{x} : '?';
	my $y = defined $pos->{y} ? $pos->{y} : '?';

	return "binID=$bin_id nameID=$name_id pos=($x,$y)";
}

## Purpose: Builds the detailed warning text for one drop decision.
## Args: `($target, $drop_info)` where `$drop_info` is the structured hashref
## returned by `find_assister_drop_reason`.
## Returns: A human-readable debug string.
## Notes: This consolidates the log format so both `shouldDropTarget` and
## `getBestTarget` warnings stay explicit and consistent.
sub format_assister_drop_reason_message {
	my ($target, $drop_info) = @_;
	return 'for an unknown avoidAssisters reason.' unless $target && $drop_info;

	my $target_pos = $drop_info->{targetPosition}{pos} || {};
	my $position_source = $drop_info->{targetPosition}{source} || 'unknown_pos';
	my $position_x = defined $target_pos->{x} ? $target_pos->{x} : '?';
	my $position_y = defined $target_pos->{y} ? $target_pos->{y} : '?';
	my $rule = $drop_info->{rule} || {};
	my $rule_scope = $rule->{ruleScope} || 'unknownRule';
	my $rule_block_key = format_avoid_assisters_dump_value($rule->{blockKey});
	my $rule_block_value = format_avoid_assisters_dump_value($rule->{blockValue});
	my $assister_descriptions = join('; ', map { format_assister_actor_debug_label($_) } @{ $drop_info->{assisters} || [] });
	$assister_descriptions = 'none captured' if $assister_descriptions eq '';

	return sprintf(
		"because %s matched at %s targetPos=(%s,%s); rule=%s blockValue=%s assisterMobID=%s checkRange=%s maxMobsInRange=%s counted=%s triggerAssisters=[%s].",
		$rule_scope,
		$position_source,
		$position_x,
		$position_y,
		$rule_block_key,
		$rule_block_value,
		format_avoid_assisters_dump_value($drop_info->{assisterID}),
		format_avoid_assisters_dump_value($rule->{checkRange}),
		format_avoid_assisters_dump_value($rule->{maxMobsInRange}),
		format_avoid_assisters_dump_value($drop_info->{count}),
		$assister_descriptions,
	);
}

## Purpose: Prints the currently parsed avoidAssisters configuration to the console.
## Args: none.
## Returns: nothing.
## Notes: This dumps the rule state exactly as loaded in memory, which is useful
## for confirming runtime config reloads and parsed numeric values.
sub print_avoidAssisters_configuration {
	my $msg = center(" avoidAssisters Config ", 79, '-') . "\n";
	$msg .= sprintf(
		"Per-target rules: %d  Global rules: %d  Visible cached nameIDs: %d\n",
		scalar(@avoidAssisters_mobs),
		scalar(@avoidGlobalAssisters_mobs),
		scalar(keys %visible_monsters_by_nameID),
	);
	$msg .= ('-' x 79) . "\n";
	$msg .= center(" Per-target Rules ", 79, '-') . "\n";
	$msg .= swrite(
		"@<< @<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<< @>>>>>> @>>>>>> @>>>>>>>>\n",
		['#', 'Block', 'Rule', 'MobID', 'Range', 'MaxMobs']
	);

	if (@avoidAssisters_mobs) {
		my $index = 0;
		foreach my $rule (@avoidAssisters_mobs) {
			$msg .= swrite(
				"@<< @<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<< @>>>>>> @>>>>>> @>>>>>>>>\n",
				[
					$index,
					format_avoid_assisters_dump_value($rule->{blockKey}),
					format_avoid_assisters_dump_value($rule->{ruleKey}),
					format_avoid_assisters_dump_value($rule->{id}),
					format_avoid_assisters_dump_value($rule->{checkRange}),
					format_avoid_assisters_dump_value($rule->{maxMobsInRange}),
				]
			);
			$msg .= sprintf(
				"    blockValue=%s ruleValue=%s\n",
				format_avoid_assisters_dump_value($rule->{blockValue}),
				format_avoid_assisters_dump_value($rule->{ruleValue}),
			);
			$index++;
		}
	} else {
		$msg .= "No per-target avoidAssisters blocks are configured.\n";
	}

	$msg .= ('-' x 79) . "\n";
	$msg .= center(" Global Rules ", 79, '-') . "\n";
	$msg .= swrite(
		"@<< @<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<< @>>>>>> @>>>>>> @>>>>>>>>\n",
		['#', 'Block', 'Rule', 'MobID', 'Range', 'MaxMobs']
	);

	if (@avoidGlobalAssisters_mobs) {
		my $index = 0;
		foreach my $rule (@avoidGlobalAssisters_mobs) {
			$msg .= swrite(
				"@<< @<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<< @>>>>>> @>>>>>> @>>>>>>>>\n",
				[
					$index,
					format_avoid_assisters_dump_value($rule->{blockKey}),
					format_avoid_assisters_dump_value($rule->{ruleKey}),
					format_avoid_assisters_dump_value($rule->{id}),
					format_avoid_assisters_dump_value($rule->{checkRange}),
					format_avoid_assisters_dump_value($rule->{maxMobsInRange}),
				]
			);
			$msg .= sprintf(
				"    blockValue=%s ruleValue=%s\n",
				format_avoid_assisters_dump_value($rule->{blockValue}),
				format_avoid_assisters_dump_value($rule->{ruleValue}),
			);
			$index++;
		}
	} else {
		$msg .= "No global avoidGlobalAssisters blocks are configured.\n";
	}

	$msg .= ('-' x 79) . "\n";
	message $msg, "list";
}

## Purpose: Applies the plugin's drop-or-release policy to one target.
## Args: `($hook, $target, $drop_string)` where `$hook` is the calling hook name,
## `$target` is the live monster actor, and `$drop_string` is a log label such as
## `Dropping` or `Not picking`.
## Returns: `1` when the target should stay blocked, otherwise `0`.
## Notes: This shared helper exists so `shouldDropTarget` and `getBestTarget`
## enforce the same blocker logic and state transitions. Already-engaged targets
## use a short confirmation timer before the first drop so brief unsafe states
## do not immediately cancel a fight. Released targets also respect a short
## cooldown before they can be unblocked again after an assister drop.
sub should_drop_target_from_assisters {
	my ($hook, $target, $drop_string) = @_;

	my @target_positions = get_target_positions($target);
	my $is_dropped = isTargetDroppedAssisters($target);
	my @drop_infos = find_assister_drop_reasons_by_position($target, \@target_positions);
	my $engaged_by_us = target_has_been_engaged_by_us($target);
	my $must_drop = should_force_drop_target_from_assisters($hook, \@target_positions, \@drop_infos, $engaged_by_us);

	if ($must_drop) {
		if ($hook eq 'shouldDropTarget' && $engaged_by_us && !$is_dropped) {
			return 0 unless engaged_drop_confirmation_elapsed($target);
		}

		clear_engaged_drop_confirmation($target);
		start_assister_drop_release_cooldown($target) unless $is_dropped;
		warning "[avoidAssisters] [$hook] $drop_string target $target (binID: " . format_avoid_assisters_dump_value($target->{binID}) . ", nameID: " . format_avoid_assisters_dump_value($target->{nameID}) . ") " . join(' ALSO ', map { format_assister_drop_reason_message($target, $_) } @drop_infos) . "\n" if !$is_dropped;
		$target->{attackFailedAssisters} = 1;
		return 1;
	}

	clear_engaged_drop_confirmation($target);

	if ($is_dropped) {
		my ($can_release, $monster_dist, $max_dist_to_release, $required_check_range) = can_release_target_from_assisters($target, \@target_positions);
		if ($can_release) {
			warning "[avoidAssisters] [$hook] Releasing nearby ($monster_dist <= $max_dist_to_release) target $target from block, it no longer meets blocking criteria and we are close enough to fully see its assister range ($required_check_range).\n";
			$target->{attackFailedAssisters} = 0;
			clear_engaged_drop_confirmation($target);
			clear_assister_drop_release_cooldown($target);
			return 0;
		}

		return 1;
	}

	return 0;
}

## Purpose: Reports whether we have already started attacking this target.
## Args: `($target)` where `$target` is the live monster actor being checked.
## Returns: `1` when we have already engaged the target, otherwise `0`.
## Notes: This lets `shouldDropTarget` use stricter drop rules only after combat
## has actually started, while `getBestTarget` keeps the earlier cheap screening.
## `sentAttack` and `engaged` are checked first because they reflect local
## attack commitment earlier than delayed server damage feedback.
sub target_has_been_engaged_by_us {
	my ($target) = @_;
	return 0 unless $target;
	return 1 if ($target->{sentAttack} || 0) == 1;
	return 1 if ($target->{engaged} || 0) == 1;
	return 1 if (($target->{numAtkFromYou} || 0) > 0);
	return 1 if (($target->{dmgFromYou} || 0) > 0);
	return 1 if (($target->{missedFromYou} || 0) > 0);
	return 0;
}

## Purpose: Starts or checks the engaged-target drop confirmation timer.
## Args: `($target)` where `$target` is the currently evaluated monster actor.
## Returns: `1` when the target has stayed unsafe for the configured delay,
## otherwise `0`.
## Notes: This exists so already-engaged targets are only dropped after the
## unsafe state persists continuously, which better tolerates server lag and
## brief position mismatch.
sub engaged_drop_confirmation_elapsed {
	my ($target) = @_;
	return 1 unless $target;
	return 1 if ENGAGED_DROP_CONFIRMATION_DELAY <= 0;

	my $now = time;
	if (!defined $target->{avoidAssistersEngagedDropSince}) {
		$target->{avoidAssistersEngagedDropSince} = $now;
		return 0;
	}

	return (($now - $target->{avoidAssistersEngagedDropSince}) >= ENGAGED_DROP_CONFIRMATION_DELAY) ? 1 : 0;
}

## Purpose: Clears any pending engaged-target drop confirmation timer.
## Args: `($target)` where `$target` is the monster actor being reset.
## Returns: nothing.
## Notes: The timer is cleared whenever the target becomes safe again or after a
## release so later danger checks must prove a fresh continuous unsafe interval.
sub clear_engaged_drop_confirmation {
	my ($target) = @_;
	return unless $target;
	delete $target->{avoidAssistersEngagedDropSince};
}

## Purpose: Starts the cooldown that delays releasing a just-dropped target.
## Args: `($target)` where `$target` is the monster actor that has just been blocked.
## Returns: nothing.
## Notes: This exists to prevent immediate repicks when visibility briefly flickers
## after an assister-based drop.
sub start_assister_drop_release_cooldown {
	my ($target) = @_;
	return unless $target;
	$target->{avoidAssistersDroppedAt} = time;
}

## Purpose: Clears the post-drop release cooldown marker for one target.
## Args: `($target)` where `$target` is the monster actor being reset.
## Returns: nothing.
## Notes: The cooldown only matters while the target is blocked, so it is removed
## when the target is released again.
sub clear_assister_drop_release_cooldown {
	my ($target) = @_;
	return unless $target;
	delete $target->{avoidAssistersDroppedAt};
}

## Purpose: Reports whether the post-drop release cooldown has elapsed.
## Args: `($target)` where `$target` is the blocked monster actor being checked.
## Returns: `1` when release is allowed to proceed, otherwise `0`.
## Notes: This adds a short hysteresis window after assister drops so we do not
## instantly re-pick the same target on one safe-looking tick.
sub assister_drop_release_cooldown_elapsed {
	my ($target) = @_;
	return 1 unless $target;
	return 1 if ASSISTER_DROP_RELEASE_COOLDOWN <= 0;
	return 1 unless defined $target->{avoidAssistersDroppedAt};
	return ((time - $target->{avoidAssistersDroppedAt}) >= ASSISTER_DROP_RELEASE_COOLDOWN) ? 1 : 0;
}

## Purpose: Decides whether the current collected drop reasons require a drop.
## Args: `($hook, $target_positions, $drop_infos, $engaged_by_us)`.
## Returns: `1` when the target must be dropped, otherwise `0`.
## Notes: `getBestTarget` and unengaged `shouldDropTarget` drop on the first bad
## position, but engaged `shouldDropTarget` requires every checked target
## position to fail before abandoning the target.
sub should_force_drop_target_from_assisters {
	my ($hook, $target_positions, $drop_infos, $engaged_by_us) = @_;
	return 0 unless $drop_infos && @{$drop_infos};

	if ($hook eq 'shouldDropTarget' && $engaged_by_us) {
		return 0 unless $target_positions && @{$target_positions};
		return scalar(@{$drop_infos}) == scalar(@{$target_positions});
	}

	return 1;
}

## Purpose: Collects the target positions that should be checked for safety.
## Args: `($target)` where `$target` is the monster actor being evaluated.
## Returns: A list of hashrefs containing `source` and `pos`.
## Notes: The plugin checks both the current predicted pathfinding position and
## `pos_to` so moving targets cannot bypass the assister checks due to stale data.
sub get_target_positions {
	my ($target) = @_;
	return unless $target;

	my @target_positions;
	my $target_calc_pos = calcPosFromPathfinding($field, $target);
	push @target_positions, { source => 'calc_pos', pos => $target_calc_pos } if $target_calc_pos;

	my $same_as_calc = $target_calc_pos
		&& $target->{pos_to}
		&& $target_calc_pos->{x} == $target->{pos_to}{x}
		&& $target_calc_pos->{y} == $target->{pos_to}{y};
	push @target_positions, { source => 'pos_to', pos => $target->{pos_to} } if $target->{pos_to} && !$same_as_calc;

	return @target_positions;
}

## Purpose: Finds the first assister rule violation for a target, if any.
## Args: `($target, $target_positions)` where `$target_positions` is an arrayref
## of position-descriptor hashrefs returned by `get_target_positions`.
## Returns: A structured hashref describing the first blocking rule, or
## `undef` when no rule currently blocks it.
## Notes: This helper centralizes both per-target and global assister checks so
## blocking and release logic can rely on one source of truth.
sub find_assister_drop_reasons_by_position {
	my ($target, $target_positions) = @_;
	my @drop_infos;

	foreach my $target_position (@{ $target_positions || [] }) {
		my $drop_info = find_assister_drop_reason_for_position($target, $target_position);
		push @drop_infos, $drop_info if $drop_info;
	}

	return @drop_infos;
}

## Purpose: Finds the first assister rule violation for one target position.
## Args: `($target, $target_position)` where `$target_position` is one hashref
## returned by `get_target_positions`.
## Returns: A structured hashref describing the first blocking rule, or `undef`.
## Notes: This is the per-position evaluator used to distinguish `calc_pos` and
## `pos_to` outcomes when deciding whether an engaged target must be dropped.
sub find_assister_drop_reason_for_position {
	my ($target, $target_position) = @_;
	return unless $target && $target_position && $target_position->{pos};

	my $mob_id = $target->{nameID};
	my $target_rules = $avoidAssisters_rules_by_target_nameID{$mob_id};

	if ($target_rules) {
		foreach my $avoidAssister_mob (@{$target_rules}) {
			my $result = count_assisters_in_range($target, $target_position->{pos}, $mob_id, $avoidAssister_mob->{checkRange}, $avoidAssister_mob->{maxMobsInRange});
			if ($result->{count} > $avoidAssister_mob->{maxMobsInRange}) {
				return {
					rule => $avoidAssister_mob,
					targetPosition => $target_position,
					assisterID => $mob_id,
					count => $result->{count},
					assisters => $result->{assisters},
				};
			}
		}
	}

	foreach my $avoid_global_mob (@avoidGlobalAssisters_mobs) {
		my $result = count_assisters_in_range($target, $target_position->{pos}, $avoid_global_mob->{id}, $avoid_global_mob->{checkRange}, $avoid_global_mob->{maxMobsInRange});
		if ($result->{count} > $avoid_global_mob->{maxMobsInRange}) {
			return {
				rule => $avoid_global_mob,
				targetPosition => $target_position,
				assisterID => $avoid_global_mob->{id},
				count => $result->{count},
				assisters => $result->{assisters},
			};
		}
	}

	return;
}

## Purpose: Counts assister mobs of one ID near a target position.
## Args: `($target, $target_pos, $assister_id, $check_range)` where `$target` is
## the target monster, `$target_pos` is the position being checked, `$assister_id`
## is the assister monster ID to count, `$check_range` is the allowed radius, and
## `$max_allowed` is the rule threshold used for early-exit optimization.
## Returns: A hashref with `count` and `assisters`.
## Notes: The target itself is excluded, and mobs already fighting a player are
## ignored so only free potential assisters are counted. The nameID cache is used
## as a cheap early-exit, and the per-nameID bucket keeps the positional scan
## limited to monsters of the relevant assister type.
sub count_assisters_in_range {
	my ($target, $target_pos, $assister_id, $check_range, $max_allowed) = @_;
	return { count => 0, assisters => [] } unless $target && $target_pos;
	prune_hidden_cached_assisters_that_should_be_visible($assister_id);

	my $visible_bucket = $visible_monsters_by_nameID{$assister_id};
	return { count => 0, assisters => [] } unless $visible_bucket;

	my $visible_count = $visible_monster_count_by_nameID{$assister_id} || 0;
	$visible_count-- if defined $target->{nameID} && $target->{nameID} == $assister_id && defined $target->{ID} && exists $visible_bucket->{$target->{ID}};
	return { count => 0, assisters => [] } if $visible_count <= 0;
	return { count => 0, assisters => [] } if defined $max_allowed && $visible_count <= $max_allowed;

	my $count = 0;
	my @assisters;
	foreach my $monster (values %{$visible_bucket}) {
		next if $monster->{ID} eq $target->{ID};
		next unless $monster->{nameID} == $assister_id;
		next if isMobFightingSomeoneElse($monster);
		next unless $monster->{pos_to};
		next if blockDistance($monster->{pos_to}, $target_pos) > $check_range;
		$count++;
		push @assisters, $monster;
		last if defined $max_allowed && $count > $max_allowed;
	}

	return {
		count => $count,
		assisters => \@assisters,
	};
}

## Purpose: Removes hidden cached assisters once they should be visible again.
## Args: `($assister_id)` where `$assister_id` is the nameID bucket being checked.
## Returns: nothing.
## Notes: Relevant assisters that moved off screen are cached conservatively, but
## once we stand close enough to their last known position that they should be in
## view again, the stale cache entry is discarded.
sub prune_hidden_cached_assisters_that_should_be_visible {
	my ($assister_id) = @_;
	return unless defined $assister_id;
	return unless $field && $char;

	my $bucket = $visible_monsters_by_nameID{$assister_id};
	return unless $bucket;

	my $myPos = calcPosFromPathfinding($field, $char);
	return unless $myPos;

	my $visibility_dist = $config{clientSight} - RELEASE_VISIBILITY_MARGIN;
	$visibility_dist = 0 if $visibility_dist < 0;

	my @stale_monsters;
	foreach my $monster (values %{$bucket}) {
		next unless $monster;
		next unless ($monster->{disappeared} || 0) == 1;
		next if ($monster->{dead} || 0) == 1;
		next if ($monster->{teleported} || 0) == 1;
		next unless $monster->{pos_to};
		next if blockDistance($myPos, $monster->{pos_to}) > $visibility_dist;
		push @stale_monsters, $monster;
	}

	decrement_visible_monster_count($_) for @stale_monsters;
}

## Purpose: Checks whether a previously blocked target can be safely released.
## Args: `($target, $target_positions)` where `$target_positions` is an arrayref
## of positions gathered by `get_target_positions`.
## Returns: `($can_release, $monster_dist, $max_dist_to_release, $required_check_range)`.
## Notes: Release is intentionally stricter than drop; it only happens when the
## target no longer violates any rule and we are close enough for `clientSight`
## to cover the full assister radius around every checked target position. A
## small extra safety margin is applied so targets are only released when we are
## comfortably inside the sight requirement, not exactly on its edge. A short
## cooldown after drop must also elapse before the target can be released again.
sub can_release_target_from_assisters {
	my ($target, $target_positions) = @_;
	return (0, undef, undef, undef) unless $target && $field && $char;
	return (0, undef, undef, undef) unless assister_drop_release_cooldown_elapsed($target);

	my $required_check_range = get_required_release_check_range($target);
	return (1, 0, 0, 0) unless defined $required_check_range;

	my $myPos = calcPosFromPathfinding($field, $char);
	return (0, undef, undef, $required_check_range) unless $myPos;

	my $monsterDist;
	foreach my $target_position (@{$target_positions}) {
		next unless $target_position && $target_position->{pos};
		my $dist = blockDistance($myPos, $target_position->{pos});
		$monsterDist = $dist if !defined $monsterDist || $dist > $monsterDist;
	}

	return (0, undef, undef, $required_check_range) unless defined $monsterDist;

	my $max_dist_to_release = ($config{clientSight} - $required_check_range - RELEASE_VISIBILITY_MARGIN);
	$max_dist_to_release = 0 if $max_dist_to_release < 0;
	return ($monsterDist <= $max_dist_to_release, $monsterDist, $max_dist_to_release, $required_check_range);
}

## Purpose: Computes the assister radius that must be fully visible before release.
## Args: `($target)` where `$target` is the monster currently flagged as blocked.
## Returns: The largest relevant `checkRange` for that target, or `undef` if no
## current rules apply anymore.
## Notes: This helper exists so release logic stays conservative when multiple
## rules can affect the same target.
sub get_required_release_check_range {
	my ($target) = @_;
	return unless $target;

	my $mob_id = $target->{nameID};
	my $required_check_range;
	my $target_rules = $avoidAssisters_rules_by_target_nameID{$mob_id};

	if ($target_rules) {
		foreach my $avoidAssister_mob (@{$target_rules}) {
			$required_check_range = $avoidAssister_mob->{checkRange}
				if !defined $required_check_range || $avoidAssister_mob->{checkRange} > $required_check_range;
		}
	}

	foreach my $avoid_global_mob (@avoidGlobalAssisters_mobs) {
		$required_check_range = $avoid_global_mob->{checkRange}
			if !defined $required_check_range || $avoid_global_mob->{checkRange} > $required_check_range;
	}

	return $required_check_range;
}

## Purpose: Reports whether a target is currently marked as blocked by this plugin.
## Args: `($target)` where `$target` is the monster actor being checked.
## Returns: `1` if the plugin previously marked the target as blocked, otherwise `0`.
## Notes: This is used to suppress duplicate warnings and to control later release behavior.
sub isTargetDroppedAssisters {
	my ($target) = @_;
	return 1 if (exists $target->{attackFailedAssisters} && $target->{attackFailedAssisters} == 1);
	return 0;
}

## Purpose: Checks whether a monster is already engaged with any player.
## Args: `($mob)` where `$mob` is the monster actor being examined.
## Returns: `1` if player combat interaction is recorded for that mob, otherwise `0`.
## Notes: The plugin ignores engaged mobs so it only counts free nearby monsters
## as potential assisters.
sub isMobFightingSomeoneElse {
	my ($mob) = @_;
	if (scalar(keys %{$mob->{missedFromPlayer}}) == 0
	 && scalar(keys %{$mob->{dmgFromPlayer}})    == 0
	 && scalar(keys %{$mob->{castOnByPlayer}})   == 0
	 && scalar(keys %{$mob->{missedToPlayer}}) == 0
	 && scalar(keys %{$mob->{dmgToPlayer}})    == 0
	 && scalar(keys %{$mob->{castOnToPlayer}}) == 0
	) {
		return 0;
	} else {
		return 1;
	}
}

return 1;
