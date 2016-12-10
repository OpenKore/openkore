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
	$self->{not_fulfilled_actor} = undef;
	
	$self->SUPER::_parse_syntax($condition_code);
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
		$self->recheck_all_actor_names;
		
	} elsif ($callback_type eq 'hook') {
		
		if ($callback_name eq 'add_player_list' && !defined $self->{not_fulfilled_actor} && $self->validator_check($args->{name})) {
			$self->{not_fulfilled_actor} = $args;

		} elsif ($callback_name eq 'player_disappeared' && defined $self->{not_fulfilled_actor} && $args->{player}->{binID} == $self->{not_fulfilled_actor}->{binID}) {
			#need to check all other actor to find another one that matches or not
			my $last_bin_id = $self->{not_fulfilled_actor}->{binID};
			$self->{not_fulfilled_actor} = undef;
			foreach my $actor (@{$playersList->getItems()}) {
				next if ($actor->{binID} == $last_bin_id);
				next unless ($self->validator_check($actor->{name}));
				$self->{not_fulfilled_actor} = $actor;
				last;
			}
			
		} elsif ($callback_name eq 'packet_mapChange') {
			$self->{not_fulfilled_actor} = undef;
			$self->{is_on_stand_by} = 1;
			
		} elsif ($callback_name eq 'packet/map_property3') {
			$self->{is_on_stand_by} = 0;
			
		}
		
	} elsif ($callback_type eq 'recheck') {
		$self->recheck_all_actor_names;
	}
	return $self->SUPER::validate_condition( ( (defined $self->{not_fulfilled_actor} || $self->{is_on_stand_by} == 1) ? 0 : 1 ) );
}

sub recheck_all_actor_names {
	my ($self) = @_;
	$self->{not_fulfilled_actor} = undef;
	foreach my $actor (@{$playersList->getItems()}) {
		next unless ($self->validator_check($actor->{name}));
		$self->{not_fulfilled_actor} = $actor;
		last;
	}
}

1;
