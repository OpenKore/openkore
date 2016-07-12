package eventMacro::Condition::CurrentSP;

use strict;

use base 'eventMacro::NumericCondition';

use Globals qw( $char );

sub _hooks {
	[ 'packet/sendMapLoaded', 'packet/hp_sp_changed', 'packet/stat_info' ];
}

sub _get_val {
	$char->{sp};
}

sub _get_ref_val {
	$char->{sp_max};
}

sub validate_condition_status {
	my ( $self, $event_name, $args ) = @_;
	return if $event_name eq 'packet/stat_info'     && $args && $args->{type} != 7;
	return if $event_name eq 'packet/hp_sp_changed' && $args && $args->{type} != 7;
	$self->SUPER::validate_condition_status;
}

1;
