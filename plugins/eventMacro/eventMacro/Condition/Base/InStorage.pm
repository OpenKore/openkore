package eventMacro::Condition::Base::InStorage;

use strict;

use base 'eventMacro::Condition::Base::Inventory';

use Globals qw( $char );

sub _hooks {
	['storage_first_session_openning','packet/storage_item_added','storage_item_removed','packet/item_list_end'];
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	if ($callback_type eq 'hook') {

		if ($callback_name eq 'storage_first_session_openning'
			|| ($callback_name eq 'item_list_end' && $args->{type} == 0x2)) # INVTYPE_STORAGE
		{
			$self->{is_on_stand_by} = 0;
		}
	} elsif ($callback_type eq 'recheck') {
		$self->{is_on_stand_by} = $char->storage->wasOpenedThisSession ? 0 : 1;
	}
	
	return $self->SUPER::validate_condition( $callback_type, $callback_name, $args );
}

1;
