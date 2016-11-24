package eventMacro::Condition::AttackStartRegex;

use strict;
use Globals;
use Utils;

use eventMacro::Data;

use base 'eventMacro::Conditiontypes::RegexCondition';

sub _hooks {
	['attack_start'];
}

sub validate_condition_status {
	my ( $self, $event_name, $args ) = @_;
	
	$self->{id} = $args->{ID};
	
	$self->SUPER::validate_condition_status($monsters{$self->{id}}{'name'});
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	my $actor = $monsters{$self->{id}};
	
	$new_variables->{".AttackStartRegexLastName"} = $actor->{name};
	$new_variables->{".AttackStartRegexLastPos"} = sprintf("%d %d %s", $actor->{pos_to}{x}, $actor->{pos_to}{y}, $field->baseName);
	$new_variables->{".AttackStartRegexLastDist"} = sprintf("%.1f",distance(calcPosition($actor), calcPosition($char)));
	$new_variables->{".AttackStartRegexLastID"} = $actor->{binID};
	$new_variables->{".AttackStartRegexLastBinID"} = $actor->{binType};
	
	return $new_variables;
}

sub condition_type {
	EVENT_TYPE;
}

1;