#!/usr/bin/env perl

use FindBin qw($RealBin);
use lib "$RealBin";
use lib "$RealBin/src";
use lib "$RealBin/src/deps";
use File::Basename;
use strict;

use Pattern;
use BaseFile;
use Globals qw(@patterns $extractor $map_found $base_file);

unless (@ARGV) {
	print "Usage: $0 <Ragexe.exe>\n";
	exit;
}
my $bin_file = shift;

# Load Patterns
@patterns = load_all_patterns();
$base_file = new BaseFile($bin_file);
$base_file->find_pattern(@patterns);

if ((!defined $map_found)||(!defined $extractor)) {
	printf "\nSearch for Packet Len Map failed!"; 
} else {
	printf "\nExtractor generated. Please run: extractor.exe > recvpackets.txt"; 
};

# Load all pattern files
sub load_all_patterns {
	my $dir = "$RealBin/src/Pattern";
	my @return;

	# Read Directory with BaseFile types.
	return if (!opendir(DIR, $dir));
	my @items;
	my @patternfiles;
	@items = readdir DIR;
	closedir DIR;

	# Add all available BaseFile's
	foreach my $file (@items) {
		if (-f "$dir/$file" && $file =~ /\.(pm)$/) {
			$file =~ s/\.(pm)$//;
			push @patternfiles, $file;
		};
	};

	# Load all of them
	my $i; $i = 0;
	while (@patternfiles) {
		my $basefile = shift(@patternfiles);
		my $module = "Pattern::$basefile";

		eval "use $module;";
		if ($@) {
			printf "ERROR: Cannot load BaseFile %s.\nError Message: \n%s", $module, $@;
			next;
		};

		my $pattern_init = UNIVERSAL::can($module, 'new');
		if (!$pattern_init) {
			printf "ERROR: Class %s has no \'new\' subrotine.\n", $module;
			next;
		};

		@return[$i] = $pattern_init->($module);
		$i++;
	};
	return @return;
};



1;
