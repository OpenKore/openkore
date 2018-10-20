package eventMacro::Condition::SkillLevel;

use strict;

use base 'eventMacro::Conditiontypes::NumericConditionState';

use Globals qw( $char );

sub _hooks {
	['packet/skill_update','packet/skills_list','packet/skill_add','packet/skill_delete'];
}

sub _get_val {
	my ( $self ) = @_;
	$char->getSkillLevel( $self->{skill} );
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{wanted_skill_ID_or_handle} = undef;
	
	my $numeric_condition;
	if ($condition_code =~ /^(\S+)\s+(\S.*)$/) {
		$self->{wanted_skill_ID_or_handle} = $1;
		$numeric_condition = $2;
	} else {
		$self->{error} = "Value '".$condition_code."' a pair of skill ID/handle and wanted level";
		return 0;
	}
	
	$self->{skill} = new Skill( auto => $self->{wanted_skill_ID_or_handle} );
	
	$self->SUPER::_parse_syntax($numeric_condition);
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
	}
	
	return $self->SUPER::validate_condition( $self->validator_check );
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."LastName"} = $self->{skill}->getName;
	$new_variables->{".".$self->{name}."LastID"} = $self->{skill}->getIDN;
	$new_variables->{".".$self->{name}."LastHandle"} = $self->{skill}->getHandle;
	$new_variables->{".".$self->{name}."LastLevel"} = $char->getSkillLevel( $self->{skill} );
	
	return $new_variables;
}

1;
