package Interface::Wx::Base::ArrayListCtrl;
use strict;

use Wx ':everything';
use base 'Wx::ListCtrl';
use Wx::Event ':everything';

sub new {
	my ($class, $parent, $id, $args) = @_;
	Scalar::Util::weaken(my $weak = my $self = $class->SUPER::new(
		$parent, $id, wxDefaultPosition, wxDefaultSize,
		wxLC_REPORT | wxLC_VIRTUAL | wxLC_SINGLE_SEL | wxLC_HRULES
	));
	
	$self->InsertColumn($_, $args->{heading}[$_], $args->{format}[$_]) for 0 .. $args->{cols}-1;
	
	$self->{selection} = [];
	EVT_LIST_ITEM_SELECTED($self, $self->GetId, sub { $weak->_onSelection });
	EVT_LIST_ITEM_DESELECTED($self, $self->GetId, sub { $weak->_onSelection });
	EVT_LIST_ITEM_RIGHT_CLICK($self, $self->GetId, $args->{context});
	
	$self->{args} = $args;
	
	# to be called by parents after initialization
	#$self->update;
	
	return $self;
}

# wxListCtrl
sub OnGetItemText {
	my ($self, $item, $col) = @_;
	
	($self->{args}{getText}->($self->{args}{arrayref}[$item]))[$col]
}

# wxListCtrl
sub OnGetItemAttr {
	my ($self, $item) = @_;
	
	$self->{args}{getAttr}->($self->{args}{arrayref}[$item]) if $self->{args}{getAttr}
}

sub update {
	my ($self, $from, $to) = @_;
	
	$self->SetItemCount(scalar @{$self->{args}{arrayref}});
	$self->RefreshItems(defined $from ? ($from, $to // $from) : (0, -1));
	
	$self->_onSelection;
}

sub _onSelection {
	my ($self) = @_;
	
	$self->{selection} = [];
	
	for (my $i = -1; ($i = $self->GetNextItem($i, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED)) != -1;) {
		push @{$self->{selection}}, $self->{args}{arrayref}[$i]
	}
	
	&{$self->{args}{update}};
}

sub getSelection { @{$_[0]->{selection}} }

1;
