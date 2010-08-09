#########################################################################
#  OpenKore - Field model
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: 5276 $
#  $Id: Misc.pm 5276 2006-12-28 21:24:00Z vcl_kore $
#
#########################################################################
##
# MODULE DESCRIPTION: Field model.
#
# The Field class represents a field in the game. A field is a set of blocks.
# each block has a specific type, like 'walkable', 'not walkable', 'water',
# 'cliff', etc.
#
# This class is closely related to the .fld file, as used by OpenKore.
# See http://www.openkore.com/wiki/index.php/Field_file_format#The_FLD_file_format
# for more information.
#
# This class is a hash and has the following hash items:
# `l
# - <tt>name</tt> - The name of the field, like 'prontera' and '0021@cata'. This is not always the same as baseName.
#                   You should not access this item directly; use the $Field->name() method instead.
# - <tt>baseName</tt> - The name of the field, which is the base name of the file without the extension.
#             This is not always the same as name: for example,
#             descName: Training Ground, name: 'new_1-2', field file: 'new_zone01.fld', baseName: 'new_zone01'
#             descName: Catacombs, name: '0021@cata', field file: '1@cata.fld', baseName: '1@cata'
# - <tt>width</tt> - The field's width. You should not access this item directly; use $Field->width() instead.
# - <tt>height</tt> - The field's height. You should not access this item directly; use $Field->width() instead.
# - <tt>rawMap</tt> - The raw map data. Contains information about which blocks you can walk on (byte 0),
#                     and which not (byte 1).
# - <tt>dstMap</tt> - The distance map data. Used by pathfinding.
# `l`
package Field;

use strict;
use warnings;
no warnings 'redefine';
use Compress::Zlib;
use File::Spec;

use Globals qw($masterServer %field %mapAlias_lut %maps_lut %cities_lut);
use Modules 'register';
use Settings;
use FastUtils;
use Utils::Exceptions;
use Translation qw(TF);

# Block types.
use constant {
	WALKABLE                        => 0,
	NON_WALKABLE                    => 1,
	NON_WALKABLE_NON_SNIPABLE_WATER => 2,
	WALKABLE_WATER                  => 3,
	NON_WALKABLE_SNIPABLE_WATER     => 4,
	SNIPABLE_CLIFF                  => 5,
	NON_SNIPABLE_CLIFF              => 6,
	UNKNOWN                         => 7
};


##
# Field->new(options...)
#
# Create a new Load a field (.fld) file. This function also loads an associated .dist file
# (the distance map file), which is used by pathfinding (for wall avoidance support).
# If the associated .dist file does not exist, it will be created.
#
# This function also supports gzip-compressed field files (.fld.gz). If the .fld file cannot
# be found, but the corresponding .fld.gz file can be found, this function will load that
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
# new Field(file => "/path/to/prontera.fld");
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

##
# String $Field->name()
#
# Returns the field's name.
#     ex. prontera, new_1-2 (alias), 0021@cata (instance)
sub name {
	return $_[0]->{name};
}

##
# String $Field->baseName()
#
# Returns the field's base name.
#     ex. prontera, new_zone01 (aliased), 1@cata (instanced)
sub baseName {
	return $_[0]->{baseName};
}

##
# String $Field->instanceID()
#
# Returns the field's instanceID
#     ex. in 0021@cata, 002 is the instanceID
sub instanceID {
	return $_[0]->{instanceID};
}

##
# String $Field->descName()
#
# Returns the field's descriptive name.
#     ex.
#			Prontera City, Capital of Rune Midgard
#			Training Ground
#			Catacombs
sub descName {
	return $maps_lut{$_[0]->{baseName}.'.rsw'}; # TODO: $maps_lut, why not drop the .rsw from what we load in kore?
}

##
# String $Field->descString()
#
# Returns the field's descriptive string.
sub descString {
	return sprintf("%s (%s)", $_[0]->descName, $_[0]->name) . ($_[0]->{instanceID} ? TF(" at instanceID %s", $_[0]->instanceID) : '');
}

##
# String $Field->isCity()
#
# Returns wether the field is a city.
sub isCity {
	return exists $cities_lut{$_[0]->{baseName}.'.rsw'}; # TODO: $cities_lut, why replicate string data from $maps_lut? We can just add a maptype field in $maps_lut. (we can also look at the map_property packets)
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
# Returns: The type for this block. This is one of the block type constants.
#
# Get the type for the block on the specified coordinate. This type is an integer, which
# corresponds with the values specified in the field file format specification:
# http://www.openkore.com/wiki/index.php/Field_file_format#The_FLD_file_format
#
# If you want to check whether the block is walkable, use $field->isWalkable() instead.
sub getBlock {
	my ($self, $x, $y) = @_;
	if ($self->isOffMap($x, $y)) {
		return NON_WALKABLE;
	} else {
		return ord(substr($self->{rawMap}, ($y * $self->{width}) + $x, 1));
	}
}

sub isOffMap {
	my ($self, $x, $y) = @_;
	return ($x < 0 || $x >= $self->{width} || $y < 0 || $y >= $self->{height});
}

##
# boolean $Field->isWalkable(int x, int y)
#
# Check whether you can walk on ($x,$y) on this field.
sub isWalkable {
	my $p = &getBlock;
	return ($p == WALKABLE || $p == WALKABLE_WATER);
}

##
# boolean $Field->isSnipable(int x, int y)
#
# Check whether you can snipe through ($x,$y) on this field.
sub isSnipable {
	my $p = &getBlock;
	return ($p == WALKABLE || $p == WALKABLE_WATER || $p == NON_WALKABLE_SNIPABLE_WATER || $p == SNIPABLE_CLIFF);
}

##
# void $Field->loadFile(String filename, [boolean loadDistanceMap = true])
# filename: The filename of the field file to load.
# loadDistanceMap: Whether to also load the associated distance map file.
#
# Load the specified field file (.fld file). This is like calling the constructor
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
	$distFile =~ s/\.fld(\.gz)?$/.dist/i;
	if ($loadDistanceMap) {
		if (!-f $distFile || !$self->loadDistanceMap($distFile, $width, $height)) {
			# (Re)create the distance map.
			my $f;
			$self->{dstMap} = Utils::makeDistMap($fieldData, $width, $height);
			if (open($f, ">", $distFile)) {
				binmode $f;
				print $f pack("a2 v1", 'V#', 3);
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
	$self->{baseName} =~ s/\.fld$//i;
	$self->{name} = $self->{baseName};
	return 1;
}

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
		# Version 3 (the current version) adds better support for walkable water blocks.
		# If the distance map version is smaller than 3, regenerate the distance map.

		if ($dversion >= 3 && $width == $dw && $height == $dh) {
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
	($self->{baseName}, $self->{instanceID}) = $self->nameToBaseName($name);
	my $file = $self->{baseName} . ".fld";

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
	
	my ($baseName, $instanceID);

	if ($name =~ /^(\d{3})(\d@.*)/) { # instanced maps, ex: 0021@cata
		$instanceID = $1;
		$name = $2;
	}

	if ($baseName = $masterServer->{"field_$name"}) {
		# Handle server-specific versions of the field from servers.txt
	} elsif ($baseName = $mapAlias_lut{"$name"}) {
		# Some fields have multiple names, but have the same field data nevertheless.
		# For example, the newbie grounds (new_1-1, new_2-1, etc.) all look the same,
		# even though they're different fields and may have different monsters.
		# Take care of that.
	} else {
		# The field name is already the base name.
		$baseName = $name;
	}

	return ($baseName, $instanceID);

	# tl;dr $name =~ s/^\d{3}(?=\d@)//; return $masterServer->{"field_$name"} || $mapAlias_lut{$name} || $name;
}

1;
