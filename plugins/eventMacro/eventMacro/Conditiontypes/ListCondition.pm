package eventMacro::Conditiontypes::ListCondition;

use strict;

use base 'eventMacro::Condition';

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	my $validator = $self->{validator} = eventMacro::Validator::ListMemberCheck->new( $condition_code );
	return 1;
}

sub validate_condition_status {
	my ( $self, $possible_member ) = @_;
	$self->SUPER::validate_condition_status( $self->{validator}->validate($possible_member) );
}

1;
