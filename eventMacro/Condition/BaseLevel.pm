package eventMacro::Condition::BaseLevel;

use strict;

use base 'eventMacro::Conditiontypes::NumericConditionState';

use Globals qw( $char );

sub _hooks {
	[qw( packet/sendMapLoaded packet/stat_info )];
}

sub _get_val {
    $char->{lv};
}

sub validate_condition_status {
	my ( $self, $event_name, $args ) = @_;
	return if $event_name eq 'packet/stat_info' && $args && $args->{type} != 11;
	$self->SUPER::validate_condition_status;
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".BaseLevelLast"} = $char->{lv};
	
	return $new_variables;
}

1;
