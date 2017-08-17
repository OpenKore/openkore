package eventMacro::Condition::BaseActorNearDist;

use strict;
use Globals;
use Utils;

use base 'eventMacro::Conditiontypes::MultipleValidatorState';

sub _hooks {
	[];
}

sub _dynamic_hooks {
	['packet/actor_movement_interrupted','packet/high_jump','packet/character_moves','packet_mapChange'];
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
		$self->update_validator_var($callback_name, $args);
		
		foreach my $validator_index ( @{ $self->{var_to_validator_index}{$callback_name} } ) {
			if ($validator_index == 0) {
				$self->recheck_all_actor_names;
			} elsif ($validator_index == 1) {
				$self->search_for_dist_match_on_possible_fulfill_actors_list;
			}
		}
		
	} elsif ($callback_type eq 'hook') {
		
		if ($self->{hook_type} eq 'add_list' && $self->validator_check(0,$self->{actor}->{name})) {
			
			if ($self->{number_of_possible_fulfill_actors} == 0) {
				$self->add_or_remove_dynamic_hooks(1);
			}
			
			$self->{number_of_possible_fulfill_actors}++;
			$self->{possible_fulfill_actors}{$self->{actor}->{binID}} = $args;
			
			if ( !defined $self->{fulfilled_actor} && $self->validator_check( 1, distance($char->{pos_to}, $self->{actor}->{pos_to}) ) ) {
				$self->{fulfilled_actor} = $args;
			}

		} elsif ($self->{hook_type} eq 'disappeared' && exists($self->{possible_fulfill_actors}{$self->{actor}->{binID}})) {
		
			$self->{number_of_possible_fulfill_actors}--;
			delete $self->{possible_fulfill_actors}{$self->{actor}->{binID}};
			
			if (defined $self->{fulfilled_actor} && $self->{actor}->{binID} == $self->{fulfilled_actor}->{binID}) {
				$self->search_for_dist_match_on_possible_fulfill_actors_list;
			}
			
			if ($self->{number_of_possible_fulfill_actors} == 0) {
				$self->add_or_remove_dynamic_hooks(0);
			}
		
		} elsif ($self->{hook_type} eq 'NameUpdate') {
		
			if (!defined $self->{fulfilled_actor} && $self->validator_check(0,$self->{actor}->{name})) {
				if ($self->{number_of_possible_fulfill_actors} == 0) {
					$self->add_or_remove_dynamic_hooks(1);
				}
				$self->{number_of_possible_fulfill_actors}++;
				$self->{possible_fulfill_actors}{$self->{actor}->{binID}} = $self->{actor};
				if ( !defined $self->{fulfilled_actor} && $self->validator_check( 1, distance($char->{pos_to}, $self->{actor}->{pos_to}) ) ) {
					$self->{fulfilled_actor} = $self->{actor};
				}
				
			} elsif (exists($self->{possible_fulfill_actors}{$self->{actor}->{binID}})) {
				$self->{number_of_possible_fulfill_actors}--;
				delete $self->{possible_fulfill_actors}{$self->{actor}->{binID}};
				
				if (defined $self->{fulfilled_actor} && $self->{actor}->{binID} == $self->{fulfilled_actor}->{binID}) {
					$self->search_for_dist_match_on_possible_fulfill_actors_list;
				}
				
				if ($self->{number_of_possible_fulfill_actors} == 0) {
					$self->add_or_remove_dynamic_hooks(0);
				}
			}
			
		} elsif ($self->{hook_type} eq 'moved' || ($self->{hook_type} eq 'interrupted_or_jump' && $self->{actor}->isa($self->{actorType}))) {
			
			return $self->SUPER::validate_condition unless (exists($self->{possible_fulfill_actors}{$self->{actor}->{binID}}));
			
			if (defined $self->{fulfilled_actor}) {
			
				return $self->SUPER::validate_condition if ($self->{actor}->{binID} != $self->{fulfilled_actor}->{binID} || $self->validator_check( 1, distance( $char->{pos_to}, $self->{actor}->{pos_to} ) ));
				$self->search_for_dist_match_on_possible_fulfill_actors_list;
				
			} else {
				
				return $self->SUPER::validate_condition unless ( $self->validator_check( 1, distance( $char->{pos_to}, $self->{actor}->{pos_to} ) ) );
				$self->{fulfilled_actor} = $self->{actor};
				
			}
		} elsif ($callback_name eq 'packet/character_moves' || ($callback_name eq 'packet/actor_movement_interrupted' && Actor::get($args->{ID})->isa('Actor::You')) || ($callback_name eq 'packet/high_jump' && Actor::get($args->{ID})->isa('Actor::You'))) {
			
			if (defined $self->{fulfilled_actor}) {
				return $self->SUPER::validate_condition if ( $self->validator_check( 1, distance( $char->{pos_to}, $self->{fulfilled_actor}->{pos_to} ) ) );
			}
			$self->search_for_dist_match_on_possible_fulfill_actors_list;
			
		} elsif ($callback_name eq 'packet_mapChange') {
			if ($self->{number_of_possible_fulfill_actors} > 0) {
				$self->add_or_remove_dynamic_hooks(0);
			}
			$self->{number_of_possible_fulfill_actors} = 0;
			$self->{possible_fulfill_actors} = {};
			$self->{fulfilled_actor} = undef;
		}
		
	} elsif ($callback_type eq 'recheck') {
		$self->recheck_all_actor_names;
	}
	
	return $self->SUPER::validate_condition( (defined $self->{fulfilled_actor} ? 1 : 0) );
}

sub search_for_dist_match_on_possible_fulfill_actors_list {
	my ($self) = @_;
	$self->{fulfilled_actor} = undef;
	my @array_of_possibles = values %{ $self->{possible_fulfill_actors} };
	foreach my $actor (@array_of_possibles) {
		next unless ( $self->validator_check( 1, distance($char->{pos_to}, $actor->{pos_to}) ) );
		$self->{fulfilled_actor} = $actor;
		last;
	}
}

sub recheck_all_actor_names {
	my ($self) = @_;
	
	my $pre_number = $self->{number_of_possible_fulfill_actors};
	
	$self->{fulfilled_actor} = undef;
	$self->{number_of_possible_fulfill_actors} = 0;
	$self->{possible_fulfill_actors} = {};
	foreach my $actor (@{${$self->{actorList}}->getItems}) {
		next unless ( $self->validator_check(0, $actor->{name}) );
		$self->{number_of_possible_fulfill_actors}++;
		$self->{possible_fulfill_actors}{$actor->{binID}} = $actor;
		
		unless (defined $self->{fulfilled_actor}) {
			next unless ( $self->validator_check( 1, distance($char->{pos_to}, $actor->{pos_to}) ) );
			$self->{fulfilled_actor} = $actor;
		}
	}
	
	if ($pre_number == 0 && $self->{number_of_possible_fulfill_actors} > 0) {
		$self->add_or_remove_dynamic_hooks(1);
	} elsif ($pre_number > 0 && $self->{number_of_possible_fulfill_actors} == 0) {
		$self->add_or_remove_dynamic_hooks(0);
	}
}

sub usable {
	0;
}

1;
