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
# 1. avoidAssisters_N
#    Applies the check only when the current target matches the configured mob ID.
# 2. avoidGlobalAssisters_N
#    Applies the check to any target when a configured assister mob is nearby.
#
# How to configure it:
# Add entries in config.txt using a numeric index (0, 1, 2, ...).
#
# Per-target assister check:
# avoidAssisters_0 1
# avoidAssisters_0_id 1096
# avoidAssisters_0_checkRange 9
# avoidAssisters_0_maxMobsInRange 2
#
# Global assister check:
# avoidGlobalAssisters_0 1
# avoidGlobalAssisters_0_id 1113
# avoidGlobalAssisters_0_checkRange 9
# avoidGlobalAssisters_0_maxMobsInRange 3
#
# Meaning of each field:
# - *_id: Monster ID to watch.
# - *_checkRange: Distance around the target to scan for assisting mobs.
# - *_maxMobsInRange: Maximum allowed assisting mobs before the target is dropped.
#
# Examples:
# 1. Avoid attacking a mob if there are more than 2 monsters of the same type
#    close enough to assist it:
#    avoidAssisters_0 1
#    avoidAssisters_0_id 1096
#    avoidAssisters_0_checkRange 9
#    avoidAssisters_0_maxMobsInRange 2
#
# 2. Avoid any target if there are more than 3 dangerous support mobs nearby:
#    avoidGlobalAssisters_0 1
#    avoidGlobalAssisters_0_id 1113
#    avoidGlobalAssisters_0_checkRange 9
#    avoidGlobalAssisters_0_maxMobsInRange 3
#
# 3. Use multiple rules by increasing the index:
#    avoidAssisters_1 1
#    avoidAssisters_1_id 1155
#    avoidAssisters_1_checkRange 7
#    avoidAssisters_1_maxMobsInRange 1
#
# Notes:
# - The plugin ignores monsters already fighting a player.
# - If a previously blocked nearby target no longer meets the block conditions,
#   the plugin can release it and allow it to be targeted again.
#
package avoidAssisters;

use strict;
use Globals;
use Settings;
use Misc;
use Plugins;
use Utils;
use Log qw(message debug error warning);

Plugins::register('avoidAssisters', 'enable custom conditions', \&onUnload);

my %check_avoidAssisters_exists_hash;
my @avoidAssisters_mobs;

my %check_avoidGlobalAssisters_exists_hash;
my @avoidGlobalAssisters_mobs;

my $hooks = Plugins::addHooks(
	# Setup
	['post_configModify', \&onpost_configModify, undef],
	['pos_load_config.txt',       \&onpost_configModify, undef],

	# Target check
	['AI::Attack::process', \&on_AIAttackprocess, undef],
	['getBestTarget', \&on_AIAttackprocess, undef],
);

sub onUnload {
    Plugins::delHooks($hooks);
}

sub onpost_configModify {
	undef %check_avoidAssisters_exists_hash;
	undef @avoidAssisters_mobs;

	undef %check_avoidGlobalAssisters_exists_hash;
	undef @avoidGlobalAssisters_mobs;
	parse_avoidAssisters();
	parse_avoidGlobalAssisters();
}


sub parse_avoidAssisters {
	my $i = 0;
	while (exists $config{"avoidAssisters_$i"}) {
		next unless (defined $config{"avoidAssisters_$i"});
		next unless (defined $config{"avoidAssisters_$i"."_id"});
		next unless (defined $config{"avoidAssisters_$i"."_checkRange"});
		next unless (defined $config{"avoidAssisters_$i"."_maxMobsInRange"});

		my %mobAvoid;
		$mobAvoid{id} = $config{"avoidAssisters_$i"."_id"};
		$mobAvoid{checkRange} = $config{"avoidAssisters_$i"."_checkRange"};
		$mobAvoid{maxMobsInRange} = $config{"avoidAssisters_$i"."_maxMobsInRange"};

		push(@avoidAssisters_mobs, \%mobAvoid);
		$check_avoidAssisters_exists_hash{$mobAvoid{id}} = 1;

	} continue {
		$i++;
	}
}

sub parse_avoidGlobalAssisters {
	my $i = 0;
	while (exists $config{"avoidGlobalAssisters_$i"}) {
		next unless (defined $config{"avoidGlobalAssisters_$i"});
		next unless (defined $config{"avoidGlobalAssisters_$i"."_id"});
		next unless (defined $config{"avoidGlobalAssisters_$i"."_checkRange"});
		next unless (defined $config{"avoidGlobalAssisters_$i"."_maxMobsInRange"});

		my %mobAvoid;
		$mobAvoid{id} = $config{"avoidGlobalAssisters_$i"."_id"};
		$mobAvoid{checkRange} = $config{"avoidGlobalAssisters_$i"."_checkRange"};
		$mobAvoid{maxMobsInRange} = $config{"avoidGlobalAssisters_$i"."_maxMobsInRange"};

		push(@avoidGlobalAssisters_mobs, \%mobAvoid);
		$check_avoidGlobalAssisters_exists_hash{$mobAvoid{id}} = 1;

	} continue {
		$i++;
	}
}

# This call is done in AI::Attack::process and is used to drop targets before the attack proceeds, drops when return value is 1
sub on_AIAttackprocess {
	my ($hook, $args) = @_;

	my $target = $args->{target};
	my $mob_id = $target->{nameID};
	
	my $targetPos = calcPosFromPathfinding($field, $target);

	my $is_dropped = isTargetDroppedAssisters($target);
	
	#return if ($args->{target_is_aggressive});

	my $drop_string;
	if ($hook eq 'AI::Attack::process') {
		$drop_string = 'Dropping';
	} elsif ($hook eq 'getBestTarget') {
		$drop_string = 'Not picking';
	}

	if (exists $check_avoidAssisters_exists_hash{$mob_id}) {
		foreach my $avoidAssister_mob (@avoidAssisters_mobs) {
			next unless ($avoidAssister_mob->{id} == $mob_id);

			my $count = 0;
			for my $monster (@$monstersList) {
				next if ($monster->{ID} eq $target->{ID});
				next unless ($monster->{nameID} == $mob_id);
				next if (isMobFightingPlayer($monster));
				next if (blockDistance($monster->{pos_to}, $targetPos) > $avoidAssister_mob->{checkRange});
				$count++;
			}

			
			if ($count > $avoidAssister_mob->{maxMobsInRange}) {
				warning "[avoidAssisters] [$hook] $drop_string target $target (ID: $target->{nameID}) because it has too many avoidAssisters (".$count.") in range (".$avoidAssister_mob->{checkRange}.") and the max allowed is ".$avoidAssister_mob->{maxMobsInRange}.".\n" if (!$is_dropped);
				if ($hook eq 'AI::Attack::process') {
					AI::dequeue while (AI::inQueue("attack"))
				}
				$target->{attackFailedAssisters} = 1;
				$args->{return} = 1;
				return;
			}
		}
	}
	
    foreach my $avoid_global_mob (@avoidGlobalAssisters_mobs) {
        my $count = 0;
        foreach my $monster (@{$monstersList}) {
            next if ($monster->{ID} eq $target->{ID});
			next unless ($monster->{nameID} == $avoid_global_mob->{id});
        	next if (isMobFightingPlayer($monster));
            next if (blockDistance($monster->{pos_to}, $targetPos) > $avoid_global_mob->{checkRange});
            $count++;
         }

        if ($count > $avoid_global_mob->{maxMobsInRange}) {
            warning "[avoidAssisters] [$hook] $drop_string target $target (ID: $target->{nameID}) - Too many Global assisters near it (Mob ID $avoid_global_mob->{id} | count $count > $avoid_global_mob->{maxMobsInRange} | range $avoid_global_mob->{checkRange})\n" if (!$is_dropped);
            if ($hook eq 'AI::Attack::process') {
				AI::dequeue while (AI::inQueue("attack"))
			}
            $target->{attackFailedAssisters} = 1;
            $args->{return} = 1;
            return;
        }
    }

	if ($is_dropped) {
		my $myPos = calcPosFromPathfinding($field, $char);
		my $monsterDist = blockDistance($myPos, $targetPos);

		my $max_dist_to_release = ($config{clientSight} - 10); # 10 here because assit range is 9 and add 1 for the proper target pos

		# Release close mobs that are no longer assisted, don't do this to distant mobs becase their assisters might just be out of range
		if ($monsterDist < $max_dist_to_release) {
			warning "[avoidAssisters] [$hook] Releasing nearby ($monsterDist < $max_dist_to_release) target $target from block, it no longer meets blocking criteria.\n";
			$target->{attackFailedAssisters} = 0;
		} else {
			$args->{return} = 1;
		}
	}
}

sub isTargetDroppedAssisters {
	my ($target) = @_;
	return 1 if (exists $target->{attackFailedAssisters} && $target->{attackFailedAssisters} == 1);
	return 0;
}

sub isMobFightingPlayer {
	my ($mob) = @_;
	if (scalar(keys %{$mob->{missedFromPlayer}}) == 0
	 && scalar(keys %{$mob->{dmgFromPlayer}})    == 0
	 && scalar(keys %{$mob->{castOnByPlayer}})   == 0
	 && scalar(keys %{$mob->{missedToPlayer}}) == 0
	 && scalar(keys %{$mob->{dmgToPlayer}})    == 0
	 && scalar(keys %{$mob->{castOnToPlayer}}) == 0
	 #&& !objectIsMovingTowardsPlayer($monster)
	) {
		return 0;
	} else {
		return 1;
	}
}

return 1;
