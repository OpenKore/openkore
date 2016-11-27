package eventMacro::Condition::FreeSkillPoints;

use strict;

use base 'eventMacro::Conditiontypes::NumericConditionState';

use Globals qw( $char );

sub _hooks {
	['packet/stat_info'];
}

sub _get_val {
	$char->{points_skill};
}

sub validate_condition {
	my ( $self, $event_name, $args ) = @_;
	return if $event_name eq 'packet/stat_info' && $args && $args->{type} != 12;
	$self->SUPER::validate_condition;
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".FreeSkillPointsLast"} = $char->{points_skill};
	
	return $new_variables;
}

1;
