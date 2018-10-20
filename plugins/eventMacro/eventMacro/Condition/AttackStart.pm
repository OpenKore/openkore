package eventMacro::Condition::AttackStart;

use strict;
use Globals qw( %monsters $field $char);
use Utils   qw( calcPosition distance );

use base 'eventMacro::Conditiontypes::ListConditionEvent';

sub _hooks {
	['attack_start'];
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		$self->{id} = $args->{ID};
		return $self->SUPER::validate_condition( $self->validator_check($monsters{$self->{id}}{'name'}) );
	} elsif ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	my $actor = $monsters{$self->{id}};
	
	$new_variables->{".".$self->{name}."Last"."Name"} = $actor->{name};
	$new_variables->{".".$self->{name}."Last"."Pos"} = sprintf("%d %d %s", $actor->{pos_to}{x}, $actor->{pos_to}{y}, $field->baseName);
	$new_variables->{".".$self->{name}."Last"."Dist"} = sprintf("%.1f",distance(calcPosition($actor), calcPosition($char)));
	$new_variables->{".".$self->{name}."Last"."ID"} = $actor->{binID};
	$new_variables->{".".$self->{name}."Last"."BinID"} = $actor->{binType};
	
	return $new_variables;
}

1;