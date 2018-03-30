package OpenKore::Plugins::ItemWeightRecorder;
###############################################################################
# Record item weights into tables/item_weights.txt.
# Also supports Actor::Item->weight.

use strict;

use Globals qw( $char );
use Time::HiRes qw( &time );

our $name = 'item_weight_recorder';

our $filename = 'item_weights.txt';

our $item_weights ||= {};
our $loader ||= Settings::addTableFile( 'item_weights.txt', loader => [ \&FileParsers::parseDataFile2, $item_weights ], mustExist => 0 );
Settings::loadByHandle( $loader );

# Tracking inventory changes seems unnecessary, but it works around a specific
# failure case: when attempting to add an item to inventory/storage/cart fails
# (usually due to being overweight) the server sends an add AND remove for the
# same item.
our $inventory_changes;
our $last_item;
our $last_weight;

Plugins::register( $name, "$name plugin", \&Unload, \&Unload );

my $hooks = Plugins::addHooks(    #
	[ 'get_item_weight'             => \&onGetItemWeight ],
	[ 'packet/inventory_item_added' => \&onInventoryItemAdded ],
	[ 'inventory_item_removed'      => \&onInventoryItemRemoved ],
	[ 'packet/stat_info'            => \&onStatInfo ],
	[ 'packet/item_used'            => \&onItemUsed ],
);

sub Unload {
	Plugins::delHooks( $hooks );
}

sub onGetItemWeight {
	my ( undef, $args ) = @_;
	$args->{weight} = $item_weights->{ $args->{nameID} };
}

sub onInventoryItemAdded {
	my ( undef, $args ) = @_;

	return if $args->{fail};

	my $item = $char->inventory->getByID( $args->{ID} );
	return if !$item || !$args->{amount};

	# Weight updates to equipped items happen in reverse order. Ignore changes to them.
	return if $item->{equipped};

	$last_item = { item_id => $item->{nameID}, amount => $args->{amount}, time => time };
	$inventory_changes++;
}

sub onInventoryItemRemoved {
	my ( undef, $args ) = @_;
	return if $args->{item}->{equipped};
	$last_item = { item_id => $args->{item}->{nameID}, amount => $args->{amount}, time => time };
	$inventory_changes++;
}

# The server sends weight changes immediately after each inventory change.
sub onStatInfo {
	my ( undef, $args ) = @_;

	# 0x18 is WEIGHT.
	return if $args->{type} != 0x18;

	# Ignore item changes from more than one second ago. This might result
	# in some false negatives, but should also prevent some false positives.
	if ( $inventory_changes == 1 && defined $last_weight && !Utils::timeOut( $last_item->{time}, 1 ) ) {
		my $weight = abs( $args->{val} - $last_weight ) / $last_item->{amount};
		if ( $item_weights->{ $last_item->{item_id} } ne $weight ) {
			$item_weights->{ $last_item->{item_id} } = $weight;
			Log::debug( sprintf( "Item [%s] has weight [%.1f].\n", $last_item->{item_id}, $weight / 10 ), $name );
			log_update( $last_item->{item_id} );
		}
	}
	$last_item         = undef;
	$last_weight       = $args->{val};
	$inventory_changes = 0;
}

# The packet sequence here is: weight, item_used, inventory_removed.
# Ignore the next inventory change to avoid a false positive.
sub onItemUsed {
    $inventory_changes++;
}

sub log_update {
	my ( $item_id ) = @_;
	open FP, '>>', Settings::getTableFilename( $filename );
	print FP "$item_id $item_weights->{$item_id}\n";
	close FP;
}

1;
