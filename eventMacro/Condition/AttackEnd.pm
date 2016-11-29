package eventMacro::Condition::AttackEnd;

use strict;
use Globals;
use Utils;

use base 'eventMacro::Conditiontypes::ListConditionEvent';

sub _hooks {
	['attack_end'];
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		$self->{id} = $args->{ID};
		$self->SUPER::validate_condition($monsters_old{$self->{id}}{'name'});
	} elsif ($callback_type eq 'variable') {
		$self->SUPER::update_validator_var($callback_name, $args);
		return 0;
	}
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

1;