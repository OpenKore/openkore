#!/usr/bin/env perl
#########################################################################
#  Copyright (c) 2010 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: 7586 $
#  $Id: packet_extract.pl 7586 2010-10-22 01:19:43Z kLabMouse $
#
#########################################################################

use FindBin qw($RealBin);
use File::Basename;
#use Data::Dumper;
use Disassemble::X86;
use Disassemble::X86::FormatTree;
use strict;

# ###################################################################
# todo:
#   Add support for more target types
#   Convert all this Shit to Perl Packages
#   Add Nice GUI (optional)
# ###################################################################

unless (@ARGV) {
	print "Usage: $0 <Ragexe.exe>\n";
	exit;
}

#Innit
my $packet_len_extractor = {};
$packet_len_extractor->{file_name_raw} = shift;
$packet_len_extractor->{file_name} = "";
$packet_len_extractor->{file} = undef;
$packet_len_extractor->{original_extractor_name} = $RealBin . "/src/extractor.exe";
$packet_len_extractor->{original_extractor} = undef;
$packet_len_extractor->{new_extractor_name} = $RealBin . "/extractor.exe";
$packet_len_extractor->{new_extractor} = undef;
$packet_len_extractor->{map_version} = 3; # 1: Old 'std::map{int,int}' style; 2: Mixed style; 3: Renewal style #1; 4: Renewal style #2;
$packet_len_extractor->{map_pointer} = undef;
$packet_len_extractor->{map_pointer_entry_offset} = 0;
$packet_len_extractor->{map_function_offset} = undef;
$packet_len_extractor->{map_function} = undef;
$packet_len_extractor->{map_function_disassemble};
$packet_len_extractor->{stolen_function} = {};
$packet_len_extractor->{stolen_function}->{space} = 204800; # Space available for Stolen code (200Kb)
$packet_len_extractor->{stolen_function}->{known_calls} = {}; # Map of Known Calls
$packet_len_extractor->{stolen_function}->{stolen_code} = undef; # Stolen Function Data

# Get Just the FileName
($packet_len_extractor->{file_name}, undef) = fileparse($packet_len_extractor->{file_name_raw});


# debug
# Try 'Renewal style #1'
$packet_len_extractor->{map_pointer} = find_pattern_in_file($packet_len_extractor->{file_name_raw}, "89 ?? ?? 89 ?? ?? 89 ?? ?? 89 ?? ?? 89 ?? 8B ?? ?? 83 ?? 04 89 ?? ?? ?? ?? 89 ?? ?? E8 ?? ?? ?? ?? 8B ?? ?? 8B C6");
$packet_len_extractor->{map_pointer_entry_offset} = 29;
$packet_len_extractor->{map_version} = 3;
# $packet_len_extractor->{map_pointer} = 1565170;

# Try 'Renewal style #2'
if (not defined $packet_len_extractor->{map_pointer}) {
  $packet_len_extractor->{map_pointer} = find_pattern_in_file($packet_len_extractor->{file_name_raw}, "8B ?? 89 ?? ?? ?? E8 ?? ?? ?? ?? C7 44 24 14 ?? ?? ?? ?? 8B ?? E8 ?? ?? ?? ?? C7 44 24 14");
  $packet_len_extractor->{map_pointer_entry_offset} = 22;
  $packet_len_extractor->{map_version} = 4;
  # $packet_len_extractor->{map_pointer} = 1676290;
}

open($packet_len_extractor->{file}, "<", $packet_len_extractor->{file_name_raw}) || die "can't open ".$packet_len_extractor->{file_name_raw}.": $!";
binmode $packet_len_extractor->{file};
if (defined $packet_len_extractor->{map_pointer}) {
	# Get PacketLenMap function offset
	seek($packet_len_extractor->{file}, $packet_len_extractor->{map_pointer} + $packet_len_extractor->{map_pointer_entry_offset}, 0);
	read($packet_len_extractor->{file}, $packet_len_extractor->{map_function_offset}, 4);
	$packet_len_extractor->{map_function_offset} = tell($packet_len_extractor->{file}) + unpack("V!",$packet_len_extractor->{map_function_offset}); # Plus asm comand len

	# debug
	# printf "Packet Len Map offset: %i (%0.8X)-> %0.8X\n", $packet_len_extractor->{map_function_offset}, $packet_len_extractor->{map_function_offset}, $packet_len_extractor->{map_function_offset} + 0x400000;
	
	# Read PacketLenMap function RAW
	my $packet_len_func;
	seek($packet_len_extractor->{file}, $packet_len_extractor->{map_function_offset}, 0);
	read($packet_len_extractor->{file}, $packet_len_extractor->{map_function}, 204800); # Read 200kb

	# Disasm and Fix
	printf "Packet Len Map found.\nWorking...";
	$packet_len_extractor->{map_function_disassemble} = Disassemble::X86->new( text => $packet_len_extractor->{map_function}, format => "Tree" );
	until ( $packet_len_extractor->{map_function_disassemble}->at_end() ) {
		my $disasm = $packet_len_extractor->{map_function_disassemble}->disasm();
		# Process Call to Functions
		if ($disasm->{op} eq 'call') {
			my $offset = $disasm->{arg}->[0]->{arg}->[0] + $packet_len_extractor->{map_function_offset};
			# debug
			# printf "call: (pos: %i) %i -> %i -> %0.8X\n", $packet_len_extractor->{map_function_disassemble}->op_start(), $disasm->{arg}->[0]->{arg}->[0], $offset, $offset + 0x400000;
			# print Data::Dumper->Dump([$disasm]);
			
			my ($replace_name, $replace_data) = remap_function($packet_len_extractor->{file_name_raw}, $offset, length($packet_len_extractor->{stolen_function}->{stolen_code}), $packet_len_extractor->{stolen_function}->{known_calls}->{$offset} ? $packet_len_extractor->{stolen_function}->{known_calls}->{$offset} : undef);
			if (defined $replace_name) {
				$packet_len_extractor->{stolen_function}->{known_calls}->{$offset} = $replace_name;
				$packet_len_extractor->{stolen_function}->{stolen_code} .= $replace_data;
			} else {
				# Output raw command
				$packet_len_extractor->{stolen_function}->{stolen_code} .= substr($packet_len_extractor->{map_function}, $packet_len_extractor->{map_function_disassemble}->op_start(), $packet_len_extractor->{map_function_disassemble}->op_len());
			}
			next;
		} else {
			# Output raw command
			$packet_len_extractor->{stolen_function}->{stolen_code} .= substr($packet_len_extractor->{map_function}, $packet_len_extractor->{map_function_disassemble}->op_start(), $packet_len_extractor->{map_function_disassemble}->op_len());
		};
		
		# Exit on 'ret' or 'retn'
		if ($disasm->{op} eq 'ret' or $disasm->{op} eq 'retn') {
			last;
		};
	};
	printf "\n";
	
	# Fill the rest of code space with 'nop'
	while (length($packet_len_extractor->{stolen_function}->{stolen_code}) < $packet_len_extractor->{stolen_function}->{space}) {
		$packet_len_extractor->{stolen_function}->{stolen_code} .= pack("C", 0x90); #Fill with 'nop'
	}
	
	# Output Extractor Binary
	# Open Original Extractor File for read
	my $bytes_to_read = -s $packet_len_extractor->{original_extractor}; 
	open($packet_len_extractor->{original_extractor}, "<", $packet_len_extractor->{original_extractor_name}) || die "can't open ".$packet_len_extractor->{original_extractor_name}.": $!";
	binmode $packet_len_extractor->{original_extractor};
	# Open Target Extractor File for write
	open($packet_len_extractor->{new_extractor}, ">", $packet_len_extractor->{new_extractor_name}) || die "can't open ".$packet_len_extractor->{new_extractor_name}.": $!";
	binmode $packet_len_extractor->{new_extractor};
	my $data;
	read($packet_len_extractor->{original_extractor}, $data, 698); # Hardcoded Value
	seek($packet_len_extractor->{original_extractor}, $packet_len_extractor->{stolen_function}->{space}, 1);
	print {$packet_len_extractor->{new_extractor}} $data;
	print {$packet_len_extractor->{new_extractor}} $packet_len_extractor->{stolen_function}->{stolen_code};
	# Copy the Rest of File until FileName string
	while ((! eof($packet_len_extractor->{original_extractor})) && (tell($packet_len_extractor->{original_extractor}) < 205898)) {  # Hardcoded Value
		read($packet_len_extractor->{original_extractor}, $data, 1);
		print {$packet_len_extractor->{new_extractor}} $data;
	}
	# Print out FileName
	print {$packet_len_extractor->{new_extractor}} $packet_len_extractor->{file_name} . pack("C", 0x00);
	seek($packet_len_extractor->{original_extractor}, length($packet_len_extractor->{file_name})+1, 1);
	# Copy the Rest of file
	while (! eof($packet_len_extractor->{original_extractor})) {
		read($packet_len_extractor->{original_extractor}, $data, 1);
		print {$packet_len_extractor->{new_extractor}} $data;
	};
	close($packet_len_extractor->{original_extractor});
	close($packet_len_extractor->{new_extractor});
};
close($packet_len_extractor->{file});

sub remap_function {
	my ($file_name, $offset, $stolen_code_offset, $name) = @_;
	
	my $known_patterns = {};
	# __alloca_probe
	$known_patterns->{"alloca_probe"}->{pattern} = "51 3D 00 10 00 00 8D 4C 24 08 72 14 81 E9 00 10 00 00 2D 00 10 00 00 85 01 3D 00 10 00 00 73 EC 2B C8 8B C4 85 01 8B E1 8B 08 8B 40 04 50 C3";
	$known_patterns->{"alloca_probe"}->{deltaoffset} = -190;

	# set_packet_len
	$known_patterns->{"set_packet_len"}->{pattern} = "55 8B EC 8B 55 0C 8B C1 8B 4D 08 89 08 89 50 04 5D C2 08 00";
	$known_patterns->{"set_packet_len"}->{deltaoffset} = -143;

	# print_packet1
	$known_patterns->{"print_packet1"}->{pattern} = "55 8B EC 8B C1 8B 4D 08 8B 11 8B 4D 0C 89 10 8B 11 89 50 04 8B 49 04 89 48 08 5D C2 08 00";
	$known_patterns->{"print_packet1"}->{deltaoffset} = -123;
	
	# print_packet2
	$known_patterns->{"print_packet2"}->{pattern} = "55 8B EC 8B 45 0C 8B 08 8B 45 08 89 08 8B 4D 10 8B 11 89 50 04 8B 49 04 89 48 08 5D C3";
	$known_patterns->{"print_packet2"}->{deltaoffset} = -84;
	
	# print_packet3
	$known_patterns->{"print_packet3"}->{pattern} = "51 55 8B 6C 24 10 56 57 8B F9 8B 77 04 8B 46 04 80 78 19 00 B1 01 88 4C 24 0C 75 21 8B 55 00 90";
	$known_patterns->{"print_packet3"}->{deltaoffset} = -49;
	
	# dummy
	$known_patterns->{"dummy1"}->{pattern} = "55 8B EC 83 EC 08 53 56 8B 15 ?? ?? ?? ?? 57 8B F9 B0 01 8B 4F 04 8B F1 8B 59 04 3B DA 74 22 8B 45 0C 8B 00 89 45 F8";
	$known_patterns->{"dummy1"}->{deltaoffset} = -16;
	
	# dummy
	$known_patterns->{"dummy2"}->{pattern} = "55 8B EC 8B C1 8B 4D 08 8B 11 8B 4D 0C 89 10 8A 11 88 50 04 5D C2 08 00";
	$known_patterns->{"dummy2"}->{deltaoffset} = -16;
	
	# dummy
	$known_patterns->{"dummy3"}->{pattern} = "55 8B EC 8B C1 8B 4D 08 8B 11 89 10 8B 51 04 89 50 04 8B 49 08 89 48 08 5D C2 04 00";
	$known_patterns->{"dummy3"}->{deltaoffset} = -16;
	
	# dummy
	$known_patterns->{"dummy4"}->{pattern} = "55 8B EC 51 53 8B D9 8B 0D ?? ?? ?? ?? 56 8B 53 04 57 8B FA B0 01 8B 72 04 3B F1 74 22 8B 45 0C 8B 00 89 45 FC";
	$known_patterns->{"dummy4"}->{deltaoffset} = -16;
	
	# Search for code, if it was not mapped yet
	if (not defined $name) {
		foreach my $pattern_name (keys %{$known_patterns}) {
			if (match_pattern_in_file($file_name, $offset, $known_patterns->{$pattern_name}->{pattern}) != 0) {
				# YEY!!! Pattern Found
				$name = $pattern_name;
				last;
			}
		}
	}
	
	# Now code should be mapped to function name, set $replace_code
	if (defined $name) {
		# debug
		# printf "remap call \'%s\' -> %i (delta: %i) -> %i -> %0.8X\n", $name, $stolen_code_offset, $known_patterns->{$name}->{deltaoffset}, $known_patterns->{$name}->{deltaoffset} + (0 - $stolen_code_offset - 1), $known_patterns->{$name}->{deltaoffset} + (0 - $stolen_code_offset - 1);
		# printf ".";
		
		my $replace_code = pack("C V", 0xE8, $known_patterns->{$name}->{deltaoffset} + (0 - $stolen_code_offset - 1));
		return ($name, $replace_code);
	}
	return (undef, undef);
}

sub find_pattern_in_file {
	my ($file_name, $pattern) = @_;
	my $bytes_to_read = -s $file_name; 
	my $data;
	my $chunk;
	my $chunksize = 512; # Set chunk size to some save value
	my $file;
	open($file, "<", $file_name) || die "can't open $file_name: $!";
	binmode $file;
	while ($bytes_to_read > 0) {
		# Read chunk
		my $new_chunk;
		read($file, $new_chunk, $bytes_to_read >= $chunksize ? $chunksize : $bytes_to_read);
		$data = $chunk . $new_chunk;
		$chunk = $new_chunk; # set Old chunk
		$bytes_to_read -= $bytes_to_read >= $chunksize ? $chunksize : $bytes_to_read;
		
		# Bin Match Chunk
		my $found_offset = search_pattern($data, $pattern);
		if ($found_offset) { return tell($file) - length($data) + $found_offset; };
	}
	close($file);
	return undef;
}

sub match_pattern_in_file {
	my ($file_name, $offset, $pattern) = @_;
	my $bytes_to_read = -s $file_name; 
	my $chunksize = 512; # Set chunk size to some save value
	my $data;
	my $file;
	open($file, "<", $file_name) || die "can't open $file_name: $!";
	binmode $file;
	seek($file, $offset, 0);
	read($file, $data, $chunksize);
	close($file);
	return match_pattern($data, $pattern);
}

# Uber SLOW !!!!!!!
# TODO: Optimize this one
sub search_pattern {
	my ($data, $pattern) = @_;
	my $data_len = length($data);
	my @bytes = split / /,$pattern; # Get Each HEX code of byte
	my $bytes_to_find = $#bytes + 1; # Get size of string to search for
	# Convert @bytes members to Chars for Better Performance
	for (my $i = 0; $i < $bytes_to_find; $i++) {
		if (@bytes[$i] ne "??" and @bytes[$i] ne "?") {
			@bytes[$i] = hex(@bytes[$i]);
		} else {
			@bytes[$i] = undef;
		}
	}
	my $offset = 0;
	BYTE: while ($offset + $bytes_to_find <= $data_len) {
		for (my $i = 0; $i < $bytes_to_find; $i++) {
			if (defined @bytes[$i]) {
				if (ord(substr($data, $offset + $i, 1)) != @bytes[$i]) {
					$offset++;
					next BYTE;
				};
			};
		};
		return $offset;
	};
	return undef;
}

sub match_pattern {
	my ($data, $pattern) = @_;
	my @bytes = split / /,$pattern; # Get Each HEX code of byte
	my $bytes_to_find = $#bytes + 1; # Get size of string to search for
	my $found = 0;
	for (my $i = 0; $i < $#bytes + 1; $i++) {
		if (@bytes[$i] ne "??" and @bytes[$i] ne "?") {
			if (ord(substr($data, $i, 1)) != hex(@bytes[$i])) {
				return 0
			};
		};
	};
	return 1;
}

1;
