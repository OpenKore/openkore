package ExtractorGen;

use strict;
use FindBin qw($RealBin);
use lib "$RealBin";
use lib "$RealBin/src";
use lib "$RealBin/src/deps";

use BaseFile;
use Disassemble::X86;
use Disassemble::X86::FormatTree;

####################################
### CATEGORY: Constructor
####################################

##
# ExtractorGen->new(BaseFile base_file, int map_function_offset)
#
# Create a new ExtractorGen object.
sub new {
	my ($class, $base_file, $map_function_offset) = @_;
	my $self = {};
	
	if (!defined $base_file) {
		printf "ERROR: Target file not loaded.\n";
		die;
	}
	
	if (!defined $map_function_offset) {
		printf "ERROR: No Offset to extract from.\n";
		die;
	}

	$self->{base_file} = $base_file;
	$self->{map_function_offset} = $map_function_offset;
	
	# Load Original Pattern for Extractor
	$self->{original_extractor_name} = $RealBin . "/src/extractor.bin";
	$self->{original_extractor} = undef;
	open($self->{original_extractor}, "<", $self->{original_extractor_name}) || die "can't open ".$self->{original_extractor_name}.": $!";
	binmode $self->{original_extractor};
	$self->{stolen_function_start} = 882; # TODO: Make it Dynamic
	$self->{original_extractor_file_name_offset} = 205918; # TODO: Make it Dynamic
	
	# Load Target Extractor
	$self->{target_extractor_name} = $RealBin . "/extractor.exe";
	$self->{target_extractor} = undef;
	open($self->{target_extractor}, ">", $self->{target_extractor_name}) || die "can't open ".$self->{target_extractor_name}.": $!";
	binmode $self->{target_extractor};

	# Place for Stolen Function
	$self->{stolen_function} = {};
	$self->{stolen_function}->{space} = 204800; # Space available for Stolen code (200Kb)
	$self->{stolen_function}->{known_calls} = {}; # Map of Known Calls
	$self->{stolen_function}->{stolen_code} = undef; # Stolen Function Data

	bless $self, $class;
	return $self;
}

####################################
### CATEGORY: Destructor
####################################

sub DESTROY {
	my ($self) = @_;
	close($self->{original_extractor});
	close($self->{target_extractor});

	$self->SUPER::DESTROY() if ($self->can("SUPER::DESTROY"));
}

####################################
### CATEGORY: Public
####################################

##
# int $ExtractorGen->generate_extractor()
#
# Searches file for Specific patterns
#
# Return: Offset of found data that matches @patterns[$_] and Pattern handler OnFound return 1 or undef
sub generate_extractor {
	my $self = shift;
	
	# Read the Map function
	my $original_data = $self->{base_file}->file_read_offset($self->{map_function_offset}, $self->{stolen_function}->{space});
	
	# Prepare Stolen Function
	printf "Working...";
	my $disassembler = Disassemble::X86->new( text => $original_data, format => "Tree" );
	until ( $disassembler->at_end() ) {
		my $disasm = $disassembler->disasm();
		# Process Call to Functions
		if ($disasm->{op} eq 'call') {
			my $offset = $disasm->{arg}->[0]->{arg}->[0] + $self->{map_function_offset};
			# debug
			# printf "call: (pos: %i) %i -> %i -> %0.8X\n", $disassembler->op_start(), $disasm->{arg}->[0]->{arg}->[0], $offset, $offset + 0x400000;
			# print Data::Dumper->Dump([$disasm]);
			
			# Remap Calls
			my ($replace_name, $replace_data) = $self->_remap_function($offset, length($self->{stolen_function}->{stolen_code}), $self->{stolen_function}->{known_calls}->{$offset} ? $self->{stolen_function}->{known_calls}->{$offset} : undef);
			if (defined $replace_name) {
				$self->{stolen_function}->{known_calls}->{$offset} = $replace_name;
				$self->{stolen_function}->{stolen_code} .= $replace_data;
			} else {
				# Output raw command
				$self->{stolen_function}->{stolen_code} .= substr($original_data, $disassembler->op_start(), $disassembler->op_len());
			}
			next;
		} else {
			# Output raw command
			$self->{stolen_function}->{stolen_code} .= substr($original_data, $disassembler->op_start(), $disassembler->op_len());
		};
		
		# Exit on 'ret' or 'retn'
		if ($disasm->{op} eq 'ret' or $disasm->{op} eq 'retn') {
			last;
		};
	};
	printf "\n";

	# Fill the rest of code space with 'nop'
	while (length($self->{stolen_function}->{stolen_code}) < $self->{stolen_function}->{space}) {
		$self->{stolen_function}->{stolen_code} .= pack("C", 0x90); #Fill with 'nop'
	}

	# Generate the output file.
	my $data;
	read($self->{original_extractor}, $data, $self->{stolen_function_start});
	seek($self->{original_extractor}, $self->{stolen_function}->{space}, 1);
	print {$self->{target_extractor}} $data;
	print {$self->{target_extractor}} $self->{stolen_function}->{stolen_code};
	# Copy the Rest of File until FileName string
	while ((! eof($self->{original_extractor})) && (tell($self->{original_extractor}) < $self->{original_extractor_file_name_offset})) {
		read($self->{original_extractor}, $data, 1);
		print {$self->{target_extractor}} $data;
	}
	# Print out FileName
	print {$self->{target_extractor}} $self->{base_file}->{file_name} . pack("C", 0x00); # Kids!!! this is a bad Example of OOP. So do not do this at home!
	seek($self->{original_extractor}, length($self->{base_file}->{file_name})+1, 1);
	# Copy the Rest of file
	while (! eof($self->{original_extractor})) {
		read($self->{original_extractor}, $data, 1);
		print {$self->{target_extractor}} $data;
	};

};

####################################
### CATEGORY: Private
####################################

sub _remap_function {
	my ($self, $offset, $stolen_code_offset, $name) = @_;
	
	# TODO: Make this MAP more dynamic
	my $known_patterns = {};
	# __alloca_probe
	$known_patterns->{"alloca_probe"}->{pattern} = "51 3D 00 10 00 00 8D 4C 24 08 72 14 81 E9 00 10 00 00 2D 00 10 00 00 85 01 3D 00 10 00 00 73 EC 2B C8 8B C4 85 01 8B E1 8B 08 8B 40 04 50 C3";
	$known_patterns->{"alloca_probe"}->{deltaoffset} = -374;

	# set_packet_len
	$known_patterns->{"set_packet_len"}->{pattern} = "55 8B EC 8B 55 0C 8B C1 8B 4D 08 89 08 89 50 04 5D C2 08 00";
	$known_patterns->{"set_packet_len"}->{deltaoffset} = -327;

	# set_packet_len
	$known_patterns->{"set_packet_len2"}->{pattern} = "55 8B EC 8B 55 0C 8B C1 8B 4D 08 89 08 8B 4D 10 89 50 04 89 48 08 5D C2 0C 00";
	$known_patterns->{"set_packet_len2"}->{deltaoffset} = -307;

	# print_packet1
	$known_patterns->{"print_packet1"}->{pattern} = "55 8B EC 8B C1 8B 4D 08 8B 11 8B 4D 0C 89 10 8B 11 89 50 04 8B 49 04 89 48 08 5D C2 08 00";
	$known_patterns->{"print_packet1"}->{deltaoffset} = -281;
	
	# print_packet2
	$known_patterns->{"print_packet2_1"}->{pattern} = "55 8B EC 8B 45 0C 8B 08 8B 45 08 89 08 8B 4D 10 8B 11 89 50 04 8B 49 04 89 48 08 5D C3";
	$known_patterns->{"print_packet2_1"}->{deltaoffset} = -240;
	
	# print_packet2
	$known_patterns->{"print_packet2_2"}->{pattern} = "55 8B EC 8B 45 0C 56 8B 75 08 57 8B 08 8B 45 10 8B FE 8B 10 8B 40 04 89 0F 89 57 04 89 47 08 8B C6 5F 5E 5D C3";
	$known_patterns->{"print_packet2_2"}->{deltaoffset} = -240;
	
	# print_packet3
	$known_patterns->{"print_packet3"}->{pattern} = "51 55 8B 6C 24 10 56 57 8B F9 8B 77 04 8B 46 04 80 78 19 00 B1 01 88 4C 24 0C 75 21 8B 55 00 90";
	$known_patterns->{"print_packet3"}->{deltaoffset} = -205;
	
	# print_packet4
	$known_patterns->{"print_packet4"}->{pattern} = "55 8B EC 8B C1 56 8B 4D 08 8B 11 8D 48 04 89 10 8B 55 0C 8B 32 89 31 8B 72 04 89 71 04 5E 8B 52 08 89 51 08 5D C2 08 00";
	$known_patterns->{"print_packet4"}->{deltaoffset} = -172;
	
	# print_packet5
	$known_patterns->{"print_packet5"}->{pattern} = "55 8B EC 8B 45 0C 56 8B 08 8B 45 08 89 08 8B 4D 10 8D 50 04 8B 31 89 32 8B 71 04 89 72 04 5E 8B 49 08 89 4A 08 5D C3";
	$known_patterns->{"print_packet5"}->{deltaoffset} = -133;
	
	# print_packet6
	$known_patterns->{"print_packet6"}->{pattern} = "51 55 8B 6C 24 10 56 57 8B F9 8B 77 04 8B 46 04 80 78 1D 00 B1 01 88 4C 24 0C 75 21 8B 55 00 90";
	$known_patterns->{"print_packet6"}->{deltaoffset} = -94;

	# print_packet6
	$known_patterns->{"print_packet6_1"}->{pattern} = "55 8B EC 83 EC 10 8B 45 0C 8B 55 14 53 8B D9 8B 4D 10 56 8B 75 08 89 4D F8 8B 4B 04 89 75 F0 89 45 F4 89 55 FC 8B 71 04";
	$known_patterns->{"print_packet6_1"}->{deltaoffset} = -57;
	
	# print_packet6
	$known_patterns->{"print_packet6_2"}->{pattern} = "83 EC 18 8B 44 24 20 8B 54 24 24 56 8B 74 24 2C 57 8B 7C 24 24 89 44 24 14 8D 44 24 10 89 54 24 18 50 8D 54 24 0C 52 89";
	$known_patterns->{"print_packet6_2"}->{deltaoffset} = -57;

	# dummy
	$known_patterns->{"dummy_1"}->{pattern} = "55 8B EC 83 EC 08 53 56 8B 15 ?? ?? ?? ?? 57 8B F9 B0 01 8B 4F 04 8B F1 8B 59 04 3B DA 74 22 8B 45 0C 8B 00 89 45 F8";
	$known_patterns->{"dummy_1"}->{deltaoffset} = -16;

	# dummy
	$known_patterns->{"dummy_2"}->{pattern} = "55 8B EC 83 EC 10 53 8B D9 56 57 8B 7B 04 8D 4D F4 C6 45 FF 01 8B 77 04 E8 ?? ?? ?? ?? 8B ?? ?? ?? ?? ?? 3B F2";
	$known_patterns->{"dummy_2"}->{deltaoffset} = -16;

	# dummy
	$known_patterns->{"dummy_3"}->{pattern} = "55 8B EC 83 EC 08 8B 45 0C 8D 55 F8 50 52 E8 ?? ?? ?? ?? 8B 08 8B 40 04 88 45 FC 8B 45 08 89 08";
	$known_patterns->{"dummy_3"}->{deltaoffset} = -16;
	
	# dummy
	$known_patterns->{"dummy_4"}->{pattern} = "55 8B EC 8B C1 8B 4D 08 8B 11 8B 4D 0C 89 10 8A 11 88 50 04 5D C2 08 00";
	$known_patterns->{"dummy_4"}->{deltaoffset} = -16;
	
	# dummy
	$known_patterns->{"dummy_5"}->{pattern} = "55 8B EC 8B C1 8B 4D 08 8B 11 89 10 8B 51 04 89 50 04 8B 49 08 89 48 08 5D C2 04 00";
	$known_patterns->{"dummy_5"}->{deltaoffset} = -16;
	
	# dummy
	$known_patterns->{"dummy_6"}->{pattern} = "55 8B EC 51 53 8B D9 8B 0D ?? ?? ?? ?? 56 8B 53 04 57 8B FA B0 01 8B 72 04 3B F1 74 22 8B 45 0C 8B 00 89 45 FC";
	$known_patterns->{"dummy_6"}->{deltaoffset} = -16;
	
	# dummy
	$known_patterns->{"dummy_7"}->{pattern} = "55 8B EC 8B C1 56 8B 4D 08 8B 11 83 C1 04 89 10 8D 50 04 8B 31 89 32 8B 71 04 89 72 04 5E 8B 49 08 89 4A 08 5D C2 04 00";
	$known_patterns->{"dummy_7"}->{deltaoffset} = -16;
	
	# dummy
	$known_patterns->{"dummy_8"}->{pattern} = "55 8B EC 51 53 8B D9 8B ?? ?? ?? ?? ?? 56 8B 53 04 57 8B FA B0 01 8B 72 04 3B F1 74 22 8B 45 0C 8B 00 89 45 FC 8B 45 FC 8B FE 3B 46 0C 0F 9C C0";
	$known_patterns->{"dummy_8"}->{deltaoffset} = -16;
	
	# Search for code, if it was not mapped yet
	if (not defined $name) {
		foreach my $pattern_name (keys %{$known_patterns}) {
			if ( $self->{base_file}->match_pattern_at_offset($known_patterns->{$pattern_name}->{pattern}, $offset) != 0) {
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

1;