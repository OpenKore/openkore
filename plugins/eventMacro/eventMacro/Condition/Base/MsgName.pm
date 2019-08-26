package eventMacro::Condition::Base::MsgName;

use strict;

use eventMacro::Data qw( EVENT_TYPE );

use base 'eventMacro::Condition';

sub _hooks {
	[];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{message_validator} = undef;
	$self->{name_validator} = undef;
	
	$self->{var_in_message} = {};
	$self->{var_in_name} = {};
	
	my $var_exists_hash = {};
	
	if ($condition_code =~ /^(\/.*?\/\w?)\s+(.*?)$/) {
		my $message_regex = $1;
		my $name_regex = $2;
		
		unless (defined $message_regex && defined $name_regex) {
			$self->{error} = "Condition code '".$condition_code."' must have a message regex and a name regex defined";
			return 0;
		}
		
		my @validators = (
			eventMacro::Validator::RegexCheck->new( $message_regex ),
			eventMacro::Validator::RegexCheck->new( $name_regex ),
		);
		
		my @var_setting = (
			$self->{var_in_message},
			$self->{var_in_name},
		);
		
		foreach my $validator_index (0..$#validators) {
			my $validator = $validators[$validator_index];
			my $var_hash = $var_setting[$validator_index];
			if (defined $validator->error) {
				$self->{error} = $validator->error;
				return 0;
			} else {
				my @vars = @{$validator->variables};
				foreach my $var (@vars) {
					push ( @{ $self->{variables} }, $var ) unless (exists $var_exists_hash->{$var->{display_name}});
					$var_hash->{$var->{display_name}} = undef;
					$var_exists_hash->{$var->{display_name}} = undef;
				}
			}
		}
		
		$self->{message_validator} = $validators[0];
		$self->{name_validator} = $validators[1];
		
	} else {
		$self->{error} = "Condition code '".$condition_code."' must have a message regex and a name regex defined";
		return 0;
	}
	
	return 1;
}

sub update_validator_var {
	my ( $self, $var_name, $var_value ) = @_;
	
	if (exists $self->{var_in_message}{$var_name}) {
		$self->{message_validator}->update_vars($var_name, $var_value);
	}
	
	if (exists $self->{var_in_name}{$var_name}) {
		$self->{name_validator}->update_vars($var_name, $var_value);
	}
}

sub validator_message_check {
	my ( $self, $check ) = @_;
	return $self->{message_validator}->validate($check);
}

sub validator_name_check {
	my ( $self, $check ) = @_;
	return $self->{name_validator}->validate($check);
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		return $self->SUPER::validate_condition( 0 ) unless $self->validator_message_check( $self->{message} );

		return $self->SUPER::validate_condition( 0 ) unless $self->validator_name_check( $self->{source} );
		
		return $self->SUPER::validate_condition( 1 );
		
	} elsif ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"."Name"} = $self->{source};
	$new_variables->{".".$self->{name}."Last"."Msg"} = $self->{message};
	
	return $new_variables;
}

sub condition_type {
	EVENT_TYPE;
}

1;
