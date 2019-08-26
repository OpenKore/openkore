package eventMacro::Condition::Base::NoActorNear;

use strict;
use base 'eventMacro::Condition';

#'packet/map_property3' has to exchanged
sub _hooks {
	['packet_mapChange','packet/map_property3'];
}

sub _parse_syntax {
	my ($self) = @_;
	
	$self->{is_on_stand_by} = 1;
	$self->{change} = 0;
	
	1;
}

sub get_size {
	0;
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		if ($callback_name eq 'packet_mapChange') {
			$self->{is_on_stand_by} = 1;
		} elsif ($callback_name eq 'packet/map_property3') {
			$self->{is_on_stand_by} = 0;
		}
	} elsif ($callback_type eq 'recheck') {
		$self->{is_on_stand_by} = 0;
	}
	
	return $self->SUPER::validate_condition(0) if ($self->{is_on_stand_by} == 1);
	return $self->SUPER::validate_condition( ($self->get_size > 0 ? 0 : 1) );
}

1;
