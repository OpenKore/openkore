package eventMacro::Validator::RegexCheck;

use strict;
use base 'eventMacro::Validator';
use eventMacro::Data;

sub parse {
	my ( $self, $regex_code ) = @_;
	
	if ($regex_code =~ /^\/(.*?)\/(\w?)$/) {
		$self->{original_regex} = $1;
		$self->{case_insensitive} = !!$2;
		
		my @variables = $self->{original_regex} =~ /(?:^|(?<=[^\\]))\$($variable_qr)/g;
		
		$self->{defined_var_list} = {};
		
		foreach my $var (@variables) {
			next if (exists $self->{defined_var_list}{$var});
			if ($var =~ /^\./) {
				$self->{error} = "System variables should not be used in automacros (The ones starting with a dot '.')";
				$self->{parsed} = 0;
				return;
			}
			$self->{defined_var_list}{$var} = 0;
			push(@{$self->{var}}, $var);
		}
		
		
		$self->{regex_parts} = [];
		$self->{var_to_regex_part_index} = {};
		$self->{undefined_vars} = scalar(@{$self->{var}});
		
		unless ($self->{undefined_vars}) {
			$self->{regex} = $self->{original_regex};
			$self->{parsed} = 1;
			return;
		}
		
		my $part_index = 0;
		my $remaining_regex = $self->{original_regex};
		foreach my $var_index (0..$#{$self->{var}}) {
			my $var = $self->{var}->[$var_index];
			my ($before_var);
			if ($remaining_regex =~ /^(.*?)\$$var(.*?)$/) {
				$before_var = $1;
				$remaining_regex = $2;
			} else {
				$self->{error} = "Could not find detected variable in regex";
				$self->{parsed} = 0;
				return;
			}
			
			if ($before_var ne '') {
				push (@{$self->{regex_parts}}, $before_var);
				$part_index++;
			}
			
			push (@{$self->{var_to_regex_part_index}{$var}}, $part_index);
			push (@{$self->{regex_parts}}, undef);
			$part_index++;
		}
		if ($remaining_regex ne '') {
			push (@{$self->{regex_parts}}, $remaining_regex);
		}
		
		$self->{parsed} = 1;
	} else {
		$self->{error} = "There were found no regex in the condition code";
		$self->{parsed} = 0;
	}
}

sub update_vars {
	my ( $self, $var_name, $var_value ) = @_;
	
	if (defined $var_value && $self->{defined_var_list}{$var_name} == 0) {
		$self->{defined_var_list}{$var_name} = 1;
		$self->{undefined_vars}--;
	} elsif (!defined $var_value && $self->{defined_var_list}{$var_name} == 1) {
		$self->{defined_var_list}{$var_name} = 0;
		$self->{undefined_vars}++;
	}
	
	foreach my $part_index (@{$self->{var_to_regex_part_index}{$var_name}}) {
		$self->{regex_parts}->[$part_index] = $var_value;
 	}
	
	if ($self->{undefined_vars} == 0) {
		$self->{regex} = join('', @{$self->{regex_parts}});
	} else {
		$self->{regex} = undef;
	}
}

sub validate {
	my ( $self, $string ) = @_;
	
	return 0 if ($self->{undefined_vars} > 0);
	
	if ($string =~ /$self->{regex}/ || ($self->{case_insensitive} && $string =~ /$self->{regex}/i)) {
		return 1;
	}
	
	return 0;
}

sub _get_code_regex {
	return '\/.*?\/\w?';
}

1;
