package eventMacro::Condition::npcTalkNpcId;

use strict;

use base 'eventMacro::Conditiontypes::NumericConditionState';

use NPC::Conversation;
use eventMacro::Condition::Base::NpcTalkState;

sub _hooks {
	eventMacro::Condition::Base::NpcTalkState::_hooks();
}

sub _get_val {
	my $npc_id = NPC::Conversation::current_npc_id();
	return defined $npc_id ? unpack('V', $npc_id) : 0;
}

sub validate_condition {
	my ($self, $callback_type, $callback_name, $args) = @_;

	if ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
	}

	$self->{last_npc_id} = _get_val();
	return $self->SUPER::validate_condition($self->validator_check);
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;

	$new_variables->{'.'.$self->{name}.'Last'} = $self->{last_npc_id};
	return $new_variables;
}

1;
