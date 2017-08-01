package eventMacro::Condition::CartCurrentWeight;

use strict;

use base 'eventMacro::Conditiontypes::NumericConditionState';

use Globals qw( $char );

sub _hooks {
	['cart_ready','cart_info_updated','packet_mapChange','packet/cart_off'];
}

sub _get_val {
    $char->cart->{weight};
}

sub _get_ref_val {
    $char->cart->{weight_max};
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {
		return $self->SUPER::validate_condition(0) if ($callback_name eq 'packet_mapChange' || $callback_name eq 'packet/cart_off');
	} elsif ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
	}
	return $self->SUPER::validate_condition( $self->validator_check );
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $char->cart->{weight};
	$new_variables->{".".$self->{name}."Last"."Percent"} = ($char->cart->{weight} / $char->cart->{weight_max}) * 100;
	
	return $new_variables;
}

1;
