package eventMacro::Condition::ZenyChanged;

use strict;

use base 'eventMacro::Conditiontypes::NumericConditionEvent';

sub _hooks {
	['zeny_change'];
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		$self->{change} = $args->{change};
		$self->{zeny} = $args->{zeny};
		return $self->SUPER::validate_condition( $self->validator_check( $self->{change}, ($self->{zeny}-$self->{change}) ) );
	} elsif ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"."Change"} = $self->{change};
	$new_variables->{".".$self->{name}."Last"."ZenyAfter"} = $self->{zeny};
	
	return $new_variables;
}

1;