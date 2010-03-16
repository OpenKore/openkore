package Interface::Wx::List::ItemList::Cart;

use strict;
use base 'Interface::Wx::List::ItemList';

use Globals qw/$char $conState %cart %storage/;

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id, [
		{key => 'count', max => %cart && $cart{items_max} ? $cart{items_max} : '100'},
		{key => 'weight', title => 'Weight', max => %cart && $cart{weight_max} ? $cart{weight_max} : '100'},
	]);
	
	$self->{hooks} = Plugins::addHooks (
		['packet/map_loaded',              sub { $self->clear }],
		['packet/cart_info',               sub { $self->onInfo }],
		['packet/cart_items_stackable',    sub { $self->update }],
		['packet/cart_items_nonstackable', sub { $self->update }],
		['packet/cart_item_added',         sub { $self->onItemsChanged ($_[1]{index}) }],
		['packet/cart_item_removed',       sub { $self->onItemsChanged ($_[1]{index}) }],
	);
	
	$self->onInfo;
	$self->update;
	
	return $self;
}

sub unload {
	my ($self) = @_;
	
	Plugins::delHooks ($self->{hooks});
}

sub onInfo {
	my ($self) = @_;
	
	if ($cart{exists} or $char && $char->{statuses} && scalar grep /^Level \d Cart$/, keys %{$char->{statuses}}) {
		$self->setStat ('count', $cart{items}, $cart{items_max});
		$self->setStat ('weight', $cart{weight}, $cart{weight_max});
	} else {
		$self->clear;
	}
}

sub onItemsChanged {
	my $self = shift;
	
	$self->setItem ($_->[0], $_->[1]) foreach map { [$_, $cart{inventory}[$_]] } @_;
}

sub update {
	my ($self, $handler, $args) = @_;
	
	$self->Freeze;
	$self->setItem ($_->{index}, $_) foreach (grep defined, @{$cart{inventory}});
	$self->Thaw;
}

sub clear { $_[0]->removeAllItems }

sub getSelection { map { $cart{inventory}[$_] } @{$_[0]{selection}} }

sub _onRightClick {
	my ($self) = @_;
	
	return unless scalar (my @selection = $self->getSelection);
	
	my $title;
	if (@selection > 3) {
		my $total = 0;
		$total += $_->{amount} foreach @selection;
		$title = @selection . ' items';
		$title .= ' (' . $total . ' total)' unless $total == @selection;
	} else {
		$title = join '; ', map { join ' ', @$_{'amount', 'name'} } @selection;
	}
	$title .= '...';
	
	my @menu;
	push @menu, {title => $title};
	
	my ($canStorage) = (%storage && $storage{opened});
	
	push @menu, {title => 'Move all to inventory' . "\tDblClick", callback => sub { $self->_onActivate; }};
	push @menu, {title => 'Move all to storage', callback => sub { $self->_onStorage; }} if $canStorage;
	
	$self->contextMenu (\@menu);
}

sub _onActivate {
	my ($self) = @_;
	
	foreach ($self->getSelection) {
		Commands::run ('cart get ' . $_->{index});
	}
}

sub _onStorage {
	my ($self) = @_;
	
	foreach ($self->getSelection) {
		Commands::run ('storage addfromcart ' . $_->{index});
	}
}

1;
