#########################################################################
#  OpenKore - Utility Functions
#
#  Copyright (c) 2004,2005,2006,2007 OpenKore Development Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Utility functions for data structure manipulation
#
# Various functions for manipulating data structures.

package Utils::DataStructures;

use strict;
use Exporter;
use base qw(Exporter);
use FastUtils;

our %EXPORT_TAGS = (
	# Manipulation functions for arrays which can contain "holes".
	arrays  => [qw( binAdd binFind binFindReverse binRemove binRemoveAndShift
			binRemoveAndShiftByIndex binSize )],
	# Functions for searching in arrays and nested data structures.
	finders => [qw( existsInList findIndex findIndexString findIndexString_lc findIndexString_lc_not_equip
			findIndexStringList_lc findLastIndex findKey findKeyString )],
	# Misc array functions.
	misc    => [qw( compactArray hashCopyByKey minHeapAdd shuffleArray )]
);
our @EXPORT_OK = (
	@{$EXPORT_TAGS{arrays}},
	@{$EXPORT_TAGS{finders}},
	@{$EXPORT_TAGS{misc}}
);
$EXPORT_TAGS{all} = \@EXPORT_OK;


##
# void binAdd(Array* array, ID)
# array: a reference to an array.
# ID: the element to add to @array.
# Requires: defined($array)
# Returns: the index of the added element.
#
# Add $ID to the first empty slot (that is, a slot which is set to undef)
# in @array, or append it to the end of @array if there are no empty
# slots.
#
# Example:
# @list = ("ID1", undef, "ID2");
# binAdd(\@list, "New");   # --> Returns: 1
# # Result:
# # $list[0] eq "ID1"
# # $list[1] eq "New"
# # $list[2] eq "ID2"
#
# @list = ("ID1", "ID2");
# binAdd(\@list, "New");   # --> Returns: 2
# # Result:
# # $list[0] eq "ID1"
# # $list[1] eq "ID2"
# # $list[2] eq "New"
sub binAdd {
	my $r_array = shift;
	my $ID = shift;
	my $i;
	for ($i = 0; $i <= @{$r_array};$i++) {
		if ($$r_array[$i] eq "") {
			$$r_array[$i] = $ID;
			return $i;
		}
	}
}

##
# binFind(Array *array, ID)
# array: a reference to an array.
# ID: the element to search for.
# Returns: the index of the element for $ID, or undef is $ID
#          is not an element in $array.
#
# Look for element $ID in $array.
#
# Example:
# our @array = ("hello", "world", "!");
# binFind(\@array, "world");   # => 1
# binFind(\@array, "?");       # => undef

# This function is written in src/auto/XSTools/misc/fastutils.xs


##
# binFindReverse(Array *array, ID)
#
# Same as binFind() but starts looking from the end of the array
# instead of from the beginning.
sub binFindReverse {
	my $r_array = shift;
	my $ID = shift;
	my $i;
	for ($i = @{$r_array} - 1; $i >= 0;$i--) {
		if ($$r_array[$i] eq $ID) {
			return $i;
		}
	}
}

##
# void binRemove(Array *array, ID)
# array: a reference to an array
# ID: the element to remove.
#
# Find a value in $array which has the same value as $ID,
# and remove it.
#
# Example:
# our @array = ("hello", "world", "!");
# # Same as: delete $array[1];
# binRemove(\@array, "world");
sub binRemove {
	my $r_array = shift;
	my $ID = shift;
	my $i;
	for ($i = 0; $i < @{$r_array};$i++) {
		if ($$r_array[$i] eq $ID) {
			delete $$r_array[$i];
			last;
		}
	}
}

sub binRemoveAndShift {
	my $r_array = shift;
	my $ID = shift;
	my $found;
	my $i;
	my @newArray;
	for ($i = 0; $i < @{$r_array};$i++) {
		if ($$r_array[$i] ne $ID || $found ne "") {
			push @newArray, $$r_array[$i];
		} else {
			$found = $i;
		}
	}
	@{$r_array} = @newArray;
	return $found;
}

sub binRemoveAndShiftByIndex {
	my $r_array = shift;
	my $index = shift;
	my $found;
	my $i;
	my @newArray;
	for ($i = 0; $i < @{$r_array};$i++) {
		if ($i != $index) {
			push @newArray, $$r_array[$i];
		} else {
			$found = 1;
		}
	}
	@{$r_array} = @newArray;
	return $found;
}

##
# int binSize(Array *array)
# r_array: a reference to an array.
#
# Calculates the size of $array, excluding undefined values.
#
# Example:
# our @array = ("hello", undef, "world");
# scalar @array;        # -> 3
# binSize(\@array);     # -> 2
sub binSize {
	my $r_array = shift;
	return 0 if !defined $r_array;

	my $found = 0;
	my $i;
	for ($i = 0; $i < @{$r_array};$i++) {
		if ($$r_array[$i] ne "") {
			$found++;
		}
	}
	return $found;
}

##
# void compactArray(Array *array)
#
# Resize an array by removing undefined items.
sub compactArray {
	my ($array) = @_;
	for (my $i = $#{$array}; $i >= 0; $i--) {
		if (!defined $array->[$i]) {
			splice @{$array}, $i, 1;
		}
	}
}

##
# boolean existsInList(list, val)
# list: a string containing a list of comma-seperated items.
# val: the value to check for.
#
# Check whether $val exists in $list. This function is case-insensitive.
#
# Example:
# my $list = "Apple,Orange Juice";
# existsInList($list, "apple");		# => 1
# existsInList($list, "Orange Juice");	# => 1
# existsInList($list, "juice");		# => 0
sub existsInList {
	my ($list, $val) = @_;
	return 0 if ($val eq "");
	my @array = split / *, */, $list;
	$val = lc($val);
	foreach (@array) {
		s/^\s+//;
		s/\s+$//;
		s/\s+/ /g;
		next if ($_ eq "");
		return 1 if (lc($_) eq $val);
	}
	return 0;
}


##
# findIndex(r_array, key, [num])
# r_array: A reference to an array, which contains a hash in each element.
# key: The name of the key to lookup.
# num: The number to compare with.
# Returns: The index in r_array of the found item, or undef if not found. Or, if not found and $num is not given: returns the index of first undefined array element, or the index of the last array element + 1.
#
# This function loops through the entire array, looking for a hash item whose
# value equals $num.
#
# Example:
# my @inventory;
# $inventory[0]{amount} = 50;
# $inventory[1]{amount} = 100;
# $inventory[2] = undef;
# $inventory[3]{amount} = 200;
# findIndex(\@inventory, "amount", 100);    # 1
# findIndex(\@inventory, "amount", 99);     # undef
# findIndex(\@inventory, "amount");         # 2
#
# @inventory = ();
# $inventory[0]{amount} = 50;
# findIndex(\@inventory, "amount");         # 1
sub findIndex {
	my $r_array = shift;
	return undef if !$r_array;
	my $key = shift;
	my $num = shift;

	if ($num ne "") {
		my $max = @{$r_array};
		for (my $i = 0; $i < $max; $i++) {
			return $i if (exists $r_array->[$i] && $r_array->[$i]{$key} == $num);
		}
		return undef;
	} else {
		my $max = @{$r_array};
		my $i;
		for ($i = 0; $i < $max; $i++) {
			return $i if (!$r_array->[$i] || !%{$r_array->[$i]});
		}
		return $i;
	}
}


##
# findIndexString(r_array, key, [str])
#
# Same as findIndex(), except this function compares strings, not numbers.
sub findIndexString {
	my $r_array = shift;
	return undef if !$r_array;
	my $key = shift;
	my $str = shift;

	if ($str ne "") {
		my $max = @{$r_array};
		for (my $i = 0; $i < $max; $i++) {
			if (exists $r_array->[$i] && $r_array->[$i]{$key} eq $str) {
				return $i;
			}
		}
		return undef;
	} else {
		my $max = @{$r_array};
		my $i;
		for ($i = 0; $i < $max; $i++) {
			return $i if (!$r_array->[$i] || !%{$r_array->[$i]});
		}
		return $i;
	}
}


##
# findIndexString_lc(r_array, key, [str])
#
# Same has findIndexString(), except this function does case-insensitive string comparisons.
sub findIndexString_lc {
	my $r_array = shift;
	return undef if !$r_array;
	my $key = shift;
	my $str = shift;

	if ($str ne "") {
		$str = lc $str;
		my $max = @{$r_array};
		for (my $i = 0; $i < $max; $i++) {
			return $i if (exists $r_array->[$i] && lc($r_array->[$i]{$key}) eq $str);
		}
		return undef;
	} else {
		my $max = @{$r_array};
		my $i;
		for ($i = 0; $i < $max; $i++) {
			return $i if (!$r_array->[$i] || !%{$r_array->[$i]});
		}
		return $i;
	}
}

our %findIndexStringList_lc_cache;

sub findIndexStringList_lc {
	my $r_array = shift;
	return undef if !defined $r_array;
	my $match = shift;
	my $ID = shift;
	my $skipID = shift;

	my $max = @{$r_array};
	my ($i, $arr);
	if (exists $findIndexStringList_lc_cache{$ID}) {
		$arr = $findIndexStringList_lc_cache{$ID};
	} else {
		my @tmp = split / *, */, lc($ID);
		$arr = \@tmp;
		%findIndexStringList_lc_cache = () if (scalar(keys %findIndexStringList_lc_cache) > 30);
		$findIndexStringList_lc_cache{$ID} = $arr;
	}

	foreach (@{$arr}) {
		for ($i = 0; $i < $max; $i++) {
			next if $i eq $skipID;
			if (exists $r_array->[$i] && lc($r_array->[$i]{$match}) eq $_) {
				return $i;
			}
		}
	}
	if ($ID eq "") {
		return $i;
	} else {
		return undef;
	}
}

##
# findIndexString_lc_not_equip(r_array, key, [str])
#
# Same has findIndexString(), except this function does case-insensitive string comparisons.
# It only finds items which are not equipped AND are able to be equipped (identified).
sub findIndexString_lc_not_equip {
	my $r_array = shift;
	return undef if !defined $r_array;
	my $match = shift;
	my $ID = lc(shift);
	my $i;
	for ($i = 0; $i < @{$r_array} ;$i++) {
		if ((exists $r_array->[$i] && lc($$r_array[$i]{$match}) eq $ID && ($$r_array[$i]{'identified'}) && !($$r_array[$i]{'equipped'}))
			 || (!$$r_array[$i] && $ID eq "")) {
			return $i;
		}
	}
	if ($ID eq "") {
		return $i;
	} else {
		return undef;
	}
}

sub findLastIndex {
	my $r_array = shift;
	return undef if !$r_array;
	my $key = shift;
	my $num = shift;

	if ($num ne "") {
		my $max = @{$r_array};
		for (my $i = $max-1; $i > -1; $i--) {
			return $i if (exists $r_array->[$i] && $r_array->[$i]{$key} == $num);
		}
		return undef;
	} else {
		my $max = @{$r_array};
		my $i;
		for ($i = $max-1; $i > -1; $i--) {
			return $i if (!$r_array->[$i] || !%{$r_array->[$i]});
		}
		return $i;
	}
}

sub findKey {
	my $r_hash = shift;
	my $match = shift;
	my $ID = shift;
	foreach (keys %{$r_hash}) {
		if (exists $r_hash->{$_} && $r_hash->{$_}{$match} == $ID) {
			return $_;
		}
	}
}

sub findKeyString {
	my $r_hash = shift;
	my $match = shift;
	my $ID = shift;
	foreach (keys %{$r_hash}) {
		if (ref($r_hash->{$_}) && $r_hash->{$_}{$match} eq $ID) {
			return $_;
		}
	}
}

##
# hashCopyByKey(Hash* target, Hash* source, keys...)
#
# Copies each key from the target to the source.
#
# For example,
# <pre class="example">
# hashCopyByKey(\%target, \%source, qw(some keys));
# </pre>
# would copy 'some' and 'keys' from the source hash to the
# target hash.
sub hashCopyByKey {
	my ($target, $source, @keys) = @_;
	foreach (@keys) {
		$target->{$_} = $source->{$_} if exists $source->{$_};
	}
}

sub minHeapAdd {
	my $r_array = shift;
	my $r_hash = shift;
	my $match = shift;
	my $i;
	my $found;
	my @newArray;
	for ($i = 0; $i < @{$r_array};$i++) {
		if (!$found && exists $r_array->[$i] && $$r_hash{$match} < $$r_array[$i]{$match}) {
			push @newArray, $r_hash;
			$found = 1;
		}
		push @newArray, $$r_array[$i];
	}
	if (!$found) {
		push @newArray, $r_hash;
	}
	@{$r_array} = @newArray;
}

##
# void shuffleArray(Array* array)
# array: A reference to an array.
#
# Randomize the order of the items in the array.
sub shuffleArray {
	my $r_array = shift;
	my $i = @{$r_array};
	my $j;
        while ($i--) {
               $j = int rand ($i+1);
               @$r_array[$i,$j] = @$r_array[$j,$i];
        }
}

1;
