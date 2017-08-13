package eventMacro::Condition::NpcMsgName;

use strict;
use Globals;
use Utils;

use eventMacro::Data;

use base 'eventMacro::Condition::BaseMsgName';

sub _hooks {
	my ( $self ) = @_;
	my $hooks = $self->SUPER::_hooks;
	my @other_hooks = ('npc_talk');
	push(@{$hooks}, @other_hooks);
	return $hooks;
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	$self->{message} = undef;
	$self->{source} = undef;
	
	if ($callback_type eq 'hook') {
		$self->{message} = $args->{msg};
		$self->{source} = $args->{name};
	}
	return $self->SUPER::validate_condition( $callback_type, $callback_name, $args );
}

sub usable {
	1;
}

1;