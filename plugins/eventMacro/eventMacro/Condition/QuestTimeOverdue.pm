package eventMacro::Condition::QuestTimeOverdue;

use strict;
use Globals qw( $questList );
use eventMacro::Utilities qw( find_variable );

use base 'eventMacro::Condition';

sub _hooks {
	['quest_all_list_end','quest_all_mission_end','quest_added','quest_update_mission_hunt_end','quest_delete','quest_active'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{fulfilled_ID} = undef;
	$self->{fulfilled_member_index} = undef;
	
	$self->{var_to_member_index} = {};
	$self->{members_array} = [];
	
	$self->{is_on_stand_by} = 1;
	
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
				push(@{$self->{variables}}, $var) unless (exists $var_exists_hash->{$var->{display_name}});
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

sub check_quests {
	my ( $self, $list ) = @_;
	$self->{fulfilled_ID} = undef;
	$self->{fulfilled_member_index} = undef;
	foreach my $member_index ( 0..$#{ $self->{members_array} } ) {
		my $quest_ID = $self->{members_array}->[$member_index];
		next unless (defined $quest_ID);
		next unless (exists $questList->{$quest_ID});
		next unless (exists $questList->{$quest_ID}->{active});
		next unless ($questList->{$quest_ID}->{active});
		next unless (exists $questList->{$quest_ID}->{time_expire});
		next unless ($questList->{$quest_ID}->{time_expire} > 0);
		next unless ($questList->{$quest_ID}->{time_expire} < time);
		
		$self->{fulfilled_ID} = $quest_ID;
		$self->{fulfilled_member_index} = $member_index;
		last;
	}
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		$self->{is_on_stand_by} = 0;
		
	} elsif ($callback_type eq 'variable') {
		$self->update_vars($callback_name, $args);
		
	} elsif ($callback_type eq 'recheck') {
		$self->{is_on_stand_by} = 0;
	}
	
	$self->check_quests;
	
	if ($self->{is_on_stand_by} == 1) {
		return $self->SUPER::validate_condition(0);
	} else {
		return $self->SUPER::validate_condition( (defined $self->{fulfilled_ID} ? 1 : 0) );
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."LastID"} = $self->{fulfilled_ID};
	$new_variables->{".".$self->{name}."LastListIndex"} = $self->{fulfilled_member_index};
	
	return $new_variables;
}

1;
