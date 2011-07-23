package Interface::Wx::Context::InventoryItem;

use strict;
use base 'Interface::Wx::Context::Item';

use Globals qw($char %storage $cardMergeIndex @cardMergeItemsID @identifyID %currentDeal);
use Translation qw(T TF);
use Utils qw(binFind);

sub new {
	my ($class, $parent, $objects) = @_;
	
	Scalar::Util::weaken(my $weak = my $self = $class->SUPER::new ($parent, $objects));
	
	my ($canStorage, $canCart) = (%storage && $storage{opened}, $char->cartActive);
	
	if (@$objects == 1) { # single item selected
		my ($object) = @$objects;
		my $invIndex = $object->{invIndex};
		
		my ($canActivate, $subActivate, $canDrop) = (undef, undef, 1);
		unless ($object->{identified}) {
			$canActivate = T('Identify') if defined (my $identifyIndex = binFind(\@identifyID, $object->{invIndex}));
			$subActivate = sub { Commands::run("identify $identifyIndex") };
		} elsif ($object->usable) {
			$canActivate = T('Use 1 on Self');
			$subActivate = sub { $object->use };
		} elsif ($object->equippable) {
			unless ($object->{equipped}) {
				$canActivate = T('Equip') if $object->{identified};
				$subActivate = sub { $object->equip };
			} else {
				$canActivate = T('Unequip');
				$subActivate = sub { $object->unequip };
				$canCart = 0;
				$canStorage = 0;
				$canDrop = 0;
			}
		} elsif ($object->mergeable) {
			$canActivate = T('Request Merge List');
			$subActivate = sub { Commands::run("card use $object->{invIndex}") };
		}
		
		push @{$self->{head}}, {};
		push @{$self->{head}}, {title => $canActivate, callback => $subActivate} if $canActivate;
		
		# Network bugs prevent from adding multiple items at once
		push @{$self->{head}}, {
			title => T('Add to Deal'),
			command => join ';;', map { "deal add $_" } $invIndex
		} if %currentDeal && !$currentDeal{you_finalize} && $currentDeal{you_items} + @$objects <= 10;
		
		# FIXME: if your items change order or are used, this list will be wrong
		for (@cardMergeItemsID) {
			if ($object->{invIndex} == $_) {
				push @{$self->{head}}, {
					title => TF('Merge with %s', $char->inventory->get($cardMergeIndex)->{name}),
					command => "card merge $invIndex"
				};
				last;
			}
		}
		
		push @{$self->{head}}, {title => T('Drop 1'), command => "drop $invIndex 1"} if $canDrop;
		
	} else { # multiple items selected
		if (List::MoreUtils::all { $_->equippable } @$objects) {
			if (my @items = grep { $_->equippable && !$_->{equipped} } @$objects) {
				push @{$self->{head}}, {
					title => TF('Equip %s', $self->listTitle(@items)),
					callback => sub { $_->equip for @items },
				}
			}
			if (my @items = grep { $_->{equipped} } @$objects) {
				push @{$self->{head}}, {
					title => TF('Unequip %s', $self->listTitle(@items)),
					callback => sub { $_->unequip for @items },
				}
			}
		}
		
		# TODO
	}
	
	push @{$self->{head}}, {};
	my @invIndexes = map { $_->{invIndex} } @$objects;
	push @{$self->{head}}, {
		title => T('Move to Cart'),
		command => join ';;', map { "cart add $_" } @invIndexes
	} if $canCart;
	push @{$self->{head}}, {
		title => T('Move to Storage'),
		command => join ';;', map { "storage add $_" } @invIndexes
	} if $canStorage;
	push @{$self->{head}}, {
		title => T('Sell'),
		command => "sell " . (join ',', @invIndexes) . ";;sell done"
	};
	push @{$self->{head}}, {
		title => T('Drop'),
		command => "drop " . (join ',', @invIndexes)
	};
	
	return $self;
}

1;
