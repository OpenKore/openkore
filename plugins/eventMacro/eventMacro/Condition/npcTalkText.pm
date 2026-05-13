package eventMacro::Condition::npcTalkText;

use strict;

use base 'eventMacro::Condition';

use NPC::Conversation;
use eventMacro::Condition::Base::NpcTalkState;

sub _hooks {
	eventMacro::Condition::Base::NpcTalkState::_hooks();
}

sub _parse_syntax {
	my ($self, $condition_code) = @_;
	$self->{wanted_text} = $condition_code;
}

sub validate_condition {
	my ($self, $callback_type, $callback_name, $args) = @_;

	$self->{last_text} = NPC::Conversation::text();
	return $self->SUPER::validate_condition(
		defined $self->{wanted_text} && $self->{last_text} eq $self->{wanted_text} ? 1 : 0
	);
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;

	$new_variables->{'.'.$self->{name}.'Last'} = $self->{last_text};
	return $new_variables;
}

1;
