package eventMacro::Condition::ConfigKeyNot;

use strict;

use base 'eventMacro::Condition';

use Globals qw( %config );
use eventMacro::Data qw( $general_wider_variable_qr );
use eventMacro::Utilities qw( find_variable );

sub _hooks {
	['configModify','pos_load_config.txt','in_game'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{fulfilled_key} = undef;
	$self->{fulfilled_member_index} = undef;
	$self->{fulfilled_key_value} = undef;
	$self->{fulfilled_wanted_value} = undef;
	$self->{config_keys_member} = {};
	$self->{var_name_to_member_index_key} = {};
	$self->{var_name_to_member_index_value} = {};
	
	$self->{variable_members} = {};
	
	my $var_exists_hash = {};
	
	my $member_counter = 0;
	my @members = split(/\s*,\s*/, $condition_code);
	foreach my $member (@members) {
		my ($key, $value);
		if ($member =~ /^([\w\.]+|$general_wider_variable_qr)\s+(\S.*)$/i) {
			$key = $1;
			$value = $2;
		} else {
			$self->{error} = "List Member '".$member."' must be a pair of 'config key' and 'config value'";
			return 0;
		}

		my $key_is_var = 0;
		if (my $var = find_variable($key)) {
			if ($var =~ /^\./) {
				$self->{error} = "System variables should not be used in automacros (The ones starting with a dot '.')";
				return 0;
			}
			$key_is_var = 1;
			push(@{$self->{var_name_to_member_index_key}{$var->{display_name}}}, $member_counter);
			
			push(@{$self->{variables}}, $var) unless (exists $var_exists_hash->{$var->{display_name}});
			$var_exists_hash->{$var->{display_name}} = undef;
		}
		
		my $value_is_var = 0;
		if (my $var = find_variable($value)) {
			if ($var =~ /^\./) {
				$self->{error} = "System variables should not be used in automacros (The ones starting with a dot '.')";
				return 0;
			}
			$value_is_var = 1;
			push(@{$self->{var_name_to_member_index_value}{$var->{display_name}}}, $member_counter);
			
			push(@{$self->{variables}}, $var) unless (exists $var_exists_hash->{$var->{display_name}});
			$var_exists_hash->{$var->{display_name}} = undef;
		}
		
		if (!$key_is_var && !$value_is_var) {
			push(@{$self->{config_keys_member}->{$key}}, {index => $member_counter, value => $value});
			
		} else {
			if ($key_is_var) {
				$self->{variable_members}{$member_counter}{key} = undef;
			} else {
				$self->{variable_members}{$member_counter}{key} = $key;
			}
			
			if ($value_is_var) {
				$self->{variable_members}{$member_counter}{value} = undef;
			} else {
				$self->{variable_members}{$member_counter}{value} = $value;
			}
			$self->{variable_members}{$member_counter}{active} = 0;
			$self->{variable_members}{$member_counter}{index_in_config_hash} = undef;
			$self->{variable_members}{$member_counter}{index} = $member_counter;
		}
		
	} continue {
		$member_counter++;
	}
}

sub update_vars {
	my ( $self, $var_name, $var_value ) = @_;
	
	my $changed_indexes = {};
	
	foreach my $index (@{$self->{var_name_to_member_index_key}{$var_name}}) {
		if ($self->{variable_members}{$index}{active} == 1) {
			splice(@{$self->{config_keys_member}->{$self->{variable_members}{$index}{key}}}, $self->{variable_members}{$index}{index_in_config_hash}, 1);
			$self->{variable_members}{$index}{active} = 0;
			$self->{variable_members}{$index}{index_in_config_hash} = undef;
		}
		$self->{variable_members}{$index}{key} = $var_value;
		$changed_indexes->{$index} = 1;
	}
	
	foreach my $index (@{$self->{var_name_to_member_index_value}{$var_name}}) {
		if ($self->{variable_members}{$index}{active} == 1) {
			splice(@{$self->{config_keys_member}->{$self->{variable_members}{$index}{key}}}, $self->{variable_members}{$index}{index_in_config_hash}, 1);
			$self->{variable_members}{$index}{active} = 0;
			$self->{variable_members}{$index}{index_in_config_hash} = undef;
		}
		$self->{variable_members}{$index}{value} = $var_value;
		$changed_indexes->{$index} = 1;
	}
	
	foreach my $index (keys %{$changed_indexes}) {
		if (defined $self->{variable_members}{$index}{key} && defined $self->{variable_members}{$index}{value}) {
			push(@{$self->{config_keys_member}->{$self->{variable_members}{$index}{key}}}, {index => $self->{variable_members}{$index}{index}, value => $self->{variable_members}{$index}{value}});
			$self->{variable_members}{$index}{active} = 1;
			$self->{variable_members}{$index}{index_in_config_hash} = $#{$self->{config_keys_member}->{$self->{variable_members}{$index}{key}}};
		}
	}
	
	if (!defined $self->{fulfilled_member_index} || exists $changed_indexes->{$self->{fulfilled_member_index}}) {
		$self->check_keys;
	}

}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'variable') {
		
		$self->update_vars($callback_name, $args);
		
	} elsif ($callback_type eq 'hook') {
		
		if ($callback_name eq 'configModify') {
			
			return $self->SUPER::validate_condition if (defined $self->{fulfilled_key} && $args->{key} ne $self->{fulfilled_key});
			return $self->SUPER::validate_condition if (!defined $self->{fulfilled_key} && !exists $self->{config_keys_member}->{$args->{key}});
			
			$self->check_keys($args->{key}, $args->{val});
			
		} elsif ($callback_name eq 'pos_load_config.txt' || $callback_name eq 'in_game') {
			$self->check_keys;
			
		}
		
	} elsif ($callback_type eq 'recheck') {
		$self->check_keys;
		
	}
	
	return $self->SUPER::validate_condition( (defined $self->{fulfilled_key} ? 1 : 0) );
}

sub check_keys {
	my ($self, $key_from_hook, $value_from_hook) = @_;
	$self->{fulfilled_key} = undef;
	$self->{fulfilled_member_index} = undef;
	$self->{fulfilled_key_value} = undef;
	$self->{fulfilled_wanted_value} = undef;
	foreach my $key (keys %{$self->{config_keys_member}}) {
		my $real_key = get_real_key($key); #when have a label, then key changes, else key is the same
		my $config_key_value;
		if (defined $key_from_hook && $real_key eq $key_from_hook) {
			$config_key_value = (defined $value_from_hook ? $value_from_hook : 'none');
		} else {
			$config_key_value = (!exists $config{$real_key} ? 'none' : (!defined $config{$real_key} ? 'none' : $config{$real_key}));
		}
		foreach my $member (@{$self->{config_keys_member}{$key}}) {
			next unless ($member->{value} ne $config_key_value);
			$self->{fulfilled_key} = $real_key;
			$self->{fulfilled_member_index} = $member->{index};
			$self->{fulfilled_key_value} = $config_key_value;
			$self->{fulfilled_wanted_value} = $member->{value};
			last;
		}
		last if (defined $self->{fulfilled_key});
	}
}

sub get_real_key {
	# Basic Support for "label" in blocks. Thanks to "piroJOKE" (from Commands.pm, sub cmdConf)
	$_[0] =~ s/\.+/\./; # Filter Out unnecessary dot's
	my ($label, $param) = split /\./, $_[0], 2; # Split the label from parameter
	foreach (keys %config) {
		if ($_ =~ /_\d+_label/){ # we only need those blocks which have labels
			if ($config{$_} eq $label) {
				my ($real_key, undef) = split /_label/, $_, 2;
				# "<label>.block" param support. Thanks to "vit"
				if ($param ne "block") {
					$real_key .= "_";
					$real_key .= $param;
				}
				return $real_key;
			}
		}
	}
	#if not found any label, return UNchanged key
	return $_[0];
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
			
	$new_variables->{".".$self->{name}."LastKey"} = $self->{fulfilled_key};
	$new_variables->{".".$self->{name}."LastKeyValue"} = $self->{fulfilled_key_value};
	$new_variables->{".".$self->{name}."LastWantedValue"} = $self->{fulfilled_wanted_value};
	$new_variables->{".".$self->{name}."LastMemberIndex"} = $self->{fulfilled_member_index};
	
	return $new_variables;
}

1;
