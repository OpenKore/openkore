package enhancedCasting;

use strict;
use warnings;
use Plugins;
use Globals qw(%config %monsters %monstersTable $char $accountID);
use Log qw(message warning debug);
use Misc qw(checkSelfCondition checkMonsterCondition);
use Utils qw(existsInList);
use Skill;
use Commands;

BEGIN {
	my $folder = $Plugins::current_plugin_folder || 'plugins/enhancedCasting';
	unshift @INC, $folder if -d $folder && !grep { $_ eq $folder } @INC;
}
use EnhancedCasting::ElementTable qw(element_multiplier normalize_element select_best);

Plugins::unload('enhancedCasting') if Plugins::registered('enhancedCasting');
Plugins::register(
	'enhancedCasting',
	'Selects skills and ammunition from monster elemental properties',
	\&on_unload
);

our $evaluating_candidates = 0;
my %pending_cast;
my %damage_per_level;
my %last_choice;
my %skill_change_element = (
	NPC_CHANGEWATER => 'Water',
	NPC_CHANGEGROUND => 'Earth',
	NPC_CHANGEFIRE => 'Fire',
	NPC_CHANGEWIND => 'Wind',
	NPC_CHANGEPOISON => 'Poison',
	NPC_CHANGEHOLY => 'Holy',
	NPC_CHANGEDARKNESS => 'Shadow',
	NPC_CHANGETELEKINESIS => 'Ghost',
);

my $hooks = Plugins::addHooks(
	['checkMonsterCondition', \&on_check_monster],
	['packet_skilluse', \&on_skill_use],
	['packet/skill_use_no_damage', \&on_skill_use_no_damage],
	['attack_start', \&on_attack_start],
);
my $commands = Commands::register([
	'ecinfo',
	'show elemental skill/ammunition selection for a visible monster',
	\&command_elemental,
]);

sub monster_property {
	my ($monster) = @_;
	return unless $monster && defined $monster->{nameID};
	my $mob = $monstersTable{$monster->{nameID}};
	return unless $mob;
	my $element = normalize_element($mob->{Element});
	my $level = $mob->{ElementLevel} || 1;
	if ($monster->{element}) {
		$element = normalize_element($monster->{element}) || $element;
	}
	if ($monster->statusActive('BODYSTATE_STONECURSE')
		|| $monster->statusActive('BODYSTATE_STONECURSE_ING')) {
		($element, $level) = ('Earth', 1);
	} elsif ($monster->statusActive('BODYSTATE_FREEZING')) {
		($element, $level) = ('Water', 1);
	}
	return ($element, $level, $mob);
}

sub slot_is_available {
	my ($slot, $monster) = @_;
	my $block = "attackSkillSlot_$slot";
	return 0 unless $config{"${block}_target_elementalBest"};
	return 0 unless normalize_element($config{"${block}_elementalElement"});
	my $skill = Skill->new(auto => $config{$block});
	return 0 unless $skill && $char && $char->getSkillLevel($skill) > 0;
	return 0 unless checkSelfCondition($block);
	return 0 if $config{"${block}_monsters"}
		&& !existsInList($config{"${block}_monsters"}, $monster->{name})
		&& !existsInList($config{"${block}_monsters"}, $monster->{nameID});
	return 0 if $config{"${block}_notMonsters"}
		&& (existsInList($config{"${block}_notMonsters"}, $monster->{name})
			|| existsInList($config{"${block}_notMonsters"}, $monster->{nameID}));
	local $evaluating_candidates = 1;
	return checkMonsterCondition("${block}_target", $monster) ? 1 : 0;
}

sub skill_candidates {
	my ($monster) = @_;
	my @candidates;
	for (my $slot = 0; exists $config{"attackSkillSlot_$slot"}; $slot++) {
		next unless slot_is_available($slot, $monster);
		push @candidates, {
			slot => $slot,
			name => $config{"attackSkillSlot_$slot"},
			element => $config{"attackSkillSlot_${slot}_elementalElement"},
			priority => 0 + ($config{"attackSkillSlot_${slot}_elementalPriority"} || 0),
			order => $slot,
		};
	}
	return \@candidates;
}

sub best_skill {
	my ($monster) = @_;
	my ($element, $level) = monster_property($monster);
	return unless $element;
	return select_best($element, $level, skill_candidates($monster));
}

sub remaining_hp {
	my ($monster, $mob) = @_;
	return $monster->{hp} if defined $monster->{hp} && $monster->{hp} > 0;
	my $base = $mob->{Hp} // $mob->{HP};
	return unless defined $base && $base =~ /^\d+$/;
	return $base + ($monster->{deltaHp} || 0);
}

sub apply_smart_level {
	my ($choice, $monster, $mob) = @_;
	my $slot = $choice->{slot};
	my $block = "attackSkillSlot_$slot";
	return unless lc($config{"${block}_elementalLevelMode"} || '') eq 'linear';
	my $skill = Skill->new(auto => $config{$block});
	my $max = $char->getSkillLevel($skill);
	return unless $max > 0;
	my $remaining = remaining_hp($monster, $mob);
	my $sample = $damage_per_level{$skill->getIDN}{$monster->{nameID}};
	my $level = $max;
	if (defined $remaining && $remaining > 0 && $sample && $sample > 0) {
		my $safe = $sample * 0.85;
		$level = int(($remaining + $safe - 1) / $safe);
		$level = 1 if $level < 1;
		$level = $max if $level > $max;
	}
	$config{"${block}_lvl"} = $level;
	$pending_cast{$monster->{ID}} = {
		skill_id => $skill->getIDN,
		level => $level,
		monster_id => $monster->{nameID},
	};
}

sub on_check_monster {
	my (undef, $args) = @_;
	return if $evaluating_candidates;
	my $prefix = $args->{prefix} || '';
	return unless $config{"${prefix}_elementalBest"};
	my $monster = $args->{monster};
	my $choice = best_skill($monster);
	if (!$choice) {
		warning "[enhancedCasting] No usable elemental skill is configured for $monster.\n";
		$args->{return} = 0;
		return;
	}
	(my $block = $prefix) =~ s/_target$//;
	if ($block ne "attackSkillSlot_$choice->{slot}") {
		$args->{return} = 0;
		return;
	}
	my ($element, $level, $mob) = monster_property($monster);
	apply_smart_level($choice, $monster, $mob);
	my $key = join(':', $monster->{ID}, $choice->{slot}, $element, $level);
	if (($last_choice{$monster->{ID}} || '') ne $key) {
		message sprintf(
			"[enhancedCasting] %s%s -> %s (%s, %.0f%% modifier).\n",
			$element, $level, $choice->{name}, $choice->{element},
			100 * $choice->{multiplier}
		), 'skill';
		$last_choice{$monster->{ID}} = $key;
	}
}

sub on_skill_use {
	my (undef, $args) = @_;
	return unless $char && ($args->{sourceID} || '') eq ($accountID || '');
	return unless ($args->{damage} || 0) > 0;
	my $pending = delete $pending_cast{$args->{targetID}} or return;
	return unless ($args->{skillID} || 0) == $pending->{skill_id};
	my $sample = $args->{damage} / $pending->{level};
	my $old = $damage_per_level{$pending->{skill_id}}{$pending->{monster_id}};
	$damage_per_level{$pending->{skill_id}}{$pending->{monster_id}} = $sample
		if !$old || $sample < $old;
}

sub on_skill_use_no_damage {
	my (undef, $args) = @_;
	my $element = $skill_change_element{$args->{skillID}} or return;
	return unless defined $args->{sourceID} && defined $args->{targetID};
	return unless $args->{sourceID} eq $args->{targetID};
	my $monster = $monsters{$args->{targetID}} or return;
	$monster->{element} = $element;
	delete $last_choice{$monster->{ID}};
	debug "[enhancedCasting] $monster changed property to $element.\n", 'skill';
}

sub ammo_candidates {
	my @candidates;
	return \@candidates unless $char && $char->inventory;
	for (my $i = 0; exists $config{"elementalAmmo_$i"}; $i++) {
		my $item = $char->inventory->getByName($config{"elementalAmmo_$i"});
		next unless $item;
		my $element = normalize_element($config{"elementalAmmo_${i}_element"});
		next unless $element;
		push @candidates, {
			item => $item,
			name => $config{"elementalAmmo_$i"},
			element => $element,
			priority => 0 + ($config{"elementalAmmo_${i}_priority"} || 0),
			order => $i,
		};
	}
	return \@candidates;
}

sub equip_best_ammo {
	my ($monster) = @_;
	my ($element, $level) = monster_property($monster);
	return unless $element;
	my $choice = select_best($element, $level, ammo_candidates());
	return unless $choice && $choice->{item};
	return if $choice->{item}{equipped};
	message sprintf(
		"[enhancedCasting] Equipping %s against %s%s (%.0f%% modifier).\n",
		$choice->{name}, $element, $level, 100 * $choice->{multiplier}
	), 'equip';
	$choice->{item}->equip();
}

sub on_attack_start {
	my (undef, $args) = @_;
	my $monster = $monsters{$args->{ID}} or return;
	equip_best_ammo($monster);
}

sub command_elemental {
	my (undef, $arguments) = @_;
	my ($bin_id) = ($arguments || '') =~ /(\d+)/;
	my ($monster) = grep {
		!defined $bin_id || (defined $_->{binID} && $_->{binID} == $bin_id)
	} values %monsters;
	if (!$monster) {
		warning "Usage: ecinfo <monster index>\n";
		return;
	}
	my ($element, $level, $mob) = monster_property($monster);
	my $choice = best_skill($monster);
	message sprintf(
		"%s: Lv %s, HP %s, %s%s, %s, %s. Selected skill: %s.\n",
		$monster->{name}, ($mob->{Level} // '?'), ($mob->{Hp} // $mob->{HP} // '?'),
		($element // '?'), ($level // ''), ($mob->{Race} // '?'), ($mob->{Size} // '?'),
		($choice ? "$choice->{name} [$choice->{element}, " . int(100 * $choice->{multiplier}) . '%]' : 'none')
	), 'info';
}

sub on_unload {
	Plugins::delHooks($hooks) if $hooks;
	Commands::unregister($commands) if $commands;
}

1;
