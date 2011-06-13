# Unit test for FileParsers
package FileParsersTest;
use strict;

use Test::More;
use FileParsers;
use Globals;
use Misc;

sub start {
	subtest 'FileParsers' => sub {
		binmode STDOUT, ':utf8';
		
		my $items = do {
			use utf8;
			{
				501 => q(Red Potion),
				512 => q(Apple),
				528 => q(Monster's Feed),
				2784 => q(Caixinha "Noite Feliz"),
				12080 => q(Коктейль 'Дыхание дракона'),
				12153 => q(Bowman Scroll 1),
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
			is(items_control($_)->{keep}, 2, $_) for 'Unknown #502';
			is(items_control($_)->{keep}, 2, $_) for 'Slotted Item [1]';
			is(items_control($_)->{keep}, 22, $_) for 'Slotted Item [2]';
			
			done_testing
		};
		
		subtest 'pickupitems.txt' => sub {
			parseDataFile_lc('pickupitems.txt', \%pickupitems);
			
			is(pickupitems('Random Item'), 1, 'all');
			is(pickupitems($_), 2, $_) for values %$items;
			is(pickupitems($_), 2, $_) for 'Unknown #502';
			is(pickupitems($_), 2, $_) for 'Slotted Item [1]';
			is(pickupitems($_), -1, $_) for 'Slotted Item [2]';
			
			done_testing
		};
		
		done_testing
	}
}

1;
