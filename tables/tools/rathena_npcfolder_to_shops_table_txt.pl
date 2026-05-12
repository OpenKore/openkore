#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open ':std', ':encoding(UTF-8)';

use File::Basename qw(dirname);
use File::Find qw(find);
use File::Spec;

# Usage:
#   perl rathena_npcfolder_to_shops_table_txt.pl
#   perl rathena_npcfolder_to_shops_table_txt.pl <npc folder> <output file>
#
# Default input:
#   tables/tools/npc
#
# Default output:
#   tables/npc_shops.txt
#
# The script scans all files under the npc folder recursively and extracts
# rAthena NPC shop declarations in the form:
#   <map>,<x>,<y>,<dir>    shop    <name>    <sprite>[,no],<itemid>:<price>,...
#
# For shop entries priced as -1, the script fills the price from the RE item DB
# under tables/tools/re using the item's Buy price, or 2 * Sell when Buy is
# omitted in the YAML.
#
# It writes a flattened CSV-like table:
#   npcmap,npcx,npcy,item1id:item1price,item2id:item2price,etc

my $script_dir = dirname(File::Spec->rel2abs($0));
my $default_npc_dir = File::Spec->catdir($script_dir, 'npc');
my $default_output = File::Spec->catfile(dirname($script_dir), 'npc_shops.txt');
my $default_re_dir = File::Spec->catdir($script_dir, 're');

my $npc_dir = defined $ARGV[0] ? $ARGV[0] : $default_npc_dir;
my $output_file = defined $ARGV[1] ? $ARGV[1] : $default_output;

die "NPC folder not found: '$npc_dir'\n" unless -d $npc_dir;
die "RE item folder not found: '$default_re_dir'\n" unless -d $default_re_dir;

my @files;
my @rows;
my %seen_rows;
my $duplicate_rows = 0;
my $skipped_unplaced_rows = 0;
my $replaced_prices = 0;
my %item_prices = load_item_prices($default_re_dir);

find(
	{
		no_chdir => 1,
		wanted => sub {
			return unless -f $_;
			push @files, $File::Find::name;
		},
	},
	$npc_dir
);

for my $file (sort @files) {
	open my $fh, '<:raw', $file
		or die "Cannot open input file '$file': $!\n";

	my $line_number = 0;
	while (my $line = <$fh>) {
		$line_number++;
		$line =~ s/\x{FEFF}//g;
		$line =~ s/[\r\n]+$//;

		next if $line =~ /^\s*\/\//;
		next if $line =~ /^\s*#/;
		next unless $line =~ /\tshop\t/;

		my ($location, $type, undef, $rest) = split /\t+/, $line, 4;
		next unless defined $rest;
		next unless defined $type && lc($type) eq 'shop';

		my ($map, $x, $y) = parse_location($location);
		if ($map eq '-' || $x eq '-' || $y eq '-') {
			$skipped_unplaced_rows++;
			next;
		}

		my ($items_ref, $replacements) = parse_items($rest, \%item_prices);
		my @items = @$items_ref;
		$replaced_prices += $replacements;
		next unless @items;

		my @row = ($map, $x, $y, @items);
		my $row_key = join(',', @row);
		if ($seen_rows{$row_key}++) {
			$duplicate_rows++;
			next;
		}

		push @rows, \@row;
	}

	close $fh;
}

open my $out, '>', $output_file
	or die "Cannot open output file '$output_file': $!\n";

	print $out "npcmap,npcx,npcy,item1id:item1price,item2id:item2price,etc\n";
	for my $row (@rows) {
		print $out join(',', @$row), "\n";
	}

close $out;

print "Scanned ", scalar(@files), " files under '$npc_dir'\n";
print "Found ", scalar(@rows), " total shops\n";
print "Wrote '$output_file'\n";
print "Skipped $duplicate_rows duplicate rows\n";
print "Skipped $skipped_unplaced_rows unplaced shops\n";
print "Replaced $replaced_prices placeholder prices from RE item DB\n";

sub parse_location {
	my ($location) = @_;

	return ('-', '-', '-') if !defined $location || $location eq '-';

	my ($map, $x, $y) = split /,/, $location, 4;
	$map = defined $map && length $map ? $map : '-';
	$x = defined $x && length $x ? $x : '-';
	$y = defined $y && length $y ? $y : '-';

	return ($map, $x, $y);
}

sub parse_items {
	my ($rest, $item_prices) = @_;

	my @tokens = split /,/, $rest;
	return ([], 0) unless @tokens;

	shift @tokens; # sprite or sprite name
	shift @tokens while @tokens && $tokens[0] !~ /\d+:-?\d+/;

	my $items_text = join(',', @tokens);
	my @items;
	my $replacements = 0;

	while ($items_text =~ /(\d+):(-?\d+)/g) {
		my ($item_id, $price) = ($1, $2);
		if ($price == -1 && exists $item_prices->{$item_id}) {
			$price = $item_prices->{$item_id};
			$replacements++;
		}
		push @items, "$item_id:$price";
	}

	return (\@items, $replacements);
}

sub load_item_prices {
	my ($re_dir) = @_;

	my %prices;
	my @item_files = map { File::Spec->catfile($re_dir, $_) } qw(
		item_db.yml
		item_db_usable.yml
		item_db_equip.yml
		item_db_etc.yml
	);

	for my $file (@item_files) {
		next unless -f $file;

		open my $fh, '<:raw', $file
			or die "Cannot open item DB file '$file': $!\n";

		my ($current_id, $buy, $sell);
		while (my $line = <$fh>) {
			$line =~ s/\x{FEFF}//g;
			$line =~ s/[\r\n]+$//;

			if ($line =~ /^\s*-\s+Id:\s+(\d+)/) {
				store_item_price(\%prices, $current_id, $buy, $sell);
				($current_id, $buy, $sell) = ($1, undef, undef);
			} elsif (defined $current_id && $line =~ /^\s+Buy:\s+(-?\d+)/) {
				$buy = $1;
			} elsif (defined $current_id && $line =~ /^\s+Sell:\s+(-?\d+)/) {
				$sell = $1;
			}
		}

		store_item_price(\%prices, $current_id, $buy, $sell);
		close $fh;
	}

	return %prices;
}

sub store_item_price {
	my ($prices, $item_id, $buy, $sell) = @_;

	return unless defined $item_id;

	if (defined $buy) {
		$prices->{$item_id} = $buy;
	} elsif (defined $sell) {
		$prices->{$item_id} = $sell * 2;
	}
}
