package eventMacro::Condition::FreeSkillPoints;

use strict;

use base 'eventMacro::NumericCondition';

use Globals qw( $char );

sub _hooks {
	['packet/stat_info'];
}

sub _get_val {
	$char->{points_skill};
}

sub validate_condition_status {
	my ( $self, $event_name, $args ) = @_;
	return if $event_name eq 'packet/stat_info' && $args && $args->{type} != 12;
	$self->SUPER::validate_condition_status;
}

1;
