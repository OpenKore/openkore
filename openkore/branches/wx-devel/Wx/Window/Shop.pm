package Interface::Wx::Window::Shop;

use strict;
use base 'Interface::Wx::Base::ItemList';

use Globals qw($char %shop $shopstarted @articles $shopEarned);
use Translation qw(T TF);
use Utils qw(formatNumber);

use Interface::Wx::Context::StorageItem;

sub new {
	my ($class, $parent, $id) = @_;
	
	my $self = $class->SUPER::new ($parent, $id, [
		{key => 'title', title => T('Title')},
		{key => 'earned', title => T('Earned')},
		{key => 'zeny', title => T('Zeny')},
		{key => 'earned_max', title => T('Max earned')},
		{key => 'zeny_max', title => T('Max zeny')},
	]);
	
	$self->{title} = T('Shop');
	
	Scalar::Util::weaken(my $weak = $self);
	
	$self->{hooks} = Plugins::addHooks (
 		['packet/vending_start', sub { $weak->update }],
		['packet/shop_sold',     sub { $weak->update; }],
	);
	
	my $closeShop = \&Misc::closeShop;
	*Misc::closeShop = sub {
		&$closeShop;
		$weak->clear if $weak;
	};
	
	$self->update;
	
	return $self;
}

sub DESTROY { Plugins::delHooks($_[0]{hooks}) }

sub update {
	my ($self, $handler, $args) = @_;
	
	return unless $char && $shopstarted;
	$self->Freeze;
	my $i = 1;
	my $priceAfterSale = 0;
	for (grep defined, @articles) {
		$priceAfterSale += $_->{quantity}*$_->{price};
		$self->setItem($i++, $_);
	}
	$self->setStat('title', $shop{title});
	$self->setStat('earned', formatNumber($shopEarned));
	$self->setStat('zeny', formatNumber($char->{zeny}));
	$self->setStat('earned_max', formatNumber($priceAfterSale));
	$self->setStat('zeny_max', formatNumber($priceAfterSale + $char->{zeny}));
	$self->Thaw;
}

sub clear { $_[0]->removeAll }

sub getSelection {
	local @articles = grep defined, @articles;
	map { $articles[$_-1] } @{$_[0]{selection}}
}

sub _onRightClick {
	my ($self) = @_;
	
	return unless scalar(my @selection = $self->getSelection);
	Interface::Wx::Context::Item->new($self, \@selection)->popup;
}

1;
