package eventMacro::Condition::StatusInactiveHandle;

use strict;
use Globals qw( %statusName $char );

use base 'eventMacro::Condition';
use eventMacro::Utilities qw( find_variable );

sub _hooks {
	['in_game','Actor::setStatus::change'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{fulfilled_handle} = undef;
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
			
		} else {
			$self->{members_array}->[$member_index] = $member;
		}
	}
	
	return 1;
}

sub update_vars {
	my ( $self, $var_name, $var_value ) = @_;
	foreach my $member_index ( @{ $self->{var_to_member_index}{$var_name} } ) {
		$self->{members_array}->[$member_index] = $var_value;
	}
}

sub check_statuses {
	my ( $self, $list ) = @_;
	$self->{fulfilled_handle} = undef;
	$self->{fulfilled_member_index} = undef;
	return unless ($char);
	foreach my $member_index ( 0..$#{ $self->{members_array} } ) {
		my $handle = $self->{members_array}->[$member_index];
		next unless (defined $handle);
		next if (exists $char->{statuses} && exists $char->{statuses}{$handle});
		$self->{fulfilled_handle} = $handle;
		$self->{fulfilled_member_index} = $member_index;
		last;
	}
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
		$self->check_statuses;
		
	} elsif ($callback_type eq 'hook') {
	
		if ($callback_name eq 'Actor::setStatus::change') {
			return ($self->SUPER::validate_condition) unless ($args->{actor_type}->isa('Actor::You'));
			
			if ($self->is_fulfilled) {
				return ($self->SUPER::validate_condition) if ($args->{flag} == 0);
				return ($self->SUPER::validate_condition) if ($args->{handle} ne $self->{fulfilled_handle});
				$self->check_statuses;
				
			} else {
				return ($self->SUPER::validate_condition) if ($args->{flag} == 1);
				$self->check_statuses;
			}
			
		} elsif ($callback_name eq 'in_game') {
			$self->check_statuses;
		}
	} elsif ($callback_type eq 'recheck') {
		$self->check_statuses;
	}
	
	return $self->SUPER::validate_condition( (defined $self->{fulfilled_handle} ? 1 : 0) );
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;

	$new_variables->{".".$self->{name}."LastHandle"} = $self->{fulfilled_handle};
	$new_variables->{".".$self->{name}."LastName"} = (defined $statusName{$self->{fulfilled_handle}} ? $statusName{$self->{fulfilled_handle}} : $self->{fulfilled_handle});
	$new_variables->{".".$self->{name}."LastListIndex"} = $self->{fulfilled_member_index};
	
	return $new_variables;
}

1;
