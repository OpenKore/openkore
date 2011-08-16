package BaseFile;

# perl related
use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin";
use lib "$RealBin/src";
use lib "$RealBin/src/deps";
use File::Basename;

####################################
### CATEGORY: Constructor
###################################

##
# BaseFile->new(String file_path)
#
# Create a new BaseFile parser object.
sub new {
	my ($class, $file_path) = @_;
	my $self = {};

	# DIE about 'file_path' not specified
	if (!defined $file_path) {
		printf "ERROR: Target file not specified.\n";
		die;
	}
	
	$self->{base_file_name} = $file_path;
	$self->{base_file_len} = -s $file_path;
	open($self->{base_file}, "<", $file_path) || die "ERROR: Can't open $file_path: $!";
	binmode $self->{base_file};
	$self->{chunk_size} = 512; # Read using chunks of 512 bytes;
	
	# Get Just the FileName
	($self->{file_name}, undef) = fileparse($self->{base_file_name});
	
	bless $self, $class;
	return $self;
} 

####################################
### CATEGORY: Destructor
####################################

sub DESTROY {
	my $self = shift;
	close($self->{base_file});
	$self->SUPER::DESTROY() if ($self->can("SUPER::DESTROY"));
}

####################################
### CATEGORY: Public
####################################

##
# int $BaseFile->find_pattern(String pattern)
#
# Searches file for Specific patterns
#
# Return: Offset of found data that matches @patterns[$_] and Pattern handler OnFound return 1 or undef
sub find_pattern {
	my $self = shift;
	my @patterns = @_;
	my $bytes_to_read = $self->{base_file_len};
	my $old_addr = tell($self->{base_file});
	my $data;
	my $chunk = '';
	my $return_offset = undef;
	BYTE: while ($bytes_to_read > 0) {
		# Read chunk
		my $new_chunk;
		read($self->{base_file}, $new_chunk, $bytes_to_read >= $self->{chunk_size} ? $self->{chunk_size} : $bytes_to_read);
		$data = $chunk . $new_chunk;
		$chunk = $new_chunk; # set Old chunk
		$bytes_to_read -= $bytes_to_read >= $self->{chunk_size} ? $self->{chunk_size} : $bytes_to_read;
		
		# Bin Match Chunk
		foreach my $pattern (@patterns) {
		# 	my $pattern = $_;
			my $found_offset = $self->_search_pattern($data, $pattern->get_map_pointer_pattern());
			if ($found_offset) {
				$return_offset = tell($self->{base_file}) - length($data) + $found_offset;
				# TODO Fix the OFFSET THING,
				my $ret = $pattern->onFound($return_offset, $self);
				if ($ret == 1) {
					last BYTE;
				};
			};
		};
	};
	seek($self->{base_file}, $old_addr, 0);
	return $return_offset;
}

##
# int $BaseFile->match_pattern(String pattern)
#
# Matches pattern at current location
#
# Return: 1 -- match, undef -- not match
sub match_pattern {
	my ($self, $pattern) = @_;
	my $bytes_to_read = $self->{base_file_len};
	my $old_addr = tell($self->{base_file});
	my $data;
	read($self->{base_file}, $data, $self->{chunk_size});
	seek($self->{base_file}, $old_addr, 0);
	return $self->_match_pattern($data, $pattern);
}

##
# int $BaseFile->match_pattern_at_offset(String pattern, int offset)
#
# Matches pattern at $offset
#
# Return: 1 -- match, undef -- not match
sub match_pattern_at_offset {
	my ($self, $pattern, $offset) = @_;
	my $bytes_to_read = $self->{base_file_len};
	my $old_addr = tell($self->{base_file});
	my $data;
	seek($self->{base_file}, $offset, 0);
	read($self->{base_file}, $data, $self->{chunk_size});
	seek($self->{base_file}, $old_addr, 0);
	return $self->_match_pattern($data, $pattern);
}

##
# int $BaseFile->file_seek(int offset, int mode)
#
# Seek the loaded file
#
# Return: global $offset of file
sub file_seek {
	my ($self, $offset, $mode) = @_;
	seek($self->{base_file}, $offset, $mode);
	return tell($self->{base_file});
}

# int $BaseFile->file_seek(int offset, int mode)
#
# Tell current location of loaded file
#
# Return: global $offset of file
sub file_tell {
	my $self = shift;
	return tell($self->{base_file});
}

# int $BaseFile->file_size()
#
# Tell loaded file size
#
# Return: file size in bytes
sub file_size {
	my $self = shift;
	return $self->{base_file_len};
}

# String $BaseFile->file_read(int size)
#
# Read $size bytes from file
#
# Return: string containing read out bytes
sub file_read {
	my ($self, $size) = @_;
	my $bytes;
	read($self->{base_file}, $bytes, $size);
	return $bytes;
}


# String $BaseFile->file_read_offset(int offset, int size)
#
# Read $size bytes from file at $offset
#
# Return: string containing read out bytes
sub file_read_offset {
	my ($self, $offset, $size) = @_;
	my $old_addr = tell($self->{base_file});
	my $data;
	seek($self->{base_file}, $offset, 0);
	read($self->{base_file}, $data, $size);
	seek($self->{base_file}, $old_addr, 0);
	return $data;
}

####################################
### CATEGORY: Private
####################################

# Search for $pattern in $data
# TODO:
#  Uber SLOW !!!!!!! Optimize this one.
sub _search_pattern {
	my ($self, $data, $pattern) = @_;
	my $data_len = length($data);
	my @bytes = split / /,$pattern; # Get Each HEX code of byte
	my $bytes_to_find = $#bytes + 1; # Get size of string to search for
	# Convert @bytes members to Chars for Better Performance
	for (my $i = 0; $i < $bytes_to_find; $i++) {
		if ($bytes[$i] ne "??" and $bytes[$i] ne "?") {
			$bytes[$i] = hex($bytes[$i]);
		} else {
			$bytes[$i] = undef;
		}
	}
	my $offset = 0;
	BYTE: while ($offset + $bytes_to_find <= $data_len) {
		for (my $i = 0; $i < $bytes_to_find; $i++) {
			if (defined $bytes[$i]) {
				if (ord(substr($data, $offset + $i, 1)) != $bytes[$i]) {
					$offset++;
					next BYTE;
				};
			};
		};
		return $offset;
	};
	return undef;
}

sub _match_pattern {
	my ($self, $data, $pattern) = @_;
	my @bytes = split / /,$pattern; # Get Each HEX code of byte
	my $bytes_to_find = $#bytes + 1; # Get size of string to search for
	my $found = 0;
	for (my $i = 0; $i < $#bytes + 1; $i++) {
		if ($bytes[$i] ne "??" and $bytes[$i] ne "?") {
			if (ord(substr($data, $i, 1)) != hex($bytes[$i])) {
				return undef
			};
		};
	};
	return 1;
}

1;