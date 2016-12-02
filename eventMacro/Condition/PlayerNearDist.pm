package eventMacro::Condition::PlayerNearDist;

use strict;
use Globals;
use Utils;

use base 'eventMacro::Conditiontypes::MultipleValidatorState';

sub _hooks {
	['add_player_list','player_disappeared'];
}

sub _dynamic_hooks {
	['packet/actor_movement_interrupted','packet/high_jump','packet/character_moves','packet_mapChange','player_moved'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{validators_index} = {
		0 => 'eventMacro::Validator::RegexCheck',
		1 => 'eventMacro::Validator::NumericComparison'
	};
	
	$self->{number_of_possible_fulfill_actors} = 0;
	$self->{possible_fulfill_actors} = {};
	$self->{fulfilled_actor} = undef;
	
	$self->SUPER::_parse_syntax($condition_code);
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'variable') {
		$self->SUPER::update_validator_var($callback_name, $args);
		
		foreach my $validator_index ( @{ $self->{var_to_validator_index}{$callback_name} } ) {
			if ($validator_index == 0) {
				$self->recheck_all_actor_names;
			} elsif ($validator_index == 1) {
				$self->search_for_dist_match_on_possible_fulfill_actors_list;
			}
		}
		
	} elsif ($callback_type eq 'hook') {
		
		if ($callback_name eq 'add_player_list' && $self->SUPER::validate_condition(0,$args->{name})) {
			
			if ($self->{number_of_possible_fulfill_actors} == 0) {
				$self->add_or_remove_dynamic_hooks(1);
			}
			
			$self->{number_of_possible_fulfill_actors}++;
			$self->{possible_fulfill_actors}{$args->{binID}} = $args;
			
			if ( !$self->{is_Fulfilled} && $self->SUPER::validate_condition( 1, distance($char->{pos_to}, $args->{pos_to}) ) ) {
				$self->{fulfilled_actor} = $args;
				$self->{is_Fulfilled} = 1;
			}

		} elsif ( $callback_name eq 'player_disappeared' && exists($self->{possible_fulfill_actors}{$args->{player}->{binID}}) ) {
		
			$self->{number_of_possible_fulfill_actors}--;
			delete $self->{possible_fulfill_actors}{$args->{player}->{binID}};
			
			if ($self->{is_Fulfilled} && $args->{player}->{binID} == $self->{fulfilled_actor}->{binID}) {
				$self->search_for_dist_match_on_possible_fulfill_actors_list;
			}
			
			if ($self->{number_of_possible_fulfill_actors} == 0) {
				$self->add_or_remove_dynamic_hooks(0);
			}
			
		} elsif ( $callback_name eq 'player_moved' || ($callback_name eq 'packet/actor_movement_interrupted' && Actor::get($args->{ID})->isa('Actor::Player')) || ($callback_name eq 'packet/high_jump' && Actor::get($args->{ID})->isa('Actor::Player')) ) {
			my $actor;
			unless  ($callback_name eq 'player_moved') {
				$actor = Actor::get($args->{ID});
				return unless ($actor->isa('Actor::Player'));
			} else {
				$actor = $args;
			}
			
			return unless (exists($self->{possible_fulfill_actors}{$actor->{binID}}));
			
			if ($self->{is_Fulfilled}) {
			
				return unless ($actor->{binID} == $self->{fulfilled_actor}->{binID});
				return if ( $self->SUPER::validate_condition( 1, distance( $char->{pos_to}, $actor->{pos_to} ) ) );
				$self->search_for_dist_match_on_possible_fulfill_actors_list;
				
			} else {
				
				return unless ( $self->SUPER::validate_condition( 1, distance( $char->{pos_to}, $actor->{pos_to} ) ) );
				$self->{fulfilled_actor} = $actor;
				$self->{is_Fulfilled} = 1;
				
			}
		} elsif ($callback_name eq 'packet/character_moves' || ($callback_name eq 'packet/actor_movement_interrupted' && Actor::get($args->{ID})->isa('Actor::You')) || ($callback_name eq 'packet/high_jump' && Actor::get($args->{ID})->isa('Actor::You'))) {
			
			if ($self->{is_Fulfilled}) {
				return if ( $self->SUPER::validate_condition( 1, distance( $char->{pos_to}, $self->{fulfilled_actor}->{pos_to} ) ) );
				$self->search_for_dist_match_on_possible_fulfill_actors_list;
			} else {
				$self->search_for_dist_match_on_possible_fulfill_actors_list;
			}
			
		} elsif ($callback_name eq 'packet_mapChange') {
			$self->{number_of_possible_fulfill_actors} = 0;
			$self->{possible_fulfill_actors} = {};
			$self->{fulfilled_actor} = undef;
			$self->{is_Fulfilled} = 0;
		}
		
	} elsif ($callback_type eq 'recheck') {
		$self->recheck_all_actor_names;
	}
}

sub search_for_dist_match_on_possible_fulfill_actors_list {
	my ($self) = @_;
	$self->{fulfilled_actor} = undef;
	$self->{is_Fulfilled} = 0;
	my @array_of_possibles = values %{ $self->{possible_fulfill_actors} };
	foreach my $actor (@array_of_possibles) {
		next unless ( $self->SUPER::validate_condition( 1, distance($char->{pos_to}, $actor->{pos_to}) ) );
		$self->{fulfilled_actor} = $actor;
		$self->{is_Fulfilled} = 1;
		last;
	}
}

sub recheck_all_actor_names {
	my ($self) = @_;
	
	my $pre_number = $self->{number_of_possible_fulfill_actors};
	
	$self->{fulfilled_actor} = undef;
	$self->{is_Fulfilled} = 0;
	$self->{number_of_possible_fulfill_actors} = 0;
	$self->{possible_fulfill_actors} = {};
	foreach my $actor (@{$playersList->getItems()}) {
		next unless ( $self->SUPER::validate_condition(0, $actor->{name}) );
		$self->{number_of_possible_fulfill_actors}++;
		$self->{possible_fulfill_actors}{$actor->{binID}} = $actor;
		
		unless ($self->{is_Fulfilled}) {
			next unless ( $self->SUPER::validate_condition( 1, distance($char->{pos_to}, $actor->{pos_to}) ) );
			$self->{fulfilled_actor} = $actor;
			$self->{is_Fulfilled} = 1;
		}
	}
	
	if ($pre_number == 0 && $self->{number_of_possible_fulfill_actors} > 0) {
		$self->add_or_remove_dynamic_hooks(1);
	} elsif ($pre_number > 0 && $self->{number_of_possible_fulfill_actors} == 0) {
		$self->add_or_remove_dynamic_hooks(0);
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $self->{fulfilled_actor}->{name};
	$new_variables->{".".$self->{name}."Last"."Pos"} = sprintf("%d %d %s", $self->{fulfilled_actor}->{pos_to}{x}, $self->{fulfilled_actor}->{pos_to}{y}, $field->baseName);
	$new_variables->{".".$self->{name}."Last"."BinId"} = $self->{fulfilled_actor}->{binID};
	$new_variables->{".".$self->{name}."Last"."Dist"} = distance($char->{pos_to}, $self->{fulfilled_actor}->{pos_to});
	$new_variables->{".".$self->{name}."Last"."Level"} = $self->{fulfilled_actor}->{lv};
	$new_variables->{".".$self->{name}."Last"."Job"} = $self->{fulfilled_actor}->job;
	$new_variables->{".".$self->{name}."Last"."AccountId"} = $self->{fulfilled_actor}->{binID};
	
	return $new_variables;
}

1;
