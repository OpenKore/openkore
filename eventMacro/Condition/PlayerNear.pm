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
		$self->{actor} = $args;
		
		if ($callback_name eq 'add_player_list') {
			if ($self->{is_Fulfilled}) {
				return 1;
			} else {
				if ($self->SUPER::validate_condition($self->{actor}->{name})) {
					$self->{is_Fulfilled} = 1;
					return 1;
				}
			}
		} else {
			if ($self->{is_Fulfilled}) {
				if ($self->SUPER::validate_condition($self->{actor}->{name})) {
					#need to check all other player to find another one that matches or not
					foreach my $player (@{$playersList->getItems()}) {
						if ($self->SUPER::validate_condition($player->{name})) {
							$self->{is_Fulfilled} = 1;
							$self->{actor} = $player;
							return 1;
						}
					}
					$self->{is_Fulfilled} = 0;
					return 0;
				}
			} else {
				return 0;
			}
		}
		
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $self->{actor}->{name};
	$new_variables->{".".$self->{name}."Last"."Pos"} = sprintf("%d %d %s", $self->{actor}->{pos_to}{x}, $self->{actor}->{pos_to}{y}, $field->baseName);
	$new_variables->{".".$self->{name}."Last"."Level"} = $self->{actor}->{lv};
	$new_variables->{".".$self->{name}."Last"."Job"} = $self->{actor}->job;
	$new_variables->{".".$self->{name}."Last"."AccountId"} = $self->{actor}->{nameID};
	$new_variables->{".".$self->{name}."Last"."BinId"} = $self->{actor}->{binID};
	
	return $new_variables;
}

1;
