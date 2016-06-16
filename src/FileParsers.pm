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
#use utf8;
use Carp;
use Text::Balanced qw(extract_delimited);

use Utils;
use Utils::TextReader;
use Plugins;
use Log qw(warning error debug);
use Translation qw/T TF/;

our @EXPORT = qw(
	parseArrayFile
	parseAvoidControl
	parseChatResp
	parseCommandsDescription
	parseConfigFile
	parseDataFile
	parseDataFile_lc
	parseDataFile2
	parseEmotionsFile
	parseItemsControl
	parseList
	parseNPCs
	parseMonControl
	parsePortals
	parsePortalsLOS
	parsePriority
	parseResponses
	parseRecvpackets
	parseROLUT
	parseRODescLUT
	parseROSlotsLUT
	parseROQuestsLUT
	parseSectionedFile
	parseShopControl
	parseSkillsSPLUT
	parseTimeouts
	parseWaypoint
	processUltimate
	writeDataFile
	writeDataFileIntact
	writeDataFileIntact2
	writePortalsLOS
	writeSectionedFileIntact
	updateMonsterLUT
	updatePortalLUT
	updatePortalLUT2
	updateNPCLUT
);


sub parseArrayFile {
	my $file = shift;
	my $r_array = shift;
	undef @{$r_array};

	my @lines;
	my $reader = new Utils::TextReader($file);
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		$line =~ s/[\r\n\x{FEFF}]//g;
		$line =~ s/\#$//g; # support msgstringtable.txt
		push @lines, $line;
	}
	@{$r_array} = scalar(@lines) + 1;
	my $i = 1;
	foreach (@lines) {
		$r_array->[$i] = $_;
		$i++;
	}
	return 1;
}

sub parseAvoidControl {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my ($key,@args,$args);
	my $reader = new Utils::TextReader($file);

	my $section = "";
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		$line =~ s/\x{FEFF}//g;
		next if ($line =~ /^#/);
		$line =~ s/[\r\n]//g;
		$line =~ s/\s+$//g;

		next if ($line eq "");

		if ($line =~ /^\[(.*)\]$/) {
			$section = $1;
			next;

		} else {
			($key, $args) = lc($line) =~ /([\s\S]+?)[\s]+(\d+[\s\S]*)/;
			@args = split / /,$args;
			if ($key ne "") {
				$r_hash->{$section}{$key}{disconnect_on_sight} = $args[0];
				$r_hash->{$section}{$key}{teleport_on_sight} = $args[1];
				$r_hash->{$section}{$key}{disconnect_on_chat} = $args[2];
			}
		}
	}
	return 1;
}

sub parseChatResp {
	my $file = shift;
	my $r_array = shift;

	my $reader = new Utils::TextReader($file);
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		$line =~ s/[\r\n\x{FEFF}]//g;
		next if ($line eq "" || $line =~ /^#/);
		if ($line =~ /^first_resp_/) {
			Log::error(Translation::T("The chat_resp.txt format has changed. Please read News.txt and upgrade to the new format.\n"));
			return;
		}

		my ($key, $value) = split /\t+/, lc($line), 2;
		my @input = split /,+/, $key;
		my @responses = split /,+/, $value;

		foreach my $word (@input) {
			my %args = (
				word => $word,
				responses => \@responses
			);
			push @{$r_array}, \%args;
		}
	}
	return 1;
}

sub parseCommandsDescription {
	my $file = shift;
	my $r_hash = shift;
	my $no_undef = shift;

	undef %{$r_hash} unless $no_undef;
	my ($key, $commentBlock, $description);
	
	my $reader = new Utils::TextReader($file);
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		$line =~ s/\x{FEFF}//g;
		next if ($line =~ /^[\s\t]*#/);
		$line =~ s/[\r\n]//g;	# Remove line endings
		$line =~ s/^[\t\s]*//;	# Remove leading tabs and whitespace
		$line =~ s/\s+$//g;	# Remove trailing whitespace
		next if ($line eq "");

		if (!defined $commentBlock && $line =~ /^\/\*/) {
			$commentBlock = 1;
			next;

		} elsif ($line =~ m/\*\/$/) {
			undef $commentBlock;
			next;

		} elsif (defined $commentBlock) {
			next;

		} elsif ($description) {
			$description = 0;
			push @{$r_hash->{$key}}, $line;

		} elsif ($line =~ /^\[(\w+)\]$/) {
			$key = $1;
			$description = 1;
			$r_hash->{$key} = [];

		} elsif ($line =~ /^(.*?)\t+(.*)$/) {
			push @{$r_hash->{$key}}, [$1, $2];
		
		} elsif ($line !~ /\t/) {	#if a console command is without any params
			push @{$r_hash->{$key}}, ["", $line];
		}
		
	}
	return 1;
}

sub parseConfigFile {
	my $file = shift;
	my $r_hash = shift;
	my $no_undef = shift;
	my $blocks = (shift) || {};

	undef %{$r_hash} unless $no_undef;
	my ($key, $value, $inBlock, $commentBlock);
	
	my $reader = new Utils::TextReader($file);
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		$line =~ s/\x{FEFF}//g;
		next if ($line =~ /^[\s\t]*#/);
		$line =~ s/[\r\n]//g;	# Remove line endings
		$line =~ s/^[\t\s]*//;	# Remove leading tabs and whitespace
		$line =~ s/\s+$//g;	# Remove trailing whitespace
		next if ($line eq "");

		if (!defined $commentBlock && $line =~ /^\/\*/) {
			$commentBlock = 1;
			next;

		} elsif (defined $commentBlock && $line =~ m/\*\/$/) {
			undef $commentBlock;
			next;

		} elsif (defined $commentBlock) {
			next;

		} elsif (!defined $inBlock && $line =~ /{$/) {
			# Begin of block
			$line =~ s/ *{$//;
			($key, $value) = $line =~ /^(.*?) (.*)/;
			$key = $line if ($key eq '');

			if (!exists $blocks->{$key}) {
				$blocks->{$key} = 0;
			} else {
				$blocks->{$key}++;
			}
			if ($key ne 'teleportAuto'){
				$inBlock = "${key}_$blocks->{$key}";
			} else {
				$inBlock = "${key}";
			}
			$r_hash->{$inBlock} = $value;

		} elsif (defined $inBlock && $line eq "}") {
			# End of block
			undef $inBlock;

		} else {
			# Option
			($key, $value) = $line =~ /^(.*?) (.*)/;
			if ($key eq "") {
				$key = $line;
				$key =~ s/ *$//;
			}
			#$value = $r_hash->{$1} if ($value =~ /^constant\.(.*)/);
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
				if (-f $f) {
					my $ret = parseConfigFile($f, $r_hash, 1, $blocks);
					return $ret unless $ret;
				} else {
					error Translation::TF("%s: Include file not found: %s\n", $file, $f);
					return 0;
				}

			} else {
				$r_hash->{$key} = $value;
			}
		}
	}

	if ($inBlock) {
		error Translation::TF("%s: Unclosed { at EOF\n", $file);
		return 0;
	}
	return 1;
}

sub parseEmotionsFile {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my ($key, $word, $name);
	my $reader = new Utils::TextReader($file);
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		$line =~ s/\x{FEFF}//g;
		next if ($line =~ /^#/);
		$line =~ s/[\r\n]//g;
		$line =~ s/\s+$//g;

		($key, $word, $name) = $line =~ /^(\d+) (\S+) (.*)$/;

		if ($key ne "") {
			$$r_hash{$key}{command} = $word;
			$$r_hash{$key}{display} = $name;
		}
	}
	return 1;
}


sub parseDataFile {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my ($key,$value);
	my $reader = new Utils::TextReader($file);
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		$line =~ s/\x{FEFF}//g;
		next if ($line =~ /^#/);
		$line =~ s/[\r\n]//g;
		$line =~ s/\s+$//g;
		($key, $value) = $line =~ /([\s\S]*) ([\s\S]*?)$/;
		if ($key ne "" && $value ne "") {
			$$r_hash{$key} = $value;
		}
	}
	return 1;
}

sub parseDataFile_lc {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my ($key,$value);
	my $reader = new Utils::TextReader($file);
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		$line =~ s/\x{FEFF}//g;
		next if ($line =~ /^#/);
		$line =~ s/[\r\n]//g;
		$line =~ s/\s+$//g;
		($key, $value) = $line =~ /([\s\S]*) ([\s\S]*?)$/;
		if ($key ne "" && $value ne "") {
			$$r_hash{lc($key)} = $value;
		}
	}
	return 1;
}

sub parseDataFile2 {
	my ($file, $r_hash) = @_;

	%{$r_hash} = ();
	my $reader = new Utils::TextReader($file);
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		$line =~ s/\x{FEFF}//g;
		next if ($line =~ /^#/);
		$line =~ s/[\r\n]//g;
		next if (length($line) == 0);

		my ($key, $value) = split / /, $line, 2;
		$key =~ s/^(0x[0-9a-f]+)$/hex $1/e;
		$r_hash->{$key} = $value;
	}
	close FILE;
	
	return 1;
}

sub parseList {
	my $file = shift;
	my $r_hash = shift;

	undef %{$r_hash};

	my $reader = new Utils::TextReader($file);
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		chomp($line);
		$r_hash->{$line} = 1;
	}
	return 1;
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
	my $reader = new Utils::TextReader($file);

	# Read shop items
	$shop->{items} = [];
	my $linenum = 0;
	my @errors = ();
	my $line;

	while (!$reader->eof()) {
		$line = $reader->readLine();
		$linenum++;
		chomp;
		$line =~ s/[\r\n\x{FEFF}]//g;
		next if $line =~ /^$/ || $line =~ /^#/;

		if (!$shop->{title_line}) { 
			$shop->{title_line} = $line;
			next;
		}

		my ($name, $price, $amount) = split(/\t+/, $line);
		$price =~ s/^\s+//g;
		$amount =~ s/^\s+//g;
		my $real_price = $price;
		$real_price =~ s/,//g;

		my ($priceMax, $priceCommas, $priceMaxCommas);
		if ($real_price =~ /../) {
			($real_price, $priceMax) = split(/\../, $real_price);
			($priceCommas, $priceMaxCommas) = split(/\../, $price);
		}

		my $loc = Translation::TF("Line %s: Item '%s'", $linenum, $name);
		if ($real_price !~ /^\d+$/) {
			push(@errors, Translation::TF("%s has non-integer price: %s", $loc, $price));
		} elsif (!$priceMax && ($price ne $real_price && formatNumber($real_price) ne $price) ||
				 $priceMax  && ($priceCommas ne $real_price && formatNumber($real_price) ne $priceCommas ||
							   $priceMaxCommas ne $priceMax && formatNumber($priceMax) ne $priceMaxCommas))
		{
			push(@errors, Translation::TF("%s has incorrect comma placement in price: %s", $loc, $price));
		} elsif ($real_price < 0) {
			push(@errors, Translation::TF("%s has non-positive price: %s", $loc, $price));
		} elsif ($real_price > 1000000000) {
			push(@errors, Translation::TF("%s has price over 1,000,000,000: %s", $loc, $price));
		} elsif ($amount > 30000) {
			push(@errors, Translation::TF("%s has amount over 30,000: %s", $loc, $amount));
		}

		push(@{$shop->{items}}, {name => $name, price => $real_price, priceMax => $priceMax, amount => $amount});
	}

	if (@errors) {
		error Translation::TF("Errors were found in %s:\n", $file);
		foreach (@errors) { error("$_\n"); }
		error Translation::TF("Please correct the above errors and type 'reload %s'.\n", $file);
		return 0;
	}
	return 1;
}

sub parseItemsControl {
	my ($file, $r_hash) = @_;
	undef %{$r_hash};
	my ($key, $args_text, %cache);
	
	my $reader = new Utils::TextReader($file);
	until ($reader->eof) {
		$_ = lc $reader->readLine;
		next if /^#/;
		if (($key, $args_text) = extract_delimited and $key) {
			$key =~ s/^.|.$//g;
			$args_text =~ s/^\s+//;
		} else {
			($key, $args_text) = /([\s\S]+?)\s(\d+[\s\S]*)/;
		}
		
		next if $key =~ /^$/;
		my @args = split /\s+/, $args_text;
		# Cache similar entries to save memory.
		$r_hash->{$key} = $cache{$args_text} ||= { map {$_ => shift @args} qw(keep storage sell cart_add cart_get) };
	}
	return 1;
}

sub parseNPCs {
	my $file = shift;
	my $r_hash = shift;
	my ($i, $string);
	undef %{$r_hash};
	my ($key, $value, @args);
	my $reader = new Utils::TextReader($file);
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		$line =~ s/\cM|\cJ//g;
		$line =~ s/^\s+|\s+$//g;
		next if $line =~ /^#/ || $line eq '';
		#izlude 135 78 Charfri
		my ($map,$x,$y,$name) = split /\s+/, $line,4;
		next unless $name;
		$$r_hash{"$map $x $y"} = $name;
	}
	return 1;
}

sub parseMonControl {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my ($key,@args,$args);

	my $reader = new Utils::TextReader($file);
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		$line =~ s/\x{FEFF}//g;
		next if ($line =~ /^#/);
		$line =~ s/[\r\n]//g;
		$line =~ s/\s+$//g;

		if ($line =~ /\t/) {
			($key, $args) = split /\t+/, lc($line);
		} else {
			($key, $args) = lc($line) =~ /([\s\S]+?) ([\-\d\.]+[\s\S]*)/;
		}

		@args = split / /, $args;
		if ($key ne "") {
			$r_hash->{$key}{attack_auto} = $args[0];
			$r_hash->{$key}{teleport_auto} = $args[1];
			$r_hash->{$key}{teleport_search} = $args[2];
			$r_hash->{$key}{skillcancel_auto} = $args[3];
			$r_hash->{$key}{attack_lvl} = $args[4];
			$r_hash->{$key}{attack_jlvl} = $args[5];
			$r_hash->{$key}{attack_hp} = $args[6];
			$r_hash->{$key}{attack_sp} = $args[7];
			$r_hash->{$key}{weight} = $args[8];
		}
	}
	return 1;
}

sub parsePortals {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my $reader = new Utils::TextReader($file);
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		next if $line =~ /^#/;
		$line =~ s/\cM|\cJ//g;
		$line =~ s/\s+/ /g;
		$line =~ s/^\s+|\s+$//g;
		$line =~ s/(.*)[\s\t]+#.*$/$1/;
		
		if ($line =~ /^([\w|@|-]+)\s(\d{1,3})\s(\d{1,3})\s([\w|@|-]+)\s(\d{1,3})\s(\d{1,3})\s?(.*)/) {
		my ($source_map, $source_x, $source_y, $dest_map, $dest_x, $dest_y, $misc) = ($1, $2, $3, $4, $5, $6, $7);
			my $portal = "$source_map $source_x $source_y";
			my $dest = "$dest_map $dest_x $dest_y";
			$$r_hash{$portal}{'source'}{'map'} = $source_map;
			$$r_hash{$portal}{'source'}{'x'} = $source_x;
			$$r_hash{$portal}{'source'}{'y'} = $source_y;
			$$r_hash{$portal}{'dest'}{$dest}{'map'} = $dest_map;
			$$r_hash{$portal}{'dest'}{$dest}{'x'} = $dest_x;
			$$r_hash{$portal}{'dest'}{$dest}{'y'} = $dest_y;
			$$r_hash{$portal}{dest}{$dest}{enabled} = 1; # is available permanently (can be used when calculating a route)
			#$$r_hash{$portal}{dest}{$dest}{active} = 1; # TODO: is available right now (otherwise, wait until it becomes available)
			if ($misc =~ /^(\d+)\s(\d)\s(.*)$/) { # [cost] [allow_ticket] [talk sequence]
				$$r_hash{$portal}{'dest'}{$dest}{'cost'} = $1;
				$$r_hash{$portal}{'dest'}{$dest}{'allow_ticket'} = $2;
				$$r_hash{$portal}{'dest'}{$dest}{'steps'} = $3;
			} elsif ($misc =~ /^(\d+)\s(.*)$/) { # [cost] [talk sequence]
				$$r_hash{$portal}{'dest'}{$dest}{'cost'} = $1;
				$$r_hash{$portal}{'dest'}{$dest}{'steps'} = $2;
			} else { # [talk sequence]
				$$r_hash{$portal}{'dest'}{$dest}{'steps'} = $misc;
			}
		}
		
	}
	return 1;
}

sub parsePortalsLOS {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my $key;
	open FILE, "<", $file;
	foreach (<FILE>) {
		s/\x{FEFF}//g;
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
	return 1;
}

sub parsePriority {
	my $file = shift;
	my $r_hash = shift;
	return unless my $reader = new Utils::TextReader($file);

	my @lines;
	while (!$reader->eof()) {
			push @lines, $reader->readLine();
	}
	my $pri = $#lines;
	foreach (@lines) {
		s/\x{FEFF}//g;
		next if (/^#/);
		s/[\r\n]//g;
		$$r_hash{lc($_)} = $pri + 1;
		$pri--;
	}
	return 1;
}

sub parseResponses {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my ($i, $key,$value);
	my $reader = new Utils::TextReader($file);
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		$line =~ s/\x{FEFF}//g;
		next if ($line =~ /^#/);
		$line =~ s/[\r\n]//g;
		($key, $value) = $line =~ /([\s\S]*?) ([\s\S]*)$/;
		if ($key ne "" && $value ne "") {
			$i = 0;
			while ($$r_hash{"$key\_$i"} ne "") {
				$i++;
			}
			$$r_hash{"$key\_$i"} = $value;
		}
	}
	return 1;
}

sub parseROLUT {
	my ($file, $r_hash, $flag, $ext) = @_;

	my %ret = (
		file => $file,
		hash => $r_hash
	    );
	Plugins::callHook("FileParsers::ROLUT", \%ret);
	return if ($ret{return});

	undef %{$r_hash};
	my $reader = new Utils::TextReader($file);
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		$line =~ s/[\r\n\x{FEFF}]//g;
		next if (length($line) == 0 || $line =~ /^\/\// || ($ext && $line !~ /$ext#/));

		my ($id, $name) = split /$ext#/, $line, 3;
		if ($id ne "" && $name ne "") {
			$name =~ s/_/ /g unless ($flag == 1);
			$name =~ s/^\s+|\s+$//g;
			$r_hash->{$id} = $name;
		}
	}
	return 1;
}

sub parseRODescLUT {
	my ($file, $r_hash) = @_;

	my %ret = (
		file => $file,
		hash => $r_hash
	    );
	Plugins::callHook("FileParsers::RODescLUT", \%ret);
	return if ($ret{return});

	undef %{$r_hash};
	my $ID;
	my $IDdesc;
	my $reader = Utils::TextReader->new($file, { hide_comments => 0 });
	until ($reader->eof) {
		$_ = $reader->readLine;
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
	return 1;
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
	return 1;
}

sub parseROQuestsLUT {
	my ($file, $r_hash) = @_;
	
	my %ret = (
		file => $file,
		hash => $r_hash,
	);
	Plugins::callHook ('FileParsers::ROQuestsLUT', \%ret);
	return if $ret{return};
	
	undef %{$r_hash};
	my ($data, $flag);
	my $reader = Utils::TextReader->new($file, { hide_comments => 0 });
	until ($reader->eof) {
		$_ = $reader->readLine;
		s/\r//g;
		if (/^(\d+)#([^#]*)#([A-Z_]*)#([A-Z_]*)#/) {
			$data = {
				id => $1,
				title => $2,
				image => $3,
				unknown1 => $4,
			};
		} elsif (defined $data and /^([^#]*)#/) {
			unless (defined $data->{summary}) {
				$data->{summary} = $1;
				$data->{summary} =~ s/\^......//g;
			} else {
				$data->{objective} = $1;
				$flag = 1;
			}
		}
		
		if ($flag) {
			$$r_hash{$data->{id}} = $data;
			undef $data; undef $flag;
		}
	}
	
	return 1;
}

sub parseRecvpackets {
	my ($file, $r_hash) = @_;

	%{$r_hash} = ();
	my $reader = new Utils::TextReader($file);
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		$line =~ s/\x{FEFF}//g;
		next if ($line =~ /^#/);
		$line =~ s/[\r\n]//g;
		next if (length($line) == 0);

		my ($packetID, $length, $minLength, $repeat, $function) = split /\s+/, $line, 5;
		$packetID =~ s/^(0x[0-9a-f]+)$/hex $1/e;
		$r_hash->{$packetID}{length} = $length;
		$r_hash->{$packetID}{minLength} = $minLength;
		$r_hash->{$packetID}{repeat} = $repeat; # unused
		$r_hash->{$packetID}{function} = $function; # can be used as description instead of packetdescriptions.txt, if defined.
		#use Log 'warning';
		#warning $r_hash->{$key}." ".$key."\n";
	}
	close FILE;
	
	return 1;
}

sub parseSectionedFile {
	my $file = shift;
	my $r_hash = shift;
	undef %{$r_hash};
	my $reader = new Utils::TextReader($file);

	my $section = "";
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		$line =~ s/\x{FEFF}//g;
		next if ($line =~ /^#/);
		$line =~ s/[\r\n]//g;
		$line =~ s/\s+$//g;
		next if ($line eq "");

		if ($line =~ /^\[(.*)\]$/i) {
			$section = $1;
			next;
		} else {
			my ($key, $value);
			if ($line =~ / /) {
				($key, $value) = $line =~ /^(.*?) (.*)/;
			} else {
				$key = $line;
			}
			$r_hash->{$section}{$key} = $value;
		}
	}
	return 1;
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
	return 1;
}

sub parseTimeouts {
	my $file = shift;
	my $r_hash = shift;
	my $reader = new Utils::TextReader($file);
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		$line =~ s/\x{FEFF}//g;
		next if ($line =~ /^#/);
		$line =~ s/[\r\n]//g;

		my ($key, $value) = $line =~ /([\s\S]+?) ([\s\S]*?)$/;
		my @args = split (/ /, $value);
		if ($key ne "") {
			$$r_hash{$key}{'timeout'} = $args[0];
		}
	}
	return 1;
}

sub parseWaypoint {
	my $file = shift;
	my $r_array = shift;
	@{$r_array} = ();

	open FILE, "< $file";
	foreach (<FILE>) {
		s/\x{FEFF}//g;
		next if (/^#/ || /^$/);
		s/[\r\n]//g;

		my @items = split / +/, $_;
		my %point = (
			map => $items[0],
			x => $items[1],
			y => $items[2]
		);
		push @{$r_array}, \%point;
	}
	close FILE;
	return 1;
}


# The ultimate config file format. This function is a parser and writer in one.
# The config file can be divided in section, example:
#
#   foo 1
#   bar 2
#
#   [Options]
#   username me
#   password p
#
#   [Names]
#   joe
#   mike
#
# Sections can be treated as hashes or arrays. It's defined by $rules.
# If you want [Names] to be an array:
# %rule = (Names => 'list');
#
# processUltimate("file", \%hash, \%rule) returns:
# {
#   foo => 1,
#   bar => 2,
#   Options => {
#       username => 'me',
#       password => 'p';
#   },
#   Names => [
#       "joe",
#       "mike"
#   ]
# }
#
# When in write mode, this function will automatically add new keys and lines,
# while preserving comments.
sub processUltimate {
	my ($file, $hash, $rules, $writeMode) = @_;
	my $f;
	my $secname = '';
	my ($section, $rule, @lines, %written, %sectionsWritten);

	undef %{$hash} if (!$writeMode);
	if (-f $file) {
		my $reader = new Utils::TextReader($file);
		while (!$reader->eof()) {
			my $line = $reader->readLine();
			$line =~ s/\x{FEFF}//g;
			$line =~ s/[\r\n]//g;

			if ($line eq '' || $line =~ /^[ \t]*#/) {
				push @lines, $line if ($writeMode);
				next;
			}

			if ($line =~ /^\[(.+)\]$/) {
				# New section
				if ($writeMode) {
					# First, finish writing everything in the previous section
					my $h = (defined $section) ? $section : $hash;
					my @add;

					if ($rule ne 'list') {
						foreach my $key (keys %{$h}) {
							if (!$written{$key} && !ref($h->{$key})) {
								push @add, "$key $h->{$key}";
							}
						}

					} else {
						foreach (@{$h}) {
							push @add, $_ if (!$written{$_});
						}
					}

					# Add after the first non-empty line from the end
					my $linesFromEnd;
					for (my $i = @lines - 1; $i >= 0; $i--) {
						if ($lines[$i] ne '') {
							$linesFromEnd = @lines - $i - 1;
							for (my $j = $i + 1; $j < @lines; $j++) {
								delete $lines[$j];
							}
							push @lines, @add;
							for (my $j = 0; $j < $linesFromEnd; $j++) {
								push @lines, '';
							}
							last;
						}
					}
					undef %written;
				}

				# Parse the new section
				$secname = $1;
				$rule = $rules->{$secname};
				if ($writeMode) {
					$section = $hash->{$secname};
					push @lines, $line;
					$sectionsWritten{$secname} = 1;

				} else {
					if ($rule ne 'list') {
						$section = {};
					} else {
						$section = [];
					}
					$hash->{$secname} = $section;
				}

			} elsif ($rule ne 'list') {
				# Line is a key-value pair
				my ($key, $val) = split / /, $line, 2;
				my $h = (defined $section) ? $section : $hash;

				if ($writeMode) {
					# Delete line if value doesn't exist
					if (exists $h->{$key}) {
						if (!defined $h->{$key}) {
							push @lines, $key;
						} else {
							push @lines, "$key $h->{$key}";
						}
						$written{$key} = 1;
					}

				} else {
					$h->{$key} = $val;
				}

			} else {
				# Line is part of a list
				if ($writeMode) {
					# Add line only if it exists in the hash
					push @lines, $line if (defined(binFind($section, $line)));
					$written{$line} = 1;

				} else {
					push @{$section}, $line;
				}
			}
		}
	}

	if ($writeMode) {
		# Add stuff that haven't already been added
		my $h = (defined $section) ? $section : $hash;

		if ($rule ne 'list') {
			foreach my $key (keys %{$h}) {
				if (!$written{$key} && !ref($h->{$key})) {
					push @lines, "$key $h->{$key}";
				}
			}

		} else {
			foreach my $line (@{$h}) {
				push @lines, $line if (!$written{$line});
			}
		}

		# Write sections that aren't already in the file
		foreach my $section (keys %{$hash}) {
			next if (!ref($hash->{$section}) || $sectionsWritten{$section});
			push @lines, "", "[$section]";
			if ($rules->{$section} eq 'list') {
				push @lines, @{$hash->{$section}};
			} else {
				foreach my $key (keys %{$hash->{$section}}) {
					push @lines, "$key $hash->{$section}{$key}";
				}
			}
		}

		open($f, ">:utf8", $file);
		print $f join("\n", @lines) . "\n";
		close $f;
	}
	return 1;
}

sub writeDataFile {
	my $file = shift;
	my $r_hash = shift;
	my ($key,$value);
	open(FILE, ">>:utf8", $file);
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
	# following args for recursive call (!include)
	my $blocks = {};
	my $diffs = {};

	my (@lines, $key, $value, $inBlock, $commentBlock);
	my $reader = new Utils::TextReader($file, { hide_includes => 0, hide_comments => 0 });
	while (!$reader->eof()) {
		my $current_file = $reader->currentFile;
		my $lines = $reader->readLine;
		$lines =~ s/[\r\n]//g;	# Remove line endings
		if ($lines =~ /^[\s\t]*#/ || $lines =~ /^[\s\t]*$/ || $lines =~ /^\s*\!include( |$)/) {
			push @lines, $lines if $current_file eq $file;
			next;
		}
		$lines =~ s/^[\t\s]*//;	# Remove leading tabs and whitespace
		$lines =~ s/\s+$//g;	# Remove trailing whitespace

		if (!defined $commentBlock && $lines =~ /^\/\*/) {
			push @lines, "$lines" if $current_file eq $file;
			$commentBlock = 1;
			next;

		} elsif ($lines =~ m/\*\/$/) {
			push @lines, "$lines" if $current_file eq $file;
			undef $commentBlock;
			next;

		} elsif ($commentBlock) {
			push @lines, "$lines" if $current_file eq $file;
			next;

		} elsif (!defined $inBlock && $lines =~ /{$/) {
			# Begin of block
			$lines =~ s/ *{$//;
			($key, $value) = $lines =~ /^(.*?) (.*)/;
			$key = $lines if ($key eq '');

			if (!exists $blocks->{$key}) {
				$blocks->{$key} = 0;
			} else {
				$blocks->{$key}++;
			}
			if ($key ne 'teleportAuto'){
				$inBlock = "${key}_$blocks->{$key}";
			} else {
				$inBlock = "${key}";
			}

			my $line = $key;
			$line .= " $r_hash->{$inBlock}" if ($r_hash->{$inBlock} ne '');
			push @lines, "$line {" if $current_file eq $file;

		} elsif (defined $inBlock && $lines eq "}") {
			# End of block
			undef $inBlock;
			push @lines, "}" if $current_file eq $file;

		} else {
			# Option
			($key, $value) = $lines =~ /^(.*?) (.*)/;
			if ($key eq "") {
				$key = $lines;
				$key =~ s/ *$//;
			}
			if (defined $inBlock) {
				my $realKey = "${inBlock}_${key}";
				my $line = "\t$key";
				$line .= " $r_hash->{$realKey}" if ($r_hash->{$realKey} ne '');
				push @lines, $line if $current_file eq $file;
			} else {
				my $line = $key;
				$line .= " $r_hash->{$key}" if ($r_hash->{$key} ne '');
				push @lines, $line if $current_file eq $file;
				$diffs->{$key} = 1 if $current_file ne $file && $r_hash->{$key} ne $value;
				delete $diffs->{$key} if $current_file eq $file || $r_hash->{$key} eq $value;
			}
		}
	}
	close FILE;

	debug TF("Saving %s...\n", $file), 'writeFile';

	# options that are different in memory and file data, but defined in !include'd (read only) files
	foreach (sort keys %$diffs) {
		push @lines, $r_hash->{$_} ne '' ? "$_ $r_hash->{$_}" : "$_";
	}

	open FILE, ">:utf8", $file;
	print FILE join("\n", @lines) . "\n";
	close FILE;
}

sub writeDataFileIntact2 {
	my $file = shift;
	my $r_hash = shift;
	my $data;
	my $key;

	my $reader = new Utils::TextReader($file);
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		$line =~ s/\x{FEFF}//g;
		if ($line =~ /^#/ || $line =~ /^\n/ || $line =~ /^\r/) {
			$data .= $line;
			next;
		}
		($key) = $line =~ /^(\w+)/;
		$data .= $key;
		$data .= " $$r_hash{$key}{'timeout'}" if $$r_hash{$key}{'timeout'} ne '';
		$data .= "\n";
	}
	close FILE;
	open(FILE, ">:utf8", $file);
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

sub writeSectionedFileIntact {
	my $file = shift;
	my $r_hash = shift;
	my $section = "";
	my @lines;

	my $reader = new Utils::TextReader($file);
	while (!$reader->eof()) {
		my $line = $reader->readLine();
		$line =~ s/[\r\n]//g;
		if ($line =~ /^#/ || $line =~ /^ *$/) {
			push @lines, $line;
			next;
		}

		if ($line =~ /^\[(.*)\]$/) {
			$section = $1;
			push @lines, $line;
		} else {
			my ($key, $value);
			if ($line =~ / /) {
				($key) = $line =~ /^(.*?) /;
			} else {
				$key = $line;
			}
			$value = $r_hash->{$section}{$key};
			push @lines, "$key $value";
		}
	}
	close FILE;

	open(FILE, ">:utf8", $file);
	print FILE join("\n", @lines) . "\n";
	close FILE;
}

sub updateMonsterLUT {
	my $file = shift;
	my $ID = shift;
	my $name = shift;
	open FILE, ">>:utf8", $file;
	print FILE "$ID $name\n";
	close FILE;
}

sub updatePortalLUT {
	my ($file, $sourceMap, $sourceX, $sourceY, $destMap, $destX, $destY) = @_;
	
	my $plugin_args = {file => $file, sourceMap => $sourceMap, sourceX => $sourceX, sourceY => $sourceY, destMap => $destMap, destX => $destX, destY => $destY};
	Plugins::callHook('updatePortalLUT', $plugin_args);
	
	unless ($plugin_args->{return}) {
		open FILE, ">>:utf8", $file;
		print FILE "$sourceMap $sourceX $sourceY $destMap $destX $destY\n";
		close FILE;
	}
}

#Add: NPC talk Sequence
sub updatePortalLUT2 {
	my ($file, $sourceMap, $sourceX, $sourceY, $destMap, $destX, $destY, $steps) = @_;
	
	my $plugin_args = {file => $file, sourceMap => $sourceMap, sourceX => $sourceX, sourceY => $sourceY, destMap => $destMap, destX => $destX, destY => $destY, steps => $steps};
	Plugins::callHook('updatePortalLUT2', $plugin_args);
	
	unless ($plugin_args->{return}) {
		open FILE, ">>:utf8", $file;
		print FILE "$sourceMap $sourceX $sourceY $destMap $destX $destY $steps\n";
		close FILE;
	}
}

sub updateNPCLUT {
	my ($file, $location, $name) = @_;
	return unless $name;
	open FILE, ">>:utf8", $file;
	print FILE "$location $name\n";
	close FILE;
}

1;
