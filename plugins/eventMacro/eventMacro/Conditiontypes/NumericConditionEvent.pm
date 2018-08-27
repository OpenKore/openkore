package eventMacro::Conditiontypes::NumericConditionEvent;

use strict;

use base 'eventMacro::Conditiontypes::NumericConditionState';
use eventMacro::Data qw( EVENT_TYPE );

sub condition_type {
	my ($self) = @_;
	return EVENT_TYPE;
}

1;
