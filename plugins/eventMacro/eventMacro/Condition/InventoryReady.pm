package eventMacro::Condition::InventoryReady;

use strict;

use base 'eventMacro::Condition';

use Globals qw( $char );

sub _hooks {
	['inventory_clear','inventory_ready'];
}

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{wanted_state} = undef;
	
	if ($condition_code =~ /^(0|1)$/) {
		$self->{wanted_state} = $1;
	} else {
		$self->{error} = "Value '".$condition_code."' Should be '0' or '1'";
		return 0;
	}
	
	return 1;
}

sub validate_condition {
	my ( $self, $callback_type, $callback_name, $args ) = @_;
	
	return $self->SUPER::validate_condition( (($char->inventory->isReady ? 1 : 0) == $self->{wanted_state}) ? 1 : 0 );
}

1;
