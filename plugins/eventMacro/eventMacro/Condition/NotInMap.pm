package eventMacro::Condition::NotInMap;

use strict;
use Globals qw( $field );
use base 'eventMacro::Condition::InMap';

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	if ($condition_code =~ /,/) {
		$self->{error} = "You can't use comma separated values on this Condition";
		return 0;
	}
	
	$self->SUPER::_parse_syntax( $condition_code );
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
	}
	
	unless ( defined $field ) {
		$self->SUPER::validate_condition( 0 );
	}
	
	$self->{lastMap} = $field->baseName;
	
	return $self->eventMacro::Condition::validate_condition( $self->validator_check_opposite($self->{lastMap}) );
}

1;
