package eventMacro::Condition::npcTalkExpectsText;

use strict;

use base 'eventMacro::Condition';

use NPC::Conversation;
use eventMacro::Condition::Base::NpcTalkState;

sub _hooks {
	eventMacro::Condition::Base::NpcTalkState::_hooks();
}

sub _parse_syntax {
	my ($self, $condition_code) = @_;
	eventMacro::Condition::Base::NpcTalkState::parse_wanted_state($self, $condition_code);
}

sub validate_condition {
	my ($self, $callback_type, $callback_name, $args) = @_;
	return $self->SUPER::validate_condition((NPC::Conversation::expects_text() ? 1 : 0) == $self->{wanted_state} ? 1 : 0);
}

1;
