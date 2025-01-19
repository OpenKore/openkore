package eventMacro::Condition::JobID;

use strict;

use base 'eventMacro::Condition';

use Globals qw( $char );
use eventMacro::Utilities qw( find_variable );

sub _hooks {
	['Network::Receive::map_changed','in_game','sprite_job_change'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{fulfilled_ID} = undef;
	$self->{fulfilled_member_index} = undef;
	
	$self->{var_to_member_index} = {};
	$self->{members_array} = [];
	
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
			$self->{error} = "List member '".$member."' must be a job ID or a variable name";
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
	
	if ($callback_type eq 'variable') {
		$self->update_vars($callback_name, $args);
	}
	
	$self->check_jobid;
	
	return $self->SUPER::validate_condition( (defined $self->{fulfilled_ID} ? 1 : 0) );
}

sub check_jobid {
	my ($self) = @_;
	$self->{fulfilled_ID} = undef;
	$self->{fulfilled_member_index} = undef;
	foreach my $member_index ( 0..$#{ $self->{members_array} } ) {
		my $jobID = $self->{members_array}->[$member_index];
		next unless ($jobID == $char->{jobID});
		$self->{fulfilled_ID} = $jobID;
		$self->{fulfilled_member_index} = $member_index;
		last;
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $self->{fulfilled_ID};
	$new_variables->{".".$self->{name}."LastListIndex"} = $self->{fulfilled_member_index};
	
	return $new_variables;
}

1;
