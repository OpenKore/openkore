package eventMacro::Condition::Eval;

use strict;
use base 'eventMacro::Condition';

sub _hooks {
	['AI_pre'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;

	# Set the condition code
	$self->{condition_code} = $condition_code;

	# Set the condition state to false by default
	$self->{condition_state} = 0;
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;

	# Update the condition state
	if ( $callback_type eq 'hook' && $callback_name eq 'AI_pre' ) {
		$self->{condition_state} = eval $self->{condition_code};
	}

	# Return the condition state
	return $self->SUPER::validate_condition( $self->{condition_state} );
}

1;
