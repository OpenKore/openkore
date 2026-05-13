package eventMacro::Condition::npcTalkResponse;

use strict;

use base 'eventMacro::Condition';

use NPC::Conversation;
use eventMacro::Condition::Base::NpcTalkState;

sub _hooks {
	eventMacro::Condition::Base::NpcTalkState::_hooks();
}

sub _parse_syntax {
	my ($self, $condition_code) = @_;
	$self->{wanted_response} = $condition_code;
}

sub validate_condition {
	my ($self, $callback_type, $callback_name, $args) = @_;

	$self->{last_response} = undef;
	foreach my $response (@{NPC::Conversation::responses()}) {
		if (defined $self->{wanted_response} && $response eq $self->{wanted_response}) {
			$self->{last_response} = $response;
			return $self->SUPER::validate_condition(1);
		}
	}

	return $self->SUPER::validate_condition(0);
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;

	$new_variables->{'.'.$self->{name}.'Last'} = $self->{last_response};
	return $new_variables;
}

1;
