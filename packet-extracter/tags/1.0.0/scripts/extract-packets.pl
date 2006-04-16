#!/usr/bin/env perl
# extract-packets.pl by VCL
# Modified a little bit by SnT2k and Rasqual
# Modified to use with W32DSM by Karasu (code commented out; they conflict with the original code)
#
# This was the old packet extractor script, but now it isn't used anymore.
# It's still kept around for archival purposes.

use strict;
use warnings;

my $LINES_BACK_SEARCH_COUNT = 100;

if (@ARGV < 2) {
	print STDERR "No input file given. Usage: extract-packets.pl <ASM> <OUTPUT> [ADDRESS]\n" .
		"  ASM: the disassembled output of ragexe.exe, as generated\n" .
		"       by 'objdump -d -M intel'\n" .
		"  OUTPUT: the filename of the output file to write to.\n" .
		"  ADDRESS: the address of the packet size function. If not given, this program\n" .
		"           will attempt to auto-detect it.\n";
	exit(1);
}

if (!open (F, "< $ARGV[0]")) {
	print STDERR "Unable to open $ARGV[0]\n";
	exit(1);
}

my $addr;

if (!$ARGV[2]) {
	# Look for the address of the function that determines packet sizes.
	my ($found, $lastLine);
	while ((my $line = <F>)) {
		if ($line =~ /mov    ecx, dword( ptr )?\[ebp-0C\]/ && $lastLine =~ /E8ED0[0-9]0000/) {
			($found) = $lastLine =~ /^:([A-Z0-9]{8})/;
			($addr) = $lastLine =~ /call ([A-Z0-9]+)/;
			last;
		}
		$lastLine = $line;
	}

	if (!defined($addr)) {
		print STDERR "Address of packet size function not found, trying alternate method.\n";
		my ($matched_187) = 0;
		my ($line_counter) = 0;
		seek(F, 0, 0);
		while (<F>) {
			($line_counter)++;
			# mov dword[ebp-08], 00000187
			if (/mov    DWORD PTR \[ebp-8\],0x187$/ ) {
				($found) = $_ =~ /^  ([a-z0-9]{6}):/;
				($matched_187) = 1;
				last;
			}
		}
		if (($matched_187) == 1) {
			# try to find function prologue in LINES_BACK_SEARCH_COUNT previous lines
			$line_counter -= $LINES_BACK_SEARCH_COUNT;
			seek(F, 0, 0);
			while (<F>) {
				($line_counter)--;
				if (($line_counter) <= 0) {
					if (/push   ebp$/ ) {
						($addr) = $_ =~ /^  ([a-z0-9]{6}):/;
					}
				}
				if (($line_counter) == -$LINES_BACK_SEARCH_COUNT) {
					last;
				}
			}
		}
		if (!defined($addr)) {
			print STDERR "Address of packet size function not found using alternate method.\n";
			close(F);
			exit(1);
		}
	}


	print STDERR "Packet size function: $addr (found at $found)\n";
} else {
	$addr = $ARGV[2];
}
print STDERR "Extracting function at $addr...\n";

# Go to that address and get the content of the entire function
our @function;
seek(F, 0, 0);
while ((my $line = <F>)) {
	my $stop = 0;
	if ($line =~ /^  $addr:/) {
		while (($line = <F>)) {
			$line =~ s/[\r\n]//sg;
			if ($line =~ /ret /) {
				$stop = 1;
				last;
			}
			push(@function, $line);
		}
	}
	last if ($stop);
}
close(F);

if (@function == 0) {
	print STDERR "Unable to extract packet size function.\n";
	exit (1);
}


# Extract packets
my (%packets, $ebx, $switch);
print STDERR "Extracting packets...\n";

for (my $i = 0; $i < @function; $i++) {
	$_ = $function[$i];
	# We're only interested in 'mov dword' commands
	# mov dword\[(.*?)\], (.*?)
	if (/mov    DWORD PTR \[(.*?)\],(.*?)$/) {
		my $to = $1;
		my $from = $2;

		if ($to =~ /ebp/ && $from =~ /^0x/) {
			# Packet switch
			$switch = sprintf("%04X", hex($from));

		} elsif ($to =~ /eax/) {
			# Packet length
			my $len;
			if ($from eq 'ebx') {
				$len = $ebx;
			} elsif ($from =~ /^0x/) {
				$len = hex($from);
			} else {
				$len = 0;
			}
			$packets{$switch} = $len;
		}

	} elsif (/mov    ebx,(.*?)$/) {
		$ebx = hex($1);
	}
}

open(F, "> $ARGV[1]");
foreach my $key (sort keys %packets) {
	print F "$key $packets{$key}\n";
}
close(F);
print STDERR "Done.\n";
