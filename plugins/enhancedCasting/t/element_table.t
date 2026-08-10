use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/..";
use EnhancedCasting::ElementTable qw(element_multiplier normalize_element select_best);

is normalize_element('Dark'), 'Shadow', 'legacy Dark name is normalized';
is element_multiplier('Fire', 'Earth', 1), 1.5, 'Fire exploits Earth 1';
is element_multiplier('Water', 'Fire', 1), 1.5, 'Water exploits Fire 1';
is element_multiplier('Wind', 'Water', 1), 1.75, 'Wind exploits Water 1';
is element_multiplier('Earth', 'Wind', 1), 1.5, 'Earth exploits Wind 1';
is element_multiplier('Fire', 'Earth', 4), 2, 'level 4 table is used';
is element_multiplier('Poison', 'Undead', 4), -1, 'negative modifiers are preserved';
is normalize_element('  fire '), 'Fire', 'element names are trimmed and normalized';
ok !defined element_multiplier('Unknown', 'Fire', 1), 'unknown properties are rejected';

my $best = select_best('Earth', 1, [
	{ name => 'Cold Bolt', element => 'Water', priority => 20, order => 0 },
	{ name => 'Fire Bolt', element => 'Fire', priority => 10, order => 1 },
]);
is $best->{name}, 'Fire Bolt', 'multiplier outranks arbitrary priority';

$best = select_best('Neutral', 1, [
	{ name => 'Fire Bolt', element => 'Fire', priority => 10, order => 0 },
	{ name => 'Jupitel Thunder', element => 'Wind', priority => 100, order => 1 },
]);
is $best->{name}, 'Jupitel Thunder', 'priority resolves Neutral tie';

ok !defined select_best('Neutral', 1, []), 'empty candidate list has no selection';

done_testing;
