package eventMacro::Condition::NotInMap;

use strict;

use base 'eventMacro::Condition';
use eventMacro::Data;
use eventMacro::Utilities qw(find_variable);

use Globals;

sub _hooks {
	['packet_mapChange'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{wanted_map} = undef;
	
	if (my $var = find_variable($condition_code)) {
		if ($var =~ /^\./) {
			$self->{error} = "System variables should not be used in automacros (The ones starting with a dot '.')";
			return 0;
		}
		$self->{wanted_map} = undef;
		push(@{$self->{variables}}, $var);
		
	} else {
		$self->{wanted_map} = $condition_code;
	}
	
	
	return 1;
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'variable') {
		$self->{wanted_map} = $args;
	}
	
	return unless (defined $self->{wanted_map});
	
	if ($field->baseName ne $self->{wanted_map}) {
		$self->{lastMap} = $field->baseName;
		return $self->SUPER::validate_condition(1);
	} else {
		return $self->SUPER::validate_condition(0);
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $self->{lastMap};
	
	return $new_variables;
}

1;
