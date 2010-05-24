package Interface::Wx::Base::List;

use strict;
use Wx ':everything';
use base 'Wx::Panel';
use Wx::Event qw/EVT_MENU EVT_LIST_ITEM_SELECTED EVT_LIST_ITEM_DESELECTED EVT_LIST_ITEM_ACTIVATED EVT_LIST_ITEM_RIGHT_CLICK/;

use constant {
	BORDER => 1,
};

sub new {
	my ($class, $parent, $id, $stats) = @_;
	
	my $self = $class->SUPER::new ($parent, $id);
	
	$self->SetSizer (my $vsizer = new Wx::BoxSizer (wxVERTICAL));
	
	$vsizer->Add ($self->{list} = new Wx::ListCtrl (
		$self, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxLC_REPORT | wxLC_NO_HEADER | wxLC_HRULES | wxLC_SORT_ASCENDING
	), 1, wxGROW);
	
	$vsizer->Add ($self->{statusSizer} = new Wx::GridSizer (1, 0, BORDER, BORDER), 0, wxGROW | wxTOP | wxLEFT | wxRIGHT, BORDER);
	
	if ($stats && @$stats) {
		foreach my $stat (@$stats) {
			next unless $stat->{key};
			$self->{stats}{$stat->{key}} = $stat;
			
			$self->{statusSizer}->Add (my $sizer2 = new Wx::BoxSizer (wxVERTICAL), 1, wxGROW);
			$sizer2->Add (my $sizer3 = new Wx::BoxSizer (wxHORIZONTAL), 0, wxGROW);
			$sizer3->Add (my $label = new Wx::StaticText ($self, wxID_ANY, $stat->{title}), 0, wxGROW);
			if ($stat->{max}) {
				$sizer3->Add ($self->{stats}{$stat->{key}}{displayGauge} = new Wx::Gauge (
					$self, wxID_ANY, $stat->{max} || 100, wxDefaultPosition, [0, $label->GetBestSize->GetHeight + 2],
					wxHORIZONTAL | wxGA_SMOOTH
				), 1, wxGROW | wxLEFT, BORDER);
				$sizer2->Add (my $sizer4 = new Wx::BoxSizer (wxHORIZONTAL), 0, wxGROW | wxTOP, BORDER);
				$sizer4->Add ($self->{stats}{$stat->{key}}{displayValue} = new Wx::StaticText ($self, wxID_ANY, ''), 1, wxGROW);
			} else {
				$sizer3->Add ($self->{stats}{$stat->{key}}{displayValue} = new Wx::StaticText ($self, wxID_ANY, ''), 1, wxGROW, BORDER);
			}
		}
	}
	
	EVT_LIST_ITEM_SELECTED ($self, $self->{list}->GetId, sub { $self->_onSelectionChange; });
	EVT_LIST_ITEM_DESELECTED ($self, $self->{list}->GetId, sub { $self->_onSelectionChange; });
	EVT_LIST_ITEM_ACTIVATED ($self, $self->{list}->GetId, sub { $self->_onActivate; });
	EVT_LIST_ITEM_RIGHT_CLICK ($self, $self->{list}->GetId, sub { $self->_onRightClick; });
	
	$vsizer->Add ($self->{buttonSizer} = new Wx::FlexGridSizer (1, 0, BORDER, BORDER), 0, wxGROW);
	
	return $self;	
}

sub setItem {
	my ($self, $index, $cols, $color) = @_;
	
	$self->Freeze;
	
	if ($cols) {
		my $i;
		if (-1 == ($i = $self->{list}->FindItemData (-1, $index))) {
			(my $listItem = new Wx::ListItem)->SetData ($index);
			$i = $self->{list}->InsertItem ($listItem);
		}
		
		$self->{list}->SetItem($i, $_, $cols->[$_]) for 0 .. @$cols-1;
		$self->{list}->SetItemTextColour($i, $color) if $color && $color->isa('Wx::Colour');
	} else {
		$self->{list}->DeleteItem ($self->{list}->FindItemData (-1, $index));
	}
	
	$self->Thaw;
}

sub setStat {
	my ($self, $key, $value, $max) = @_;
	
	return unless $self->{stats}{$key};
	
	if ($self->{stats}{$key}{displayGauge}) {
		$self->{stats}{$key}{displayGauge}->SetRange ($max);
		$self->{stats}{$key}{displayGauge}->SetValue ($value);
		$self->{stats}{$key}{displayValue}->SetLabel ($value . ' / ' . $max);
	} else {
		$self->{stats}{$key}{displayValue}->SetLabel ($value);
	}
}

sub _onSelectionChange {
	my ($self) = @_;
	
	my $i = -1;
	$self->{selection} = [];
	
	while (1) {
		last if -1 == ($i = $self->{list}->GetNextItem ($i, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED));
		push @{$self->{selection}}, $self->{list}->GetItemData ($i);
	}
}

sub _onActivate {}
sub _onRightClick {}

1;
