#!/usr/bin/env perl
# Pathfinding benchmark utility
use strict;
use Getopt::Long;
use IO::Socket;
use Time::HiRes qw(time);
use FindBin;

BEGIN {
	# Add OpenKore modules folder
	unshift @INC, "$FindBin::Bin/../..";
}

my %options = (max => 300);
GetOptions(
	'classic' => \$options{classic},
	'ancient' => \$options{ancient},
	'short'   => \$options{short},
	'avoid'   => \$options{avoid},
	'max=i'   => \$options{max},
	'save=s'  => \$options{save},
	'help'    => \$options{help}
);

if ($options{help}) {
	my $str = <<"		EOF";
		Pathfinding benchmark utility.
		Usage: benchmark.pl [options]

		  --classic      Benchmark the non-pure-XS Tools.so/dll.
		  --ancient      Benchmark AncientTools.so/dll (which is Tools.cpp without
		                 wall avoidance support). This option conflicts with --classic.
		  --short        Calculate short distances.
		  --avoid        Avoid walls.
		  --max=NUM      Repeat calculation NUM times.
		  --save=FILE    Save solution to FILE.
		  --help         Show this message.
		EOF
	$str =~ s/^\t\t//mg;
	print "$str";
	exit;
}

if ($options{classic} && $options{ancient}) {
	print "--classic and --ancient conflict with each other.\n";
	exit;
}
$options{max} = 1 if ($options{save});


############################


if ($options{classic}) {
	eval "use Tools;";
} elsif ($options{ancient}) {
	unshift @INC, $FindBin::Bin;
	require XSLoader;
	XSLoader::load('AncientTools');
} else {
	unshift @INC, "$FindBin::Bin/..", "$FindBin::Bin/../pathfinding";
	eval "use PathFinding;";
}

my %field;
getField("$FindBin::Bin/../../fields/prontera.fld", \%field, !$options{ancient});
my %start;
if ($options{short}) {
	%start = ( x => 282, y => 325 );
} else {
	%start = ( x => 59, y => 55 );
}
my %dest = ( x => 278, y => 354 );
my $weights = createWeights(\%field, \%start, \%dest);

my $begin = time;
my $pathfinding;

if ($options{classic}) {
	for (my $i = 0; $i < $options{max}; $i++) {
		doRouteClassic();
	}

} elsif ($options{ancient}) {
	for (my $i = 0; $i < $options{max}; $i++) {
		doRouteAncient();
	}

} else {
	for (my $i = 0; $i < $options{max}; $i++) {
		doRouteXS();
	}
}

my $diff = time - $begin;
printf "Time spent: %.5f\n", $diff;




############################################

sub createWeights {
	return (chr(255) . chr(1) x 255) unless $options{avoid};
	my ($field, $start, $dest);
	my $weights;
	foreach my $z ( [0,0], [0,1],[1,0],[0,-1],[-1,0], [-1,1],[1,1],[1,-1],[-1,-1] ) {
		next if $field->{'field'}[$start->{'x'}+$$z[0] + $field->{'width'}*($start->{'y'}+$$z[1])];
		$start->{'x'} += $$z[0];
		$start->{'y'} += $$z[1];
		last;
	}
	foreach my $z ( [0,0], [0,1],[1,0],[0,-1],[-1,0], [-1,1],[1,1],[1,-1],[-1,-1] ) {
		next if $field->{'field'}[$dest->{'x'}+$$z[0] + $field->{'width'}*($dest->{'y'}+$$z[1])];
		$dest->{'x'} += $$z[0];
		$dest->{'y'} += $$z[1];
		last;
	}
	my $weights = join '', map chr $_, (255, 8, 7, 6, 5, 4, 3, 2, 1);
	$weights .= chr(1) x (256 - length($weights));
	return $weights;
}

sub doRouteClassic {
	my $SOLUTION_MAX = 5000;
	my $solution = "\0" x ($SOLUTION_MAX*4+4);

	my $session = Tools::CalcPath_init(
		$solution,
		$field{'dstMap'},
		$weights,
		$field{'width'},
		$field{'height'},
		pack("S*", $start{x}, $start{y}),
		pack("S*", $dest{x} , $dest{y}),
		3000);

	my $ret = Tools::CalcPath_pathStep($session);
	Tools::CalcPath_destroy($session);

	my $size = unpack("L", substr($solution, 0, 4));
	my $j = 0;
	my @returnArray;
	for (my $i = ($size-1)*4+4; $i >= 4; $i-=4) {
		$returnArray[$j]{'x'} = unpack("S",substr($solution, $i, 2));
		$returnArray[$j]{'y'} = unpack("S",substr($solution, $i+2, 2));
		$j++;
	}

	if ($options{save}) {
		open(F, ">", $options{save});
		for (my $i = 0; $i < @returnArray; $i++) {
			print F "$returnArray[$i]{x}, $returnArray[$i]{y}\n";
		}
		close F;
	}
}

sub doRouteAncient {
	my $SOLUTION_MAX = 5000;
	my $solution = "\0" x ($SOLUTION_MAX*4+4);

	my $session = AncientTools::CalcPath_init(
		$solution,
		$field{'rawMap'},
		$field{'width'},
		$field{'height'},
		pack("S*", $start{x}, $start{y}),
		pack("S*", $dest{x} , $dest{y}),
		3000);

	my $ret = AncientTools::CalcPath_pathStep($session);
	AncientTools::CalcPath_destroy($session);

	my $size = unpack("L", substr($solution, 0, 4));
	my $j = 0;
	my @returnArray;
	for (my $i = ($size-1)*4+4; $i >= 4; $i-=4) {
		$returnArray[$j]{'x'} = unpack("S",substr($solution, $i, 2));
		$returnArray[$j]{'y'} = unpack("S",substr($solution, $i+2, 2));
		$j++;
	}

	if ($options{save}) {
		open(F, ">", $options{save});
		for (my $i = 0; $i < @returnArray; $i++) {
			print F "$returnArray[$i]{x}, $returnArray[$i]{y}\n";
		}
		close F;
	}
}

sub doRouteXS {
	if (!$pathfinding) {
		$pathfinding = new PathFinding(
			start => \%start,
			dest => \%dest,
			field => \%field,
			weights => \$weights
		);
	} else {
		$pathfinding->reset(
			start => \%start,
			dest => \%dest,
			field => \%field,
			weights => \$weights
		);
	}
	my $ref = $pathfinding->runref();
	if ($options{save}) {
		open(F, ">", $options{save});
		foreach (@{$ref}) {
			print F "$_->{x}, $_->{y}\n";
		}
		close F;
	}
}


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
			@$r_hash{'width', 'height'} = unpack("S1 S1", substr($data, 0, 4, ''));
			close FILE;
		} else {
			local($/);
			$data = <FILE>;
			close FILE;
			@$r_hash{'width', 'height'} = unpack("S1 S1", substr($data, 0, 4, ''));
			$$r_hash{'rawMap'} = $data;
		}
	} else {
		local($/);
		$data = <FILE>;
		close FILE;
		@$r_hash{'width', 'height'} = unpack("S1 S1", substr($data, 0, 4, ''));
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
			$dversion = unpack("xx S1", substr($dist_data, 0, 4, ''));
		}

		my ($dw, $dh) = unpack("S1 S1", substr($dist_data, 0, 4, ''));
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
		print FILE pack("a2 S1", 'V#', 1);
		print FILE pack("S1 S1", @$r_hash{'width', 'height'});
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
