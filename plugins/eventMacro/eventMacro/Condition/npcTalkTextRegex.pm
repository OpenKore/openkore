package eventMacro::Condition::npcTalkTextRegex;

use strict;

use base 'eventMacro::Conditiontypes::RegexConditionState';

use NPC::Conversation;
use eventMacro::Condition::Base::NpcTalkState;

sub _hooks {
	eventMacro::Condition::Base::NpcTalkState::_hooks();
}

sub validate_condition {
	my ($self, $callback_type, $callback_name, $args) = @_;

	if ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
	}

	$self->{last_text} = NPC::Conversation::text();
	return $self->SUPER::validate_condition($self->validator_check($self->{last_text}));
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;

	$new_variables->{'.'.$self->{name}.'Last'} = $self->{last_text};
	return $new_variables;
}

1;
