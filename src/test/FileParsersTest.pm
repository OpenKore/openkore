# Unit test for FileParsers
package FileParsersTest;
use strict;

use Test::More;
use FileParsers;
use Globals;
use Misc;
use File::Copy;

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
			is(pickupitems($_), 2, $_) for grep {!/Bowman Scroll 1/} @{$item_names_part[0]};
			is(pickupitems($_), -1, $_) for @{$item_names_part[1]};
		};

		subtest 'writeDataFileIntact' => sub {
			my $config = {};
			parseConfigFile('data/write_config.txt', $config);

			my $expected = {
				parent_child_unchanged => 2,
				parent_child_changed => 2,
				block_0 => 'a',
				block_0_test => 1,
				block_1 => 'b',
				block_1_test => 2,
				leading => 'tab a',
				no_val_unchanged => undef,
				no_val_changed => undef,
				child_unchanged => 1,
				child_changed => 1,
				# TODO: Fix this? Not allowing tabs between key and value is probably a bug.
				"tab\ta" => undef,
			};
			is_deeply($config, $expected);

			$config->{parent_child_changed}++;
			$config->{block_0} = 'A';
			$config->{block_0_test}++;
			$config->{block_1} = 'B';
			$config->{block_1_test}++;
			$config->{no_val_changed}++;
			$config->{child_changed}++;

            File::Copy::cp 'data/write_config.txt' => 'data/write_config.out.txt';
			writeDataFileIntact('data/write_config.out.txt', $config);

			my $reader = Utils::TextReader->new( 'data/write_config.out.txt', { hide_includes => 0 } );
			is( $reader->readLine, "parent_child_unchanged 2\n" );
			is( $reader->readLine, "parent_child_changed 3\n" );
			is( $reader->readLine, "block A {\n" );
			is( $reader->readLine, "\ttest 2\n" );
			is( $reader->readLine, "}\n" );
			is( $reader->readLine, "!include write_config_a.txt\n" );
			is( $reader->readLine, "parent_child_unchanged 2\n" );
			is( $reader->readLine, "parent_child_changed 2\n" );
			is( $reader->readLine, "block b {\n" );
			is( $reader->readLine, "  test 2\n" );
			is( $reader->readLine, "}\n" );
			is( $reader->readLine, "child_unchanged 1\n" );
			is( $reader->readLine, "child_changed 1\n" );
			is( $reader->readLine, "leading tab a\n" );
			is( $reader->readLine, "leading tab a\n" );
			is( $reader->readLine, "tab\ta\n" );
			is( $reader->readLine, "no_val_unchanged\n" );
			is( $reader->readLine, "no_val_changed 1\n" );
			is( $reader->readLine, "child_changed 2\n" );
			is( $reader->readLine, "parent_child_changed 3\n" );
			is( $reader->eof, 1 );

			unlink 'data/write_config.out.txt';
		};
	}}
}

1;
