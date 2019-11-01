package eventMacro::Condition::MobNotNear;

use strict;
use Globals qw( $monstersList );

use base 'eventMacro::Condition::Base::ActorNotNear';

sub _hooks {
	my ( $self ) = @_;
	my $hooks = $self->SUPER::_hooks;
	my @other_hooks = ('add_monster_list','monster_disappeared','mobNameUpdate');
	push(@{$hooks}, @other_hooks);
	return $hooks;
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{actorList} = \$monstersList;
	
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
		}
	}
	
	return $self->SUPER::validate_condition( $callback_type, $callback_name, $args );
}

1;
