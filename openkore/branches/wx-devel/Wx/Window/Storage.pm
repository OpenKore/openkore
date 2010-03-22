package Interface::Wx::Window::Storage;

use strict;
use base 'Interface::Wx::Base::ItemList';

use Globals qw/$char $conState %cart %storage @storageID/;
use Misc qw/storageGet/;

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id, [
		{key => 'count', max => %cart && $cart{items_max} ? $cart{items_max} : '100'},
	]);
	
	Scalar::Util::weaken(my $weak = $self);
	
	$self->{hooks} = Plugins::addHooks (
 		['packet/map_loaded',                 sub { $weak->clear }],
		['packet/storage_opened',             sub { $weak->onInfo; }],
		['packet/storage_closed',             sub { $weak->onInfo; }],
		['packet/storage_items_stackable',    sub { $weak->update; }],
		['packet/storage_items_nonstackable', sub { $weak->update; }],
		['packet/storage_item_added',         sub { $weak->onItemsChanged ($_[1]{index}); }],
		['packet/storage_item_removed',       sub { $weak->onItemsChanged ($_[1]{index}); }],
	);
	
	$self->onInfo;
	$self->update;
	
	return $self;
}

sub DESTROY {
	my ($self) = @_;
	
	Plugins::delHooks ($self->{hooks});
}

sub onInfo {
	my ($self) = @_;
	
	if ($storage{opened}) {
		$self->setStat ('count', $storage{items}, $storage{items_max});
	} else {
		$self->clear;
	}
}

sub onItemsChanged {
	my $self = shift;
	
	$self->setItem ($_->[0], $_->[1]) foreach map { [$_, $storage{$_}] } @_;
}

sub update {
	my ($self, $handler, $args) = @_;
	
	$self->Freeze;
	$self->setItem ($_->[0], $_->[1]) foreach map { [$storageID[$_], $storage{$storageID[$_]}] } (0 .. @storageID);
	$self->Thaw;
}

sub clear { $_[0]->removeAllItems }

sub getSelection { map { $storage{$_} } @{$_[0]{selection}} }

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
	
	my ($canCart) = (%cart && $cart{exists});
	
	push @menu, {title => 'Move all to inventory' . "\tDblClick", callback => sub { $self->_onActivate; }};
	push @menu, {title => 'Move all to cart', callback => sub { $self->_onCart; }} if $canCart;
	
	$self->contextMenu (\@menu);
}

sub _onActivate {
	my ($self) = @_;
	
	Commands::run ('storage get ' . join ',', map {$_->{binID}} $self->getSelection);
}

sub _onStorage {
	my ($self) = @_;
	
	foreach ($self->getSelection) {
		Commands::run ('storage gettocart ' . $_->{binID});
	}
}

1;
