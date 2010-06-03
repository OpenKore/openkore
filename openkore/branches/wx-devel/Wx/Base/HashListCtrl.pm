package Interface::Wx::Base::HashListCtrl;
use strict;

use Wx ':everything';
use base 'Interface::Wx::Base::ArrayListCtrl';
use Wx::Event ':everything';

# wxListCtrl
sub OnGetItemText {
	my ($self, $item, $col) = @_;
	
	($self->{args}{getText}->((values %{$self->{args}{hashref}})[$item]))[$col]
}

# wxListCtrl
sub OnGetItemAttr {
	my ($self, $item) = @_;
	
	$self->{args}{getAttr}->((values %{$self->{args}{hashref}})[$item]) if $self->{args}{getAttr}
}

sub update {
	my ($self, $from, $to) = @_;
	
	$self->SetItemCount(scalar values %{$self->{args}{hashref}});
	$self->RefreshItems(defined $from ? ($from, $to // $from) : (0, -1));
	
	$self->_onSelection;
}

sub _onSelection {
	my ($self) = @_;
	
	$self->{selection} = [];
	
	for (my $i = -1; ($i = $self->GetNextItem($i, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED)) != -1;) {
		push @{$self->{selection}}, (values %{$self->{args}{hashref}})[$i]
	}
	
	&{$self->{args}{update}} if $self->{args}{update};
}

1;
