# Unit test for FileParsers
package FileParsersTest;
use strict;

use Test::More;
use FileParsers;
use Globals;
use Misc;

sub start {
	print "### Starting FileParsersTest\n";
	
	my $items = do {
		use utf8;
		{
			501 => 'Red Potion',
			512 => 'Apple',
			528 => "Monster's Feed",
			2784 => 'Caixinha "Noite Feliz"',
			12080 => "Коктейль 'Дыхание дракона'",
			12153 => 'Bowman Scroll 1',
		}
	};
	
	subtest 'items.txt' => sub {
		parseROLUT('items.txt', \%items_lut);
		
		is_deeply(\%items_lut, $items, 'content');
		
		done_testing
	};
	
	subtest 'items_control.txt' => sub {
		parseItemsControl('items_control.txt', \%items_control);
		
		is(items_control('Random Item')->{keep}, 9, 'all');
		is(items_control($_)->{keep}, 2, $_) for values %$items;
		is(items_control($_)->{keep}, 2, $_) for 'Slotted Item [1]';
		is(items_control($_)->{keep}, 22, $_) for 'Slotted Item [2]';
		
		done_testing
	};
}

1;
