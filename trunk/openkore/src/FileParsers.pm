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

our @ISA = qw(Exporter);
our @EXPORT = qw(
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
	parseSkillsLUT
	parseSkillsIDLUT
	parseSkillsReverseLUT_lc
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
	my ($key,$value);
	open FILE, $file;
	foreach (<FILE>) {
		next if (/^#/);
		s/[\r\n]//g;
		s/\s+$//g;
		($key, $value) = $_ =~ /([\s\S]*?) ([\s\S]*)$/;
		$key =~ s/\s//g;

		if ($key eq "!include") {
			my $fname = $value;
			if (!File::Spec->file_name_is_absolute($value) && !($value =~ /^\//)) {
				if ($file =~ /[\/\\]/) {
					$fname = $file;
					$fname =~ s/(.*)[\/\\].*/$1/;
					$fname = File::Spec->catfile($fname, $value);
				} else {
					$fname = $value;
				}
			}

			$r_hash->{_INCLUDES}{$file} = [] if (!$r_hash->{_INCLUDES}{$file});
			parseDataFile($fname, $r_hash, 1);
			push @{$r_hash->{_INCLUDES}{$file}}, $fname;
			next;
		}

		if ($key eq "") {
			($key) = $_ =~ /([\s\S]*)$/;
			$key =~ s/\s//g;
		}
		if ($key ne "") {
			$$r_hash{$key} = $value;
		}
	}
	close FILE;
}

sub parseItemsControl {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my ($key,@args,$args);
	open FILE, $file;
	foreach (<FILE>) {
		next if (/^#/);
		s/[\r\n]//g;
		s/\s+$//g;
		($key, $args) = $_ =~ /([\s\S]+?) (\d+[\s\S]*)/;
		@args = split / /,$args;
		if ($key ne "") {
			$$r_hash{lc($key)}{'keep'} = $args[0];
			$$r_hash{lc($key)}{'storage'} = $args[1];
			$$r_hash{lc($key)}{'sell'} = $args[2];
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
		($key, $args) = $_ =~ /([\s\S]+?) (\d+[\s\S]*)/;
		@args = split / /,$args;
		if ($key ne "") {
			$$r_hash{lc($key)}{'attack_auto'} = $args[0];
			$$r_hash{lc($key)}{'teleport_auto'} = $args[1];
			$$r_hash{lc($key)}{'teleport_search'} = $args[2];
		}
	}
	close FILE;
}

sub parsePortals {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my ($key,$value);
	my %IDs;
	my $i;
	my $j = 0;
	open FILE, $file;
	foreach (<FILE>) {
		next if (/^#/);
		s/[\r\n]//g;
		s/\s+/ /g;
		s/\s+$//g;
		my @args = split /\s/, $_;
		if (@args > 5) {
			$IDs{$args[0]}{$args[1]}{$args[2]} = "$args[0] $args[1] $args[2]";
			$$r_hash{"$args[0] $args[1] $args[2]"}{'source'}{'ID'} = "$args[0] $args[1] $args[2]";
			$$r_hash{"$args[0] $args[1] $args[2]"}{'source'}{'map'} = $args[0];
			$$r_hash{"$args[0] $args[1] $args[2]"}{'source'}{'pos'}{'x'} = $args[1];
			$$r_hash{"$args[0] $args[1] $args[2]"}{'source'}{'pos'}{'y'} = $args[2];
			$$r_hash{"$args[0] $args[1] $args[2]"}{'dest'}{'map'} = $args[3];
			$$r_hash{"$args[0] $args[1] $args[2]"}{'dest'}{'pos'}{'x'} = $args[4];
			$$r_hash{"$args[0] $args[1] $args[2]"}{'dest'}{'pos'}{'y'} = $args[5];
			if ($args[6] ne "") {
				$$r_hash{"$args[0] $args[1] $args[2]"}{'npc'}{'ID'} = $args[6];
				for ($i = 7; $i < @args; $i++) {
					$$r_hash{"$args[0] $args[1] $args[2]"}{'npc'}{'steps'}[@{$$r_hash{"$args[0] $args[1] $args[2]"}{'npc'}{'steps'}}] = $args[$i];
				}
			}
		}
		$j++;
	}
	foreach (keys %{$r_hash}) {
		$$r_hash{$_}{'dest'}{'ID'} = $IDs{$$r_hash{$_}{'dest'}{'map'}}{$$r_hash{$_}{'dest'}{'pos'}{'x'}}{$$r_hash{$_}{'dest'}{'pos'}{'y'}};
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
			print FILE "$_ $$r_hash{$_}\n";
		}
	}
	close FILE;
}

sub writeDataFileIntact {
	my $file = shift;
	my $r_hash = shift;
	my $data;
	my $key;

	open(FILE, "< $file");
	foreach (<FILE>) {
		if (/^#/ || $_ =~ /^\n/ || $_ =~ /^\r/ || $_ =~ /^\!include /) {
			$data .= $_;
			next;
		}
		($key) = $_ =~ /^(\w+)/;
		$data .= "$key $$r_hash{$key}\n";
	}
	close FILE;
	open(FILE, "> $file");
	print FILE $data;
	close FILE;

	return if (!$r_hash->{_INCLUDES}{$file});
	foreach my $fname (@{$r_hash->{_INCLUDES}{$file}}) {
		writeDataFileIntact($fname, $r_hash);
	}
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
                $data .= "$key $$r_hash{$key}{'timeout'}\n";
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
	foreach my $key (keys %{$r_hash}) {
		next if (!(keys %{$$r_hash{$key}}));
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


return 1;
