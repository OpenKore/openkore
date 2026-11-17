package eventMacro::Condition::Spirits;

use strict;

use base 'eventMacro::Conditiontypes::NumericConditionState';

use Globals qw($char);

sub _hooks {
	['packet/revolving_entity'];
}

sub _get_val {
	$char->{spirits};
}

sub validate_condition {
	my ($self, $callback_type, $callback_name, $args) = @_;

	$self->update_validator_var($callback_name, $args) if ($callback_type eq 'variable');

	return $self->SUPER::validate_condition($self->validator_check);
}

sub get_new_variable_list {
	my ($self) = @_;

	return {
		".$self->{name}Last" => $char->{spirits}
	};
}

1;
