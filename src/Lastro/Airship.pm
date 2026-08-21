package Lastro::Airship;

use strict;
use warnings;
use Exporter qw(import);

our @EXPORT_OK = qw(isEnabled normalizeMapName chooseRouteMap);

# The Lastro browser client uses the same packet for both free world-map
# transfers and item-consuming interior transfers.  Keep the feature opt-in
# through the server profile so generic kRO servers keep their normal logic.
sub isEnabled {
	my ($server) = @_;
	return $server && $server->{lastroAirship};
}

sub normalizeMapName {
	my ($map) = @_;
	return '' unless defined $map;

	$map =~ s/\.(?:gat|rsw)$//i;
	return lc $map;
}

# When the final destination itself is an allowlisted outdoor map, transfer to
# it directly.  MapRoute's solution only contains portal-source maps, so its
# final destination otherwise would not be considered.  For an interior map,
# walk the route backwards to choose the closest allowlisted outdoor map.
sub chooseRouteMap {
	my ($route, $currentMap, $freeMaps, $destinationMap) = @_;
	return unless ref($route) eq 'ARRAY' && ref($freeMaps) eq 'HASH';

	$currentMap = normalizeMapName($currentMap);
	$destinationMap = normalizeMapName($destinationMap);
	my $routeMap = normalizeMapName($route->[0]{map});
	return unless $routeMap ne '' && $routeMap eq $currentMap;

	return $destinationMap
		if $destinationMap ne '' && $destinationMap ne $currentMap && $freeMaps->{$destinationMap};

	for my $step (reverse @{$route}) {
		next unless ref($step) eq 'HASH';
		my $map = normalizeMapName($step->{map});
		next unless $map ne '' && $map ne $currentMap;
		return $map if $freeMaps->{$map};
	}

	return;
}

1;
