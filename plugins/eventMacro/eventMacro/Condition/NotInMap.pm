package eventMacro::Condition::NotInMap;

use strict;
use Globals qw( $field );
use base 'eventMacro::Condition::InMap';

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
	}
	
	$self->{lastMap} = $field->baseName;
	
	return $self->eventMacro::Condition::validate_condition( $self->validator_check_opposite($self->{lastMap}) );
}

1;
