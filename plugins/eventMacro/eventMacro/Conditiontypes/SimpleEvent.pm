package eventMacro::Conditiontypes::SimpleEvent;

use strict;

use base 'eventMacro::Condition';

use eventMacro::Data qw( EVENT_TYPE );

sub validate_condition {
	my ($self) = @_;
	return $self->SUPER::validate_condition( 1 );
}

sub condition_type {
	EVENT_TYPE;
}

1;
