package eventMacro::Condition::MobNearDist;

use strict;
use Globals qw( $char $monstersList $field );
use Utils qw( distance );

use base 'eventMacro::Condition::Base::ActorNearDist';

sub _hooks {
	my ( $self ) = @_;
	my $hooks = $self->SUPER::_hooks;
	my @other_hooks = ('add_monster_list','monster_disappeared');
	push(@{$hooks}, @other_hooks);
	return $hooks;
}

sub _dynamic_hooks {
	my ( $self ) = @_;
	my $hooks = $self->SUPER::_dynamic_hooks;
	my @other_hooks = ('monster_moved','mobNameUpdate');
	push(@{$hooks}, @other_hooks);
	return $hooks;
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{actorList} = \$monstersList;
	$self->{actorType} = 'Actor::Monster';
	
	$self->SUPER::_parse_syntax($condition_code);
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	$self->{actor} = undef;
	$self->{hook_type} = undef;
	
	if ($callback_type eq 'hook') {
		
		if ($callback_name eq 'add_monster_list') {
			$self->{actor} = $args;
			$self->{hook_type} = 'add_list';

		} elsif ($callback_name eq 'monster_disappeared') {
			$self->{actor} = $args->{monster};
			$self->{hook_type} = 'disappeared';
		
		} elsif ($callback_name eq 'mobNameUpdate') {
			$self->{actor} = $args->{monster};
			$self->{hook_type} = 'NameUpdate';
			
		} elsif ($callback_name eq 'monster_moved') {
			$self->{actor} = $args;
			$self->{hook_type} = 'moved';
			
		} elsif ($callback_name eq 'packet/actor_movement_interrupted' || $callback_name eq 'packet/high_jump') {
			$self->{actor} = Actor::get($args->{ID});
			$self->{hook_type} = 'interrupted_or_jump';
		}
	}
	
	return $self->SUPER::validate_condition( $callback_type, $callback_name, $args );
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
