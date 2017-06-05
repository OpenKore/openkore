package eventMacro::ListCondition;

use strict;

use base 'eventMacro::Condition';

#should be used only for event_only conditions

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	my $validator = $self->{validator} = eventMacro::Validator::ListMemberCheck->new( $condition_code );
	return 1;
}

sub validate_condition_status {
	my ( $self, $possible_member ) = @_;
	return $self->{validator}->validate($possible_member);
}

1;
