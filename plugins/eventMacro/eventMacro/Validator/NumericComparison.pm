package eventMacro::Validator::NumericComparison;

use strict;
use base 'eventMacro::Validator';
use eventMacro::Data qw( $general_wider_variable_qr );
use eventMacro::Utilities qw( find_variable );

my $number_qr = qr/-?\d+(?:\.\d+)?/;

sub parse {
	my ( $self, $str ) = @_;
	$self->{parsed} = $str =~ /^\s*(<|<=|=|==|!=|!|>=|>|)\s*($number_qr%?|$general_wider_variable_qr)(?:\s*\.\.\s*($number_qr%?|$general_wider_variable_qr))?\s*$/o;
	if (!$self->{parsed}) {
		$self->{error} = "There were found no numeric comparison in the condition code";
		return;
	}
	
	$self->{var_name_min} = undef;
	$self->{var_name_max} = undef;
	
	$self->{op}  = $1 || '==';
	
	if (my $var = find_variable($2)) {
		$self->{min} = undef;
		$self->{var_name_min} = $var->{display_name};
		$self->{min_is_pct} = 0;
		$self->{min_is_var} = 1;
		push(@{$self->{var}}, $var);
	} else {
		$self->{min} = $2;
		$self->{min_is_pct} = $self->{min} =~ s/%$//;
		$self->{min_is_var} = 0;
	}
	
	if ( !defined $3 ) {
		$self->{max}        = $self->{min};
		$self->{max_is_var} = $self->{min_is_var};
		$self->{max_is_pct} = $self->{min_is_pct};
		$self->{var_name_max} = $self->{var_name_min};
	} else {
		if (my $var = find_variable($3)) {
			$self->{max} = undef;
			$self->{var_name_max} = $var->{display_name};
			$self->{max_is_pct} = 0;
			$self->{max_is_var} = 1;
			push(@{$self->{var}}, $var) unless ($var->{display_name} eq $self->{var_name_min});
		} else {
			$self->{max} = $3;
			$self->{max_is_pct} = $self->{max} =~ s/%$//;
			$self->{max_is_var} = 0;
		}
	}
	
	if ((defined $self->{var_name_min} && $self->{var_name_min} =~ /^\./) || (defined $self->{var_name_max} && $self->{var_name_max} =~ /^\./)) {
		$self->{error} = "System variables should not be used in automacros (The ones starting with a dot '.')";
		$self->{parsed} = 0;
		return;
	}

	# Normalize some values.
	$self->{op} = '==' if $self->{op} eq '=';
	$self->{op} = '!=' if $self->{op} eq '!';

	$self->{parsed} = 1;
}

sub update_vars {
	my ( $self, $var_name, $var_value ) = @_;
	if ($self->{var_name_min} eq $var_name) {
		$self->{min} = $var_value;
		$self->{min_is_pct} = $self->{min} =~ s/%$//;
	}
	if ($self->{var_name_max} eq $var_name) {
		$self->{max} = $var_value;
		$self->{max_is_pct} = $self->{max} =~ s/%$//;
	}
}

sub validate {
	my ( $self, $value, $ref_value ) = @_;

	my $min = $self->{min_is_pct} ? $self->{min} * $ref_value / 100 : $self->{min};
	my $max = $self->{max_is_pct} ? $self->{max} * $ref_value / 100 : $self->{max};
	
	return 0 unless (defined $min && defined $max);
	
	return (between( $min, $value, $max ) ? 1 : 0) if ($self->{op} eq '==');
	return (!between( $min, $value, $max ) ? 1 : 0) if ($self->{op} eq '!=');
	return ($value < $min ? 1 : 0)  if ($self->{op} eq '<');
	return ($value <= $max ? 1 : 0) if ($self->{op} eq '<=');
	return ($value >= $min ? 1 : 0) if ($self->{op} eq '>=');
	return ($value > $max ? 1 : 0)  if ($self->{op} eq '>');

    # Unknown op??!
    return 0;
}

sub between {
	$_[0] <= $_[1] && $_[1] <= $_[2];
}

1;
