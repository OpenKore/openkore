package eventMacro::Condition::npcTalkResponseCount;

use strict;

use base 'eventMacro::Conditiontypes::NumericConditionState';

use NPC::Conversation;
use eventMacro::Condition::Base::NpcTalkState;

sub _hooks {
	eventMacro::Condition::Base::NpcTalkState::_hooks();
}

sub _get_val {
	NPC::Conversation::response_count();
}

sub validate_condition {
	my ($self, $callback_type, $callback_name, $args) = @_;

	if ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
	}

	$self->{last_count} = NPC::Conversation::response_count();
	return $self->SUPER::validate_condition($self->validator_check);
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;

	$new_variables->{'.'.$self->{name}.'Last'} = $self->{last_count};
	return $new_variables;
}

1;
