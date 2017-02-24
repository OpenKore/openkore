package eventMacro::Condition::MobNearCount;

use strict;
use Globals;
use Utils;
use base 'eventMacro::Condition::ActorNearCount';

use Globals;

sub _hooks {
	my $hooks = $self->SUPER::_hooks;
	my @other_hooks = ('add_monster_list','monster_disappeared');
	push(@{$hooks}, @other_hooks);
	return $hooks;
}

sub _get_val {
	return $monstersList->size;
}

1;
