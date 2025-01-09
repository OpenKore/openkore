package eventMacro::Condition::QuestHuntCompleted;

use strict;
use Globals qw( $questList );
use eventMacro::Utilities qw( find_variable );

use base 'eventMacro::Condition';

sub _hooks {
	['quest_all_list_end','quest_all_mission_end','quest_added','quest_update_mission_hunt_end','quest_delete','quest_active'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{fulfilled_quest_id} = undef;
	$self->{fulfilled_mob_id} = undef;
	$self->{fulfilled_member_index} = undef;
	
	$self->{var_to_member_index_quest_id} = {};
	$self->{var_to_member_index_mob_id} = {};
	
	$self->{members_array} = [];
	
	$self->{is_on_stand_by} = 1;
	
	my $var_exists_hash = {};
	
	my @members = split(/\s*,\s*/, $condition_code);
	foreach my $member_index (0..$#members) {
		my $member = $members[$member_index];
		
		my ($quest_id, $mob_id) = split(/\s+/, $member);
		
		unless (defined $quest_id && defined $mob_id) {
			$self->{error} = "List member '".$member."' must have a slot and an ID defined";
			return 0;
		}
		
		if (my $var = find_variable($quest_id)) {
			if ($var->{display_name} =~ /^\./) {
				$self->{error} = "System variables should not be used in automacros (The ones starting with a dot '.')";
				return 0;
			} else {
				push ( @{ $self->{var_to_member_index_quest_id}{$var->{display_name}} }, $member_index );
				$self->{members_array}->[$member_index]{quest_id} = undef;
				push(@{$self->{variables}}, $var) unless (exists $var_exists_hash->{$var->{display_name}});
				$var_exists_hash->{$var->{display_name}} = undef;
			}
			
		} elsif ($quest_id =~ /^\d+$/) {
			$self->{members_array}->[$member_index]{quest_id} = $quest_id;
			
		} else {
			$self->{error} = "List member '".$member."' has an invalid quest ID '".$quest_id."'";
			return 0;
		}
		
		if (my $var = find_variable($mob_id)) {
			if ($var->{display_name} =~ /^\./) {
				$self->{error} = "System variables should not be used in automacros (The ones starting with a dot '.')";
				return 0;
			} else {
				push ( @{ $self->{var_to_member_index_mob_id}{$var->{display_name}} }, $member_index );
				$self->{members_array}->[$member_index]{mob_id} = undef;
				push(@{$self->{variables}}, $var) unless (exists $var_exists_hash->{$var->{display_name}});
				$var_exists_hash->{$var->{display_name}} = undef;
			}
			
		} elsif ($mob_id =~ /^\d+$/) {
			$self->{members_array}->[$member_index]{mob_id} = $mob_id;
			
		} else {
			$self->{error} = "List member '".$member."' has an invalid mob ID '".$mob_id."'";
			return 0;
		}
	}
	
	return 1;
}

sub update_vars {
	my ( $self, $var_name, $var_value ) = @_;
	
	foreach my $member_index ( @{ $self->{var_to_member_index_quest_id}{$var_name} } ) {
		if ($var_value =~ /^\d+$/) {	
			$self->{members_array}->[$member_index]{quest_id} = $var_value;
		} else {
			$self->{members_array}->[$member_index]{quest_id} = undef;
		}
	}
	
	foreach my $member_index ( @{ $self->{var_to_member_index_mob_id}{$var_name} } ) {
		if ($var_value =~ /^\d+$/) {	
			$self->{members_array}->[$member_index]{mob_id} = $var_value;
		} else {
			$self->{members_array}->[$member_index]{mob_id} = undef;
		}
	}
}

sub check_quests {
	my ( $self, $list ) = @_;
	my $found = 0;
	$self->{fulfilled_quest_id} = undef;
	$self->{fulfilled_mob_id} = undef;
	$self->{fulfilled_member_index} = undef;
	foreach my $member_index ( 0..$#{ $self->{members_array} } ) {
		my $quest_ID = $self->{members_array}->[$member_index]{quest_id};
		my $mob_ID = $self->{members_array}->[$member_index]{mob_id};
		
		next unless (defined $quest_ID);
		next unless (defined $mob_ID);
		next unless (exists $questList->{$quest_ID});
		my $quest = $questList->{$quest_ID};
		
		next unless (exists $quest->{active});
		next unless ($quest->{active});
		
		next unless (exists $quest->{missions});
		next unless (keys %{$quest->{missions}});
		
		#my $quest_hunt_ID;
		#my $count;
		#my $goal;
		
		foreach my $key (keys %{$quest->{missions}}) {
			next unless (defined $key);
			my $mission = \%{$quest->{missions}{$key}};
			if ((exists $mission->{mob_id} && $mission->{mob_id} == $mob_ID) || (exists $mission->{hunt_id} && $mission->{hunt_id} == $mob_ID)) {
				next unless (exists $mission->{'mob_count'} && defined $mission->{'mob_count'});
				next unless (exists $mission->{'mob_goal'} && defined $mission->{'mob_goal'});
				next unless ($mission->{'mob_count'} == $mission->{'mob_goal'});
				$found = 1;
				#$quest_hunt_ID = $key;
                #$count = $mission->{'mob_count'};
                #$goal = $mission->{'mob_goal'};
				
				$self->{fulfilled_quest_id} = $quest_ID;
				$self->{fulfilled_mob_id} = $mob_ID;
				$self->{fulfilled_member_index} = $member_index;
			}
			last if ($found);
		}
		last if ($found);
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
		return $self->SUPER::validate_condition( (defined $self->{fulfilled_quest_id} ? 1 : 0) );
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."LastQuestID"} = $self->{fulfilled_quest_id};
	$new_variables->{".".$self->{name}."LastMobID"} = $self->{fulfilled_mob_id};
	$new_variables->{".".$self->{name}."LastListIndex"} = $self->{fulfilled_member_index};
	
	return $new_variables;
}

1;
