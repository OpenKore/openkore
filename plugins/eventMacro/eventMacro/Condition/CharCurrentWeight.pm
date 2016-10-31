package eventMacro::Condition::CharCurrentWeight;

use strict;

use base 'eventMacro::Conditiontypes::NumericCondition';

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

1;
