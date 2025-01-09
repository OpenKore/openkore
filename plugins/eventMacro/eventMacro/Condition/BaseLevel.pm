package eventMacro::Condition::BaseLevel;

use strict;

use base 'eventMacro::Conditiontypes::NumericConditionState';

use Globals qw( $char );

sub _hooks {
	['base_level_changed','Network::Receive::map_changed','in_game','packet/stat_info'];
}

sub _get_val {
    $char->{lv};
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
	}
	return $self->SUPER::validate_condition( $self->validator_check );
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $char->{lv};
	
	return $new_variables;
}

1;
