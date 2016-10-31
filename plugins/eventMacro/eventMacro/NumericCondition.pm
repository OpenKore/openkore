package eventMacro::NumericCondition;

use strict;

use base 'eventMacro::Condition';

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	my $v = $self->{validator} = eventMacro::Validator::NumericComparison->new( $condition_code );
	push @{ $self->{variables} }, $v->variables;
	$v->parsed;
}

sub validate_condition_status {
	my ( $self ) = @_;
	$self->{is_Fulfilled} = $self->{validator}->validate( $self->_get_val, $self->_get_ref_val );
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
