package eventMacro::Condition::PlayerNotNear;

use strict;
use Globals;
use Utils;

use base 'eventMacro::Conditiontypes::RegexConditionState';

use Globals;

#'packet/map_property3' has to exchanged
sub _hooks {
	['packet_mapChange','packet/map_property3','add_player_list','player_disappeared'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{is_on_stand_by} = 0;
	$self->{temporary_is_Fulfilled} = 0;
	$self->{not_fulfilled_actor} = undef;
	
	$self->SUPER::_parse_syntax($condition_code);
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'variable') {
		$self->SUPER::update_validator_var($callback_name, $args);
		$self->recheck_all_actor_names;
		
	} elsif ($callback_type eq 'hook') {
		
		if ($callback_name eq 'add_player_list' && ($self->{is_Fulfilled} || $self->{is_on_stand_by}) && $self->SUPER::validate_condition($args->{name})) {
			$self->{not_fulfilled_actor} = $args;
			if ($self->{is_on_stand_by}) {
				$self->{temporary_is_Fulfilled} = 0;
			} else {
				$self->{is_Fulfilled} = 0;
			}

		} elsif ($callback_name eq 'player_disappeared' && !$self->{is_Fulfilled} && $args->{player}->{binID} == $self->{not_fulfilled_actor}->{binID}) {
			#need to check all other actor to find another one that matches or not
			foreach my $actor (@{$playersList->getItems()}) {
				next if ($actor->{binID} == $self->{not_fulfilled_actor}->{binID});
				next unless ($self->SUPER::validate_condition($actor->{name}));
				$self->{not_fulfilled_actor} = $actor;
				return;
			}
			$self->{not_fulfilled_actor} = undef;
			$self->{is_Fulfilled} = 1;
			
		} elsif ($callback_name eq 'packet_mapChange') {
			unless ($self->{is_on_stand_by}) {
				$self->{not_fulfilled_actor} = undef;
				$self->{temporary_is_Fulfilled} = 1;
				$self->{is_on_stand_by} = 1;
				$self->{is_Fulfilled} = 0;
			}
			
		} elsif ($callback_name eq 'packet/map_property3') {
			if ($self->{is_on_stand_by}) {
				$self->{is_on_stand_by} = 0;
				$self->{is_Fulfilled} = $self->{temporary_is_Fulfilled};
				$self->{temporary_is_Fulfilled} = 0;
			}
			
		}
		
	} elsif ($callback_type eq 'recheck') {
		$self->recheck_all_actor_names;
	}
}

sub recheck_all_actor_names {
	my ($self) = @_;
	$self->{not_fulfilled_actor} = undef;
	$self->{is_Fulfilled} = 1;
	foreach my $actor (@{$playersList->getItems()}) {
		next unless ($self->SUPER::validate_condition($actor->{name}));
		$self->{not_fulfilled_actor} = $actor;
		$self->{is_Fulfilled} = 0;
		last;
	}
}

1;
