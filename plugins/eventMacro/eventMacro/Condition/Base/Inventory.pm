package eventMacro::Condition::Base::Inventory;

use strict;

use base 'eventMacro::Conditiontypes::NumericConditionState';

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{is_on_stand_by} = 1;
	
	$self->SUPER::_parse_syntax($condition_code);
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
	}
	
	if ($self->{is_on_stand_by} == 1) {
		return $self->SUPER::validate_condition(0);
	} else {
		return $self->SUPER::validate_condition( $self->validator_check );
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $self->{wanted};
	$new_variables->{".".$self->{name}."LastAmount"} = $self->_get_val;
	
	return $new_variables;
}

1;
