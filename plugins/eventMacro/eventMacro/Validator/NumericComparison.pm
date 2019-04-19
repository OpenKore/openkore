package eventMacro::Validator::NumericComparison;

use strict;
use base 'eventMacro::Validator';
use eventMacro::Data qw( $general_wider_variable_qr $eventMacro);
use eventMacro::Utilities qw( find_variable );

my $number_qr = qr/-?\d+(?:\.\d+)?/;

sub parse {
	my ( $self, $str ) = @_;
	
	my @matches = $str =~ /^\s*(<|<=|=|==|!=|!|>=|>|)\s*($number_qr%?|$general_wider_variable_qr)(?:\s*\.\.\s*($number_qr%?|$general_wider_variable_qr))?\s*$/o;
	$self->{parsed} = scalar @matches;
	
	if (!$self->{parsed}) {
		$self->{error} = "There were found no numeric comparison in the condition code";
		return;
	}
	
	$self->{var_name_min} = undef;
	$self->{var_name_max} = undef;
	
	$self->{op} = $matches[0] || '==';
	
	if (my $var = find_variable($matches[1])) {
		$self->{min} = undef;
		$self->{var_name_min} = $var->{display_name};
		$self->{min_is_pct} = 0;
		$self->{min_is_var} = 1;
		push(@{$self->{var}}, $var);
	} else {
		$self->{min} = $matches[1];
		$self->{min_is_pct} = $self->{min} =~ s/%$//;
		$self->{min_is_var} = 0;
	}
	
	if ( !defined $matches[2] ) {
		$self->{max}        = $self->{min};
		$self->{max_is_var} = $self->{min_is_var};
		$self->{max_is_pct} = $self->{min_is_pct};
		$self->{var_name_max} = $self->{var_name_min};
	} else {
		if (my $var = find_variable($matches[2])) {
			$self->{max} = undef;
			$self->{var_name_max} = $var->{display_name};
			$self->{max_is_pct} = 0;
			$self->{max_is_var} = 1;
			push(@{$self->{var}}, $var) unless ($var->{display_name} eq $self->{var_name_min});
		} else {
			$self->{max} = $matches[2];
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
	
	my ($min, $max);

	if ($self->{min_is_var}) {
		return 0 if scalar @{$self->{var}} <= 0;
		
		$min = $eventMacro->get_var($self->{var}->[0]);
		$min ||= 0;
		
		if ($self->{max_is_var}) {
			$max = (scalar @{$self->{var}} > 1) ? $eventMacro->get_var($self->{var}->[1]) : $eventMacro->get_var($self->{var}->[0]);
			$max ||= 0;
		} else {
			$max = $self->{max};
		}
	} elsif ($self->{max_is_var}) {
		return 0 if scalar @{$self->{var}} <= 0;
		
		$max = $eventMacro->get_var($self->{var}->[0]);
		$max ||= 0;
		
		$min = $self->{min};
	} else {
		$min = $self->{min};
		$max = $self->{max};
	}
	
	$min = $self->{min_is_pct} ? $min * $ref_value / 100 : $min;
	$max = $self->{max_is_pct} ? $max * $ref_value / 100 : $max;
	
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
