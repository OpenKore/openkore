package eventMacro::Condition::AttackStart;

use strict;
use Globals;
use Utils;

use eventMacro::Data;

use base 'eventMacro::Conditiontypes::ListCondition';

sub _hooks {
	['attack_start'];
}

sub validate_condition {
	my ( $self, $event_name, $args ) = @_;
	
	$self->{id} = $args->{ID};
	
	$self->SUPER::validate_condition($monsters{$self->{id}}{'name'});
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	my $actor = $monsters{$self->{id}};
	
	$new_variables->{".AttackStartLastName"} = $actor->{name};
	$new_variables->{".AttackStartLastPos"} = sprintf("%d %d %s", $actor->{pos_to}{x}, $actor->{pos_to}{y}, $field->baseName);
	$new_variables->{".AttackStartLastDist"} = sprintf("%.1f",distance(calcPosition($actor), calcPosition($char)));
	$new_variables->{".AttackStartLastID"} = $actor->{binID};
	$new_variables->{".AttackStartLastBinID"} = $actor->{binType};
	
	return $new_variables;
}

sub condition_type {
	EVENT_TYPE;
}

1;