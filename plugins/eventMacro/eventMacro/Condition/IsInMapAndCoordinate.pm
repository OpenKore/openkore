package eventMacro::Condition::IsInMapAndCoordinate;

use strict;
use Globals qw( $char $field );

use eventMacro::Utilities qw( find_variable );

use base 'eventMacro::Condition';

#Use: map1 x1 y1, x2 y2, map2 x3min..x3max y3, x4 y4min..y4max, map3 x5min..x5max y5min..y5max, map4

sub _hooks {
	['packet/actor_movement_interrupted','packet/high_jump','packet/character_moves','packet_mapChange','packet/map_property3'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{is_on_stand_by} = 0;
	
	$self->{fulfilled_coordinate} = undef;
	$self->{fulfilled_member_index} = undef;
	
	$self->{var_to_member_index_coord_x} = {};
	$self->{var_to_member_index_coord_y} = {};
	$self->{var_to_member_index_map} = {};
	
	$self->{x_validators} = {};
	$self->{y_validators} = {};
	$self->{map_validators} = {};
	
	my $var_exists_hash = {};
	
	my $member_index = 0;
	foreach my $member (split(/\s*,\s*/, $condition_code)) {
		my ($map, $coord_x, $coord_y);
		my @parts = split(/\s+/, $member);
		
		my $has_coords = 0;
		my $has_map = 0;
		
		if (@parts == 0 || @parts > 3) {
			$self->{error} = "List member '".$member."' must have a map and/or a coordinate";
			return 0;
			
		} elsif (@parts == 1) {
			$has_map = 1;
			$map = $parts[0];
			
		} elsif (@parts == 2) {
			$has_coords = 1;
			$coord_x = $parts[0];
			$coord_y = $parts[1];
			
		} elsif (@parts == 3) {
			$has_map = 1;
			$has_coords = 1;
			$map = $parts[0];
			$coord_x = $parts[1];
			$coord_y = $parts[2];
		}
		
		if ($has_coords) {
			my $x_validator = eventMacro::Validator::NumericComparison->new( $coord_x );
			
			if (defined $x_validator->error) {
				$self->{error} = $x_validator->error;
				return 0;
			} else {
				my @vars = @{$x_validator->variables};
				foreach my $var (@vars) {
					push ( @{ $self->{var_to_member_index_coord_x}{$var->{display_name}} }, $member_index );
					push ( @{ $self->{variables} }, $var ) unless (exists $var_exists_hash->{$var->{display_name}});
					$var_exists_hash->{$var->{display_name}} = undef;
				}
			}
			
			my $y_validator = eventMacro::Validator::NumericComparison->new( $coord_y );
			
			if (defined $y_validator->error) {
				$self->{error} = $y_validator->error;
				return 0;
			} else {
				my @vars = @{$y_validator->variables};
				foreach my $var (@vars) {
					push ( @{ $self->{var_to_member_index_coord_y}{$var->{display_name}} }, $member_index );
					push ( @{ $self->{variables} }, $var ) unless (exists $var_exists_hash->{$var->{display_name}});
					$var_exists_hash->{$var->{display_name}} = undef;
				}
			}
			
			$self->{x_validators}{$member_index} = $x_validator;
			$self->{y_validators}{$member_index} = $y_validator;
		}
		
		if ($has_map) {
			if (my $var = find_variable($map)) {
				if ($var =~ /^\./) {
					$self->{error} = "System variables should not be used in automacros (The ones starting with a dot '.')";
					$self->{parsed} = 0;
					return;
				}
				push ( @{ $self->{var_to_member_index_map}{$var->{display_name}} }, $member_index );
				push ( @{ $self->{variables} }, $var ) unless (exists $var_exists_hash->{$var->{display_name}});
				$var_exists_hash->{$var->{display_name}} = undef;
				$self->{map_validators}{$member_index} = undef;
			} else {
				$self->{map_validators}{$member_index} = $map;
			}
		}
		
	} continue {
		$member_index++;
	}
	
	$self->{index_of_last_validator} = $member_index-1;
	
	return 1;
}

sub update_validator_var {
	my ( $self, $var_name, $var_value ) = @_;
	
	my %members_index_changed;
	
	foreach my $member_index (@{$self->{var_to_member_index_coord_x}{$var_name}}) {
		$self->{x_validators}{$member_index}->update_vars($var_name, $var_value);
		$members_index_changed{$member_index} = undef;
	}
	
	foreach my $member_index (@{$self->{var_to_member_index_coord_y}{$var_name}}) {
		$self->{y_validators}{$member_index}->update_vars($var_name, $var_value);
		$members_index_changed{$member_index} = undef;
	}
	
	foreach my $member_index (@{$self->{var_to_member_index_map}{$var_name}}) {
		$self->{map_validators}{$member_index} = $var_value;
		$members_index_changed{$member_index} = undef;
	}
	
	if (!defined $self->{fulfilled_member_index} || exists $members_index_changed{$self->{fulfilled_member_index}}) {
		$self->check_location;
	}
}

sub validator_x_check {
	my ( $self, $validator_index, $check ) = @_;
	return $self->{x_validators}{$validator_index}->validate($check);
}

sub validator_y_check {
	my ( $self, $validator_index, $check ) = @_;
	return $self->{y_validators}{$validator_index}->validate($check);
}

sub validator_map_check {
	my ( $self, $validator_index, $check ) = @_;
	return ($self->{map_validators}{$validator_index} eq $check ? 1 : 0);
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
		
	} elsif ($callback_type eq 'hook') {
		
		if ($callback_name eq 'packet/character_moves' || ($callback_name eq 'packet/actor_movement_interrupted' && Actor::get($args->{ID})->isa('Actor::You')) || ($callback_name eq 'packet/high_jump' && Actor::get($args->{ID})->isa('Actor::You'))) {
			return $self->SUPER::validate_condition if (
				defined $self->{fulfilled_coordinate} &&
				!exists $self->{x_validators}{$self->{fulfilled_member_index}}
			);
			return $self->SUPER::validate_condition if (
				defined $self->{fulfilled_coordinate} &&
			    $self->validator_x_check( $self->{fulfilled_member_index}, $char->{pos_to}{x} ) &&
				$self->validator_y_check( $self->{fulfilled_member_index}, $char->{pos_to}{y} )
			);
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
		$self->{is_on_stand_by} = 0;
		$self->check_location;
	}
	
	return $self->SUPER::validate_condition( (defined $self->{fulfilled_coordinate} ? 1 : 0) );
}

sub check_location {
	my ( $self ) = @_;
	my $counter;
	$self->{fulfilled_coordinate} = undef;
	$self->{fulfilled_member_index} = undef;
	
	foreach my $validator_index (0..$self->{index_of_last_validator}) {
		if (exists $self->{map_validators}{$validator_index}) {
			next unless ( $self->validator_map_check( $validator_index, $field->baseName ) );
		}
		
		if (exists $self->{x_validators}{$validator_index}) {
			next unless ( $self->validator_x_check( $validator_index, $char->{pos_to}{x} ) );
			next unless ( $self->validator_y_check( $validator_index, $char->{pos_to}{y} ) );
		}
		
		$self->{fulfilled_coordinate} = sprintf("%d %d %s", $char->{pos_to}{x}, $char->{pos_to}{y}, $field->baseName);
		$self->{fulfilled_member_index} = $validator_index;
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
