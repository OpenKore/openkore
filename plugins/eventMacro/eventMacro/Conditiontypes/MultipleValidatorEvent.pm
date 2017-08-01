package eventMacro::Conditiontypes::MultipleValidatorEvent;

use strict;

use base 'eventMacro::Condition';

use eventMacro::Data;

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	$self->{validators} = [];
	
	my $number_of_modules = scalar keys %{$self->{validators_index}};
	my @validator_modules;
	
	foreach my $module_index (0..($number_of_modules-1)) {
		push (@validator_modules, $self->{validators_index}{$module_index});
	}
	
	my $multi_regex_string = '^\s*';
	foreach my $module (@validator_modules) {
		$multi_regex_string .= '('.$module->new->_get_code_regex.')';
	} continue {
		$multi_regex_string .= '\s*';
	}
	$multi_regex_string .= '$';
	
	my $multi_regex = qr/$multi_regex_string/;
	my @validator_codes;
	
	if ($condition_code =~ /$multi_regex/) {
		no strict;
		foreach my $idx (1..$#-) {
			push (@validator_codes, ${$idx});
		}
		use strict;
	} else {
		$self->{error} = "Multi validator could not parse condition code";
		return 0;
	}
	
	$self->{var_to_validator_index} = {};
	
	foreach my $index (0..(scalar(@validator_modules)-1)) {
		my $validator_module = $validator_modules[$index];
		my $validator_code = $validator_codes[$index];
		my $validator = $validator_module->new( $validator_code );
		if (defined $validator->error) {
			$self->{error} = "Error in multi validator condition, index of validator '".$index."', name of validator '".$validator_module."'.".
			                 "Validator error: '".$validator->error."'";
			return 0;
		} else {
			foreach my $var ( @{ $validator->variables } ) {
				push ( @{ $self->{var_to_validator_index}{$var} }, $index );
				push ( @{ $self->{variables} }, $var );
			}
			push (@{$self->{validators}}, $validator);
		}
	}
}

sub update_validator_var {
	my ( $self, $var_name, $var_value ) = @_;
	foreach my $update_index ( @{ $self->{var_to_validator_index}{$var_name} } ) {
		@{$self->{validators}}[$update_index]->update_vars($var_name, $var_value);
	}
}

sub validator_check{
	my ( $self, $validator_index, $check ) = @_;
	return @{$self->{validators}}[$validator_index]->validate($check);
}

sub condition_type {
	my ($self) = @_;
	EVENT_TYPE;
}

1;
