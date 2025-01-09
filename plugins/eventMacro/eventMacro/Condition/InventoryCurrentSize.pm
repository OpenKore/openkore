package eventMacro::Condition::InventoryCurrentSize;

use strict;

use base 'eventMacro::Conditiontypes::NumericConditionState';

use Globals qw( $char );

sub _hooks {
	['inventory_clear','inventory_ready','item_gathered','inventory_item_removed'];
}

sub _get_val {
    $char->inventory->size();
}

sub _get_ref_val {
    return 100;
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		return $self->SUPER::validate_condition(0) if ($callback_name eq 'inventory_clear');
	} elsif ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
	}
	return $self->SUPER::validate_condition( $self->validator_check );
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $char->inventory->size();
	
	return $new_variables;
}

1;
