package eventMacro::Condition::AttackEnd;

use strict;
use Globals;
use Utils;

use eventMacro::Data;

use base 'eventMacro::Conditiontypes::ListCondition';

sub _hooks {
	['attack_end'];
}

sub validate_condition_status {
	my ( $self, $event_name, $args ) = @_;
	
	$self->{id} = $args->{ID};
	
	$self->SUPER::validate_condition_status(lc($monsters_old{$self->{id}}{'name'}));
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	my $actor = $monsters_old{$self->{id}};
	
	$new_variables->{".AttackEndLastName"} = $actor->{name};
	$new_variables->{".AttackEndLastPos"} = sprintf("%d %d %s", $actor->{pos_to}{x}, $actor->{pos_to}{y}, $field->baseName);
	$new_variables->{".AttackEndLastDist"} = sprintf("%.1f",distance(calcPosition($actor), calcPosition($char)));
	$new_variables->{".AttackEndLastID"} = $actor->{binID};
	$new_variables->{".AttackEndLastBinID"} = $actor->{binType};
	
	return $new_variables;
}

sub condition_type {
	EVENT_TYPE;
}

1;