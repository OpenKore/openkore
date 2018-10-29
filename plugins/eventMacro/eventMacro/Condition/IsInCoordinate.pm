package eventMacro::Condition::IsInCoordinate;

use strict;
use Globals qw( $char $field );

use base 'eventMacro::Condition::IsInMapAndCoordinate';

#Use: x1 y1, x2 y2, x3min..x3max y3, x4 y4min..y4max, x5min..x5max y5min..y5max

sub _parse_syntax {
	my ( $self, $condition_code ) = @_;
	
	$self->{is_on_stand_by} = 0;
	
	$self->{fulfilled_coordinate} = undef;
	$self->{fulfilled_member_index} = undef;
	
	$self->{var_to_member_index_coord_x} = {};
	$self->{var_to_member_index_coord_y} = {};
	
	$self->{x_validators} = {};
	$self->{y_validators} = {};
	
	my $var_exists_hash = {};
	
	my $member_index = 0;
	foreach my $member (split(/\s*,\s*/, $condition_code)) {
		my ($coord_x, $coord_y) = split(/\s+/, $member);
		
		unless (defined $coord_x && defined $coord_y) {
			$self->{error} = "List member '".$member."' must have a x and a y coordinate defined";
			return 0;
		}
		
		my $x_validator = eventMacro::Validator::NumericComparison->new( $coord_x );
		
		if (defined $x_validator->error) {
			$self->{error} = $x_validator->error;
			return 0;
		} else {
			my @vars = @{$x_validator->variables};
			foreach my $var (@vars) {
				push ( @{ $self->{var_to_member_index_coord_x}{$var->{display_name}} }, $member_index );
				push ( @{ $self->{variables} }, $var ) unless (exists $var_exists_hash->{$var->{display_name}});
				$var_exists_hash->{$var->{display_name}} = undef;
			}
		}
		
		my $y_validator = eventMacro::Validator::NumericComparison->new( $coord_y );
		
		if (defined $y_validator->error) {
			$self->{error} = $y_validator->error;
			return 0;
		} else {
			my @vars = @{$y_validator->variables};
			foreach my $var (@vars) {
				push ( @{ $self->{var_to_member_index_coord_y}{$var->{display_name}} }, $member_index );
				push ( @{ $self->{variables} }, $var ) unless (exists $var_exists_hash->{$var->{display_name}});
				$var_exists_hash->{$var->{display_name}} = undef;
			}
		}
		
		$self->{x_validators}{$member_index} = $x_validator;
		$self->{y_validators}{$member_index} = $y_validator;
		
	} continue {
		$member_index++;
	}
	
	$self->{index_of_last_validator} = $member_index-1;
	return 1;
}

1;
