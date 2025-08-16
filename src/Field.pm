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
# See https://openkore.com/wiki/Field_file_format
# for more information.
#
# This class is a hash and has the following hash items:
# `l
# - <tt>name</tt> - The name of the field, like 'prontera' and '0021@cata'. This is not always the same as baseName.
#                   You should not access this item directly; use the $Field->name() method instead.
# - <tt>baseName</tt> - The name of the field, which is the base name of the field without the extension.
#             This is not always the same as name: for example,
#             descName: Training Ground, name: 'new_1-2', field file: 'new_zone01.fld2', baseName: 'new_1-2'
#             descName: Catacombs, name: '0021@cata', field file: '1@cata.fld2', baseName: '1@cata'
# - <tt>width</tt> - The field's width. You should not access this item directly; use $Field->width() instead.
# - <tt>height</tt> - The field's height. You should not access this item directly; use $Field->width() instead.
# - <tt>rawMap</tt> - The raw map data. Contains information about which blocks you can walk on (byte 0),
#                     and which not (byte 1).
# - <tt>weightMap</tt> - The weight map data. Used by pathfinding.
# `l`
package Field;

use strict;
use warnings;
no warnings 'redefine';
use Compress::Zlib;
use File::Spec;
use Log qw(message);

use Globals qw($masterServer %mapAlias_lut %maps_lut %cities_lut %config);
use Modules 'register';
use Settings;
use FastUtils;
use Utils::Exceptions;
use Translation qw(T TF);
use Misc;
use Utils;

# Block types.
use constant {
	TILE_NOWALK => 0,
	TILE_WALK   => 1,
	TILE_SNIPE  => 2,
	TILE_WATER  => 4,
	TILE_CLIFF  => 8,
};

##
# Field->new(options...)
#
# Create a new Load a field (.fld2) file. 
#
# This function also loads an associated .weight file
# (the weight per cell file), which is used by pathfinding (for path choosing).
# If the associated .weight file does not exist, it will be created using an associated .dist file
# (the distance map file). If the associated .dist file does not exist, it will be created.
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
# - <tt>loadWeightMap</tt> (optional) - Whether to also load the weight map. By default, this is true.
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
		$self->loadFile($args{file}, $args{loadWeightMap});
	} elsif ($args{name}) {
		$self->loadByName($args{name}, $args{loadWeightMap});
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
#     ex. prontera, new_1-2 (alias), 1@cata (instanced)
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
	# TODO: $maps_lut, why not drop the .rsw from what we load in kore?
	return defined $maps_lut{$_[0]->{baseName}.'.rsw'} ? $maps_lut{$_[0]->{baseName}.'.rsw'} : T('Unknown Area');
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
	return exists $cities_lut{$_[0]->{name}.'.rsw'}; # TODO: $cities_lut, why replicate string data from $maps_lut? We can just add a maptype field in $maps_lut. (we can also look at the map_property packets)
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
# https://openkore.com/wiki/Field_file_format#The_FLD_file_format
#
# If you want to check whether the block is walkable, use $field->isWalkable() instead.
sub getBlock {
	my ($self, $offset) = @_;
	return ord(substr($self->{rawMap}, $offset, 1));
}

sub getOffset {
	my ($self, $x, $y) = @_;
	return (($y * $self->{width}) + $x);
}

sub isOffMap {
	my ($self, $x, $y) = @_;
	return ($x < 0 || $x >= $self->{width} || $y < 0 || $y >= $self->{height});
}

sub getCellInfo {
	my ($self, $x, $y) = @_;
	
	if ($self->isOffMap($x, $y)) {
		message "Cell $x $y is off the map.\n";
		return;
	}
	
	if ($self->isWalkable($x, $y)) {
		message "Cell $x $y is walkable.\n";
		my $weight = $self->getBlockWeight($x, $y);
		message "Cell $x $y has weight $weight.\n";
	} else {
		message "Cell $x $y is not walkable.\n";
	}
	
	if ($self->isSnipable($x, $y)) {
		message "Cell $x $y is snipable.\n";
	} else {
		message "Cell $x $y is not snipable.\n";
	}
	
	if ($self->isWater($x, $y)) {
		message "Cell $x $y is water.\n";
	} else {
		message "Cell $x $y is not water.\n";
	}
	
	if ($self->isCliff($x, $y)) {
		message "Cell $x $y is a Cliff.\n";
	} else {
		message "Cell $x $y is not a Cliff.\n";
	}
}

##
# boolean $Field->isWalkable(int x, int y)
#
# Check whether you can walk on ($x,$y) on this field.
#  1.73 microsec -> 798.04 nanosec p.o.
sub isWalkable {
	my ($self, $x, $y) = @_;
	return PathFinding::checkTile($x, $y, TILE_WALK, $self->{width}, $self->{height}, \$self->{rawMap});
}

##
# boolean $Field->isSnipable(int x, int y)
#
# Check whether you can snipe through ($x,$y) on this field.
#  1.73 microsec -> 798.04 nanosec p.o.
sub isSnipable {
	my ($self, $x, $y) = @_;
	return PathFinding::checkTile($x, $y, TILE_SNIPE, $self->{width}, $self->{height}, \$self->{rawMap});
}

##
# boolean $Field->isWater(int x, int y)
#
# Check whether there is water ($x,$y) on this field.
#  1.73 microsec -> 798.04 nanosec p.o.
sub isWater {
	my ($self, $x, $y) = @_;
	return PathFinding::checkTile($x, $y, TILE_WATER, $self->{width}, $self->{height}, \$self->{rawMap});
}

##
# boolean $Field->isCliff(int x, int y)
#
# Check whether cell ($x,$y) in a cliff on this field.
#  1.73 microsec -> 798.04 nanosec p.o.
sub isCliff {
	my ($self, $x, $y) = @_;
	return PathFinding::checkTile($x, $y, TILE_CLIFF, $self->{width}, $self->{height}, \$self->{rawMap});
}

sub getBlockWeight {
	my ($self, $x, $y) = @_;
	return 0 if ($self->isOffMap($x, $y));
	my $offset = $self->getOffset($x, $y);
	return ord(substr($self->{weightMap}, $offset, 1));
}

sub getBlockDist {
	my ($self, $x, $y) = @_;
	return 0 if ($self->isOffMap($x, $y));
	my $offset = $self->getOffset($x, $y);
	return ord(substr($self->{dstMap}, $offset, 1));
}

##
# $Field->closestWalkableSpot(pos, max_distance)
# pos: reference to a position hash (which contains 'x' and 'y' keys).
# max_distance: max possible distance in blocks from pos
# Returns: walkable position in a reference to a position hash (which contains 'x' and 'y' keys) on success or undef on failure.
sub closestWalkableSpot {
	my ($self, $pos, $max_distance) = @_;
	
	my %center = ( x => $pos->{x}, y => $pos->{y} );
	
	if ($self->isWalkable($pos->{x}, $pos->{y})) {
		return \%center;
	}
	
	return if (!$max_distance);
	
	my @current_distance = (1..$max_distance);
	
	foreach my $distance (@current_distance) {
		my @blocks = $self->calcRectArea($center{x}, $center{y}, $distance);
		foreach my $block (@blocks) {
			next if (!$self->isWalkable($block->{x}, $block->{y}));
			return $block;
		}
	}
	
	return undef;
}

sub getSquareEdgesFromCoord {
    my ($self, $start, $radius) = @_;

	my @coords;
	PathFinding::getSquareEdgesFromCoord($start->{x}, $start->{y}, $radius, $self->{width}, $self->{height}, \@coords);
	return @coords;
}

##
# $Field->calcRectArea($x, $y, $radius)
# Returns: an array with position hashes. Each has contains an x and a y key.
#
# Creates a rectangle with center ($x,$y) and radius $radius,
# and returns a list of positions of the border of the rectangle.
# 8.9us -> 1.1us
sub calcRectArea {
	my ($self, $x, $y, $radius) = @_;

	my @walkableBlocks;
	PathFinding::calcRectArea($x, $y, $radius, TILE_WALK, $self->{width}, $self->{height}, \$self->{rawMap}, \@walkableBlocks);
	return @walkableBlocks;
}

# Bresenham's algorithm
#
# Used for checking if there are no obstacles in the direct line of sight of 2 actors
# Do not use for checking if you can walk between 2 cells, use checkPathFree for that
#
# Reference: hercules src\map\path.c path_search_long
# 27.2micros -> 1.2micros
sub checkLOS {
	my ($self, $from, $to, $can_snipe) = @_;
	
	my $tile;
	if ($can_snipe) {
		$tile = TILE_WALK|TILE_SNIPE;
	} else {
		$tile = TILE_WALK;
	}
	
	return PathFinding::checkLOS($from->{x}, $from->{y}, $to->{x}, $to->{y}, $tile, $self->{width}, $self->{height}, \$self->{rawMap});
}

# Returns:
# -1: No LOS
#  0: out of range
#  1: sucess
#
# Reference: hercules src\map\battle.c battle_check_range
# 3.1micros -> 1.1micros
sub canAttack {
	my ($self, $pos1, $pos2, $can_snipe, $range, $clientSight) = @_;
	
	my $tile;
	if ($can_snipe) {
		$tile = TILE_WALK|TILE_SNIPE;
	} else {
		$tile = TILE_WALK;
	}
	
	return PathFinding::canAttack($pos1->{x}, $pos1->{y}, $pos2->{x}, $pos2->{y}, $tile, $self->{width}, $self->{height}, $range, $clientSight, \$self->{rawMap});
}

# Used for checking if there are no obstacles in a given walking solution
#
# get_client_solution already does this in the A* algorithm itself, so there is no need to check solutions made by it
# get_client_easy_solution does not check for obstacles, so all solutions made by it *should* be checked when certainty is necessary
#
# Do not use for checking if you can attack between 2 cells, use checkLOS for that
#
# Reference: hercules src\map\path.c path_search - flag&1
sub checkPathFree {
	my ($self, $from, $to) = @_;
	return PathFinding::checkPathFree($from->{x}, $from->{y}, $to->{x}, $to->{y}, TILE_WALK, $self->{width}, $self->{height}, \$self->{rawMap});
}

# Checks wheter you can send a move command from $from to $to
#
# Reference: hercules src\map\unit.c unit_walk_toxy
#
# Todo this should be used in a lot more places like Task::Route and Follow
# Can probably be moved to XS-cpp
sub canMove {
	my ($self, $from, $to) = @_;

	return 0 unless ($self->isWalkable($from->{x}, $from->{y}));
	return 0 unless ($self->isWalkable($to->{x}, $to->{y}));

	my $dist = blockDistance($from, $to);

	# This value is actually set at
	# hercules conf\map\battle\client.conf max_walk_path (which is by default 17, can be higher)
	my $maxWalkPath = $config{maxWalkPathDistance} || 17;
	if ($dist > $maxWalkPath) {
		return 0;
	}

	# Actually uses CheckLos at rathena - TODO: check which is better, both work
	# If there are no obstacles return success
	if ($self->checkPathFree($from, $to)) {
		return 1;
	}
	
	# If there are obstacles and the path is walkable the max solution dist acceptable is 14 (double check to save time)
	if ($dist > 14) {
		return 0;
	}

	# If there are obstacles and OFFICIAL_WALKPATH is defined (which is by default) then calculate a client pathfinding
	my $solution = get_client_solution($self, $from, $to);
	my $dist_path = scalar @{$solution};

	if ($dist_path == 0) {
		return 0;
	}

	# Pathfinding always returns the original cell in the solution, so remove 1 from it (or compare to 15 (14+1))
	#$dist_path -= 1;
	if ($dist_path > 15) {
		return 0;
	}

	return 1;
}

##
# void $Field->loadFile(String filename, [boolean loadWeightMap = true])
# filename: The filename of the field file to load.
# loadWeightMap: Whether to also load the associated weight map file.
#
# Load the specified field file (.fld2 file). This is like calling the constructor
# with the 'file' argument, but allows you to load a field inside this Field object.
#
# If $loadWeightMap is set to false, then $self->{weightMap} will be undef.
#
# Throws FileNotFoundException if the specified file does not exist.
# Throws IOException if a read error occured while reading the field file
# and/or the distance map file.
sub loadFile {
	my ($self, $filename, $loadWeightMap) = @_;

	$loadWeightMap = 1 if (!defined $loadWeightMap);
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

	# Load the associated weight map (.weight file)
	my $weightFile = $filename;
	$weightFile =~ s/\.fld2(\.gz)?$/.weight/i;
	if ($loadWeightMap) {
		if ((!-f $weightFile && !-f $weightFile.'.gz') || !$self->loadWeightMap($weightFile, $width, $height)) {
			
			# Load the associated distance map (.dist file)
			my $distFile = $filename;
			$distFile =~ s/\.fld2(\.gz)?$/.dist/i;
			if ((!-f $distFile && !-f $distFile.'.gz') || !$self->loadDistanceMap($distFile, $width, $height)) {
				# (Re)create the distance map.
				my $f;
				$self->{dstMap} = Utils::makeDistMap($fieldData, $width, $height);
				if (open($f, ">", $distFile)) {
					binmode $f;
					print $f pack("a2 v1", 'V#', 4);
					print $f pack("v v", $width, $height);
					print $f $self->{dstMap};
					close $f;
				}
			}
			
			# (Re)create the weight map.
			my $f;
			$self->{weightMap} = Utils::makeWeightMap($self->{dstMap}, $width, $height);
			if (open($f, ">", $weightFile)) {
				binmode $f;
				print $f pack("a2 v1", 'V#', 1);
				print $f pack("v v", $width, $height);
				print $f $self->{weightMap};
				close $f;
			}
			
			delete $self->{dstMap};
		}
	} else {
		delete $self->{weightMap};
	}

	$self->{width}  = $width;
	$self->{height} = $height;
	$self->{rawMap} = $fieldData;
	(undef, undef, $self->{baseName}) = File::Spec->splitpath($filename);
	$self->{baseName} =~ s/\.fld2$//i;
	$self->{name} = $self->{baseName};
	return 1;
}

# boolean $Field->loadWeightMap(String filename, int width, int height)
# filename: The filename of the weight map.
# width: The width of the field.
# height: The width of the field.
# Requires: The file $filename exists.
# Returns: Whether the weight map file is valid. If it's invalid, then it should be regenerated.
#
# Load a weight map (.weight file). $self->{weightMap} will contain the weight map data.
#
# Throws IOException if a read error occured.
sub loadWeightMap {
	my ($self, $filename, $width, $height) = @_;
	my ($f, $weightData);
	
	$filename .= '.gz' if (-f $filename.'.gz');
	
	if ($filename =~ /\.gz$/) {
		use bytes;
		no encoding 'utf8';
		
		my $gz = gzopen($filename, 'rb');
		if (!$gz) {
			IOException->throw("Cannot open $filename for reading.");
			return;
		} else {
			$weightData = '';
			while (!$gz->gzeof()) {
				my $buf;
				if ($gz->gzread($buf) >= 0) {
					$weightData .= $buf;
				} else {
					IOException->throw("An error occured while decompressing $filename.");
					return;
				}
			}
			$gz->gzclose();
		}
	} elsif (open($f, "<", $filename)) {
		binmode $f;
		local($/);
		$weightData = <$f>;
		close $f;
	} else {
		IOException->throw("Cannot open distance map $filename for reading.");
		return;
	}
	
	# Get file version.
	my $dversion = 0;
	if (substr($weightData, 0, 2) eq "V#") {
		$dversion = unpack("xx v", substr($weightData, 0, 4, ''));
	}

	# Get map width and height.
	my ($dw, $dh) = unpack("v v", substr($weightData, 0, 4, ''));

	# Version 0 files had a bug when height != width
	# Version 1 (the current version) is the first version.
	# If the distance map version is smaller than 4, regenerate the distance map.

	if ($dversion >= 1 && $width == $dw && $height == $dh) {
		$self->{weightMap} = $weightData;
		return 1;
	} else {
		return 0;
	}
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

	$filename .= '.gz' if (-f $filename.'.gz');

	if ($filename =~ /\.gz$/) {
		use bytes;
		no encoding 'utf8';

		my $gz = gzopen($filename, 'rb');
		if (!$gz) {
			IOException->throw("Cannot open $filename for reading.");
			return;
		} else {
			$distData = '';
			while (!$gz->gzeof()) {
				my $buf;
				if ($gz->gzread($buf) >= 0) {
					$distData .= $buf;
				} else {
					IOException->throw("An error occured while decompressing $filename.");
					return;
				}
			}
			$gz->gzclose();
		}
	} elsif (open($f, "<", $filename)) {
		binmode $f;
		local($/);
		$distData = <$f>;
		close $f;
	} else {
		IOException->throw("Cannot open distance map $filename for reading.");
		return;
	}

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
	# Version 4 (the current version) uses the new fld2 field file format.
	# If the distance map version is smaller than 4, regenerate the distance map.

	if ($dversion >= 4 && $width == $dw && $height == $dh) {
		$self->{dstMap} = $distData;
		return 1;
	} else {
		return 0;
	}
}

##
# void $Field->loadByName(String name, [boolean loadWeightMap = true])
# name: The name of the field to load. E.g. "prontera".
# loadWeightMap: Whether to also load the associated weight map file.
#
# Load a field file based on it's name. The actual field file to load is automatically
# determined based on the field name, the field files folder, whether the field file
# is compressed, etc.
#
# This method is like calling the constructor with the 'name' argument,
# but allows you to load a field inside this Field object.
#
# If $loadWeightMap is set to false, then $self->{weightMap} will be undef.
#
# Throws FileNotFoundException if a field file cannot be found for the specified
# field name.
# Throws IOException if a read error occured while reading the field file
# and/or the distance map file.
sub loadByName {
	my ($self, $name, $loadWeightMap) = @_;
	my $baseName;
	($baseName, $self->{instanceID}) = $self->nameToBaseName($name);
	$self->{baseName} = $baseName;
	my $file = $self->sourceName . ".fld2";

	if ($Settings::fields_folder) {
		$file = File::Spec->catfile($Settings::fields_folder, $file);
	}
	if (! -f $file) {
		$file .= ".gz";
	}

	if (-f $file) {
		$self->loadFile($file, $loadWeightMap);
		$self->{baseName} = $baseName;
		$self->{name} = $name;
	} else {
		FileNotFoundException->throw("No corresponding field file found for field '$name'.");
	}
}

# Map a field name to its field file's base name.
sub nameToBaseName {
	my ($self, $name) = @_;

	my ($instanceID, $baseName);
	
	my %hookArgs = (
		field => $self,
		name => $name,
		return => 0
	);
	Plugins::callHook('field_nameToBaseName', \%hookArgs);

	if ($hookArgs{return}) {
		if (exists $hookArgs{baseName}) {
			$baseName = $hookArgs{baseName};
		}
		if (exists $hookArgs{instanceID}) {
			$instanceID = $hookArgs{instanceID};
		}
		
	} elsif ($name =~ /^(\w{3})(\d@.*)/) { # instanced maps, ex: 0021@cata
		$instanceID = $1;
		$baseName = $2;
		
	} else {
		$baseName = $name;
	}

	return ($baseName, $instanceID);
}

sub sourceName {
	my ($self) = @_;
	my $name = $self->baseName;
	my $baseName;

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

	return $baseName;
}

### CATEGORY: Map image API

##
# String $Field->image([String format])
# format: image format
#
# Path to file with map image, autogenerated if needed.
sub image {
	my ($self, $format) = @_;
	my $name = $self->sourceName;
	my $search = $format;
	if ($search) {
		($format) = split /\s*,\s*/, $search;
	} else {
		$search = 'jpg, png, bmp, xpm';
		$format = 'xpm';
	}

	for (map { File::Spec->catfile($Settings::maps_folder, "$name.$_") } split /\s*,\s*/, $search) {
		return $_ if -f;
	}

	if (!-d $Settings::maps_folder) {
		if (!File::Path::make_path($Settings::maps_folder)) {
			IOException->throw("Unable to create folder $Settings::maps_folder ($!)");
		}
	}

	my $xpmFile = File::Spec->catfile($Settings::maps_folder, "$name.xpm");
	return unless open my $f, '>', $xpmFile;
	binmode $f;
	print $f Utils::xpmmake($self->width, $self->height, $self->{rawMap});
	close $f;

	return $xpmFile if $format eq 'xpm';

	undef $@;
	eval q(use Wx ':everything');
	return if $@;

	my %wxImageType = (
		jpg => eval 'wxBITMAP_TYPE_JPEG()',
		png => eval 'wxBITMAP_TYPE_PNG()',
		bmp => eval 'wxBITMAP_TYPE_BMP()',
	);

	my $file = File::Spec->catfile($Settings::maps_folder, "$name.$format");
	my $image = Wx::Image->newNameType($xpmFile, eval 'wxBITMAP_TYPE_ANY()');
	$image->SaveFile($file, $wxImageType{$format});

	return $file;
}

1;
