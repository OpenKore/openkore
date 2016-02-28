#!/usr/bin/perl
# See http://www.openkore.com/wiki/index.php/Field_file_format
# for information about the file formats.
use strict;

my $i = 0;
foreach my $name (sort(listMaps("."))) {
	$i++;
	print "$i\t$name\n";
	gat2fld("$name.gat", "$name.fld", readWaterLevel("$name.rsw"));
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
# void gat2fld(String gat, String fld, float waterLevel)
#
# Convert a .GAT file to the specifid .FLD file.
sub gat2fld {
	my ($gat, $fld, $waterLevel) = @_;
	my ($in, $out, $data);

	if (!open $in, "<", $gat) {
		print "Cannot open $gat for reading.\n";
		exit 1;
	}
	if (!open $out, ">", $fld) {
		print "Cannot open $fld for writing.\n";
		exit 1;
	}

	binmode $in;
	binmode $out;

	# Read header. Yes we're assuming that maps are never
	# larger than 2^16-1 blocks.
	read($in, $data, 14);
	print $out pack("v", unpack("V", substr($data, 6, 4)));
	print $out pack("v", unpack("V", substr($data, 10, 4)));

	while (read($in, $data, 20)) {
		my ($a, $b, $c, $d) = unpack("f4", $data);
		my $type = unpack("C", substr($data, 16, 1));
		my $averageDepth = ($a + $b + $c + $d) / 4;

		# In contrast to what the if-condition tells you,
		# we're actually checking whether this block
		# is below the map's water level.
		if ($averageDepth > $waterLevel) {
			# Block is below water level.

			if ($type == 0 || $type == 3) {
				# Walkable water
				print $out pack("C", 3);
			} elsif ($type == 1 || $type == 6) {
				# Non-walkable water (not snipable)
				print $out pack("C", 2);
			} elsif ($type == 5) {
				# Non-walkable water (snipable)
				print $out pack("C", 4);
			} else {
				# Unknown
				print $out pack("C", 7);
			}

		} else {
			# Block is above water level
			if ($type < 7) {
				print $out pack("C", $type);
			} else {
				print $out pack("C", 7);
			}
		}
	}

	close $in;
	close $out;
} 
