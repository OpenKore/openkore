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
	my $result = $self->{validator}->validate($possible_member);
	return $result if ($self->is_event_only);
	$self->{is_Fulfilled} = $result;
}

1;
