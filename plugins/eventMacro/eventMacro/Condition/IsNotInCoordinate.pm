package eventMacro::Condition::IsNotInCoordinate;

use strict;
use Globals qw( $char $field );

use base 'eventMacro::Condition::IsInCoordinate';

#Use: x1 y1, x2 y2, x3min..x3max y3, x4 y4min..y4max, x5min..x5max y5min..y5max

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	#if $condition_code have other thing besides letters, spaces and commas
	if ($condition_code =~ /,/) {
		$self->{error} = "You can't use comma separated values on this Condition";
		return 0;
	}
	
	$self->SUPER::_parse_syntax( $condition_code );
}

sub check_location {
	my ( $self ) = @_;
	my $counter;
	my $found;
	$self->{fulfilled_coordinate} = undef;
	$self->{fulfilled_member_index} = undef;
	foreach my $validator_index (0..$self->{index_of_last_validator}) {
		
		if (exists $self->{x_validators}{$validator_index}) {
			next unless ( $self->validator_x_check( $validator_index, $char->{pos_to}{x} ) );
			next unless ( $self->validator_y_check( $validator_index, $char->{pos_to}{y} ) );
		}
		$found = 1;
	}
	if (!defined $found) {
		$self->{fulfilled_coordinate} = sprintf("%d %d %s", $char->{pos_to}{x}, $char->{pos_to}{y}, $field->baseName);
	}
}

1;