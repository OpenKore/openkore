package eventMacro::Condition::NoNpcNear;

use strict;
use Globals qw( $npcsList );
use base 'eventMacro::Condition::Base::NoActorNear';

use Globals;

sub _hooks {
	my ( $self ) = @_;
	my $hooks = $self->SUPER::_hooks;
	my @other_hooks = ('add_npc_list','npc_disappeared');
	push(@{$hooks}, @other_hooks);
	return $hooks;
}

sub get_size {
	my ( $self ) = @_;
	return ($npcsList->size + $self->{change});
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	if ($callback_type eq 'hook' && $callback_name eq 'npc_disappeared') {
		$self->{change} = -1;
	} else {
		$self->{change} = 0;
	}
	return $self->SUPER::validate_condition( $callback_type, $callback_name, $args );
}

1;
