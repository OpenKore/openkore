package eventMacro::Condition::Base::MsgNameDist;

use strict;
use Globals qw( $field $char);
use Utils qw( distance );

use eventMacro::Data qw( EVENT_TYPE );

use base 'eventMacro::Condition';

sub _hooks {
	[];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{message_validator} = undef;
	$self->{name_validator} = undef;
	$self->{dist_validator} = undef;
	
	$self->{var_in_message} = {};
	$self->{var_in_name} = {};
	$self->{var_in_dist} = {};
	
	my $var_exists_hash = {};
	
	if ($condition_code =~ /^(\/.*?\/\w?)\s+(\/.*?\/\w?)\s+(.*?)$/) {
		my $message_regex = $1;
		my $name_regex = $2;
		my $dist = $3;
		
		unless (defined $message_regex && defined $name_regex) {
			$self->{error} = "Condition code '".$condition_code."' must have a message regex, a name regex and a numeric comparison defined";
			return 0;
		}
		
		my @validators = (
			eventMacro::Validator::RegexCheck->new( $message_regex ),
			eventMacro::Validator::RegexCheck->new( $name_regex ),
			eventMacro::Validator::NumericComparison->new( $dist ),
		);
		
		my @var_setting = (
			$self->{var_in_message},
			$self->{var_in_name},
			$self->{var_in_dist},
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
		$self->{dist_validator} = $validators[2];
		
	} else {
		$self->{error} = "Condition code '".$condition_code."' must have a message regex, a name regex and a numeric comparison defined";
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
	
	if (exists $self->{var_in_dist}{$var_name}) {
		$self->{dist_validator}->update_vars($var_name, $var_value);
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

sub validator_dist_check {
	my ( $self, $check ) = @_;
	return $self->{dist_validator}->validate($check);
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		return $self->SUPER::validate_condition( 0 ) unless $self->validator_message_check( $self->{message} );
		
		return $self->SUPER::validate_condition( 0 ) unless $self->validator_name_check( $self->{source} );
		
		foreach my $actor (@{${$self->{actorList}}->getItems}) {
			next unless ($actor->{name} eq $self->{source});
			$self->{actor} = $actor;
			$self->{dist} = distance($char->{pos_to}, $actor->{pos_to});
		}
		
		return $self->SUPER::validate_condition( 0 ) unless ( defined $self->{dist} && $self->validator_dist_check( $self->{dist} ) );
		
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
	$new_variables->{".".$self->{name}."Last"."Pos"} = sprintf("%d %d %s", $self->{actor}->{pos_to}{x}, $self->{actor}->{pos_to}{y}, $field->baseName);
	$new_variables->{".".$self->{name}."Last"."Dist"} = $self->{dist};
	$new_variables->{".".$self->{name}."Last"."ID"} = $self->{actor}->{binID};
	
	return $new_variables;
}

sub condition_type {
	EVENT_TYPE;
}

1;
