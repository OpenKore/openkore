package eventMacro::Condition::BaseMsgNameDist;

use strict;
use Globals;
use Utils;

use eventMacro::Data;

use base 'eventMacro::Conditiontypes::MultipleValidatorEvent';

sub _hooks {
	[];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{validators_index} = {
		0 => 'eventMacro::Validator::RegexCheck',
		1 => 'eventMacro::Validator::RegexCheck',
		2 => 'eventMacro::Validator::NumericComparison'
	};
	
	$self->SUPER::_parse_syntax($condition_code);
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		return $self->SUPER::validate_condition( 0 ) unless $self->validator_check( 0, $self->{message} );
		
		return $self->SUPER::validate_condition( 0 ) unless $self->validator_check( 1, $self->{source} );
		
		foreach my $actor (@{${$self->{actorList}}->getItems}) {
			next unless ($actor->{name} eq $self->{source});
			$self->{actor} = $actor;
			$self->{dist} = distance($char->{pos_to}, $actor->{pos_to});
		}
		
		return $self->SUPER::validate_condition( 0 ) unless ( defined $self->{dist} && $self->validator_check( 2, $self->{dist} ) );
		
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

sub usable {
	0;
}

1;
