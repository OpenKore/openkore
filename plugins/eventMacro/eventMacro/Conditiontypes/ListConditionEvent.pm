package eventMacro::Conditiontypes::ListConditionEvent;

use strict;

use base 'eventMacro::Conditiontypes::ListConditionState';
use eventMacro::Data qw( EVENT_TYPE );

sub condition_type {
	my ($self) = @_;
	return EVENT_TYPE;
}

1;
