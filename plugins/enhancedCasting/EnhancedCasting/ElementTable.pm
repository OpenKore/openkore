package EnhancedCasting::ElementTable;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(element_multiplier normalize_element select_best);

my @ELEMENTS = qw(Neutral Water Earth Fire Wind Poison Holy Shadow Ghost Undead);

# Official pre-renewal property table. Rows are attack properties and columns
# are target properties. Each target level has its own table.
my %RAW = (
	1 => [
		[100,100,100,100,100,100,100,100, 25,100],
		[100, 25,100,150, 50,100, 75,100,100,100],
		[100,100,100, 50,150,100, 75,100,100,100],
		[100, 50,150, 25,100,100, 75,100,100,125],
		[100,175, 50,100, 25,100, 75,100,100,100],
		[100,100,125,125,125,  0, 75, 50,100,-25],
		[100,100,100,100,100,100,  0,125,100,150],
		[100,100,100,100,100, 50,125,  0,100,-25],
		[ 25,100,100,100,100,100, 75, 75,125,100],
		[100,100,100,100,100, 50,100,  0,100,  0],
	],
	2 => [
		[100,100,100,100,100,100,100,100, 25,100],
		[100,  0,100,175, 25,100, 50, 75,100,100],
		[100,100, 50, 25,175,100, 50, 75,100,100],
		[100, 25,175,  0,100,100, 50, 75,100,150],
		[100,175, 25,100,  0,100, 50, 75,100,100],
		[100, 75,125,125,125,  0, 50, 25, 75,-50],
		[100,100,100,100,100,100,-25,150,100,175],
		[100,100,100,100,100, 25,150,-25,100,-50],
		[  0, 75, 75, 75, 75, 75, 50, 50,150,125],
		[100, 75, 75, 75, 75, 25,125,  0,100,  0],
	],
	3 => [
		[100,100,100,100,100,100,100,100,  0,100],
		[100,-25,100,200,  0,100, 25, 50,100,125],
		[100,100,  0,  0,200,100, 25, 50,100, 75],
		[100,  0,200,-25,100,100, 25, 50,100,175],
		[100,200,  0,100,-25,100, 25, 50,100,100],
		[100, 50,100,100,100,  0, 25,  0, 50,-75],
		[100,100,100,100,100,125,-50,175,100,200],
		[100,100,100,100,100,  0,175,-50,100,-75],
		[  0, 50, 50, 50, 50, 50, 25, 25,175,150],
		[100, 50, 50, 50, 50,  0,150,  0,100,  0],
	],
	4 => [
		[100,100,100,100,100,100,100,100,  0,100],
		[100,-50,100,200,  0, 75,  0, 25,100,150],
		[100,100,-25,  0,200, 75,  0, 25,100, 50],
		[100,  0,200,-50,100, 75,  0, 25,100,200],
		[100,200,  0,100,-50, 75,  0, 25,100,100],
		[100, 25, 75, 75, 75,  0,  0,-25, 25,-100],
		[100, 75, 75, 75, 75,125,-100,200,100,200],
		[100, 75, 75, 75, 75,-25,200,-100,100,-100],
		[  0, 25, 25, 25, 25, 25,  0,  0,200,175],
		[100, 25, 25, 25, 25,-25,175,  0,100,  0],
	],
);

my %INDEX = map { lc($ELEMENTS[$_]) => $_ } 0 .. $#ELEMENTS;

sub normalize_element {
	my ($element) = @_;
	return unless defined $element;
	$element =~ s/^\s+|\s+$//g;
	$element = 'Shadow' if lc($element) eq 'dark';
	$element = 'Ghost' if lc($element) eq 'sense';
	return $ELEMENTS[$INDEX{lc($element)}] if exists $INDEX{lc($element)};
	return;
}

sub element_multiplier {
	my ($attack, $target, $level) = @_;
	$attack = normalize_element($attack);
	$target = normalize_element($target);
	return unless defined $attack && defined $target;
	$level = 1 unless defined $level && $level =~ /^[1-4]$/;
	return $RAW{$level}[$INDEX{lc($attack)}][$INDEX{lc($target)}] / 100;
}

sub select_best {
	my ($target, $level, $candidates) = @_;
	return unless ref $candidates eq 'ARRAY' && @$candidates;
	my @ranked = sort {
		$b->{multiplier} <=> $a->{multiplier}
			|| ($b->{priority} || 0) <=> ($a->{priority} || 0)
			|| ($a->{order} || 0) <=> ($b->{order} || 0)
	} map {
		my %copy = %$_;
		$copy{multiplier} = element_multiplier($copy{element}, $target, $level);
		\%copy;
	} grep { defined element_multiplier($_->{element}, $target, $level) } @$candidates;
	return $ranked[0];
}

1;
