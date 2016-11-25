package eventMacro::Validator::RegexCheck;

use strict;
use base 'eventMacro::Validator';
use eventMacro::Data;

my $variable_qr = qr/\.?[a-zA-Z][a-zA-Z\d]*/;

sub parse {
	my ( $self, $regex_code ) = @_;
	
	if ($regex_code =~ /^\/(.*?)\/(\w?)$/) {
		$self->{regex} = $1;
		$self->{case_insensitive} = !!$2;
		
		my @variables = $self->{regex} =~ /(?:^|(?<=[^\\]))\$($variable_qr)/g;
		
		foreach my $var (@variables) {
			if ($var =~ /^\./) {
				$self->{error} = "System variables should not be used in automacros (The ones starting with a dot '.')";
				$self->{parsed} = 0;
				return;
			}
			push(@{$self->{var}}, $var);
		}
		
		$self->{parsed} = 1;
	} else {
		$self->{error} = "There was not found a regex in the condition code";
		$self->{parsed} = 0;
	}
}

sub validate {
	my ( $self, $string ) = @_;
	
	my $current_regex = $self->{regex};
	foreach my $var (@{$self->{var}}) {
		$current_regex =~ s/(?:^|(?<=[^\\]))\$$var/$eventMacro->get_var($var)/e;
	}
	
	
	if ($string =~ /$current_regex/ || ($self->{case_insensitive} && $string =~ /$current_regex/i)) {
		return 1;
	}
	
	return 0;
}

1;
