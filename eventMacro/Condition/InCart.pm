package eventMacro::Condition::InCart;

use strict;

use base 'eventMacro::Conditiontypes::NumericConditionState';

use Globals qw( $char );

sub _hooks {
	['packet_mapChange','cart_ready','packet/cart_item_added','cart_item_removed','packet/cart_off'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{wanted_name} = undef;
	
	if ($condition_code =~ /"(.+)"\s+(\S.*)/) {
		$self->{wanted_name} = $1;
		$condition_code = $2;
	} else {
		$self->{error} = "Item name must be inside quotation marks and a numeric comparison must be given";
		return 0;
	}
	
	$self->{cart_exists} = 0;
	$self->{is_on_stand_by} = 1;
	
	$self->SUPER::_parse_syntax($condition_code);
}

sub _get_val {
	my ( $self ) = @_;
	$char->cart->sumByName($self->{wanted_name});
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {

		if ($callback_name eq 'packet_mapChange') {
			$self->{fulfilled_binID} = undef;
			$self->{is_on_stand_by} = 1;
			
		} elsif ($callback_name eq 'cart_ready') {
			$self->{cart_exists} = 1;
			$self->{is_on_stand_by} = 0;
			
		} elsif ($callback_name eq 'packet/cart_off') {
			$self->{cart_exists} = 0;
		}
		
	} elsif ($callback_type eq 'variable') {
		$self->update_validator_var($callback_name, $args);
		
	} elsif ($callback_type eq 'recheck') {
		$self->{is_on_stand_by} = 0;
		$self->{cart_exists} = $char->cart->isReady;
	}
	
	if ($self->{is_on_stand_by} == 1 || $self->{cart_exists} == 0) {
		return $self->SUPER::validate_condition(0);
	} else {
		return $self->SUPER::validate_condition( $self->validator_check );
	}
}

sub get_new_variable_list {
	my ($self) = @_;
	my $new_variables;
	
	$new_variables->{".".$self->{name}."Last"} = $self->{wanted_name};
	$new_variables->{".".$self->{name}."LastAmount"} = $char->cart->sumByName($self->{wanted_name});
	
	return $new_variables;
}

1;
