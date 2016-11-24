package eventMacro::Conditiontypes::RegexCondition;

use strict;

use base 'eventMacro::Condition';

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	my $validator = $self->{validator} = eventMacro::Validator::RegexCheck->new( $condition_code );
	push @{ $self->{variables} }, $validator->variables;
	$validator->parsed;
}

sub validate_condition_status {
	my ( $self, $possible_member ) = @_;
	$self->SUPER::validate_condition_status( $self->{validator}->validate($possible_member) );
}

1;
