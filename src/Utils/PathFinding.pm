#########################################################################
#  OpenKore - Pathfinding algorithm
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Pathfinding algorithm.
#
# This module implements the
# <a href="https://en.wikipedia.org/wiki/A*_search_algorithm">A*</a>
# (A-Star) pathfinding algorithm, which you can use to calculate how to
# walk to a certain spot on the map.
#
# This module is only for <i>calculation</i> of a route, not for
# telling OpenKore to walk to a certain place. That's what ai_route() is for.

# The actual algorithm itself is implemented in auto/XSTools/pathfinding/algorithm.{cpp|h}.
# This module is a Perl XS wrapper API for that algorithm. Most functions in this module
# are implemented in auto/XSTools/pathfinding/wrapper.xs.
package PathFinding;

use strict;
use warnings;
use Carp;

use Field;

use XSTools;
use Modules 'register';
XSTools::bootModule("PathFinding");



##
# PathFinding->new([args])
# args: Arguments to pass to $PathFinding->reset().
#
# Create a new PathFinding object. If args are given, the object will
# be initialized for you. If not, you must initialize it yourself
# by calling $PathFinding->reset().
sub new {
	my $class = shift;
	my $self = create();
	$self->reset(@_) if (@_);
	return $self;
}


##
# $PathFinding->reset(args...)
# Returns: a PathFinding object
#
# Required arguments:
# `l
# - start: a hash containing x and y values where the path should start.<br>
# - dest: a hash as above, but for the path's destination.
# `l`
#
# Semi-required arguments:
# `l
# - field: a hash with the keys <tt>weightMap</tt>, <tt>width</tt>, and <tt>height</tt>
# `l`
# OR all of:
# `l
# - weight_map: a reference to a field map with precomuted weights for each cell
# - width: the width of the field
# - height: the height of the field
# `l`
#
# Optional arguments:
# `l
# - timeout: the number of milliseconds to run each step for, defaults to 1500
# - avoidWalls: if walls should be avoided during pathing, defaults to 1
# - min_x: limits the map in a certain minimum x coordinate, defaults to 0
# - max_x: limits the map in a certain maximum x coordinate, defaults to width-1
# - min_y: limits the map in a certain minimum y coordinate, defaults to 0
# - max_y: limits the map in a certain maximum y coordinate, defaults to height-1
# - customWeights: if secondWeightMap should be used during pathing, defaults to 0
# - secondWeightMap: An array of hashes containing 3 keys, 'x', 'y' and 'weight', for all the cells which had their weight changed, 'weight' is the weight of the cell, defaults to undef
# `l`
sub reset {
	my $class = shift;
	my %args = @_;

	# Check arguments
	croak "Required arguments missing or wrong, specify correct 'field' or 'weight_map' and 'width' and 'height'\n"
	unless ($args{field} && UNIVERSAL::isa($args{field}, 'Field')) || ($args{weight_map} && $args{width} && $args{height});
	croak "Required argument 'start' missing\n" unless $args{start};
	croak "Required argument 'dest' missing\n" unless $args{dest};

	# Rebuild 'field' arg temporary here, to avoid that stupid bug, when weightMap not available
	if ($args{field} && UNIVERSAL::isa($args{field}, 'Field') && !$args{field}->{weightMap}) {
		$args{field}->loadByName($args{field}->name, 1);
	}

	# Default optional arguments
	my %hookArgs;
	$hookArgs{args} = \%args;
	$hookArgs{return} = 1;
	Plugins::callHook('PathFindingReset', \%hookArgs);
	if ($hookArgs{return}) {
		$args{avoidWalls} = 1 unless (defined $args{avoidWalls});
		$args{weight_map} = \($args{field}->{weightMap}) unless (defined $args{weight_map});

		$args{customWeights} = 0 unless (defined $args{customWeights});
		$args{secondWeightMap} = undef unless (defined $args{secondWeightMap});

		$args{randomFactor} = 0 unless (defined $args{randomFactor});
		$args{useManhattan} = 0 unless (defined $args{useManhattan});
		
		$args{width} = $args{field}{width} unless (defined $args{width});
		$args{height} = $args{field}{height} unless (defined $args{height});
		$args{timeout} = 1500 unless (defined $args{timeout});
		$args{min_x} = 0 unless (defined $args{min_x});
		$args{max_x} = ($args{width}-1) unless (defined $args{max_x});
		$args{min_y} = 0 unless (defined $args{min_y});
		$args{max_y} = ($args{height}-1) unless (defined $args{max_y});
	}

	return $class->_reset(
		$args{weight_map}, 
		$args{avoidWalls}, 
		$args{customWeights},
		$args{secondWeightMap},
		$args{randomFactor},
		$args{useManhattan},
		$args{width}, 
		$args{height},
		$args{start}{x},
		$args{start}{y},
		$args{dest}{x},
		$args{dest}{y},
		$args{timeout},
		$args{min_x},
		$args{max_x},
		$args{min_y},
		$args{max_y}
	);
}


##
# $PathFinding->run(solution_array)
# solution_array: Reference to an array in which the solution is stored. It will contain hashes of x and y coordinates from the start to the end of the path, including the starting pos
# Returns:
#    -3 when pathfinding is not yet complete.
#    -2 when Pathfinding->reset was not called.
#    -1 on no path found.
#    The number of steps required to walk from source to destination on success.

##
# $PathFinding->runcount()
# Returns:
#    -3 when pathfinding is not yet complete.
#    -2 when Pathfinding->reset was not called.
#    -1 on no path found.
#    The number of steps required to walk from source to destination on success.

1;
