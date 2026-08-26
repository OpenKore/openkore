package Lastro::Airship;

use strict;
use warnings;
use Exporter qw(import);

our @EXPORT_OK = qw(isEnabled normalizeMapName chooseRouteMap choosePreRouteMap);

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

# Choose a free private-airship destination before MapRoute performs its
# normal cross-map calculation.  Work backwards from the final destination
# through the portal graph, so the first free map found is the one requiring
# the fewest inter-map portal hops after the transfer.
sub choosePreRouteMap {
	my ($destinationMap, $currentMap, $freeMaps, $portals) = @_;
	return unless ref($freeMaps) eq 'HASH' && ref($portals) eq 'HASH';

	$destinationMap = normalizeMapName($destinationMap);
	$currentMap = normalizeMapName($currentMap);
	return unless $destinationMap ne '';

	return $destinationMap if $freeMaps->{$destinationMap};

	my %reverse;
	for my $sourceID (keys %{$portals}) {
		my $entry = $portals->{$sourceID};
		next unless ref($entry) eq 'HASH';
		next unless ref($entry->{source}) eq 'HASH';
		next unless ref($entry->{dest}) eq 'HASH';

		my $sourceMap = normalizeMapName($entry->{source}{map});
		next unless $sourceMap ne '';

		for my $destID (keys %{$entry->{dest}}) {
			my $dest = $entry->{dest}{$destID};
			next unless ref($dest) eq 'HASH';
			next if exists $dest->{enabled} && !$dest->{enabled};

			my $destMap = normalizeMapName($dest->{map});
			next unless $destMap ne '';
			$reverse{$destMap}{$sourceMap} = 1;
		}
	}

	my %visited = ($destinationMap => 1);
	my @frontier = ($destinationMap);

	while (@frontier) {
		my %next;
		for my $map (@frontier) {
			next unless $reverse{$map};
			for my $sourceMap (keys %{$reverse{$map}}) {
				next if $visited{$sourceMap}++;
				$next{$sourceMap} = 1;
			}
		}

		my @free = sort grep { $freeMaps->{$_} } keys %next;
		if (@free) {
			return $currentMap if $currentMap ne '' && grep { $_ eq $currentMap } @free;
			return $free[0];
		}
		@frontier = sort keys %next;
	}

	return;
}

1;
