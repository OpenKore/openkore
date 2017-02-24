package eventMacro::Condition::NoNpcNear;

use strict;
use Globals;
use Utils;
use base 'eventMacro::Condition::NoActorNear';

use Globals;

sub _hooks {
	my $hooks = $self->SUPER::_hooks;
	my @other_hooks = ('add_npc_list','npc_disappeared');
	push(@{$hooks}, @other_hooks);
	return $hooks;
}

sub get_size {
	return $npcsList->size;
}

1;
