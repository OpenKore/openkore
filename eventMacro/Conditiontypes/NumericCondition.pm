package eventMacro::Conditiontypes::NumericCondition;

use strict;

use base 'eventMacro::Condition';

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	my $validator = $self->{validator} = eventMacro::Validator::NumericComparison->new( $condition_code );
	if (defined $validator->error) {
		$self->{error} = $validator->error;
	} else {
		push @{ $self->{variables} }, $validator->variables;
	}
	$validator->parsed;
}

sub validate_condition {
	my ( $self ) = @_;
	$self->SUPER::validate_condition( $self->{validator}->validate( $self->_get_val, $self->_get_ref_val ) );
}

# Get the value to compare.
sub _get_val {
	1;
}

# Get the reference value to do percentage comparisons with.
sub _get_ref_val {
	undef;
}

1;
