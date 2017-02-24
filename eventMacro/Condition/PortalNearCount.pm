package eventMacro::Condition::PortalNearCount;

use strict;
use Globals;
use Utils;
use base 'eventMacro::Condition::ActorNearCount';

use Globals;

sub _hooks {
	my $hooks = $self->SUPER::_hooks;
	my @other_hooks = ('add_portal_list','portal_disappeared');
	push(@{$hooks}, @other_hooks);
	return $hooks;
}

sub _get_val {
	return $portalsList->size;
}

1;
