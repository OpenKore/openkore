package eventMacro::Validator::RegexCheck;

use strict;
use base 'eventMacro::Validator';
use eventMacro::Data;

my $variable_qr = qr/\.?[a-zA-Z][a-zA-Z\d]*/;

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
		
		#If we don't do this and we have vars like '$var' and '$var2' we may end up substituting '$var2' for 'var1value+2'
		@{$self->{var}} = sort { length $a <=> length $b } @{$self->{var}};
		
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
		$self->{regex} = $self->{original_regex};
		foreach my $var (@{$self->{var}}) {
			$self->{regex} =~ s/(?:^|(?<=[^\\]))\$$var/$eventMacro->get_var($var)/e;
		}
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
