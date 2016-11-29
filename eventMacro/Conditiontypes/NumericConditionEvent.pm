package eventMacro::Conditiontypes::NumericConditionEvent;

use strict;

use base 'eventMacro::Condition';

use eventMacro::Data;

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	my $validator = $self->{validator} = eventMacro::Validator::NumericComparison->new( $condition_code );
	if (defined $validator->error) {
		$self->{error} = $validator->error;
	} else {
		push (@{ $self->{variables} }, @{$validator->variables});
	}
	$validator->parsed;
}

sub validate_condition {
	my ( $self, $value, $ref_value ) = @_;
	#since it is a event it doesn't make much sense to have the get_val methods
	$self->SUPER::validate_condition( $self->{validator}->validate( $value, $ref_value ) );
}

sub update_validator_var {
	my ( $self, $var_name, $var_value ) = @_;
	$self->{validator}->update_vars($var_name, $var_value);
}

sub condition_type {
	my ($self) = @_;
	EVENT_TYPE;
}

1;
