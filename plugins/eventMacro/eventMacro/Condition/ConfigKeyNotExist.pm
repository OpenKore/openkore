package eventMacro::Condition::ConfigKeyNotExist;

use strict;

use base 'eventMacro::Condition';

use Globals;
use eventMacro::Data;
use eventMacro::Utilities qw(find_variable);

sub _hooks {
	['configModify','pos_load_config.txt','in_game'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{fulfilled_key} = undef;
	$self->{fulfilled_member_index} = undef;
	
	$self->{var_to_member_index} = {};
	$self->{members_array} = [];
	
	my $var_exists_hash = {};
	
	my $member_counter = 0;
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

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'variable') {
		$self->update_vars($callback_name, $args);
		$self->check_keys;
		
	} elsif ($callback_type eq 'hook') {
		
		if ($callback_name eq 'configModify') {
			return $self->SUPER::validate_condition if (defined $self->{fulfilled_key} && $args->{key} ne $self->{fulfilled_key});
			return $self->SUPER::validate_condition if (!defined $args->{val});
			
			$self->{fulfilled_key} = undef;
			$self->{fulfilled_member_index} = undef;
			foreach my $member_index ( 0..$#{ $self->{members_array} } ) {
				my $key = $self->{members_array}->[$member_index];
				next unless (defined $key);
				next if (exists $config{$key} || $key eq $args->{key});
				$self->{fulfilled_key} = $key;
				$self->{fulfilled_member_index} = $member_index;
				last;
			}
			
		} else {
			$self->check_keys;
		}
		
	} else {
		$self->check_keys;
	}
	
	return $self->SUPER::validate_condition( (defined $self->{fulfilled_key} ? 1 : 0) );
}

sub check_keys {
	my ( $self, $list ) = @_;
	$self->{fulfilled_key} = undef;
	$self->{fulfilled_member_index} = undef;
	foreach my $member_index ( 0..$#{ $self->{members_array} } ) {
		my $key = $self->{members_array}->[$member_index];
		next unless (defined $key);
		next if (exists $config{$key});
		$self->{fulfilled_key} = $key;
		$self->{fulfilled_member_index} = $member_index;
		last;
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
			
	$new_variables->{".".$self->{name}."LastKey"} = $self->{fulfilled_key};
	$new_variables->{".".$self->{name}."LastMemberIndex"} = $self->{fulfilled_member_index};
	
	return $new_variables;
}

1;
