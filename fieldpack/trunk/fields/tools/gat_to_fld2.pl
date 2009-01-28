#!/usr/bin/perl
# See http://www.openkore.com/wiki/index.php/Field2_file_format
# for information about the file formats.
# gat_to_fld2
use strict;
use constant {
	TILE_NOWALK => 0,
	TILE_WALK => 1,
	TILE_SNIPE => 2,
	TILE_WATER => 4,
	TILE_CLIFF => 8,
};

# conversion (ex. $TILE_TYPE[0] = TILE_WALK = 1), (ex. $TILE_TYPE[1] = TILE_NOWALK = 0)
my @TILE_TYPE = (	TILE_WALK,				# 0) Walkable
					TILE_NOWALK,			# 1) Non-walkable
					TILE_WATER,				# 2) Non-walkable water
					TILE_WALK|TILE_WATER,	# 3) Walkable water
					TILE_WATER|TILE_SNIPE,	# 4) Non-walkable water (snipable)
					TILE_CLIFF|TILE_SNIPE,	# 5) Cliff (snipable)
					TILE_CLIFF,				# 6) Cliff (not snipable)
					TILE_NOWALK);			# 7) Unknown

my $i = 0;
foreach my $name (sort(listMaps("."))) {
	$i++;
	gat_to_fld2("$name.gat", "$name.fld2", readWaterLevel("$name.rsw"));
}

sub listMaps {
	my ($dir) = @_;
	my $handle;

	opendir($handle, $dir);
	my @list = grep { /\.gat$/i && -f $_ } readdir $handle;
	closedir $handle;

	foreach my $file (@list) {
		$file =~ s/\.gat$//i;
	}
	return @list;
}

##
# float readWaterLevel(String rswFile)
#
# Read the map's water level from the corresponding RSW file.
sub readWaterLevel {
	my ($rswFile) = @_;
	my ($f, $buf);

	if (!open($f, "<", $rswFile)) {
		print "Cannot open $rswFile for reading.\n";
		exit 1;
	}
	seek $f, 166, 0;
	read $f, $buf, 4;
	close $f;

	return unpack("f", $buf);
}

##
# void gat_to_fld2(String gat, String fld2, float waterLevel)
#
# Convert a GAT file to the specified FLD2 file.
sub gat_to_fld2 {
	my ($gat, $fld2, $waterLevel) = @_;
	my ($in, $out, $data);

	if (!open $in, "<", $gat) {
		print "Cannot open $gat for reading.\n";
		exit 1;
	}
	if (!open $out, ">", $fld2) {
		print "Cannot open $fld2 for writing.\n";
		exit 1;
	}

	binmode $in;
	binmode $out;

	# Read header. Yes we're assuming that maps are never
	# larger than 2^16-1 blocks.
	read($in, $data, 14);
	my ($width, $height) = unpack("V2", substr($data, 6, 8));
	my $size = $width * $height;

	# when y = height, we variate x from 0 to width
	# thus, we variate block offset from size - width to size
	my $max_Y = $size - $width;

	#print $out pack("v", $index);
	print $out pack ("v2", $width, $height);

	my ($y, $x) = (1, 1);
	while (read($in, $data, 20)) {

		my ($a, $b, $c, $d) = unpack("f4", $data);
		my $type = unpack("C", substr($data, 16, 1));
		my $averageDepth = ($a + $b + $c + $d) / 4;

		# make upper blocks unwalkable
		if ($y > $max_Y ) {
			print $out pack("C", TILE_NOWALK);
		# make rightern blocks unwalkable
		} elsif ($y == $x * $width) {
			$x++;
			print $out pack("C", TILE_NOWALK);

		# In contrast to what the elsif-condition tells you,
		# we're actually checking whether this block
		# is below the map's water level.
		# Block is below water level.
		} elsif ($averageDepth > $waterLevel) {
			# add bitflag water to non-water blocks
			print $out pack("C", (($TILE_TYPE[$type] & TILE_WATER) == TILE_WATER) ? $TILE_TYPE[$type] : $TILE_TYPE[$type]|TILE_WATER);
		# Block is above water level
		} else {
			print $out pack("C", $TILE_TYPE[$type]);
		}
	$y++;
	}

	close $in;
	close $out;
}