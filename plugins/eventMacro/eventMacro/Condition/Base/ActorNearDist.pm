package eventMacro::Condition::Base::ActorNearDist;

use strict;
use Globals qw( $char );
use Utils qw( distance ) ;

use base 'eventMacro::Condition';

sub _hooks {
	[];
}

sub _dynamic_hooks {
	['packet/actor_movement_interrupted','packet/high_jump','packet/character_moves','packet_mapChange'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{number_of_possible_fulfill_actors} = 0;
	$self->{possible_fulfill_actors} = {};
	$self->{fulfilled_actor} = undef;
	
	$self->{name_validator} = undef;
	$self->{dist_validator} = undef;
	
	$self->{var_in_name} = {};
	$self->{var_in_dist} = {};
	
	my $var_exists_hash = {};
	
	if ($condition_code =~ /^(\/.*?\/\w?)\s+(.*?)$/) {
		my $regex = $1;
		my $dist = $2;
		
		unless (defined $regex && defined $dist) {
			$self->{error} = "Condition code '".$condition_code."' must have a name regex and a distance comaparison defined";
			return 0;
		}
		
		my @validators = (
			eventMacro::Validator::RegexCheck->new( $regex ),
			eventMacro::Validator::NumericComparison->new( $dist ),
		);
		
		my @var_setting = (
			$self->{var_in_name},
			$self->{var_in_dist},
		);
		
		foreach my $validator_index (0..$#validators) {
			my $validator = $validators[$validator_index];
			my $var_hash = $var_setting[$validator_index];
			if (defined $validator->error) {
				$self->{error} = $validator->error;
				return 0;
			} else {
				my @vars = @{$validator->variables};
				foreach my $var (@vars) {
					push ( @{ $self->{variables} }, $var ) unless (exists $var_exists_hash->{$var->{display_name}});
					$var_hash->{$var->{display_name}} = undef;
					$var_exists_hash->{$var->{display_name}} = undef;
				}
			}
		}
		
		$self->{name_validator} = $validators[0];
		$self->{dist_validator} = $validators[1];
		
	} else {
		$self->{error} = "Condition code '".$condition_code."' must have a name regex and a distance comparison defined";
		return 0;
	}
	
	return 1;
}

sub update_validator_var {
	my ( $self, $var_name, $var_value ) = @_;
	
	my $changed_name = 0;
	my $changed_dist = 0;
	
	if (exists $self->{var_in_name}{$var_name}) {
		$self->{name_validator}->update_vars($var_name, $var_value);
		$changed_name = 1;
	}
	
	if (exists $self->{var_in_dist}{$var_name}) {
		$self->{dist_validator}->update_vars($var_name, $var_value);
		$changed_dist = 1;
	}
	
	if ($changed_name) {
		$self->recheck_all_actor_names;
	} elsif ($changed_dist) {
		$self->search_for_dist_match_on_possible_fulfill_actors_list;
	}
}

sub validator_name_check {
	my ( $self, $check ) = @_;
	return $self->{name_validator}->validate($check);
}

sub validator_dist_check {
	my ( $self, $check ) = @_;
	return $self->{dist_validator}->validate($check);
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
		
	} elsif ($callback_type eq 'hook') {
		
		if ($self->{hook_type} eq 'add_list' && $self->validator_name_check($self->{actor}->{name})) {
			
			if ($self->{number_of_possible_fulfill_actors} == 0) {
				$self->add_or_remove_dynamic_hooks(1);
			}
			
			$self->{number_of_possible_fulfill_actors}++;
			$self->{possible_fulfill_actors}{$self->{actor}->{binID}} = $args;
			
			if ( !defined $self->{fulfilled_actor} && $self->validator_dist_check( distance($char->{pos_to}, $self->{actor}->{pos_to}) ) ) {
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
		
			if (!defined $self->{fulfilled_actor} && $self->validator_name_check($self->{actor}->{name})) {
				if ($self->{number_of_possible_fulfill_actors} == 0) {
					$self->add_or_remove_dynamic_hooks(1);
				}
				$self->{number_of_possible_fulfill_actors}++;
				$self->{possible_fulfill_actors}{$self->{actor}->{binID}} = $self->{actor};
				if ( !defined $self->{fulfilled_actor} && $self->validator_dist_check( distance($char->{pos_to}, $self->{actor}->{pos_to}) ) ) {
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
			
				return $self->SUPER::validate_condition if ($self->{actor}->{binID} != $self->{fulfilled_actor}->{binID} || $self->validator_dist_check( distance( $char->{pos_to}, $self->{actor}->{pos_to} ) ));
				$self->search_for_dist_match_on_possible_fulfill_actors_list;
				
			} else {
				
				return $self->SUPER::validate_condition unless ( $self->validator_dist_check( distance( $char->{pos_to}, $self->{actor}->{pos_to} ) ) );
				$self->{fulfilled_actor} = $self->{actor};
				
			}
		} elsif ($callback_name eq 'packet/character_moves' || ($callback_name eq 'packet/actor_movement_interrupted' && Actor::get($args->{ID})->isa('Actor::You')) || ($callback_name eq 'packet/high_jump' && Actor::get($args->{ID})->isa('Actor::You'))) {
			
			if (defined $self->{fulfilled_actor}) {
				return $self->SUPER::validate_condition if ( $self->validator_dist_check( distance( $char->{pos_to}, $self->{fulfilled_actor}->{pos_to} ) ) );
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
		next unless ( $self->validator_dist_check( distance($char->{pos_to}, $actor->{pos_to}) ) );
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
		next unless ( $self->validator_name_check( $actor->{name}) );
		$self->{number_of_possible_fulfill_actors}++;
		$self->{possible_fulfill_actors}{$actor->{binID}} = $actor;
		
		unless (defined $self->{fulfilled_actor}) {
			next unless ( $self->validator_dist_check( distance($char->{pos_to}, $actor->{pos_to}) ) );
			$self->{fulfilled_actor} = $actor;
		}
	}
	
	if ($pre_number == 0 && $self->{number_of_possible_fulfill_actors} > 0) {
		$self->add_or_remove_dynamic_hooks(1);
	} elsif ($pre_number > 0 && $self->{number_of_possible_fulfill_actors} == 0) {
		$self->add_or_remove_dynamic_hooks(0);
	}
}

1;
