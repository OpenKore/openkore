package eventMacro::Conditiontypes::MultipleValidatorEvent;

use strict;

use base 'eventMacro::Condition';

use eventMacro::Data;

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	my $validator = $self->{validator} = eventMacro::Validator::RegexCheck->new( $condition_code );
	if (defined $validator->error) {
		$self->{error} = $validator->error;
	} else {
		push (@{ $self->{variables} }, @{$validator->variables});
	}
	$validator->parsed;
}

sub validate_condition {
	my ( $self, $possible_member ) = @_;
	$self->SUPER::validate_condition( $self->{validator}->validate($possible_member) );
}

sub update_validator_var {
	my ( $self, $var_name, $var_value ) = @_;
	$self->{validator}->update_vars($var_name, $var_value);
	$self->SUPER::validate_condition( 0 );
}

sub condition_type {
	my ($self) = @_;
	EVENT_TYPE;
}

1;
