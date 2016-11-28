package eventMacro::Validator::NumericComparison;

use strict;
use base 'eventMacro::Validator';
use eventMacro::Data;

my $number_qr   = qr/-?\d+(?:\.\d+)?/;
my $variable_qr = qr/\.?[a-zA-Z][a-zA-Z\d]*/;

sub parse {
	my ( $self, $str ) = @_;
	$self->{parsed} = $str =~ /^\s*(<|<=|=|==|!=|!|>=|>|)\s*($number_qr%?|\$($variable_qr))(?:\s*\.\.\s*($number_qr%?|\$($variable_qr)))?\s*$/o;
	if (!$self->{parsed}) {
		$self->{error} = "There were found no numeric comparison in the condition code";
		return;
	}

	$self->{op}  = $1 || '==';
	$self->{min} = $3 || $2;
	$self->{max} = $5 || $4;
	$self->{var} = [ grep {$_} $3, $5 ];

	$self->{min_is_var} = !!$3;
	$self->{max_is_var} = !!$5;
	$self->{min_is_pct} = $self->{min} =~ s/%$//;
	$self->{max_is_pct} = $self->{max} =~ s/%$//;
	
	if (($self->{min_is_var} && $self->{min} =~ /^\./) || ($self->{max_is_var} && $self->{max} =~ /^\./)) {
		$self->{error} = "System variables should not be used in automacros (The ones starting with a dot '.')";
		$self->{parsed} = 0;
		return;
	}

	# Normalize some values.
	$self->{op} = '==' if $self->{op} eq '=';
	$self->{op} = '!=' if $self->{op} eq '!';
	if ( !defined $self->{max} ) {
		$self->{max}        = $self->{min};
		$self->{max_is_var} = $self->{min_is_var};
		$self->{max_is_pct} = $self->{min_is_pct};
	}
	
	if ($self->{min_is_var}) {
		$self->{var_name_min} = $self->{min};
		$self->{min} = undef;
	}
	
	if ($self->{max_is_var}) {
		$self->{var_name_max} = $self->{max};
		$self->{max} = undef;
	}

	$self->{parsed} = 1;
}

sub update_vars {
	my ( $self, $var_name, $var_value ) = @_;
	if ($self->{var_name_min} eq $var_name) {
		$self->{min} = $var_value;
	}
	if ($self->{var_name_max} eq $var_name) {
		$self->{max} = $var_value;
	}
}

sub validate {
	my ( $self, $value, $ref_value ) = @_;

	my $min = $self->{min_is_pct} ? $self->{min} * $ref_value / 100 : $self->{min};
	my $max = $self->{max_is_pct} ? $self->{max} * $ref_value / 100 : $self->{max};

	return between( $min, $value, $max ) if $self->{op} eq '==';
	return !between( $min, $value, $max ) if $self->{op} eq '!=';
	return $value < $min  if $self->{op} eq '<';
	return $value <= $max if $self->{op} eq '<=';
	return $value >= $min if $self->{op} eq '>=';
	return $value > $max  if $self->{op} eq '>';

    # Unknown op??!
    0;
}

sub between {
	$_[0] <= $_[1] && $_[1] <= $_[2];
}

1;
