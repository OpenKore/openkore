package eventMacro::Condition::SimpleHookEvent;

use strict;

use base 'eventMacro::Condition';

use eventMacro::Data qw( $eventMacro EVENT_TYPE );
use eventMacro::Utilities qw( find_variable );

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;

	foreach my $member (split(/\s*,\s*/, $condition_code)) {
		if (find_variable($member)) {
			$self->{error} = "In this condition no variables are accepted";
			return 0;
		}
		push (@{$self->{hooks}}, $member);
	}

	return 1;
}

sub _hooks {
	[];
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;

	#always true
	$self->{last_hook} = $callback_name;
	$self->{vars} = \%$args;

	return $self->SUPER::validate_condition( 1 );
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;

	$new_variables->{".".$self->{name}."Last"} = $self->{last_hook};

	while ( my( $key, $value ) = each %{$self->{vars}} ) {
		if (ref($value) eq 'ARRAY') {
			$eventMacro->set_full_array(".".$self->{name}."Last".ucfirst($key), \@{$value});
		} elsif (ref($value) eq "HASH") {
			$eventMacro->set_full_hash(".".$self->{name}."Last".ucfirst($key), \%{$value});
		} else {
			$new_variables->{".".$self->{name}."Last".ucfirst($key)} = $value;
		}
	}

	return $new_variables;
}

sub condition_type {
	EVENT_TYPE;
}

1;
