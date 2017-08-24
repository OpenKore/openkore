package eventMacro::Condition::IsInCoordinate;

use strict;
use Globals;
use Utils;

#Use: x1 y1, x2 y2, x3min..x3max y3, x4 y4min..y4max, x5min..x5max y5min..y5max

use base 'eventMacro::Conditiontypes::MultipleValidatorState';

sub _hooks {
	['packet/actor_movement_interrupted','packet/high_jump','packet/character_moves','packet_mapChange','packet/map_property3'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{validators_index} = {};
	$self->{member_index_to_validator_indexes} = [];
	$self->{is_on_stand_by} = 0;
	$self->{fulfilled_coordinate} = undef;
	$self->{fulfilled_member_index} = undef;
	
	my $counter = 0;
	my @members = split(/\s*,\s*/, $condition_code);
	my @coordinates_array;
	foreach my $member (@members) {
		my ($coord_x, $coord_y) = split(/\s+/, $member);
		
		unless (defined $coord_x && defined $coord_y) {
			$self->{error} = "List member '".$member."' must have a slot and an ID defined";
			return 0;
		}
		
		push(@coordinates_array, $coord_x);
		push(@coordinates_array, $coord_y);
		
		push(@{$self->{member_index_to_validator_indexes}}, {x => ($counter*2), y => (($counter*2)+1), index => $counter});
	} continue {
		$counter++;
	}
	
	my $remade_condition_code = join(' ', @coordinates_array);
	
	$self->{number_of_validators} = @coordinates_array;
	
	my $counter;
	for ($counter = 0; $counter < $self->{number_of_validators}; $counter++) {
		$self->{validators_index}{$counter} = 'eventMacro::Validator::NumericComparison';
	}
	
	$self->SUPER::_parse_syntax($remade_condition_code);
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
		
		$self->check_location;
		
	} elsif ($callback_type eq 'hook') {
		
		if ($callback_name eq 'packet/character_moves' || ($callback_name eq 'packet/actor_movement_interrupted' && Actor::get($args->{ID})->isa('Actor::You')) || ($callback_name eq 'packet/high_jump' && Actor::get($args->{ID})->isa('Actor::You'))) {
			return $self->SUPER::validate_condition if (defined $self->{fulfilled_coordinate} &&
			                                            $self->validator_check( @{$self->{member_index_to_validator_indexes}}[$self->{fulfilled_member_index}]->{x}, $char->{pos_to}{x} ) &&
														$self->validator_check( @{$self->{member_index_to_validator_indexes}}[$self->{fulfilled_member_index}]->{y}, $char->{pos_to}{y} ));
			$self->check_location;
			
		} elsif ($callback_name eq 'packet_mapChange') {
			$self->{fulfilled_coordinate} = undef;
			$self->{fulfilled_member_index} = undef;
			$self->{is_on_stand_by} = 1;
			
		} elsif ($callback_name eq 'packet/map_property3') {
			if ($self->{is_on_stand_by} == 1) {
				$self->{is_on_stand_by} = 0;
				$self->check_location;
			}
		}
		
	} elsif ($callback_type eq 'recheck') {
		$self->check_location;
		
	}
	return $self->SUPER::validate_condition( (defined $self->{fulfilled_coordinate} ? 1 : 0) );
}

sub check_location {
	my ( $self ) = @_;
	my $counter;
	$self->{fulfilled_coordinate} = undef;
	$self->{fulfilled_member_index} = undef;
	foreach my $member (@{$self->{member_index_to_validator_indexes}}) {
		next unless ( $self->validator_check( $member->{x}, $char->{pos_to}{x} ) && $self->validator_check( $member->{y}, $char->{pos_to}{y} ) );
		$self->{fulfilled_coordinate} = sprintf("%d %d %s", $char->{pos_to}{x}, $char->{pos_to}{y}, $field->baseName);
		$self->{fulfilled_member_index} = $member->{index};
		last;
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $self->{fulfilled_coordinate};
	$new_variables->{".".$self->{name}."LastMemberIndex"} = $self->{fulfilled_member_index};
	
	return $new_variables;
}

1;
