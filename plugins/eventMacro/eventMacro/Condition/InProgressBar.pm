package eventMacro::Condition::InProgressBar;

use strict;

use base 'eventMacro::Condition';

#InProgressBar 1 -> Only triggers during a Progress Bar
#InProgressBar 0 -> Only triggers while not in a Progress Bar

use Globals qw( $char $field );

sub _hooks {
	['packet/progress_bar','packet/progress_bar_stop','packet_mapChange','packet/map_property3'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{wanted_progress_bar} = undef;
	
	if ($condition_code =~ /^(0|1)$/) {
		$self->{wanted_progress_bar} = $1;
	} else {
		$self->{error} = "Value '".$condition_code."' Should be '0' or '1'";
		return 0;
	}
	
	return 1;
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	return $self->SUPER::validate_condition(0) if ($callback_name eq 'packet_mapChange');
	
	$self->{lastMap} = $field->baseName;
	
	
	return $self->SUPER::validate_condition( (((exists $char->{progress_bar} && $char->{progress_bar} == 1) == $self->{wanted_progress_bar}) ? 1 : 0) );
}

1;
