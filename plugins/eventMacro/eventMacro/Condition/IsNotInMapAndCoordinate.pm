package eventMacro::Condition::IsNotInMapAndCoordinate;

use strict;
use Globals qw( $char $field );

use base 'eventMacro::Condition::IsInMapAndCoordinate';

sub check_location {
	my ( $self ) = @_;
	my $counter;
	my $found;
	$self->{fulfilled_coordinate} = undef;
	$self->{fulfilled_member_index} = undef;
	foreach my $validator_index (0..$self->{index_of_last_validator}) {
		if (exists $self->{map_validators}{$validator_index}) {
			next unless ( $self->validator_map_check( $validator_index, $field->baseName ) );
		}
		
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
