#########################################################################
#  OpenKore - Config File Parsers
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision$
#  $Id$
#
#########################################################################
##
# MODULE DESCRIPTION: Configuration file parsers
#
# This module contains functions for parsing an writing config/* and
# tables/* files.

package FileParsers;

use strict;
use File::Spec;
use Exporter;
use base qw(Exporter);
use Carp;

use Utils;
use Log qw(warning error);

our @ISA = qw(Exporter);
our @EXPORT = qw(
	parseArrayFile
	parseAvoidControl
	parseDataFile
	parseDataFile_lc
	parseDataFile2
	parseItemsControl
	parseNPCs
	parseMonControl
	parsePortals
	parsePortalsLOS
	parsePriority
	parseResponses
	parseROLUT
	parseRODescLUT
	parseROSlotsLUT
	parseSectionedFile
	parseShopControl
	parseSkills
	parseSkillsLUT
	parseSkillsIDLUT
	parseSkillsReverseLUT_lc
	parseSkillsReverseIDLUT_lc
	parseSkillsSPLUT
	parseTimeouts
	writeDataFile
	writeDataFileIntact
	writeDataFileIntact2
	writePortalsLOS
	updateMonsterLUT
	updatePortalLUT
	updateNPCLUT
	);

sub parseArrayFile {
	my $file = shift;
	my $r_array = shift;
	undef @{$r_array};

	open FILE, "< $file";
	my @lines = <FILE>;
	@{$r_array} = scalar(@lines) + 1;
	my $i = 1;
	foreach (@lines) {
		s/[\r\n]//g;
		$r_array->[$i] = $_;
		$i++;
	}
	close FILE;
}

sub parseAvoidControl {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my ($key,@args,$args);
	open FILE, "< $file";

	my $section = "";
	foreach (<FILE>) {
		next if (/^#/);
		s/[\r\n]//g;
		s/\s+$//g;

		next if ($_ eq "");

		if (/^\[(.*)\]$/) {
			$section = $1;
			next;

		} else {
			($key, $args) = $_ =~ /([\s\S]+?)[\s]+(\d+[\s\S]*)/;
			@args = split / /,$args;
			if ($key ne "") {
				$$r_hash{$section}{lc($key)}{'disconnect_on_sight'} = $args[0];
				$$r_hash{$section}{lc($key)}{'teleport_on_sight'} = $args[1];
				$$r_hash{$section}{lc($key)}{'disconnect_on_chat'} = $args[2];
			}
		}
	}
	close FILE;
}

sub parseDataFile {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my ($key,$value);
	open FILE, "< $file";
	foreach (<FILE>) {
		next if (/^#/);
		s/[\r\n]//g;
		s/\s+$//g;
		($key, $value) = $_ =~ /([\s\S]*) ([\s\S]*?)$/;
		if ($key ne "" && $value ne "") {
			$$r_hash{$key} = $value;
		}
	}
	close FILE;
}

sub parseDataFile_lc {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my ($key,$value);
	open FILE, $file;
	foreach (<FILE>) {
		next if (/^#/);
		s/[\r\n]//g;
		s/\s+$//g;
		($key, $value) = $_ =~ /([\s\S]*) ([\s\S]*?)$/;
		if ($key ne "" && $value ne "") {
			$$r_hash{lc($key)} = $value;
		}
	}
	close FILE;
}

sub parseDataFile2 {
	my $file = shift;
	my $r_hash = shift;
	my $no_undef = shift;

	undef %{$r_hash} unless $no_undef;
	my ($key, $value, $inBlock, %blocks);

	open FILE, "< $file";
	foreach (<FILE>) {
		next if (/^[\s\t]*#/);
		s/[\r\n]//g;	# Remove line endings
		s/^[\t\s]*//;	# Remove leading tabs and whitespace
		s/\s+$//g;	# Remove trailing whitespace
		next if ($_ eq "");

		if (!defined $inBlock && /{$/) {
			# Begin of block
			s/ *{$//;
			($key, $value) = $_ =~ /^(.*?) (.*)/;
			$key = $_ if ($key eq '');

			if (!exists $blocks{$key}) {
				$blocks{$key} = 0;
			} else {
				$blocks{$key}++;
			}
			$inBlock = "${key}_$blocks{$key}";
			$r_hash->{$inBlock} = $value;

		} elsif (defined $inBlock && $_ eq "}") {
			# End of block
			undef $inBlock;

		} else {
			# Option
			($key, $value) = $_ =~ /^(.*?) (.*)/;
			if ($key eq "") {
				$key = $_;
				$key =~ s/ *$//;
			}
			$key = "${inBlock}_${key}" if (defined $inBlock);

			if ($key eq "!include") {
				# Process special !include directives
				# The filename can be relative to the current file
				my $f = $value;
				if (!File::Spec->file_name_is_absolute($value) && $value !~ /^\//) {
					if ($file =~ /[\/\\]/) {
						$f = $file;
						$f =~ s/(.*)[\/\\].*/$1/;
						$f = File::Spec->catfile($f, $value);
					} else {
						$f = $value;
					}
				}
				parseDataFile2($f, $r_hash, 1) if (-f $f);

			} else {
				$r_hash->{$key} = $value;
			}
		}
	}
	close FILE;
}

##
# parseShopControl(file, shop)
# file: Filename to parse
# shop: Return hash
#
# Parses a shop control file. The shop control file should have the shop title
# on its first line, followed by "$item\t$price\t$quantity" on subsequent
# lines. Blank lines, or lines starting with "#" are ignored. If $price
# contains commas, then they are checked for syntactical validity (e.g.
# "1,000,000" instead of "1,000,00") to protect the user from entering the
# wrong price. If $quantity is missing, all available will be sold.
#
# Example:
# My Shop!
# Poring Card	1,000
# Andre Card	1,000,000	3
# +8 Chain [3]	500,000
sub parseShopControl {
	my ($file, $shop) = @_;

	%{$shop} = ();
	open(SHOP, $file);

	# Read shop title
	chomp($shop->{title} = <SHOP>);
	$shop->{title} =~ s/[\r\n]//g;

	# Read shop items
	$shop->{items} = [];
	my $linenum = 1;
	my @errors = ();
	foreach (<SHOP>) {
		$linenum++;
		chomp;
		s/[\r\n]//g;
		next if /^$/ || /^#/;

		my ($name, $price, $amount) = split(/\t+/);
		$price =~ s/^\s+//g;
		$amount =~ s/^\s+//g;
		my $real_price = $price;
		$real_price =~ s/,//g;

		my $loc = "Line $linenum: Item '$name'";
		if ($real_price !~ /^\d+$/) {
			push(@errors, "$loc has non-integer price: $price");
		} elsif ($price ne $real_price && formatNumber($real_price) ne $price) {
			push(@errors, "$loc has incorrect comma placement in price: $price");
		} elsif ($real_price < 0) {
			push(@errors, "$loc has non-positive price: $price");
		} elsif ($real_price > 10000000) {
			push(@errors, "$loc has price over 10mil: $price");
		}

		push(@{$shop->{items}}, {name => $name, price => $real_price, amount => $amount});
	}
	close(SHOP);

	if (@errors) {
		%{$shop} = ();

		error("Errors were found in $file:\n");
		foreach (@errors) { error("$_\n"); }
		error("Please correct the above errors and type 'reload $file'.\n");
	}
}

sub parseItemsControl {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my ($key,@args,$args);
	open FILE, "< $file";
	foreach (<FILE>) {
		next if (/^#/);
		s/[\r\n]//g;
		s/\s+$//g;
		($key, $args) = lc($_) =~ /([\s\S]+?) (\d+[\s\S]*)/;
		@args = split / /,$args;
		if ($key ne "") {
			$$r_hash{$key}{'keep'} = $args[0];
			$$r_hash{$key}{'storage'} = $args[1];
			$$r_hash{$key}{'sell'} = $args[2];
			$$r_hash{$key}{'cart_add'} = $args[3];
		}
	}
	close FILE;
}

sub parseNPCs {
	my $file = shift;
	my $r_hash = shift;
	my ($i, $string);
	undef %{$r_hash};
	my ($key,$value);
	open FILE, $file;
	foreach (<FILE>) {
		next if (/^#/);
		s/[\r\n]//g;
		s/\s+/ /g;
		s/\s+$//g;
		my @args = split /\s/, $_;
		if (@args > 4) {
			$$r_hash{$args[0]}{'map'} = $args[1];
			$$r_hash{$args[0]}{'pos'}{'x'} = $args[2];
			$$r_hash{$args[0]}{'pos'}{'y'} = $args[3];
			$string = $args[4];
			for ($i = 5; $i < @args; $i++) {
				$string .= " $args[$i]";
			}
			$$r_hash{$args[0]}{'name'} = $string;
		}
	}
	close FILE;
}

sub parseMonControl {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my ($key,@args,$args);
	open FILE, $file;
	foreach (<FILE>) {
		next if (/^#/);
		s/[\r\n]//g;
		s/\s+$//g;
		($key, $args) = $_ =~ /([\s\S]+?) ([\-\d]+[\s\S]*)/;
		@args = split / /,$args;
		if ($key ne "") {
			$$r_hash{lc($key)}{'attack_auto'} = $args[0];
			$$r_hash{lc($key)}{'teleport_auto'} = $args[1];
			$$r_hash{lc($key)}{'teleport_search'} = $args[2];
			$$r_hash{lc($key)}{'skillcancel_auto'} = $args[3];
		}
	}
	close FILE;
}

sub parsePortals {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	open FILE, "< $file";
	while (my $line = <FILE>) {
		next if $line =~ /^#/;
		$line =~ s/\cM|\cJ//g;
		$line =~ s/\s+/ /g;
		$line =~ s/^\s+|\s+$//g;
		my @args = split /\s/, $line, 8;
		if (@args > 5) {
			my $portal = "$args[0] $args[1] $args[2]";
			my $dest = "$args[3] $args[4] $args[5]";
			$$r_hash{$portal}{'source'}{'ID'} = $portal;
			$$r_hash{$portal}{'source'}{'map'} = $args[0];
			$$r_hash{$portal}{'source'}{'pos'}{'x'} = $args[1];
			$$r_hash{$portal}{'source'}{'pos'}{'y'} = $args[2];
			$$r_hash{$portal}{'dest'}{$dest}{'ID'} = $dest;
			$$r_hash{$portal}{'dest'}{$dest}{'map'} = $args[3];
			$$r_hash{$portal}{'dest'}{$dest}{'pos'}{'x'} = $args[4];
			$$r_hash{$portal}{'dest'}{$dest}{'pos'}{'y'} = $args[5];
			$$r_hash{$portal}{'dest'}{$dest}{'cost'} = $args[6];
			$$r_hash{$portal}{'dest'}{$dest}{'steps'} = $args[7];
		}
	}
	close FILE;
}

sub parsePortalsLOS {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my $key;
	open FILE, $file;
	foreach (<FILE>) {
		next if (/^#/);
		s/[\r\n]//g;
		s/\s+/ /g;
		s/\s+$//g;
		my @args = split /\s/, $_;
		if (@args) {
			my $map = shift @args;
			my $x = shift @args;
			my $y = shift @args;
			for (my $i = 0; $i < @args; $i += 4) {
				$$r_hash{"$map $x $y"}{"$args[$i] $args[$i+1] $args[$i+2]"} = $args[$i+3];
			}
		}
	}
	close FILE;
}

sub parsePriority {
	my $file = shift;
	my $r_hash = shift;
	return unless open (FILE, "< $file");

	my @lines = <FILE>;
	my $pri = $#lines;
	foreach (@lines) {
		next if (/^#/);
		s/[\r\n]//g;
		$$r_hash{lc($_)} = $pri + 1;
		$pri--;
	}
	close FILE;
}

sub parseResponses {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my ($key,$value);
	my $i;
	open FILE, $file;
	foreach (<FILE>) {
		next if (/^#/);
		s/[\r\n]//g;
		($key, $value) = $_ =~ /([\s\S]*?) ([\s\S]*)$/;
		if ($key ne "" && $value ne "") {
			$i = 0;
			while ($$r_hash{"$key\_$i"} ne "") {
				$i++;
			}
			$$r_hash{"$key\_$i"} = $value;
		}
	}
	close FILE;
}

sub parseROLUT {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my @stuff;
	open FILE, $file;
	foreach (<FILE>) {
		s/\r//g;
		next if /^\/\//;
		@stuff = split /#/, $_;
		$stuff[1] =~ s/_/ /g;
		if ($stuff[0] ne "" && $stuff[1] ne "") {
			$$r_hash{$stuff[0]} = $stuff[1];
		}
	}
	close FILE;
}

sub parseRODescLUT {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my $ID;
	my $IDdesc;
	open FILE, $file;
	foreach (<FILE>) {
		s/\r//g;
		if (/^#/) {
			$$r_hash{$ID} = $IDdesc;
			undef $ID;
			undef $IDdesc;
		} elsif (!$ID) {
			($ID) = /([\s\S]+)#/;
		} else {
			$IDdesc .= $_;
			$IDdesc =~ s/\^......//g;
			$IDdesc =~ s/_/--------------/g;
		}
	}
	close FILE;
}

sub parseROSlotsLUT {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my $ID;
	open FILE, $file;
	foreach (<FILE>) {
		if (!$ID) {
			($ID) = /(\d+)#/;
		} else {
			($$r_hash{$ID}) = /(\d+)#/;
			undef $ID;
		}
	}
	close FILE;
}

sub parseSectionedFile {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	open(FILE, "< $file");

	my $section = "";
	foreach (<FILE>) {
		next if (/^#/);
		s/[\r\n]//g;
		s/\s+$//g;
		next if ($_ eq "");

		my $line = $_;
		if (/^\[(.*)\]$/) {
			$section = $1;
			next;
		} else {
			my ($key, $value) = $line =~ /([\s\S]*?) ([\s\S]*)$/;
			$$r_hash{$section}{$key} = $value;
		}
	}
	close FILE;
}

sub parseSkills {
	my ($file, $r_array) = @_;

	# skill ID is numbered starting from 1, not 0
	@{$r_array} = ([undef, undef]);

	open(FILE, "<$file");
	foreach (<FILE>) {
		my ($handle, $name) = split(/#/);
		$name =~ s/_/ /g;
		$name =~ s/ *$//;
		if ($handle ne "" && $name ne "") {
			push(@{$r_array}, [$handle, $name]);
		}
	}
	close(FILE);

	# FIXME: global variable abuse; this assumes that $r_array is
	# \@Skills::skills
	Skills->init();
}

sub parseSkillsLUT {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my @stuff;
	my $i;
	open(FILE, "<$file");
	$i = 1;
	foreach (<FILE>) {
		@stuff = split /#/, $_;
		$stuff[1] =~ s/_/ /g;
		$stuff[1] =~ s/ *$//;
		if ($stuff[0] ne "" && $stuff[1] ne "") {
			$$r_hash{$stuff[0]} = $stuff[1];
		}
		$i++;
	}
	close FILE;
}


sub parseSkillsIDLUT {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my @stuff;
	my $i;
	open(FILE, "<$file");
	$i = 1;
	foreach (<FILE>) {
		@stuff = split /#/, $_;
		$stuff[1] =~ s/_/ /g;
		if ($stuff[0] ne "" && $stuff[1] ne "") {
			$$r_hash{$i} = $stuff[1];
		}
		$i++;
	}
	close FILE;
}

sub parseSkillsReverseIDLUT_lc {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my @stuff;
	my $i;
	open(FILE, "<$file");
	$i = 1;
	foreach (<FILE>) {
		@stuff = split /#/, $_;
		$stuff[1] =~ s/_/ /g;
		if ($stuff[0] ne "" && $stuff[1] ne "") {
			$$r_hash{lc($stuff[1])} = $i;
		}
		$i++;
	}
	close FILE;
}

sub parseSkillsReverseLUT_lc {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my @stuff;
	my $i;
	open(FILE, "< $file");
	$i = 1;
	foreach (<FILE>) {
		@stuff = split /#/, $_;
		$stuff[1] =~ s/_/ /g;
		$stuff[1] =~ s/ *$//;
		if ($stuff[0] ne "" && $stuff[1] ne "") {
			$$r_hash{lc($stuff[1])} = $stuff[0];
		}
		$i++;
	}
	close FILE;
}

sub parseSkillsSPLUT {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my $ID;
	my $i;
	$i = 1;
	open(FILE, "< $file");
	foreach (<FILE>) {
		if (/^\@/) {
			undef $ID;
			$i = 1;
		} elsif (!$ID) {
			($ID) = /([\s\S]+)#/;
		} else {
			($$r_hash{$ID}{$i++}) = /(\d+)#/;
		}
	}
	close FILE;
}

sub parseTimeouts {
	my $file = shift;
	my $r_hash = shift;
	open(FILE, "< $file");
	foreach (<FILE>) {
		next if (/^#/);
		s/[\r\n]//g;

		my ($key, $value) = $_ =~ /([\s\S]+?) ([\s\S]*?)$/;
		my @args = split (/ /, $value);
		if ($key ne "") {
			$$r_hash{$key}{'timeout'} = $args[0];
		}
	}
	close FILE;
}


sub writeDataFile {
	my $file = shift;
	my $r_hash = shift;
	my ($key,$value);
	open(FILE, "+> $file");
	foreach (keys %{$r_hash}) {
		if ($_ ne "") {
			print FILE $_;
			print FILE " $$r_hash{$_}" if $$r_hash{$_} ne '';
			print FILE "\n";
		}
	}
	close FILE;
}

sub writeDataFileIntact {
	my $file = shift;
	my $r_hash = shift;
	my $no_undef = shift;

	my (@lines, $key, $value, $inBlock, %blocks);
	open FILE, "< $file";
	foreach (<FILE>) {
		s/[\r\n]//g;	# Remove line endings
		if (/^[\s\t]*#/ || /^[\s\t]*$/ || /^\!include( |$)/) {
			push @lines, $_;
			next;
		}
		s/^[\t\s]*//;	# Remove leading tabs and whitespace
		s/\s+$//g;	# Remove trailing whitespace

		if (!defined $inBlock && /{$/) {
			# Begin of block
			s/ *{$//;
			($key, $value) = $_ =~ /^(.*?) (.*)/;
			$key = $_ if ($key eq '');

			if (!exists $blocks{$key}) {
				$blocks{$key} = 0;
			} else {
				$blocks{$key}++;
			}
			$inBlock = "${key}_$blocks{$key}";

			my $line = $key;
			$line .= " $r_hash->{$inBlock}" if ($r_hash->{$inBlock} ne '');
			push @lines, "$line {";

		} elsif (defined $inBlock && $_ eq "}") {
			# End of block
			undef $inBlock;
			push @lines, "}";

		} else {
			# Option
			($key, $value) = $_ =~ /^(.*?) (.*)/;
			if ($key eq "") {
				$key = $_;
				$key =~ s/ *$//;
			}
			if (defined $inBlock) {
				my $realKey = "${inBlock}_${key}";
				my $line = "\t$key";
				$line .= " $r_hash->{$realKey}" if ($r_hash->{$realKey} ne '');
				push @lines, $line;
			} else {
				my $line = $key;
				$line .= " $r_hash->{$key}" if ($r_hash->{$key} ne '');
				push @lines, $line;
			}
		}
	}
	close FILE;

	open FILE, "> $file";
	print FILE join("\n", @lines) . "\n";
	close FILE;
}

sub writeDataFileIntact2 {
	my $file = shift;
	my $r_hash = shift;
	my $data;
	my $key;

	open(FILE, "< $file");
	foreach (<FILE>) {
		if (/^#/ || $_ =~ /^\n/ || $_ =~ /^\r/) {
			$data .= $_;
			next;
		}
		($key) = $_ =~ /^(\w+)/;
		$data .= $key;
		$data .= " $$r_hash{$key}{'timeout'}" if $$r_hash{$key}{'timeout'} ne '';
		$data .= "\n";
	}
	close FILE;
	open(FILE, "> $file");
	print FILE $data;
	close FILE;
}

sub writePortalsLOS {
	my $file = shift;
	my $r_hash = shift;
	open(FILE, "+> $file");
	foreach my $key (sort keys %{$r_hash}) {
		next if (!$$r_hash{$key} || !(keys %{$$r_hash{$key}}));
		print FILE $key;
		foreach (keys %{$$r_hash{$key}}) {
			print FILE " $_ $$r_hash{$key}{$_}";
		}
		print FILE "\n";
	}
	close FILE;
}

sub updateMonsterLUT {
	my $file = shift;
	my $ID = shift;
	my $name = shift;
	open FILE, ">> $file";
	print FILE "$ID $name\n";
	close FILE;
}

sub updatePortalLUT {
	my ($file, $src, $x1, $y1, $dest, $x2, $y2) = @_;
	open FILE, ">> $file";
	print FILE "$src $x1 $y1 $dest $x2 $y2\n";
	close FILE;
}

sub updateNPCLUT {
	my ($file, $ID, $map, $x, $y, $name) = @_;
	open FILE, ">> $file"; 
	print FILE "$ID $map $x $y $name\n"; 
	close FILE; 
}

1;
