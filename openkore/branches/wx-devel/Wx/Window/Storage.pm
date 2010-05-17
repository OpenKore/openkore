package Interface::Wx::Window::Storage;

use strict;
use base 'Interface::Wx::Base::ItemList';

use Globals qw/$char $conState %cart %storage @storageID/;
use Misc qw/storageGet/;
use Translation qw/T TF/;

use Interface::Wx::Context::StorageItem;

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id, [
		{key => 'count', max => %cart && $cart{items_max} ? $cart{items_max} : '100'},
	]);
	
	$self->{title} = T('Storage');
	
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
	
	return unless scalar(my @selection = $self->getSelection);
	Interface::Wx::Context::StorageItem->new($self, \@selection)->popup;
}

1;
