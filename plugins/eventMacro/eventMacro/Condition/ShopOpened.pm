package eventMacro::Condition::ShopOpened;

use strict;

use base 'eventMacro::Condition';

use Globals qw( $shopstarted );

sub _hooks {
	['in_game','shop_sold','shop_sold_long', 'shop_open', 'shop_close', 'packet_mapChange'];
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
	use Log qw(warning);
    warning "shop is open? R: $shopstarted\n";
	return $self->SUPER::validate_condition( ($shopstarted == $self->{wanted_state}) ? 1 : 0 );
}

1;
