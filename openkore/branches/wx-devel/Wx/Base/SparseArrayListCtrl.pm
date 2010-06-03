package Interface::Wx::Base::SparseArrayListCtrl;
use strict;

use Wx ':everything';
use base 'Interface::Wx::Base::ArrayListCtrl';
use Wx::Event ':everything';

sub getItem {
	my ($self, $item) = @_;
	
	my $index = 0;
	do { until ($self->{args}{arrayref}[$index]) {
		return unless ++$index < @{$self->{args}{arrayref}}
	}} while $item--&&++$index;
	$self->{args}{arrayref}[$index]
}

# wxListCtrl
sub OnGetItemText {
	my ($self, $item, $col) = @_;
	
	($self->{args}{getText}->($self->getItem($item)))[$col]
}

# wxListCtrl
sub OnGetItemAttr {
	my ($self, $item) = @_;
	
	$self->{args}{getAttr}->($self->getItem($item)) if $self->{args}{getAttr}
}

sub update {
	my ($self, $from, $to) = @_;
	
	$self->SetItemCount(scalar grep {$_} @{$self->{args}{arrayref}});
	$self->RefreshItems(defined $from ? ($from, $to // $from) : (0, -1));
	
	$self->_onSelection;
}

sub _onSelection {
	my ($self) = @_;
	
	$self->{selection} = [];
	
	for (my $i = -1; ($i = $self->GetNextItem($i, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED)) != -1;) {
		push @{$self->{selection}}, $self->getItem($i)
	}
	
	&{$self->{args}{update}};
}

1;
