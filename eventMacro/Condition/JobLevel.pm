package eventMacro::Condition::JobLevel;

use strict;

use base 'eventMacro::NumericCondition';

use Globals qw( $char );

sub _hooks {
	[qw( packet/sendMapLoaded packet/stat_info )];
}

sub _get_val {
    $char->{lv_job};
}

sub validate_condition_status {
	my ( $self, $event_name, $args ) = @_;
	return if $event_name eq 'packet/stat_info' && $args && $args->{type} != 55;
	$self->SUPER::validate_condition_status;
}

1;
