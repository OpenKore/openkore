#
# checkAggressive
# Author: Henrybk
#
# What this plugin does:
# This plugin extends aggressive monster detection for both the main character
# and slaves. It checks monster AI data from monsters_table.txt and marks a
# monster as aggressive only when it is both clean and moving toward the
# character or one of the character's slaves.
#
# How it works:
# - The plugin reads monster data from %monstersTable.
# - It uses the monster Ai value to determine whether the monster is aggressive.
# - It then checks whether the monster is still clean.
# - It also checks whether the monster is moving toward the character or a
#   slave before returning true.
#
# Hooks handled by this plugin:
# - ai_check_Aggressiveness
# - ai_slave_check_Aggressiveness
#
# How to configure it:
# This plugin does not require custom config.txt entries.
# Just enable it and make sure monsters_table.txt is loaded and includes the Ai
# column.
#
# Examples:
# 1. Use this plugin to improve how OpenKore recognizes aggressive monsters
#    before they have attacked you.
#
# 2. Keep it enabled when using slaves so aggressive monsters moving toward a
#    homunculus, mercenary, or other slave are also detected correctly.
#
# Notes:
# - This plugin depends on monsters_table.txt, not on a separate JSON database.
# - A monster must be aggressive by AI, clean, and moving toward you or a
#   slave before it is treated as aggressive by this plugin.
#
package checkAggressive;

use strict;
use Plugins;
use Globals;
use Log qw(message error debug warning);

Plugins::register('checkAggressive', 'checkAggressive', \&Unload, \&Unload);

my $hooks = Plugins::addHooks(
	['ai_check_Aggressiveness',				\&on_ai_check_Aggressiveness, undef],
	['ai_slave_check_Aggressiveness',		\&on_ai_slave_check_Aggressiveness, undef],
);

use constant {
	PLUGIN_NAME => 'checkAggressive',
};

my %ai_constant = (
	'01' => 0x81, '02' => 0x83, '03' => 0x1089, '04' => 0x3885,
	'05' => 0x2085, '06' => 0, '07' => 0x108B, '08' => 0x7085,
	'09' => 0x3095, '10' => 0x84, '11' => 0x84, '12' => 0x2085,
	'13' => 0x308D, '17' => 0x91, '19' => 0x3095, '20' => 0x3295,
	'21' => 0x3695, '24' => 0xA1, '25' => 0x1, '26' => 0xB695,
	'27' => 0x8084, 'ABR_PASSIVE' => 0x21, 'ABR_OFFENSIVE' => 0xA5
);

sub Unload {
	Plugins::delHooks($hooks);
	message "[".PLUGIN_NAME."] Plugin unloading or reloading.\n", 'success';
}

sub is_monster_ai_aggressive {
	my ($ai_str) = @_;
	$ai_str = uc($ai_str);

	my $mode_value = exists $ai_constant{$ai_str}
		? $ai_constant{$ai_str}
		: $ai_constant{'06'};

	return ($mode_value & 0x4) ? 1 : 0;
}

sub on_ai_check_Aggressiveness {
	my ($self, $args) = @_;
	
	my $monster = $args->{monster};
	my $ID = $monster->{ID};
	
	return unless (exists $monstersTable{$monster->{nameID}});
	return unless (is_monster_ai_aggressive($monstersTable{$monster->{nameID}}{Ai}));
	
	my $found_clean = 0;
	my $found_moving = 0;
	
	$found_clean = 1  if (Misc::checkMonsterCleanness($ID));
	$found_moving = 1 if (Misc::objectIsMovingTowards($monster, $char));
	
	foreach my $slave (values %{$char->{slaves}}) {
		$found_clean = 1  if (Misc::slave_checkMonsterCleanness($slave, $ID));
		$found_moving = 1 if (Misc::objectIsMovingTowards($monster, $slave));
	}
	
	return unless ($found_clean && $found_moving);
	
	debug "[".PLUGIN_NAME."] Monster $monster at ($monster->{pos}{x} $monster->{pos}{y}) | Lvl $monstersTable{$monster->{nameID}}{Level} | is Aggressive, clean, and coming to us\n";
	
	$args->{return} = 1;
	return;
}

sub on_ai_slave_check_Aggressiveness {
	my ($self, $args) = @_;
	
	my $monster = $args->{monster};
	my $ID = $monster->{ID};
	my $slave = $args->{slave};
	
	return unless (exists $monstersTable{$monster->{nameID}});
	return unless (is_monster_ai_aggressive($monstersTable{$monster->{nameID}}{Ai}));
	
	return unless (Misc::slave_checkMonsterCleanness($slave, $ID) || Misc::checkMonsterCleanness($ID));
	
	return unless (Misc::objectIsMovingTowards($monster, $slave) || Misc::objectIsMovingTowards($monster, $char));
	
	debug "[".PLUGIN_NAME."] Monster $monster at ($monster->{pos}{x} $monster->{pos}{y}) | Lvl $monstersTable{$monster->{nameID}}{Level} | is Aggressive towards slave, clean, and coming to him\n";
	
	$args->{return} = 1;
	return;
}

1;
