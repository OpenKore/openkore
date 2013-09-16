package Pattern;

use strict;
use FindBin qw($RealBin);
use lib "$RealBin";
use lib "$RealBin/src";
use lib "$RealBin/src/deps";

use BaseFile;

####################################
### CATEGORY: Constructor
####################################

##
# Pattern->new()
#
# Create a new Pattern object.
sub new {
	my $class = shift;
	my %args = @_;
	my $self = {};
	
	$self->{map_pointer_pattern} = undef; # Pattern to find Function Pointer
	$self->{map_pointer_entry_offset} = undef; # Offset in Pattern to get the next data offset
	
	bless $self, $class;

	return $self;
}

####################################
### CATEGORY: Destructor
####################################

sub DESTROY {
	my ($self) = @_;
	$self->SUPER::DESTROY();
}

####################################
### CATEGORY: Public
####################################

# String $Pattern->get_map_pointer_pattern()
#
# Get pattern used to find map pointer
#
# Return: String containing HEX search pattern
sub get_map_pointer_pattern {
	my $self = shift;
	return $self->{map_pointer_pattern};
}

####################################
### CATEGORY: Events
####################################

# void $Pattern->onFound(int offset, BaseFile base_file)
#
# Event Handler to process the $base_file if the pattern was found
# By Default, this will get pointer to PacketLen Map and call $Pattern->onProcess
# with that pointer as param.
#
# Overload it in Children
sub onFound {
	my ($self, $offset, $base_file) = @_;
	
	# First, Try to match the Offset to be more Safe.
	if ($base_file->match_pattern_at_offset($self->{map_pointer_pattern}, $offset) == 1) {
		# Get the Offset of LenMap
		my $map_offset_raw = $base_file->file_read_offset($offset + $self->{map_pointer_entry_offset}, 4);
		my $map_offset = ($offset + $self->{map_pointer_entry_offset} + 4) + unpack("V!",$map_offset_raw); # Plus asm comand len
		return $self->onProcess($map_offset, $base_file);
	}
	
	return 0;
};

# void $Pattern->onProcess(int offset, BaseFile base_file)
#
# Event Handler to process actual PacketLen Map
#
# Overload it in Children
sub onProcess {
	my ($self, $offset, $base_file) = @_;
	return 0;
};


1;