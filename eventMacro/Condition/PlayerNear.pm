package eventMacro::Condition::PlayerNear;

use strict;

use base 'eventMacro::Conditiontypes::RegexConditionState';

use Globals;

sub _hooks {
	['add_player_list','player_disappeared'];
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'variable') {
		$self->SUPER::update_validator_var($callback_name, $args);
	} elsif ($callback_type eq 'hook') {
		
		if ($callback_name eq 'add_player_list' && !$self->{is_Fulfilled} && $self->SUPER::validate_condition($args->{name})) {
			$self->{fulfilled_actor} = $args;
			$self->{is_Fulfilled} = 1;

		} elsif ($callback_name eq 'player_disappeared' && $self->{is_Fulfilled} && $args->{player}->{nameID} == $self->{fulfilled_actor}->{nameID}) {
			#need to check all other player to find another one that matches or not
			foreach my $player (@{$playersList->getItems()}) {
				next if ($player->{nameID} == $self->{fulfilled_actor}->{nameID});
				next unless ($self->SUPER::validate_condition($player->{name}));
				$self->{fulfilled_actor} = $player;
				return;
			}
			$self->{fulfilled_actor} = undef;
			$self->{is_Fulfilled} = 0;
		}
		
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $self->{fulfilled_actor}->{name};
	$new_variables->{".".$self->{name}."Last"."Pos"} = sprintf("%d %d %s", $self->{fulfilled_actor}->{pos_to}{x}, $self->{fulfilled_actor}->{pos_to}{y}, $field->baseName);
	$new_variables->{".".$self->{name}."Last"."Level"} = $self->{fulfilled_actor}->{lv};
	$new_variables->{".".$self->{name}."Last"."Job"} = $self->{fulfilled_actor}->job;
	$new_variables->{".".$self->{name}."Last"."AccountId"} = $self->{fulfilled_actor}->{nameID};
	$new_variables->{".".$self->{name}."Last"."BinId"} = $self->{fulfilled_actor}->{binID};
	
	return $new_variables;
}

1;
