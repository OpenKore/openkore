package eventMacro::Condition::AttackStart;

use strict;
use Globals;

use base 'eventMacro::Conditiontypes::ListCondition';

sub _hooks {
	['attack_start'];
}

sub validate_condition_status {
	my ( $self, $event_name, $args ) = @_;
	
	$self->SUPER::validate_condition_status(lc($monsters{$args->{ID}}{'name'}));
}

sub condition_type {
	EVENT_TYPE;
}

1;