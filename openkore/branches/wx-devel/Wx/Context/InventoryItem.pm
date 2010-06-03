package Interface::Wx::Context::InventoryItem;

use strict;
use base 'Interface::Wx::Context::Item';

use Globals qw/$char %storage $cardMergeIndex @cardMergeItemsID %currentDeal/;
use Translation qw/T TF/;

sub new {
	my ($class, $parent, $objects) = @_;
	
	Scalar::Util::weaken(my $weak = my $self = $class->SUPER::new ($parent, $objects));
	
	my ($canStorage, $canCart) = (%storage && $storage{opened}, $char->cartActive);
	
	if (@$objects == 1) {
		my ($object) = @$objects;
		my $invIndex = $object->{invIndex};
		
		my ($canActivate, $canDrop) = (undef, 1);
		if ($self->isUsable ($object)) {
			$canActivate = T('Use 1 on Self');
		} elsif ($self->isEquip ($object)) {
			unless ($object->{equipped}) {
				$canActivate = T('Equip') if $object->{identified};
			} else {
				$canActivate = T('Unequip');
				$canCart = 0;
				$canStorage = 0;
				$canDrop = 0;
			}
		} elsif ($self->isCard ($object)) {
			$canActivate = T('Request Merge List');
		}
		
		push @{$self->{head}}, {};
		push @{$self->{head}}, {title => $canActivate, callback => sub {
			$self->isUsable($object) ? $object->use
			: $self->isEquip($object) ? ($object->{equipped} ? $object->unequip : $object->equip)
			: $self->isCard($object) && Commands::run ("card use $object->{invIndex}");
		}} if $canActivate;
		
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
	} else {
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
