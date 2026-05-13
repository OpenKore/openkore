package eventMacro::Condition::Base::NpcTalkState;

use strict;

sub _hooks {
	return ['in_game', 'npc_talk_state_changed'];
}

sub parse_wanted_state {
	my ($self, $condition_code) = @_;

	if (defined $condition_code && $condition_code =~ /^(0|1)$/) {
		$self->{wanted_state} = $1;
		return 1;
	}

	$self->{error} = "Value '$condition_code' Should be '0' or '1'";
	return 0;
}

1;
