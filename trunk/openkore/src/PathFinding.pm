package PathFinding;

use 5.006;
use strict;
use warnings;
use Carp;

require XSLoader;
XSLoader::load('Tools');



##
# PathFinding->new(...)
# Required arguments:
#   start: a hash containing x and y values where the path should start
#   dest: a hash as above, but for the path's destination
#
# Semi-required arguments:
#   field: a hash with the keys dstMap, width, and height
# OR all of:
#   distance_map: a reference to a field map with precomuted distances from walls
#   width: the width of the field
#   height: the height of the field
#
# Optional arguments:
#   timeout: the number of milliseconds to run each step for, defaults to 1500
#   weights: a reference to a string of 256 characters, used as the weights to give
#            squares from 0 to 255 squares away from the closest wall. The first
#            character must be chr(255).
#
# Returns: a PathFinding object
sub new {
	my $class = shift;
	my %args = @_;

	# Check arguments
	croak "Required arguments missing, specify 'field' or 'distance_map' and 'width' and 'height'\n"
		unless $args{field} || ($args{distance_map} && $args{width} && $args{height});
	croak "Required argument 'start' missing\n" unless $args{start};
	croak "Required argument 'dest' missing\n" unless $args{dest};

	# Default optional arguments
	$args{distance_map} = \$args{field}{dstMap} unless $args{distance_map};
	$args{width} = $args{field}{width} unless $args{width};
	$args{height} = $args{field}{height} unless $args{height};
	$args{timeout} = 1500 unless $args{timeout};

	return init(${$args{distance_map}}, $args{weights}, $args{width}, $args{height},
		$args{start}{x}, $args{start}{y},
		$args{dest}{x}, $args{dest}{y},
		$args{timeout});
}


1;
__END__

# Docs for XS functions:

##
# $path_obj->runref()
# Retunrs: undef on failure, 0 when pathfinding is not yet complete, or an array
#     reference when a path is found. The array reference contains hashes of x
#     and y coordinates from the start to the end of the path.

##
# $path_obj->runstr()
# Retunrs: undef on failure, 0 when pathfinding is not yet complete, or a string
#     of packed shorts. The shorts are pairs of X and Y coordinates running
#     from the end to the start of the path. (note that the order is reversed)

##
# $path_obj->runcount()
# Returns: -1 on failure, 0 when pathfinding is not yet complete, or the
#     number of steps required to walk from source to destination.
