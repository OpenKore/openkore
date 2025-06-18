package eventMacro::Condition::EvalHook;

use strict;
use base 'eventMacro::Condition';

use eventMacro::Data      qw( $eventMacro EVENT_TYPE );
use eventMacro::Utilities qw( find_variable );

sub _hooks {
	[];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;

	# Parse the hook names and hook code
	if ( $condition_code !~ /^\s*([\w:]+(?:\s*,\s*[\w:]+)*)\s*:\s*(\{.*\}|\S.*)/s ) {
		$self->{error} = "Invalid syntax for EvalHook condition. Expected format: <hook1>,<hook2> : <hook_code>";
		return 0;
	}

	# Set the condition state to false by default
	$self->{condition_state} = 0;

	# Set the condition code
	$self->{condition_code} = $2;

	# Trim the condition hooks
	( my $hook_name = $1 ) =~ s/^\s+|\s+$//g;

	# Parse the condition hooks
	foreach my $member ( split( /\s*,\s*/, $hook_name ) ) {

		# Check the hook name
		if ( find_variable( $member ) ) {
			$self->{error} = "In this condition no variables are accepted";
			return 0;
		}

		# Push the hook name into the hooks array
		push( @{ $self->{hooks} }, $member );
	}
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;

	# Update the condition state
	if ( $callback_type eq 'hook' ) {
		$self->{condition_state} = eval $self->{condition_code};
	}

	# Return the condition state
	return $self->SUPER::validate_condition( $self->{condition_state} );
}

1;
