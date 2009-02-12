#########################################################################
#  OpenKore - Thread safe "splice" function
#
#  Copyright (c) 2006 OpenKore Development Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
package Utils::Splice;

use strict;

# MultiThreading Support
use threads;
use threads::shared;

sub splice_shared :locked {
	# Read Array and It's Size
	my $obj = shift;
	my $sz  = $#{$obj}; # not size, index of last element

	# Read and Prepare Offsets
	my $off = (@_) ? shift : 0;
	$off += $sz + 1 if $off < 0; # we set a new offset to element sz + old offset + 1 (ex. old = -1, new = $sz)

	# Prepare Head.
	my @head = @{$obj}[0 .. $off-1]; # copy part of the array before offset index in head

	# Read and prepare Len
	my $len = (@_) ? shift : $sz + 1 - $off; # If LENGTH is omitted, removes everything from OFFSET onward. # can be 0
	$len += $sz + 1 - $off if $len < 0; # we set a new len

	# Prepare Tail.
	my @tail = @{$obj}[$off + $len .. $sz]; # copy part of the array after (offset index plus len)

	# Prepare Resulting Array
	my @result = @{$obj}[$off .. $off + $len - 1];

	# Put list elements on middle
	my @middle = shared_clone(@_) if @_;

	# Output
	@{$obj} = (@head, @middle, @tail);
	return wantarray ? @result : pop @result;
}

1;
