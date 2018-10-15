package eventMacro::Conditiontypes::RegexConditionEvent;

use strict;

use base 'eventMacro::Conditiontypes::RegexConditionState';
use eventMacro::Data qw( EVENT_TYPE );

sub condition_type {
	EVENT_TYPE;
}

1;
