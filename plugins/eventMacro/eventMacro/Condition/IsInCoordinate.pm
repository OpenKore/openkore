package eventMacro::Condition::IsInCoordinate;

use strict;

use base 'eventMacro::Condition::IsInMapAndCoordinate';

#Use: x1 y1, x2 y2, x3min..x3max y3, x4 y4min..y4max, x5min..x5max y5min..y5max

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	#if $condition_code have other thing besides letters, spaces and commas
	if ($condition_code =~ /[^\d\s,.]+/) {
		$self->{error} = "This Condition only accept coordinates";
		return 0;
	}
	
	$self->SUPER::_parse_syntax( $condition_code );
}

1;
