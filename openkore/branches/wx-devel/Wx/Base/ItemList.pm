package Interface::Wx::Base::ItemList;

use strict;
use base 'Interface::Wx::Base::List';

use Wx ':everything';

use Globals qw/%equipTypes_lut %itemsDesc_lut %shop/;
use Misc qw/items_control pickupitems/;
use Translation qw/T TF/;
use Utils qw/formatNumber/;

sub new {
	my ($class, $parent, $id) = (shift, shift, shift);
	
	my $self = $class->SUPER::new ($parent, $id, @_);
	
	$self->{list}->InsertColumn(0, do {
		$_ = Wx::ListItem->new;
		$_->SetAlign(wxLIST_FORMAT_RIGHT);
		$_->SetWidth(26);
	$_ });
	$self->{list}->InsertColumn(1, do {
		$_ = Wx::ListItem->new;
		$_->SetAlign(wxLIST_FORMAT_RIGHT);
		$_->SetWidth(50);
	$_ });
	$self->{list}->InsertColumn(2, do {
		$_ = Wx::ListItem->new;
		#$_->SetWidth(wxLIST_AUTOSIZE);
		$_->SetWidth(150);
	$_ });
	
	return $self;
}

sub setItem {
	my ($self, $index, $item) = @_;
	
	if ($item && $item->{amount}) {
		my $i;
		if (-1 == ($i = $self->{list}->FindItemData (-1, $index))) {
		 	my $listItem = new Wx::ListItem;
		 	$listItem->SetData ($index);
			$i = $self->{list}->InsertItem ($listItem);
		}
		
		$self->{list}->SetItemText ($i, $index);
		$self->{list}->SetItem ($i, 1, $item->{amount});
		$self->{list}->SetItem ($i, 2,
			$item->{name}
			. ($item->{equipped} ? ($equipTypes_lut{$item->{equipped}} ? ' ('.$equipTypes_lut{$item->{equipped}}.')' : ' (Equipped)') : '')
			. ($item->{identified} ? '' : ' (Not identified)')
		);
	} else {
		$self->{list}->DeleteItem ($self->{list}->FindItemData (-1, $index));
	}
}

sub removeAllItems {
	my ($self) = @_;
	
	$self->{list}->DeleteAllItems;
}

sub contextMenu {
	my ($self, $items) = (shift, shift);
	
	my @selection = $self->getSelection;
	
	if (@selection == 1 and my $item = $selection[0]) {
		my $control = items_control($item->{name});
		push @$items, {}, {title => TF('Keep %s minimum', formatNumber($control->{keep}))};
		for (
			['storage', T('Auto-store')],
			['sell', T('Auto-sell')],
			['cart_add', T('Auto-put in cart')],
			['cart_get', T('Auto-get from cart')],
		) {
			my $value = join ' ', $item->{name},
			map {$_ || 0} @{{%$control, @$_[0] => $control->{@$_[0]} ? 0 : 1}} {qw/keep storage sell cart_add cart_get/};
			$value =~ s/\s+[ 0]*$//;
			push @$items, {title => @$_[1], check => $control->{@$_[0]}, callback => sub { Commands::run("iconf $value") }};
		}
		
		$control = pickupitems($item->{name});
		push @$items, {};
		for (
			[-1, T('Auto-drop')],
			[0, T('Ignore')],
			[1, T('Auto-pick up')],
			[2, T('Auto-pick up quickly')],
		) {
			my $value = join ' ', $item->{name}, @$_[0];
			push @$items, {title => @$_[1], radio => $control == @$_[0], callback => sub { Commands::run("pconf $value") }};
		}
		
		if ($shop{items} and ($control) = grep {$_->{name} eq $item->{name}} @{$shop{items}}) {
			push @$items, {}, {title => $control->{amount}
				? TF('Vend %d for %s', $control->{amount}, formatNumber($control->{price}))
				: TF('Vend for %s', formatNumber($control->{price}))
			};
		}
		
		if ($control = $itemsDesc_lut{$item->{nameID}}) {
			chomp $control;
			push @$items, {}, {title => T('Description'), menu => [{title => $control}]};
		}
	}
	
	return $self->SUPER::contextMenu ($items, @_);
}

1;
