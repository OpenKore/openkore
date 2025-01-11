package eventMacro::Condition::Base::ActorNotNear;

use strict;

use base 'eventMacro::Conditiontypes::RegexConditionState';

#'packet/map_property3' has to exchanged
sub _hooks {
	['packet_mapChange','packet/map_property3'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{is_on_stand_by} = 0;
	$self->{not_fulfilled_actor} = undef;
	
	$self->SUPER::_parse_syntax($condition_code);
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
		$self->recheck_all_actor_names;
		
	} elsif ($callback_type eq 'hook') {
		
		if ($self->{hook_type} eq 'add_list' && !defined $self->{not_fulfilled_actor} && $self->validator_check($self->{actor}->{name})) {
			$self->{not_fulfilled_actor} = $self->{actor};

		} elsif ($self->{hook_type} eq 'disappeared' && defined $self->{not_fulfilled_actor} && $self->{actor}->{binID} == $self->{not_fulfilled_actor}->{binID}) {
		
			#need to check all other actor to find another one that matches or not
			my $last_bin_id = $self->{not_fulfilled_actor}->{binID};
			$self->{not_fulfilled_actor} = undef;
			foreach my $actor (@{${$self->{actorList}}->getItems}) {
				next if ($actor->{binID} == $last_bin_id);
				next unless ($self->validator_check($actor->{name}));
				$self->{not_fulfilled_actor} = $actor;
				last;
			}
		
		} elsif ($self->{hook_type} eq 'NameUpdate') {
		
			if (!defined $self->{not_fulfilled_actor} && $self->validator_check($self->{actor}->{name})) {
				$self->{not_fulfilled_actor} = $self->{actor};
				
			} elsif (defined $self->{not_fulfilled_actor} && $self->{actor}->{binID} == $self->{not_fulfilled_actor}->{binID}) {
	
				unless ($self->validator_check($self->{actor}->{name})) {
					$self->{not_fulfilled_actor} = undef;
					foreach my $actor (@{${$self->{actorList}}->getItems}) {
						next unless ($self->validator_check($actor->{name}));
						$self->{not_fulfilled_actor} = $actor;
						last;
					}
				}
			}
			
		} elsif ($callback_name eq 'packet_mapChange') {
			$self->{not_fulfilled_actor} = undef;
			$self->{is_on_stand_by} = 1;
			
		} elsif ($callback_name eq 'packet/map_property3') {
			$self->{is_on_stand_by} = 0;
			
		}
		
	} elsif ($callback_type eq 'recheck') {
		$self->recheck_all_actor_names;
		$self->{is_on_stand_by} = 0;
	}
	
	return $self->SUPER::validate_condition( ( (defined $self->{not_fulfilled_actor} || $self->{is_on_stand_by} == 1) ? 0 : 1 ) );
}

sub recheck_all_actor_names {
	my ($self) = @_;
	$self->{not_fulfilled_actor} = undef;
	foreach my $actor (@{${$self->{actorList}}->getItems}) {
		next unless ($self->validator_check($actor->{name}));
		$self->{not_fulfilled_actor} = $actor;
		last;
	}
}

1;
