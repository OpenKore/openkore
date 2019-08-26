package eventMacro::Condition::InStorageID;

use strict;

use base 'eventMacro::Condition::Base::InStorage';


use eventMacro::Utilities qw( getStorageAmountbyID );

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{wanted} = undef;
	
	if ($condition_code =~ /^(\d+)\s+(\S.*)$/) {
		$self->{wanted} = $1;
		$condition_code = $2;
	} else {
		$self->{error} = "Item ID must and a numeric comparison must be given";
		return 0;
	}
	
	$self->SUPER::_parse_syntax($condition_code);
}

sub _get_val {
	my ( $self ) = @_;
	getStorageAmountbyID($self->{wanted});
}

1;
