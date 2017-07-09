package eventMacro::Condition::MobNear;

use strict;
use Globals;
use Utils;

use base 'eventMacro::Conditiontypes::RegexConditionState';

sub _hooks {
	['packet_mapChange','add_monster_list','monster_disappeared','mobNameUpdate'];
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
		$self->recheck_all_actor_names;
		
	} elsif ($callback_type eq 'hook') {
		
		if ($callback_name eq 'add_monster_list' && !defined $self->{fulfilled_actor} && $self->validator_check($args->{name})) {
			$self->{fulfilled_actor} = $args;

		} elsif ($callback_name eq 'monster_disappeared' && defined $self->{fulfilled_actor} && $args->{monster}->{binID} == $self->{fulfilled_actor}->{binID}) {
			#need to check all other actor to find another one that matches or not
			my $last_bin_id = $self->{fulfilled_actor}->{binID};
			$self->{fulfilled_actor} = undef;
			foreach my $actor (@{$monstersList->getItems()}) {
				next if ($actor->{binID} == $last_bin_id);
				next unless ($self->validator_check($actor->{name}));
				$self->{fulfilled_actor} = $actor;
				last;
			}
		
		} elsif ($callback_name eq 'mobNameUpdate') {
		
			if (!defined $self->{fulfilled_actor} && $self->validator_check($args->{monster}->{name})) {
				$self->{fulfilled_actor} = $args;
				
			} elsif (defined $self->{fulfilled_actor} && $args->{monster}->{binID} == $self->{fulfilled_actor}->{binID}) {
				unless ($self->validator_check($args->{monster}->{name})) {
					$self->{fulfilled_actor} = undef;
					foreach my $actor (@{$npcsList->getItems()}) {
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
	foreach my $actor (@{$monstersList->getItems()}) {
		next unless ($self->validator_check($actor->{name}));
		$self->{fulfilled_actor} = $actor;
		last;
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $self->{fulfilled_actor}->{name};
	$new_variables->{".".$self->{name}."Last"."Pos"} = sprintf("%d %d %s", $self->{fulfilled_actor}->{pos_to}{x}, $self->{fulfilled_actor}->{pos_to}{y}, $field->baseName);
	$new_variables->{".".$self->{name}."Last"."BinId"} = $self->{fulfilled_actor}->{binID};
	$new_variables->{".".$self->{name}."Last"."Dist"} = distance($char->{pos_to}, $self->{fulfilled_actor}->{pos_to});
	$new_variables->{".".$self->{name}."Last"."Id"} = $self->{fulfilled_actor}->{binType};
	
	return $new_variables;
}

1;
