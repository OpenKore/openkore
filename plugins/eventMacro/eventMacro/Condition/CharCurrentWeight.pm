package eventMacro::Condition::CharCurrentWeight;

use strict;

use base 'eventMacro::Conditiontypes::NumericConditionState';

use Globals qw( $char );

sub _hooks {
	['inventory_clear','inventory_ready','packet/stat_info'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{is_on_stand_by} = 1;
	
	$self->SUPER::_parse_syntax($condition_code);
}

sub _get_val {
    $char->{weight};
}

sub _get_ref_val {
    $char->{weight_max};
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_name eq 'inventory_clear') {
		$self->{is_on_stand_by} = 1;
	} elsif ($callback_name eq 'inventory_ready') {
		$self->{is_on_stand_by} = 0;
	}
	
	if ($callback_type eq 'recheck') {
		$self->{is_on_stand_by} = 0;
	}
	
	if ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
	}
	
	if ($self->{is_on_stand_by} == 1) {
		return $self->SUPER::validate_condition(0);
	}
	
	return $self->SUPER::validate_condition( $self->validator_check );
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $char->{weight};
	$new_variables->{".".$self->{name}."Last"."Percent"} = ($char->{weight} / $char->{weight_max}) * 100;
	
	return $new_variables;
}

1;
