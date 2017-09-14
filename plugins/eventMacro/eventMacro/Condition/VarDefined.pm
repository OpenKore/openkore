package eventMacro::Condition::VarDefined;

use strict;

use base 'eventMacro::Condition';

use eventMacro::Data;
use eventMacro::Utilities qw(find_variable);

sub _parse_syntax {
	my ($self, $condition_code) = @_;

	if ($condition_code =~ /^$general_variable_qr/) {
		
		if ($var =~ /^\./) {
			$self->{error} = "System variables should not be used in automacros (The ones starting with a dot '.')";
			return 0;
		} elsif ($var->{display_name} =~ /^@|^%/) {
			$self->{error} = "This condition doesn't accept variables that start with '@' or '%' (those are used to initialize the variable)";
			return 0;
		} else {
			push ( @{ $self->{variables} }, $var );
		}

	} else {
		$self->{error} = "Variable '".$condition_code."' must be a valid variable name";
		return 0;
	}
	return 1;
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;

	return $self->SUPER::validate_condition( defined $args ? 1 : 0 );
}

1;
