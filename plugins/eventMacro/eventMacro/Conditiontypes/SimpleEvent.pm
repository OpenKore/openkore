package eventMacro::Conditiontypes::SimpleEvent;

use strict;

use base 'eventMacro::Condition';

use eventMacro::Data;

sub validate_condition  {
	my ($self) = @_;
	return $self->SUPER::validate_condition( 1 );
}

sub condition_type {
	my ($self) = @_;
	EVENT_TYPE;
}

1;
