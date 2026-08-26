package Lastro::Airship;

use strict;
use warnings;
use Exporter qw(import);

our @EXPORT_OK = qw(
	isEnabled normalizeMapName chooseRouteMap choosePreRouteMap
	normalizeAirshipRequestName resolveMapAliasCandidates
);

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

# Private-airship announcements can expose the client resource name instead
# of the logical server map name, sometimes suffixed with #x#y coordinates.
# Normalize only the user-facing request here; normal route map names keep the
# narrower normalizeMapName behavior above.
sub normalizeAirshipRequestName {
	my ($map) = @_;
	return '' unless defined $map;

	$map =~ s/^\s+|\s+$//g;
	$map =~ s/#\d+#\d+\s*$//;
	$map =~ s/\.(?:gat|gnd|rsw)$//i;
	return lc $map;
}

# LastRO reuses client map resources for several distinct logical server maps
# (for example force_1-3/force_2-3/force_3-3 all render force_map3).  Resolve a
# resource alias backwards through resnametable.txt without inserting fake map
# names into maps.txt.  Only .rsw rows are considered so .gat/.gnd duplicates
# do not produce duplicate candidates, and only logical maps known to maps_lut
# are returned.
sub resolveMapAliasCandidates {
	my ($requestedMap, $maps, $resnametableFile) = @_;
	return [] unless ref($maps) eq 'HASH';

	my $requested = normalizeAirshipRequestName($requestedMap);
	return [] unless $requested ne '';
	return [$requested] if defined $maps->{"$requested.rsw"};
	return [] unless defined $resnametableFile && $resnametableFile ne '';

	open my $handle, '<', $resnametableFile or return [];
	my (@candidates, %seen);
	while (my $line = <$handle>) {
		$line =~ s/\r?\n\z//;
		$line =~ s/^\s+|\s+\z//g;
		next if $line eq '' || $line =~ m{^//};

		my ($logical, $resource) = split /#/, $line;
		next unless defined $logical && defined $resource;
		next unless $logical =~ /\.rsw$/i && $resource =~ /\.rsw$/i;

		my $logicalMap = normalizeMapName($logical);
		my $resourceMap = normalizeMapName($resource);
		next unless $resourceMap eq $requested;
		next unless defined $maps->{"$logicalMap.rsw"};
		next if $seen{$logicalMap}++;
		push @candidates, $logicalMap;
	}
	close $handle;

	return \@candidates;
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
#
# If the current map is already the destination, or is discovered at the same
# or a smaller reverse-BFS depth than the best free gateway, return the current
# map as a sentinel.  The plugin then keeps the native route from the current
# position instead of airshipping backwards and walking the same route again.
sub choosePreRouteMap {
	my ($destinationMap, $currentMap, $freeMaps, $portals) = @_;
	return unless ref($freeMaps) eq 'HASH' && ref($portals) eq 'HASH';

	$destinationMap = normalizeMapName($destinationMap);
	$currentMap = normalizeMapName($currentMap);
	return unless $destinationMap ne '';

	return $currentMap if $currentMap ne '' && $destinationMap eq $currentMap;
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

		return $currentMap if $currentMap ne '' && $next{$currentMap};

		my @free = sort grep { $freeMaps->{$_} } keys %next;
		return $free[0] if @free;

		@frontier = sort keys %next;
	}

	return;
}

1;
