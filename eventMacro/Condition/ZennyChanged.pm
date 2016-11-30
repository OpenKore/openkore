package eventMacro::Condition::ZennyChanged;

use strict;
use Utils;

use base 'eventMacro::Conditiontypes::NumericConditionEvent';

use Globals qw( $char );

sub _hooks {
	['zeny_change'];
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		$self->{change} = $args->{change};
		$self->{zeny} = $args->{zeny};
		$self->SUPER::validate_condition( $self->{change}, ($self->{zeny}-$self->{change}) );
	} elsif ($callback_type eq 'variable') {
		$self->SUPER::update_validator_var($callback_name, $args);
		return 0;
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"."Change"} = $self->{change};
	$new_variables->{".".$self->{name}."Last"."ZennyAfter"} = $self->{zeny};
	
	return $new_variables;
}

1;