package eventMacro::Conditiontypes::ListConditionState;

use strict;

use base 'eventMacro::Condition';

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	my $validator = $self->{validator} = eventMacro::Validator::ListMemberCheck->new( $condition_code );
	if (defined $validator->error) {
		$self->{error} = $validator->error;
	} else {
		push (@{ $self->{variables} }, @{$validator->variables});
	}
}

sub validator_check {
	my ( $self, $possible_member ) = @_;
	return $self->{validator}->validate($possible_member);
}

sub validator_check_opposite {
	my ( $self, $possible_member ) = @_;
	return $self->{validator}->validate_opposite($possible_member);
}

sub update_validator_var {
	my ( $self, $var_name, $var_value ) = @_;
	$self->{validator}->update_vars($var_name, $var_value);
}

1;
