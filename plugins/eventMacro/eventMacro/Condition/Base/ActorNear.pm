package eventMacro::Condition::Base::ActorNear;

use strict;

use base 'eventMacro::Conditiontypes::RegexConditionState';

sub _hooks {
	['packet_mapChange'];
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
		$self->recheck_all_actor_names;
		
	} elsif ($callback_type eq 'hook') {
		
		if ($self->{hook_type} eq 'add_list' && !defined $self->{fulfilled_actor} && $self->validator_check($self->{actor}->{name})) {
			$self->{fulfilled_actor} = $self->{actor};

		} elsif ($self->{hook_type} eq 'disappeared' && defined $self->{fulfilled_actor} && $self->{actor}->{binID} == $self->{fulfilled_actor}->{binID}) {
		
			#need to check all other actor to find another one that matches or not
			my $last_bin_id = $self->{fulfilled_actor}->{binID};
			$self->{fulfilled_actor} = undef;
			foreach my $actor (@{${$self->{actorList}}->getItems}) {
				next if ($actor->{binID} == $last_bin_id);
				next unless ($self->validator_check($actor->{name}));
				$self->{fulfilled_actor} = $actor;
				last;
			}
		
		} elsif ($self->{hook_type} eq 'NameUpdate') {
		
			if (!defined $self->{fulfilled_actor} && $self->validator_check($self->{actor}->{name})) {
				$self->{fulfilled_actor} = $self->{actor};
				
			} elsif (defined $self->{fulfilled_actor} && $self->{actor}->{binID} == $self->{fulfilled_actor}->{binID}) {
				unless ($self->validator_check($self->{actor}->{name})) {
					$self->{fulfilled_actor} = undef;
					foreach my $actor (@{${$self->{actorList}}->getItems}) {
						next unless ($self->validator_check($actor->{name}));
						$self->{fulfilled_actor} = $actor;
						last;
					}
				}
			}
			
		} elsif ($callback_name eq 'packet_mapChange') {
			$self->{fulfilled_actor} = undef;
		}
		
	} elsif ($callback_type eq 'recheck') {
		$self->recheck_all_actor_names;
	}
	return $self->SUPER::validate_condition( (defined $self->{fulfilled_actor} ? 1 : 0) );
}

sub recheck_all_actor_names {
	my ($self) = @_;
	$self->{fulfilled_actor} = undef;
	foreach my $actor (@{${$self->{actorList}}->getItems}) {
		next unless ($self->validator_check($actor->{name}));
		$self->{fulfilled_actor} = $actor;
		last;
	}
}

1;
