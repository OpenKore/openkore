package eventMacro::Condition::Base::Quest;

use strict;
use eventMacro::Utilities qw( find_variable updateQuestConditionStandbyState );

use base 'eventMacro::Condition';

sub _hooks {
	['in_game','packet_mapChange','quest_all_list_end','quest_all_mission_end','quest_added','quest_update_mission_hunt_end','quest_delete','quest_active'];
}

sub _dynamic_hooks {
	['mainLoop_pre'];
}

sub initialize_quest_condition {
	my ($self) = @_;
	$self->{is_on_stand_by} = 1;
	$self->{quest_standby_dynamic_hooks_enabled} = 0;
}

sub initialize_simple_quest_id_condition {
	my ($self) = @_;
	$self->{fulfilled_ID} = undef;
	$self->{fulfilled_member_index} = undef;
	$self->{var_to_member_index} = {};
	$self->{members_array} = [];
	$self->initialize_quest_condition;
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;

	$self->initialize_simple_quest_id_condition;

	my $var_exists_hash = {};
	my @members = split(/\s*,\s*/, $condition_code);
	foreach my $member_index (0..$#members) {
		my $member = $members[$member_index];

		if (my $var = find_variable($member)) {
			if ($var->{display_name} =~ /^\./) {
				$self->{error} = "System variables should not be used in automacros (The ones starting with a dot '.')";
				return 0;
			} else {
				push ( @{ $self->{var_to_member_index}{$var->{display_name}} }, $member_index );
				$self->{members_array}->[$member_index] = undef;
				push(@{$self->{variables}}, $var) unless exists $var_exists_hash->{$var->{display_name}};
				$var_exists_hash->{$var->{display_name}} = undef;
			}
		} elsif ($member =~ /^\d+$/) {
			$self->{members_array}->[$member_index] = $member;
		} else {
			$self->{error} = "List member '".$member."' must be a quest ID or a variable name";
			return 0;
		}
	}

	return 1;
}

sub update_vars {
	my ( $self, $var_name, $var_value ) = @_;
	foreach my $member_index ( @{ $self->{var_to_member_index}{$var_name} } ) {
		if ($var_value =~ /^\d+$/) {
			$self->{members_array}->[$member_index] = $var_value;
		} else {
			$self->{members_array}->[$member_index] = undef;
		}
	}
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;

	if ($callback_type eq 'hook' || $callback_type eq 'recheck') {
		updateQuestConditionStandbyState($self, $callback_type, $callback_name);
	} elsif ($callback_type eq 'variable') {
		$self->update_vars($callback_name, $args);
	}

	$self->check_quests;

	if ($self->{is_on_stand_by} == 1) {
		return $self->SUPER::validate_condition(0);
	}

	return $self->SUPER::validate_condition($self->get_quest_condition_result);
}

sub get_quest_condition_result {
	my ($self) = @_;
	return defined $self->{fulfilled_ID} ? 1 : 0;
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables = {};

	$new_variables->{".".$self->{name}."LastID"} = $self->{fulfilled_ID};
	$new_variables->{".".$self->{name}."LastListIndex"} = $self->{fulfilled_member_index};

	return $new_variables;
}

1;
