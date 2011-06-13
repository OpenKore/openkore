# Unit test for FileParsers
package FileParsersTest;
use strict;

use Test::More;
use FileParsers;
use Globals;
use Misc;

use constant NOT_CONFIGURED_ITEM => 'Random Item';

sub start {
	subtest 'FileParsers' => sub { SKIP: {
		binmode STDOUT, ':utf8';
		binmode STDERR, ':utf8';
		
		my $items = do {
			use utf8;
			{
				501 => q(Red Potion),
				512 => q(Apple),
				528 => q(Monster's Feed),
				1207 => q(Main Gauche),
				1208 => q(Main Gauche),
				2784 => q(Caixinha "Noite Feliz"),
				12080 => q(Коктейль 'Дыхание дракона'),
				12153 => q(Bowman Scroll 1),
			}
		};
		
		my $itemSlotCount = {qw(
			1207 3
			1208 4
		)};
		
		subtest 'tables' => sub {
			for ('items.txt') {
				parseROLUT($_, \%items_lut);
				is_deeply(\%items_lut, $items, 'items.txt');
			}
			
			for ('itemslotcounttable.txt') {
				parseROLUT($_, \%itemSlotCount_lut);
				is_deeply(\%itemSlotCount_lut, $itemSlotCount, $_);
			}
		} or skip 'failed to load tables', 1;
		
		# 502 - unknown item
		my %item_names = map {$_ => itemName({nameID => $_, cards => pack('v*', (0)x4)})} 502, keys %items_lut;
		my @item_names_part = map {[map {$item_names{$_}} @$_]} List::MoreUtils::part {$_ == 1208} keys %item_names;
		
		subtest 'items_control.txt' => sub {
			parseItemsControl('items_control.txt', \%items_control);
			
			is(items_control(NOT_CONFIGURED_ITEM)->{keep}, 9, 'all');
			is(items_control($_)->{keep}, 2, $_) for @{$item_names_part[0]};
			is(items_control($_)->{keep}, 22, $_) for @{$item_names_part[1]};
		};
		
		subtest 'pickupitems.txt' => sub {
			parseDataFile_lc('pickupitems.txt', \%pickupitems);
			
			is(pickupitems(NOT_CONFIGURED_ITEM), 1, 'all');
			is(pickupitems($_), 2, $_) for @{$item_names_part[0]};
			is(pickupitems($_), -1, $_) for @{$item_names_part[1]};
		};
	}}
}

1;
