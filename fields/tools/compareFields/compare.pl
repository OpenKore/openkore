#!/usr/bin/perl
use strict;
use warnings;

use constant {
	TILE_NOWALK => 0,
	TILE_WALK   => 1,
	TILE_SNIPE  => 2,
	TILE_WATER  => 4,
	TILE_CLIFF  => 8,
};

my $DEFAULT_LIMIT = 200;

main();

sub main {
	my %options = parse_args(@ARGV);
	my $left = read_fld2($options{left});
	my $right = read_fld2($options{right});

	print "Comparing '$left->{path}' with '$right->{path}'\n";
	print "Left map : $left->{width} x $left->{height}\n";
	print "Right map: $right->{width} x $right->{height}\n";

	if ($left->{width} != $right->{width} || $left->{height} != $right->{height}) {
		print "Map dimensions differ; comparing only the overlapping area.\n";
	}

	my $comparison = compare_maps($left, $right);
	print_comparison($comparison, $options{limit});
}

sub parse_args {
	my @args = @_;
	my %options = (
		limit => $DEFAULT_LIMIT,
	);

	while (@args) {
		my $arg = shift @args;
		if ($arg eq '--limit') {
			die usage() unless @args;
			my $limit = shift @args;
			die "Invalid --limit value '$limit'.\n" . usage() unless $limit =~ /^\d+$/;
			$options{limit} = $limit;
		} elsif (!$options{left}) {
			$options{left} = $arg;
		} elsif (!$options{right}) {
			$options{right} = $arg;
		} else {
			die "Unexpected argument '$arg'.\n" . usage();
		}
	}

	die usage() unless $options{left} && $options{right};
	return %options;
}

sub usage {
	return "Usage: perl compare.pl <left.fld2> <right.fld2> [--limit N]\n";
}

sub read_fld2 {
	my ($path) = @_;
	open my $fh, '<', $path or die "Cannot open $path for reading: $!\n";
	binmode $fh;

	my $raw = do { local $/; <$fh> };
	close $fh;

	die "$path is too small to be a valid .fld2 file.\n" unless defined $raw && length($raw) >= 4;

	my ($width, $height) = unpack('v2', substr($raw, 0, 4));
	my $expected_tiles = $width * $height;
	my $tile_data = substr($raw, 4);
	my $actual_tiles = length($tile_data);

	die "$path has incomplete tile data. Expected $expected_tiles bytes, got $actual_tiles.\n"
		if $actual_tiles < $expected_tiles;

	if ($actual_tiles > $expected_tiles) {
		print "Warning: $path contains " . ($actual_tiles - $expected_tiles) . " trailing bytes after tile data.\n";
		$tile_data = substr($tile_data, 0, $expected_tiles);
	}

	return {
		path => $path,
		width => $width,
		height => $height,
		tiles => [unpack('C*', $tile_data)],
	};
}

sub compare_maps {
	my ($left, $right) = @_;
	my $compare_width = min($left->{width}, $right->{width});
	my $compare_height = min($left->{height}, $right->{height});

	my @changes;
	my %transition_counts;
	my %row_counts;
	my ($min_x, $min_y, $max_x, $max_y);

	for my $y (0 .. $compare_height - 1) {
		for my $x (0 .. $compare_width - 1) {
			my $left_value = tile_at($left, $x, $y);
			my $right_value = tile_at($right, $x, $y);
			next if $left_value == $right_value;

			push @changes, {
				x => $x,
				y => $y,
				left => $left_value,
				right => $right_value,
			};

			$transition_counts{"$left_value->$right_value"}++;
			$row_counts{$y}++;

			$min_x = $x if !defined $min_x || $x < $min_x;
			$max_x = $x if !defined $max_x || $x > $max_x;
			$min_y = $y if !defined $min_y || $y < $min_y;
			$max_y = $y if !defined $max_y || $y > $max_y;
		}
	}

	my $left_extra = count_extra_cells($left, $compare_width, $compare_height);
	my $right_extra = count_extra_cells($right, $compare_width, $compare_height);

	return {
		left => $left,
		right => $right,
		compare_width => $compare_width,
		compare_height => $compare_height,
		changes => \@changes,
		transition_counts => \%transition_counts,
		row_counts => \%row_counts,
		bounds => defined $min_x ? { min_x => $min_x, min_y => $min_y, max_x => $max_x, max_y => $max_y } : undef,
		left_extra => $left_extra,
		right_extra => $right_extra,
	};
}

sub count_extra_cells {
	my ($map, $compare_width, $compare_height) = @_;
	my $extra = 0;

	for my $y (0 .. $map->{height} - 1) {
		for my $x (0 .. $map->{width} - 1) {
			next if $x < $compare_width && $y < $compare_height;
			$extra++;
		}
	}

	return $extra;
}

sub tile_at {
	my ($map, $x, $y) = @_;
	return $map->{tiles}[($y * $map->{width}) + $x];
}

sub print_comparison {
	my ($comparison, $limit) = @_;
	my $changes = $comparison->{changes};
	my $change_count = scalar @{$changes};

	if (!$change_count && !$comparison->{left_extra} && !$comparison->{right_extra}) {
		print "The two maps are identical.\n";
		return;
	}

	print "Compared area: $comparison->{compare_width} x $comparison->{compare_height}\n";
	print "Changed cells in overlap: $change_count\n";

	if ($comparison->{bounds}) {
		my $bounds = $comparison->{bounds};
		print "Change bounds: x $bounds->{min_x}..$bounds->{max_x}, y $bounds->{min_y}..$bounds->{max_y}\n";
	}

	print "Cells only present on left map: $comparison->{left_extra}\n" if $comparison->{left_extra};
	print "Cells only present on right map: $comparison->{right_extra}\n" if $comparison->{right_extra};

	if (%{ $comparison->{transition_counts} }) {
		print "\nTransition summary:\n";
		foreach my $transition (sort {
			$comparison->{transition_counts}{$b} <=> $comparison->{transition_counts}{$a} || $a cmp $b
		} keys %{ $comparison->{transition_counts} }) {
			my ($left_value, $right_value) = split /->/, $transition, 2;
			printf "  %3d %-23s -> %3d %-23s : %d cells\n",
				$left_value,
				describe_tile($left_value),
				$right_value,
				describe_tile($right_value),
				$comparison->{transition_counts}{$transition};
		}
	}

	if (%{ $comparison->{row_counts} }) {
		print "\nRows with changes:\n";
		foreach my $y (sort { $a <=> $b } keys %{ $comparison->{row_counts} }) {
			print "  y=$y : $comparison->{row_counts}{$y} changed cells\n";
		}
	}

	print "\nChanged cells";
	print " (showing up to $limit)" if $limit;
	print ":\n";

	my $shown = 0;
	foreach my $change (@{$changes}) {
		last if $limit && $shown >= $limit;
		printf "  (%d, %d): %3d %-23s -> %3d %-23s\n",
			$change->{x},
			$change->{y},
			$change->{left},
			describe_tile($change->{left}),
			$change->{right},
			describe_tile($change->{right});
		$shown++;
	}

	if ($limit && $change_count > $limit) {
		print "  ... " . ($change_count - $limit) . " more changed cells omitted\n";
	}
}

sub describe_tile {
	my ($value) = @_;
	my %known = (
		TILE_NOWALK() => 'nowalk',
		TILE_WALK() => 'walk',
		TILE_WATER() => 'water',
		TILE_WALK() | TILE_WATER() => 'walk|water',
		TILE_WATER() | TILE_SNIPE() => 'water|snipe',
		TILE_CLIFF() => 'cliff',
		TILE_CLIFF() | TILE_SNIPE() => 'cliff|snipe',
	);

	return $known{$value} if exists $known{$value};

	my @parts;
	push @parts, 'walk' if ($value & TILE_WALK) == TILE_WALK;
	push @parts, 'snipe' if ($value & TILE_SNIPE) == TILE_SNIPE;
	push @parts, 'water' if ($value & TILE_WATER) == TILE_WATER;
	push @parts, 'cliff' if ($value & TILE_CLIFF) == TILE_CLIFF;

	return @parts ? join('|', @parts) : 'none';
}

sub min {
	return $_[0] < $_[1] ? $_[0] : $_[1];
}
