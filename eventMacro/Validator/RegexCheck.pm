package eventMacro::Validator::RegexCheck;

use strict;
use base 'eventMacro::Validator';
use eventMacro::Data;
use eventMacro::Utilities qw(find_variable);

my $general_variable_qr = qr/\.?[a-zA-Z][a-zA-Z\d]*(?:\[\d+\])?/;

sub parse {
	my ( $self, $regex_code ) = @_;
	
	if ($regex_code =~ /^\/(.*?)\/(\w?)$/) {
		$self->{original_regex} = $1;
		$self->{case_insensitive} = !!$2;
		
		my @variables = $self->{original_regex} =~ /(?:^|(?<=[^\\]))\$($general_variable_qr)/g;
		
		$self->{defined_var_list} = {};
		
		foreach my $variable (@variables) {
			my $var = find_variable($variable);
			if (!defined $var) {
				$self->{error} = "\$general_variable_qr found a variable but Utilities::find_variable didn't, please contact a developer";
				$self->{parsed} = 0;
				return;
			}
			my $var_name = $var->{name};
			next if (exists $self->{defined_var_list}{$var_name});
			if ($var =~ /^\./) {
				$self->{error} = "System variables should not be used in automacros (The ones starting with a dot '.')";
				$self->{parsed} = 0;
				return;
			}
			$self->{defined_var_list}{$var_name} = 0;
			push(@{$self->{var}}, $var);
		}
		
		$self->{var_to_regex_part_index} = {};
		$self->{regex_parts} = [];
		my $part_index = 0;
		my $regex = $self->{original_regex};
		foreach my $var_index (0..$#{$self->{var}}) {
			my $var = $self->{var}->[$var_index]->{name};
			my ($before_var, $regex) = $regex =~ /^(.*)$var(.*)/;
			
			push (@{$self->{regex_parts}}, $before_var);
			$part_index++;
			
			push (@{$self->{var_to_regex_part_index}{$var}}, $part_index);
			push (@{$self->{regex_parts}}, undef);
			$part_index++;
		}
		
		$self->{undefined_vars} = scalar(@{$self->{var}});
		
		$self->{regex} = $self->{original_regex};
		
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
	
	if ($self->{undefined_vars} == 0) {
		foreach my $part_index (@{$self->{var_to_regex_part_index}{$var_name}}) {
			$self->{regex_parts}->[$part_index] = $var_value;
		}
		$self->{regex} = join('', @{$self->{regex_parts}});
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
