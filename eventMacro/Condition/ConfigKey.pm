package eventMacro::Condition::ConfigKey;

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
	$self->{fulfilled_value} = undef;
	$self->{config_keys_member} = {};
	$self->{var_name_to_member_index} = {};
	
	my $var_exists_hash = {};
	
	my $member_counter = 0;
	my @members = split(/\s*,\s*/, $condition_code);
	foreach my $member (@members) {
		my ($key, $value);
		if ($member =~ /^(\w+(?:\d|\w|_)*)\s+(\S.*)$/i) {
			$key = $1;
			$value = $2;
		} else {
			$self->{error} = "List Member '".$member."' must be a pair of 'config key' and 'config value'";
			return 0;
		}
		
		if (my $var = find_variable($value)) {
			if ($var =~ /^\./) {
				$self->{error} = "System variables should not be used in automacros (The ones starting with a dot '.')";
				return 0;
			}
			push(@{$self->{config_keys_member}->{$key}}, {index => $member_counter, value => undef});
			push(@{$self->{var_name_to_member_index}{$var->{name}}}, {key => $key, index => $#{$self->{config_keys_member}->{$key}}});
			push(@{$self->{variables}}, $var) unless (exists $var_exists_hash->{$var->{name}});
			$var_exists_hash->{$var->{name}} = undef;
		} else {
			push(@{$self->{config_keys_member}->{$key}}, {index => $member_counter, value => $value});
		}
		
	} continue {
		$member_counter++;
	}
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'variable') {
		
		my $changed_indexes = {};
		foreach my $member_hash (@{$self->{var_name_to_member_index}{$callback_name}}) {
			my $real_member = $self->{config_keys_member}->{$member_hash->{key}}[$member_hash->{index}];
			$real_member->{value} = $args;
			$changed_indexes->{$real_member->{index}} = undef;
		}
		
		if (!defined $self->{fulfilled_member_index} || exists $changed_indexes->{$self->{fulfilled_member_index}}) {
			$self->check_keys;
		}
		
	} elsif ($callback_type eq 'hook') {
		
		if ($callback_name eq 'configModify') {
			return $self->SUPER::validate_condition if (defined $self->{fulfilled_key} && $args->{key} ne $self->{fulfilled_key});
			return $self->SUPER::validate_condition if (!defined $self->{fulfilled_key} && !exists $self->{config_keys_member}->{$args->{key}});
			
			$self->{fulfilled_key} = undef;
			$self->{fulfilled_member_index} = undef;
			$self->{fulfilled_value} = undef;
			foreach my $member_hash (@{$self->{config_keys_member}->{$args->{key}}}) {
				next unless (defined $member_hash->{value});
				next unless ($args->{val} eq $member_hash->{value});
				$self->{fulfilled_key} = $args->{key};
				$self->{fulfilled_member_index} = $member_hash->{index};
				$self->{fulfilled_value} = $args->{val};
				last;
			}
			
		} elsif ($callback_name eq 'pos_load_config.txt' || $callback_name eq 'in_game') {
			$self->check_keys;
			
		}
		
	} elsif ($callback_type eq 'recheck') {
		$self->check_keys;
		
	}
	return $self->SUPER::validate_condition( (defined $self->{fulfilled_key} ? 1 : 0) );
}

sub check_keys {
	my ($self) = @_;
	$self->{fulfilled_key} = undef;
	$self->{fulfilled_member_index} = undef;
	$self->{fulfilled_value} = undef;
	foreach my $key (keys %{$self->{config_keys_member}}) {
		my $config_key_value = (!exists $config{$key} ? 'none' : (!defined $config{$key} ? 'none' : $config{$key}));
		foreach my $member (@{$self->{config_keys_member}{$key}}) {
			next unless (defined $member->{value});
			next unless ($member->{value} eq $config_key_value);
			$self->{fulfilled_key} = $key;
			$self->{fulfilled_member_index} = $member->{index};
			$self->{fulfilled_value} = $member->{value};
			last;
		}
		last if (defined $self->{fulfilled_key});
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
			
	$new_variables->{".".$self->{name}."LastKey"} = $self->{fulfilled_key};
	$new_variables->{".".$self->{name}."LastValue"} = $self->{fulfilled_value};
	$new_variables->{".".$self->{name}."LastMemberIndex"} = $self->{fulfilled_member_index};
	
	return $new_variables;
}

1;
