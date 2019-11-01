package eventMacro::Condition::Base::ActorNearCount;

use strict;

use base 'eventMacro::Conditiontypes::NumericConditionState';

#'packet/map_property3' has to exchanged
sub _hooks {
	['packet_mapChange','packet/map_property3'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{is_on_stand_by} = 1;
	$self->{change} = 0;
	$self->{fulfilled_size} = undef;
	
	$self->SUPER::_parse_syntax($condition_code);
}

sub _get_val {
    0;
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		if ($callback_name eq 'packet_mapChange') {
			$self->{is_on_stand_by} = 1;
		} elsif ($callback_name eq 'packet/map_property3') {
			$self->{is_on_stand_by} = 0;
		}
	} elsif ($callback_type eq 'recheck') {
		$self->{is_on_stand_by} = 0;
	} elsif ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
	}
	
	return $self->SUPER::validate_condition(0) if ($self->{is_on_stand_by} == 1);
	
	if ($self->validator_check) {
		$self->{fulfilled_size} = $self->_get_val;
		return $self->SUPER::validate_condition(1);
	} else {
		return $self->SUPER::validate_condition(0);
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $self->{fulfilled_size};
	
	return $new_variables;
}

1;
