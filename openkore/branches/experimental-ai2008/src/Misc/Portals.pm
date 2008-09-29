package Misc::Portals;

use strict;
use threads;
use threads::shared;
use Globals qw(%portals_lut %portals_los );
use Log qw(message warning error debug);
use Translation qw(T TF);
use Plugins;
use FileParsers;
use Utils::PathFinding;
use Field;
use Misc::Field;
use Exporter;
use base qw(Exporter);

our %EXPORT_TAGS = (
	portals  => [qw(
		compilePortals
		compilePortals_check
		portalExists
		portalExists2)],
);

our @EXPORT = (
	@{$EXPORT_TAGS{portals}},
);

#####################################################
#####################################################
### CATEGORY: Portals Loading, Compiling and Modify.
#####################################################
#####################################################

sub compilePortals {
	my $checkOnly = shift;

	my %mapPortals;
	my %mapSpawns;
	my %missingMap;
	my $pathfinding;
	my @solution;
	my $field;

	lock (%portals_lut);
	lock (%portals_los);

	# Collect portal source and destination coordinates per map
	foreach my $portal (keys %portals_lut) {
		$mapPortals{$portals_lut{$portal}{'source'}{'map'}}{$portal}{'x'} = $portals_lut{$portal}{'source'}{'x'};
		$mapPortals{$portals_lut{$portal}{'source'}{'map'}}{$portal}{'y'} = $portals_lut{$portal}{'source'}{'y'};
		foreach my $dest (keys %{$portals_lut{$portal}{'dest'}}) {
			next if $portals_lut{$portal}{'dest'}{$dest}{'map'} eq '';
			$mapSpawns{$portals_lut{$portal}{'dest'}{$dest}{'map'}}{$dest}{'x'} = $portals_lut{$portal}{'dest'}{$dest}{'x'};
			$mapSpawns{$portals_lut{$portal}{'dest'}{$dest}{'map'}}{$dest}{'y'} = $portals_lut{$portal}{'dest'}{$dest}{'y'};
		}
	}

	$pathfinding = new PathFinding if (!$checkOnly);

	# Calculate LOS values from each spawn point per map to other portals on same map
	foreach my $map (sort keys %mapSpawns) {
		message TF("Processing map %s...\n", $map), "system" unless $checkOnly;
		foreach my $spawn (keys %{$mapSpawns{$map}}) {
			foreach my $portal (keys %{$mapPortals{$map}}) {
				if (not defined $portals_los{$spawn}) {
					if (is_shared(%portals_los)) {
						$portals_los{$spawn} = &share({});
					} else {
						$portals_los{$spawn} = {};
					}
				}
				next if $spawn eq $portal;
				next if $portals_los{$spawn}{$portal} ne '';
				return 1 if $checkOnly;
				if ((!$field || $field->{name} ne $map) && !$missingMap{$map}) {
					eval {
						$field = new Field(name => $map);
					};
					if ($@) {
						$missingMap{$map} = 1;
					}
				}

				my %start = %{$mapSpawns{$map}{$spawn}};
				my %dest = %{$mapPortals{$map}{$portal}};
				Misc::Field::closestWalkableSpot($field, \%start);
				Misc::Field::closestWalkableSpot($field, \%dest);

				$pathfinding->reset(
					start => \%start,
					dest  => \%dest,
					field => $field
					);
				my $count = $pathfinding->runcount;
				$portals_los{$spawn}{$portal} = ($count >= 0) ? $count : 0;
				debug "LOS in $map from $start{x},$start{y} to $dest{x},$dest{y}: $portals_los{$spawn}{$portal}\n";
			}
		}
	}
	return 0 if $checkOnly;

	# Write new portalsLOS.txt
	writePortalsLOS(Settings::getTableFilename("portalsLOS.txt"), \%portals_los);
	message TF("Wrote portals Line of Sight table to '%s'\n", Settings::getTableFilename("portalsLOS.txt")), "system";

	# Print warning for missing fields
	if (%missingMap) {
		warning TF("----------------------------Error Summary----------------------------\n");
		warning TF("Missing: %s.fld\n", $_) foreach (sort keys %missingMap);
		warning TF("Note: LOS information for the above listed map(s) will be inaccurate;\n" .
			"      however it is safe to ignore if those map(s) are not used\n");
		warning TF("----------------------------Error Summary----------------------------\n");
	}
}

sub compilePortals_check {
	return compilePortals(1);
}

sub portalExists {
	my ($map, $r_pos) = @_;
	foreach (keys %portals_lut) {
		if ($portals_lut{$_}{source}{map} eq $map
		    && $portals_lut{$_}{source}{x} == $r_pos->{x}
		    && $portals_lut{$_}{source}{y} == $r_pos->{y}) {
			return $_;
		}
	}
	return;
}

sub portalExists2 {
	my ($src, $src_pos, $dest, $dest_pos) = @_;
	my $srcx = $src_pos->{x};
	my $srcy = $src_pos->{y};
	my $destx = $dest_pos->{x};
	my $desty = $dest_pos->{y};
	my $destID = "$dest $destx $desty";

	foreach (keys %portals_lut) {
		my $entry = $portals_lut{$_};
		if ($entry->{source}{map} eq $src
		 && $entry->{source}{pos}{x} == $srcx
		 && $entry->{source}{pos}{y} == $srcy
		 && $entry->{dest}{$destID}) {
			return $_;
		}
	}
	return;
}

