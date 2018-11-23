package eventMacro::Condition::VarValue;

use strict;

use base 'eventMacro::Condition';

use eventMacro::Data qw ( $general_wider_variable_qr );
use eventMacro::Utilities qw( find_variable );

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{members_variables} = undef;
	$self->{members_value} = undef;
	
	my @members = split (/\s*,\s*/, $condition_code);
	foreach my $member (@members) {
		
		if ($member =~ /^($general_wider_variable_qr)/) {
			my $var = find_variable($1);
			if ($var =~ /^\./) {
				$self->{error} = "System variables should not be used in automacros (The ones starting with a dot '.')";
				return 0;
			}
			
			my $regex_name = quotemeta($var->{display_name});
			if ($member =~ /^$regex_name\s+(\S.*?)$/) {
				my $after_var = $1;
				push (@{$self->{members_variables}}, $var->{display_name});
				push (@{$self->{members_value}}, $after_var);
				
			} else {
				$self->{error} = "You must set the wanted var value";
				return 0;
			}
			
			push ( @{ $self->{variables} }, $var );
		
		} else {
			$self->{error} = "There must be a variable on each member (Found: '".$member."')";
			return 0;
		}
	
	}
	return 1;
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	$self->{fullfilled_condition}              = undef;
	$self->{fullfilled_condition_var}          = undef;
	$self->{fullfilled_condition_value}        = undef;
	$self->{fullfilled_condition_member_index} = undef;
	if ($callback_type eq 'variable') {
		for (my $index = 0; $index < @{$self->{members_variables}}; $index++) {
			if ($self->{members_variables}[$index] eq $callback_name) {
				if ($self->{members_value}[$index] eq $args) {
					$self->{fullfilled_condition}              = 1;
					$self->{fullfilled_condition_var}          = $self->{members_variables}[$index];
					$self->{fullfilled_condition_value}        = $self->{members_value}[$index];
					$self->{fullfilled_condition_member_index} = $index;
					last;
				}
			}
		}
	}
	
	return $self->SUPER::validate_condition( defined $self->{fullfilled_condition} ? 1 : 0 );
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."LastValue"}       = $self->{fullfilled_condition_value};
	$new_variables->{".".$self->{name}."LastVar"}         = $self->{fullfilled_condition_var};
	$new_variables->{".".$self->{name}."LastMemberIndex"} = $self->{fullfilled_condition_member_index};
	
	return $new_variables;
}

1;
