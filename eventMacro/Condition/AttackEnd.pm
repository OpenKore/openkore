package eventMacro::Condition::AttackEnd;

use strict;
use Globals;

use base 'eventMacro::Conditiontypes::ListCondition';

sub _hooks {
	['attack_end'];
}

sub validate_condition_status {
	my ( $self, $event_name, $args ) = @_;
	
	$self->SUPER::validate_condition_status(lc($monsters_old{$args->{ID}}{'name'}));
}

sub condition_type {
	EVENT_TYPE;
}

1;