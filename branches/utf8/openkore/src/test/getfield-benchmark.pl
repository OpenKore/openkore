#!/usr/bin/env perl
use strict;
use FindBin;
use Time::HiRes qw(time);

my %field;
my $begin = time;
for (my $i = 0; $i < 30; $i++) {
	getField("$FindBin::Bin/../../fields/prontera.fld", \%field, 1);
}
printf "Load field: %.5f\n", time - $begin;

sub getField {
	my $file = shift;
	my $r_hash = shift;
	my $dist_only = shift;
	my $dist_file = $file;

	undef %{$r_hash};
	unless (-e $file) {
		#warning "Could not load field $file - you must install the kore-field pack!\n";
		return 0;
	}

	$dist_file =~ s/\.fld$/.dist/i;

	# Load the .fld file
	($$r_hash{'name'}) = $file =~ m{/?([^/.]*)\.};
	open FILE, "<", $file;
	binmode(FILE);
	my $data;
	if ($dist_only) {
		if (-e $dist_file) {
			read(FILE, $data, 4);
			@$r_hash{'width', 'height'} = unpack("v1 v1", substr($data, 0, 4, ''));
			close FILE;
		} else {
			local($/);
			$data = <FILE>;
			close FILE;
			@$r_hash{'width', 'height'} = unpack("v1 v1", substr($data, 0, 4, ''));
			$$r_hash{'rawMap'} = $data;
		}
	} else {
		local($/);
		$data = <FILE>;
		close FILE;
		@$r_hash{'width', 'height'} = unpack("v1 v1", substr($data, 0, 4, ''));
		$$r_hash{'rawMap'} = $data;
		$$r_hash{'field'} = [unpack("C*", $data)];
	}

	# Load the associated .dist file (distance map)
	if (-e $dist_file) {
		open FILE, "<", $dist_file;
		binmode(FILE);
		my $dist_data;

		{
			local($/);
			$dist_data = <FILE>;
		}
		close FILE;
		my $dversion = 0;
		if (substr($dist_data, 0, 2) eq "V#") {
			$dversion = unpack("xx v1", substr($dist_data, 0, 4, ''));
		}

		my ($dw, $dh) = unpack("v1 v1", substr($dist_data, 0, 4, ''));
		if (
			#version 0 files had a bug when height != width, so keep version 0 files not effected by the bug.
			   $dversion == 0 && $dw == $dh && $$r_hash{'width'} == $dw && $$r_hash{'height'} == $dh
			#version 1 and greater have no know bugs, so just do a minimum validity check.
			|| $dversion >= 1 && $$r_hash{'width'} == $dw && $$r_hash{'height'} == $dh
		) {
			$$r_hash{'dstMap'} = $dist_data;
		}
	}

	# The .dist file is not available; create it
	unless ($$r_hash{'dstMap'}) {
		$$r_hash{'dstMap'} = makeDistMap(@$r_hash{'rawMap', 'width', 'height'});
		open FILE, ">", $dist_file or die "Could not write dist cache file: $!\n";
		binmode(FILE);
		print FILE pack("a2 v1", 'V#', 1);
		print FILE pack("v1 v1", @$r_hash{'width', 'height'});
		print FILE $$r_hash{'dstMap'};
		close FILE;
	}

	return 1;
}

sub makeDistMap {
	my $data = shift;
	my $width = shift;
	my $height = shift;
	for (my $i = 0; $i < length($data); $i++) {
		substr($data, $i, 1, (ord(substr($data, $i, 1)) ? chr(0) : chr(255)));
	}
	my $done = 0;
	until ($done) {
		$done = 1;
		#'push' wall distance right and up
		for (my $y = 0; $y < $height; $y++) {
			for (my $x = 0; $x < $width; $x++) {
				my $i = $y * $width + $x;
				my $dist = ord(substr($data, $i, 1));
				if ($x != $width - 1) {
					my $ir = $y * $width + $x + 1;
					my $distr = ord(substr($data, $ir, 1));
					my $comp = $dist - $distr;
					if ($comp > 1) {
						my $val = $distr + 1;
						$val = 255 if $val > 255;
						substr($data, $i, 1, chr($val));
						$done = 0;
					} elsif ($comp < -1) {
						my $val = $dist + 1;
						$val = 255 if $val > 255;
						substr($data, $ir, 1, chr($val));
						$done = 0;
					}
				}
				if ($y != $height - 1) {
					my $iu = ($y + 1) * $width + $x;
					my $distu = ord(substr($data, $iu, 1));
					my $comp = $dist - $distu;
					if ($comp > 1) {
						my $val = $distu + 1;
						$val = 255 if $val > 255;
						substr($data, $i, 1, chr($val));
						$done = 0;
					} elsif ($comp < -1) {
						my $val = $dist + 1;
						$val = 255 if $val > 255;
						substr($data, $iu, 1, chr($val));
						$done = 0;
					}
				}
			}
		}
		#'push' wall distance left and down
		for (my $y = $height - 1; $y >= 0; $y--) {
			for (my $x = $width - 1; $x >= 0 ; $x--) {
				my $i = $y * $width + $x;
				my $dist = ord(substr($data, $i, 1));
				if ($x != 0) {
					my $il = $y * $width + $x - 1;
					my $distl = ord(substr($data, $il, 1));
					my $comp = $dist - $distl;
					if ($comp > 1) {
						my $val = $distl + 1;
						$val = 255 if $val > 255;
						substr($data, $i, 1, chr($val));
						$done = 0;
					} elsif ($comp < -1) {
						my $val = $dist + 1;
						$val = 255 if $val > 255;
						substr($data, $il, 1, chr($val));
						$done = 0;
					}
				}
				if ($y != 0) {
					my $id = ($y - 1) * $width + $x;
					my $distd = ord(substr($data, $id, 1));
					my $comp = $dist - $distd;
					if ($comp > 1) {
						my $val = $distd + 1;
						$val = 255 if $val > 255;
						substr($data, $i, 1, chr($val));
						$done = 0;
					} elsif ($comp < -1) {
						my $val = $dist + 1;
						$val = 255 if $val > 255;
						substr($data, $id, 1, chr($val));
						$done = 0;
					}
				}
			}
		}
	}
	return $data;
}
