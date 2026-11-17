#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open ':std', ':encoding(UTF-8)';

# Usage:
#   perl itemdb_equip_yml_to_item_hand_type_txt.pl input.yml output.txt
#
# Example:
#   perl itemdb_equip_yml_to_item_hand_type_txt.pl item_db_equip.yml ../item_hand_type.txt
#
# Requires:
#   cpan YAML::XS
# or
#   cpanm YAML::XS

use YAML::XS qw(LoadFile);

my ($infile, $outfile) = @ARGV;

die "Usage: perl $0 <input item_db_equip.yml> <output item_hand_type.txt>\n"
	unless defined $infile && defined $outfile;

my $yaml = LoadFile($infile);

die "Invalid item_db_equip.yml: missing Body section\n"
	unless ref($yaml) eq 'HASH' && ref($yaml->{Body}) eq 'ARRAY';

open my $out, '>', $outfile
	or die "Cannot open output file '$outfile': $!\n";

my %valid_weapon_types = map { $_ => 1 } qw(
	Fist
	Dagger
	1hSword
	2hSword
	1hSpear
	2hSpear
	1hAxe
	2hAxe
	Mace
	2hMace
	Staff
	Bow
	Knuckle
	Musical
	Whip
	Book
	Katar
	Revolver
	Rifle
	Gatling
	Shotgun
	Grenade
	Huuma
	2hStaff
);

my @rows;
for my $item (@{ $yaml->{Body} }) {
	next unless ref($item) eq 'HASH';

	my $id = $item->{Id};
	my $aegis_name = $item->{AegisName};
	my $item_type = $item->{Type};
	next unless defined $id && $id =~ /^\d+$/;
	next unless defined $aegis_name && $aegis_name ne '';
	next unless defined $item_type && $item_type ne '';

	my $hand_type;
	if ($item_type eq 'Weapon') {
		my $sub_type = $item->{SubType};
		if (!defined $sub_type || !$valid_weapon_types{$sub_type}) {
			warn "[itemdb_equip_yml_to_item_hand_type_txt] Item ID $id has unsupported weapon subtype '"
				. (defined $sub_type ? $sub_type : '<empty>')
				. "'; skipping\n";
			next;
		}
		$hand_type = $sub_type;

	} elsif ($item_type eq 'Armor' && ref($item->{Locations}) eq 'HASH' && $item->{Locations}{Left_Hand}) {
		$hand_type = 'Shield';

	} else {
		next;
	}

	push @rows, [$id, $aegis_name, $hand_type];
}

@rows = sort { $a->[0] <=> $b->[0] || $a->[1] cmp $b->[1] } @rows;

print {$out} "# itemID AegisName type\n";
for my $row (@rows) {
	print {$out} join(' ', @{$row}), "\n";
}

close $out;
print "Done. Wrote '$outfile'\n";
