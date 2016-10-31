package eventMacro::Condition::MaxSP;

use strict;

use base 'eventMacro::Conditiontypes::NumericCondition';

use Globals qw( $char );

sub _hooks {
	[ 'packet/sendMapLoaded', 'packet/stat_info' ];
}

sub _get_val {
	$char->{sp_max};
}

sub validate_condition_status {
	my ( $self, $event_name, $args ) = @_;
	return if $event_name eq 'packet/stat_info' && $args && $args->{type} != 8;
	$self->SUPER::validate_condition_status;
}

1;
