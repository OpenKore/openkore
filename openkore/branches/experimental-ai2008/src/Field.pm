#########################################################################
#  OpenKore - Field model v2
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: 6671 $
#  $Id: Field.pm 6671 2009-03-03 21:12:00Z Technology $
#
#########################################################################
##
# MODULE DESCRIPTION: Field model v2.
#
# The Field class represents a field in the game. A field is a set of tiles (blocks).
# each tile's properties are represented by a combination of flags
# flags: TILE_NOWALK, TILE_WALK, TILE_SNIPE, TILE_WATER, TILE_CLIFF
#
# This class is closely related to the .fld2 file, as used by OpenKore.
# See http://www.openkore.com/wiki/index.php/Field2_file_format#The_FLD2_file_format
# for more information.
#
# This class is a hash and has the following hash items:
# `l
# - <tt>name</tt> - The name of the field, like 'prontera'. This is not always the same as baseName.
#                   You should not access this item directly; use the $Field->name() method instead.
# - <tt>baseName</tt> - The name of the field, which is the base name of the file without the extension.
#             This is not always the same as name: for example, in the newbie grounds,
#             the field 'new_1-2' has field file 'new_zone01.fld2' and thus base name 'new_zone01'.
# - <tt>width</tt> - The field's width. You should not access this item directly; use $Field->width() instead.
# - <tt>height</tt> - The field's height. You should not access this item directly; use $Field->width() instead.
# - <tt>rawMap</tt> - The raw map data. Contains information about the tile's properties
#                     ex. TILE_WALK = byte 1; TILE_NOWALK = byte 0; ...
# - <tt>dstMap</tt> - The distance map data. Used by pathfinding.
# `l`
package Field;

# Make all References Strict
use strict;

# Others (Perl Related)
use warnings;
no warnings 'redefine';
use Compress::Zlib;
use File::Spec;

# Others (Kore related)
use Globals qw($masterServer %field);
use Modules 'register';
use Settings;
use FastUtils;
use Utils::Exceptions;

# TODO: remove when makeDistMap in .xs is fixed, we now use: Utils::old_makeDistMap
use Utils;

# TODO: make table for map aliasing and remove the switch
use Switch;

###################################
### CATEGORY: Block flag constants
###################################

##
# Field::TILE_FLAGTYPE	=> BITFLAG
# `l
# - Field::TILE_NOWALK	=> 0
# - Field::TILE_WALK		=> 1
# - Field::TILE_WATER		=> 4
# - Field::TILE_CLIFF		=> 8
# `l`
#
# Basic block flags, the .fld2 format is built up from these.
use constant {
	TILE_NOWALK	=> 0,
	TILE_WALK	=> 1,
	TILE_SNIPE	=> 2,
	TILE_WATER	=> 4,
	TILE_CLIFF	=> 8,
};
# reserved: 0, 1, 2, 4, 8, 16, 32, 64, 128
# because : [([([(1+2=3)+4=7]+8=15)+16=31]+32=63)+64=127]+128=255

##
# Field::TILE_FLAGTYPE	=> BITFLAG
# `l
# TILE_LOS		=> TILE_WALK|TILE_SNIPE
# TILE_WALKWATER	=> TILE_WALK|TILE_WATER
# `l`
#
# The bitwise OR operation: |
# <pre class="example">
# TILE_WALK|TILE_SNIPE = 1 | 2 = 3								 
# TILE_WALK|TILE_WATER = 1 | 4 = 5
# </pre>
# When we look at binary for the 1rst example: 001 OR 010 = 011
# (wich bytes are either in first OR second 1?)
#
# The bitwise AND operation: &
# <pre class="example">
# TILE_WALKWATER & 13 = 5	water | walkable
# TILE_WALKWATER & 6 = 4	water
# TILE_WALK & 11 = 1		walkable
# 4 & TILE_SNIPE = 0		not snipable
# </pre>
# When we look at binary for the 1rst example: 1101 AND 0101 = 0101
# (wich bytes are both in first AND second 1?)
#
# Combined block flags, that are practically usefull to us.
use constant {
	TILE_LOS		=> TILE_WALK|TILE_SNIPE,
	TILE_WALKWATER	=> TILE_WALK|TILE_WATER,
};

####################################
### CATEGORY: Constructor
####################################

##
# Field->new(options...)
#
# Create a new Load a field (.fld2) file. This function also loads an associated .dist file
# (the distance map file), which is used by pathfinding (for wall avoidance support).
# If the associated .dist file does not exist, it will be created.
#
# This function also supports gzip-compressed field files (.fld2.gz). If the .fld2 file cannot
# be found, but the corresponding .fld2.gz file can be found, this function will load that
# instead and decompress its data on-the-fly.
#
# Allowed options:
#
# `l
# - <tt>file</tt> - The file to load.
# - <tt>name</tt> - The name of the field to load.
# - <tt>loadDistanceMap</tt> (optional) - Whether to also load the distance map. By default, this is true.
# `l`
#
# You must specify either the 'file' option or the 'name' option. If you do not, an
# ArgumentException will be thrown. For example:
# <pre class="example">
# new Field(name => "new_1-1");
# new Field(file => "/path/to/prontera.fld2");
# new Field(); # Error: an ArgumentException will be thrown
# </pre>
#
# Throws FileNotFoundException if the field file does not exist (if the 'file' parameter is used),
# or if a field file cannot be found for the specified field name (if the 'name' parameter is used).<br>
# Throws IOException if an error occured while reading the field file.
sub new {
	my $class = shift;
	my %args = @_;
	my $self = bless {}, $class;

	if ($args{file}) {
		$self->loadFile($args{file}, $args{loadDistanceMap});
	} elsif ($args{name}) {
		$self->loadByName($args{name}, $args{loadDistanceMap});
	} else {
		ArgumentException->throw("No field name or filename specified.");
	}

	return $self;
}

############################
### CATEGORY: Public Methods (Queries)
############################

##
# String $Field->name()
#
# Returns the field's name.
sub name {
	return $_[0]->{name};
}

##
# int $Field->width()
#
# Returns the field's width, in blocks.
sub width {
	return $_[0]->{width};
}

##
# int $Field->height()
#
# Returns the field's height, in blocks.
sub height {
	return $_[0]->{height};
}

##
# int $Field->getBlock(int x, int y)
# x, y: A coordinate on the field.
# Returns: The combination of flags for this block. This is a combination of the block flag constants.
#
# Get the combination of flags for the block on the specified coordinate. This combination of flags is an integer,
# wich is a conversion from the RO tile type information in .gat and .rsw files (gat2fld2.pl)
# and corresponds with the values specified in the field2 file format specification:
# http://www.openkore.com/wiki/index.php/Field_file_format#The_FLD2_file_format
#
# If you want to check whether the block is walkable, use $field->isWalkable() instead.
sub getBlock {
	my ($self, $x, $y) = @_;
	if (&isValid) {
		return ord(substr($self->{rawMap}, ($y * $self->{width}) + $x, 1));
	} else {
		return TILE_NOWALK;
	}
}

##
# boolean $Field->isValid(int x, int y)
#
# Check whether coordinate ($x,$y) on this field is valid.
sub isValid {
	my ($self, $x, $y) = @_;
	return ($x >= 0 && $x < $self->{width} && $y >= 0 && $y < $self->{height}) || 0;
}

##
# boolean $Field->isWalkable(int x, int y)
#
# Check whether block ($x,$y) on this field is walkable.
sub isWalkable {
	return (&getBlock & TILE_WALK);
}

##
# boolean $Field->isWalkableWater(int x, int y)
#
# Check whether block ($x,$y) on this field is walkable AND has water.
sub isWalkableWater {
	return ((&getBlock & TILE_WALKWATER) == TILE_WALKWATER) || 0;
}

##
# boolean $Field->isWater(int x, int y)
#
# Check whether block ($x,$y) on this field has water.
sub isWater {
	return (&getBlock & TILE_WATER);
}

##
# boolean $Field->isLOS(int x, int y)
# Returns:
# `l
# - 0 : not TILE_WALK, nor TILE_SNIPE
# - 1 : TILE_WALK
# - 2 : TILE_SNIPE
# `l`
# If tile is LOS, we give reason why tile is LOS.
# Checks whether block ($x,$y) on this field is walkable OR snipable.
# 											 is not an obstruction to the line of sight.
sub isLOS {
	return (&getBlock & TILE_LOS);
}

############################
### CATEGORY: Private Methods
############################

##
# void $Field->loadFile(String filename, [boolean loadDistanceMap = true])
# filename: The filename of the field file to load.
# loadDistanceMap: Whether to also load the associated distance map file.
#
# Load the specified field file (.fld2 file). This is like calling the constructor
# with the 'file' argument, but allows you to load a field inside this Field object.
#
# If $loadDistanceMap is set to false, then $self->{dstMap} will be undef.
#
# Throws FileNotFoundException if the specified file does not exist.
# Throws IOException if a read error occured while reading the field file
# and/or the distance map file.
sub loadFile {
	my ($self, $filename, $loadDistanceMap) = @_;

	$loadDistanceMap = 1 if (!defined $loadDistanceMap);
	$filename =~ s/\//\\/g if ($^O eq 'MSWin32');
	if (!-f $filename) {
		FileNotFoundException->throw("File $filename does not exist.");
	}


	# Load the field file.
	my ($fieldData, $width, $height);
	if ($filename =~ /\.gz$/) {
		use bytes;
		no encoding 'utf8';

		my $gz = gzopen($filename, 'rb');
		if (!$gz) {
			IOException->throw("Cannot open $filename for reading.");
		} else {
			$fieldData = '';
			while (!$gz->gzeof()) {
				my $buf;
				if ($gz->gzread($buf) >= 0) {
					$fieldData .= $buf;
				} else {
					IOException->throw("An error occured while decompressing $filename.");
				}
			}
			$gz->gzclose();
		}

	} else {
		my $f;
		if (open($f, "<", $filename)) {
			binmode($f);
			local($/);
			$fieldData = <$f>;
			close($f);
		} else {
			IOException->throw("Cannot open $filename for reading.");
		}
	}

	($width, $height) = unpack("v v", substr($fieldData, 0, 4, ''));

	# Load the associated distance map (.dist file)
	my $distFile = $filename;
	$distFile =~ s/\.fld2(\.gz)?$/.dist/i;
	if ($loadDistanceMap) {
		if (!-f $distFile || !$self->loadDistanceMap($distFile, $width, $height)) {
			# (Re)create the distance map.
			my $f;
			# TODO: fix makeDistMap in .xs
			#$self->{dstMap} = makeDistMap($fieldData, $width, $height);
			$self->{dstMap} = Utils::old_makeDistMap($fieldData, $width, $height);
			if (open($f, ">", $distFile)) {
				binmode $f;
				print $f pack("a2 v1", 'V#', 4);
				print $f pack("v v", $width, $height);
				print $f $self->{dstMap};
				close $f;
			}
		}
	} else {
		delete $self->{dstMap};
	}

	$self->{width}  = $width;
	$self->{height} = $height;
	$self->{rawMap} = $fieldData;
	(undef, undef, $self->{baseName}) = File::Spec->splitpath($filename);
	$self->{baseName} =~ s/\.fld2$//i;
	$self->{name} = $self->{baseName};
	return 1;
}

##
# boolean $Field->loadDistanceMap(String filename, int width, int height)
# filename: The filename of the distance map.
# width: The width of the field.
# height: The width of the field.
# Requires: The file $filename exists.
# Returns: Whether the distance map file is valid. If it's invalid, then it should be regenerated.
#
# Load a distance map (.dst file). $self->{dstMap} will contain the distance map data.
#
# Throws IOException if a read error occured.
sub loadDistanceMap {
	my ($self, $filename, $width, $height) = @_;
	my ($f, $distData);

	if (open($f, "<", $filename)) {
		binmode $f;
		local($/);
		$distData = <$f>;
		close $f;

		# Get file version.
 		my $dversion = 0;
 		if (substr($distData, 0, 2) eq "V#") {
 			$dversion = unpack("xx v", substr($distData, 0, 4, ''));
 		}

 		# Get map width and height.
 		my ($dw, $dh) = unpack("v v", substr($distData, 0, 4, ''));

		# Version 0 files had a bug when height != width
		# Version 1 files did not treat walkable water as walkable, all version 0 and 1 maps need to be rebuilt.
		# Version 2 and greater have no know bugs, so just do a minimum validity check.
		# Version 3 adds better support for walkable water blocks.
		# Version 4 (the current version) the rightern & upper tiles are made unwalkable in fld2, so also the .dist changes
		# If the distance map version is smaller than 4, regenerate the distance map.

		if ($dversion >= 4 && $width == $dw && $height == $dh) {
			$self->{dstMap} = $distData;
			return 1;
		} else {
			return 0;
		}
	} else {
		IOException->throw("Cannot open distance map $filename for reading.");
	}
}

##
# void $Field->loadByName(String name, [boolean loadDistanceMap = true])
# name: The name of the field to load. E.g. "prontera".
# loadDistanceMap: Whether to also load the associated distance map file.
#
# Load a field file based on it's name. The actual field file to load is automatically
# determined based on the field name, the field files folder, whether the field file
# is compressed, etc.
#
# This method is like calling the constructor with the 'name' argument,
# but allows you to load a field inside this Field object.
#
# If $loadDistanceMap is set to false, then $self->{dstMap} will be undef.
#
# Throws FileNotFoundException if a field file cannot be found for the specified
# field name.
# Throws IOException if a read error occured while reading the field file
# and/or the distance map file.
sub loadByName {
	my ($self, $name, $loadDistanceMap) = @_;
	my $file = $self->nameToBaseName($name);

	if ($Settings::fields_folder) {
		$file = File::Spec->catfile($Settings::fields_folder, $file);
	}
	if (! -f $file) {
		$file .= ".gz";
	}

	if (-f $file) {
		$self->loadFile($file, $loadDistanceMap);
		$self->{name} = $name;
	} else {
		FileNotFoundException->throw("No corresponding field file found for field '$name'.");
	}
}

# Map a field name to its field file's base name.
sub nameToBaseName {
	my ($self, $name) = @_;
	my ($fieldFolder, $baseName);

	$fieldFolder = $Settings::fields_folder || ".";
	if ($masterServer && $masterServer->{"field_$name"}) {
		# Handle server-specific versions of the field.
		$baseName = $masterServer->{"field_$name"};

	} else {
		# Some fields have multiple names, but have the same field data nevertheless.
		# For example, the newbie grounds (new_1-1, new_2-1, etc.) all look the same,
		# even though they're different fields and may have different monsters.
		# Take care of that.
		if ($name =~ /^new_\d-(\d)$/) {
			$name = "new_zone0$1";
		} elsif ($name =~ /^force_\d-(\d)$/) {
			$name = "force_map$1";
		} elsif ($name =~ /^pvp_([a-z])_\d-(\d)$/) {
			switch ($1) {
				case "n" {
					switch($2) {
						case 1 { $name = "new_zone03" }
						case 2 { $name = "job_hunter" }
						case 3 { $name = "job_wizard" }
						case 4 { $name = "job_priest" }
						case 5 { $name = "job_knight" }
					}
				}
				case "y" {
					switch($2) {
						case 1 { $name = "prontera" }
						case 2 { $name = "izlude" }
						case 3 { $name = "payon" }
						case 4 { $name = "alberta" }
						case 5 { $name = "morocc" }
					}
				}
				else {}
			}
		}
		$baseName = "$name.fld2";
	}
	return $baseName;
}

1;
