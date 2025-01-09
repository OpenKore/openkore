package eventMacro::Condition::Base::InInventory;

use strict;

use base 'eventMacro::Condition::Base::Inventory';

sub _hooks {
	['inventory_clear','inventory_ready','item_gathered','inventory_item_removed','packet/item_list_end'];
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	
	if ($callback_type eq 'hook') {
		if ($callback_name eq 'inventory_clear') {
			$self->{is_on_stand_by} = 1;

		} elsif ($callback_name eq 'inventory_ready' 
			|| ($callback_name eq 'item_list_end' && $args->{type}== 0x0))  # INVTYPE_INVENTORY
		{
			$self->{is_on_stand_by} = 0;
		}
	} elsif ($callback_type eq 'recheck') {
		$self->{is_on_stand_by} = 0;
	}
	
	return $self->SUPER::validate_condition( $callback_type, $callback_name, $args );
}

1;
