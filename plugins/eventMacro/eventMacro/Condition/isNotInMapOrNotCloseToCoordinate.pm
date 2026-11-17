package eventMacro::Condition::isNotInMapOrNotCloseToCoordinate;

use strict;
use Globals qw( $char $field );
use Utils;

use base 'eventMacro::Condition';

sub _hooks {
	['packet/actor_movement_interrupted','packet/high_jump','packet/character_moves','packet_mapChange','packet/map_property3'];
}


sub _parse_syntax {
	my ( $self, $condition_code ) = @_;

	if ($condition_code =~ /^([\w-]+)\s+(\d+)\s+(\d+)\s+(\d+)$/i) {
		$self->{map} = $1;
		$self->{coord_x} = $2;
		$self->{coord_y} = $3;
		$self->{coord_dist} = $4;
	} else {
		$self->{error} = "Invalid condition sintax";
		return 0;
	}
	
	return 1;
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	$self->SUPER::validate_condition( 0 ) unless ( defined $field && defined $char );

	if ($callback_type eq 'hook' && ($callback_name eq 'packet_mapChange')) {
		return $self->SUPER::validate_condition( 0 );
	}
	
	if ($callback_type eq 'hook' || $callback_type eq 'recheck') {
		return $self->SUPER::validate_condition( 1 ) if ($field->baseName ne $self->{map});
		return $self->SUPER::validate_condition( 1 ) if (blockDistance({x=>$self->{coord_x}, y=>$self->{coord_y}}, $char->{pos_to}) > $self->{coord_dist});
		return $self->SUPER::validate_condition( 0 );
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"."Map"} = $self->{map};
	$new_variables->{".".$self->{name}."Last"."X"} = $self->{coord_x};
	$new_variables->{".".$self->{name}."Last"."Y"} = $self->{coord_y};
	$new_variables->{".".$self->{name}."Last"."Dist"} = $self->{coord_dist};
	
	return $new_variables;
}

1;
