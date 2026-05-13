package eventMacro::Condition::npcTalkNpcName;

use strict;

use base 'eventMacro::Condition';

use NPC::Conversation;
use eventMacro::Condition::Base::NpcTalkState;

sub _hooks {
	eventMacro::Condition::Base::NpcTalkState::_hooks();
}

sub _parse_syntax {
	my ($self, $condition_code) = @_;
	$self->{wanted_name} = $condition_code;
}

sub validate_condition {
	my ($self, $callback_type, $callback_name, $args) = @_;

	$self->{last_name} = NPC::Conversation::current_npc_name();
	return $self->SUPER::validate_condition(
		defined $self->{wanted_name}
		&& defined $self->{last_name}
		&& $self->{last_name} eq $self->{wanted_name} ? 1 : 0
	);
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;

	$new_variables->{'.'.$self->{name}.'Last'} = $self->{last_name};
	return $new_variables;
}

1;
