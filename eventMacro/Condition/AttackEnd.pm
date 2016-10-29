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

sub is_event_only {
	1;
}

#should never be called
sub is_fulfilled {
	0;
}

1;