#!/usr/bin/perl
use strict;

my @dir_list = sort(dir_list("./"));
my $i = 0;
foreach my $file (@dir_list) {
	next unless (-f "./$file" && $file =~ /\.gat$/i);
	$i++;
	print "$i\t$file\n";
	gat2fld($file);
}

exit;


sub dir_list {
	opendir(DIR, $_[0]);
	my @list = readdir DIR;
	closedir DIR;
	return @list;
}

sub gat2fld {
	my $file = shift;

	my $out = $file;
	$out =~ s/\.gat$/.fld/i;
	open IN, "< $file";
	open OUT, "> $out";
	binmode IN;

	my $data;
	read(IN, $data, 16);
	print OUT pack("S1", unpack("L1", substr($data, 6, 4)));
	print OUT pack("S1", unpack("L1", substr($data, 10, 4)));
	while (read(IN, $data, 20)) {
		my $temp = unpack("C1", substr($data, 14, 1));
		if ($temp == 116) {
			print OUT pack("C", 0x00);
		} else {
			print OUT substr($data, 14, 1);
		}
	}
	close IN;
	close OUT;
} 
