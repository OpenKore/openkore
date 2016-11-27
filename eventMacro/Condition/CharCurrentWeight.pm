package eventMacro::Condition::CharCurrentWeight;

use strict;

use base 'eventMacro::Conditiontypes::NumericConditionState';

use Globals qw( $char );

sub _hooks {
	['packet/stat_info'];
}

sub _get_val {
    $char->{weight};
}

sub _get_ref_val {
    $char->{weight_max};
}

sub validate_condition_status {
	my ( $self, $event_name, $args ) = @_;
	return if $event_name eq 'packet/stat_info' && $args && ( $args->{type} != 24 && $args->{type} != 25 );
	$self->SUPER::validate_condition_status;
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".CharCurrentWeightLast"} = $char->{weight};
	$new_variables->{".CharCurrentWeightLastPercent"} = ($char->{weight} / $char->{weight_max}) * 100;
	
	return $new_variables;
}

1;
