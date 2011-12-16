#!/usr/bin/perl
# See http://www.openkore.com/wiki/index.php/Field2_file_format
# for information about the file formats.
# fld_to_fld2
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
					TILE_WATER,				# 2) Non-walkable water (not snipable)
					TILE_WALK|TILE_WATER,	# 3) Walkable water
					TILE_WATER|TILE_SNIPE,	# 4) Non-walkable water (snipable)
					TILE_CLIFF|TILE_SNIPE,	# 5) Cliff (snipable)
					TILE_CLIFF);			# 6) Cliff (not snipable)


my $i = 0;
foreach my $name (sort(listMaps("."))) {
	$i++;
	fld_to_fld2("$name.fld", "$name.fld2");
}

sub listMaps {
	my ($dir) = @_;
	my $handle;

	opendir($handle, $dir);
	my @list = grep { /\.fld$/i && -f $_ } readdir $handle;
	closedir $handle;

	foreach my $file (@list) {
		$file =~ s/\.fld$//i;
	}
	return @list;
}
##
# void fld_to_fld2(String fld, String fld2)
#
# Convert a .FLD file to the specified .FLD2 file.
sub fld_to_fld2 {
	my ($fld, $fld2) = @_;
	my ($in, $out, $data);

	if (!open $in, "<", $fld) {
		print "Cannot open $fld for reading.\n";
		exit 1;
	}
	if (!open $out, ">", $fld2) {
		print "Cannot open $fld2 for writing.\n";
		exit 1;
	}

	binmode $in;
	binmode $out;

	# Read fld header.
	read($in, $data, 4);
	my ($width, $height) = unpack("v2", $data);
	my $size = $width * $height;
	# when y = height, we variate x from 0 to width
	# thus, we variate block offset from size - width to size
	my $max_Y = $size - $width;

	print $out pack ("v2", $width, $height);

	my ($y, $x) = (1, 1);
	while (read($in, $data, 1)) {
		my $type = unpack("C", $data);

		# warn us for unknown/new block types
		if ($type > $#TILE_TYPE) {
			print "An unknown blocktype ($type) was found, please report this to the OpenKore devs.\n";
			exit 1;
		# make upper blocks unwalkable
		} elsif ($y > $max_Y ) {
			print $out pack("C", TILE_NOWALK);
		# make rightern blocks unwalkable
		} elsif ($y == $x * $width) {
			$x++;
			print $out pack("C", TILE_NOWALK);
		# convert fld to fld2
		} else {
			print $out pack("C", $TILE_TYPE[$type]);
		}
	$y++;
	}

	close $in;
	close $out;
}