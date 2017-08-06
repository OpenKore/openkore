package Interface::Wx::List;

use strict;
use base 'Wx::Panel';
use Wx ':everything';
use Wx::Event qw/EVT_MENU EVT_LIST_ITEM_SELECTED EVT_LIST_ITEM_DESELECTED EVT_LIST_ITEM_ACTIVATED EVT_LIST_ITEM_RIGHT_CLICK/;

use Translation qw(T);

use constant {
	BORDER => 2,
};

sub new {
	my ($class, $parent, $id, $stats) = @_;
	
	my $self = $class->SUPER::new ($parent, $id);
	
	$self->SetSizer (my $vsizer = new Wx::BoxSizer (wxVERTICAL));

	$self->{list} = new Interface::Wx::ItemList($self, T('Items'));
	$self->{list}->onActivate(sub { shift->onListActivate(@_) }, $self);
	$self->{list}->onRightClick(sub { shift->onListRightClick(@_) }, $self);
	$vsizer->Add($self->{list}, 1, wxGROW);
	
	$vsizer->Add ($self->{statusSizer} = new Wx::GridSizer (1, 0, BORDER, BORDER), 0, wxGROW | wxTOP | wxLEFT | wxRIGHT, BORDER);
	
	if ($stats && @$stats) {
		foreach my $stat (@$stats) {
			next unless $stat->{key};
			$self->{stats}{$stat->{key}} = $stat;
			
			$self->{statusSizer}->Add (my $sizer2 = new Wx::BoxSizer (wxVERTICAL), 1, wxGROW);
			$sizer2->Add (my $sizer3 = new Wx::BoxSizer (wxHORIZONTAL), 0, wxGROW);
			$sizer3->Add (my $label = new Wx::StaticText ($self, wxID_ANY, $stat->{title}), 0, wxGROW);
			$sizer3->Add ($self->{stats}{$stat->{key}}{displayGauge} = new Wx::Gauge (
				$self, wxID_ANY, $stat->{max} || 100, wxDefaultPosition, [0, $label->GetBestSize->GetHeight + 2],
				wxHORIZONTAL | wxGA_SMOOTH
			), 1, wxGROW | wxLEFT, BORDER);
			$sizer2->Add (my $sizer4 = new Wx::BoxSizer (wxHORIZONTAL), 0, wxGROW | wxTOP, BORDER);
			$sizer4->Add ($self->{stats}{$stat->{key}}{displayValue} = new Wx::StaticText ($self, wxID_ANY, ''), 1, wxGROW);
			#$sizer4->Add (new Wx::StaticText ($self, wxID_ANY, '/'), 0, wxGROW | wxLEFT | wxRIGHT, BORDER);
			#$sizer4->Add ($self->{stats}{$stat->{key}}{displayMax} = new Wx::StaticText ($self, wxID_ANY, $stat->{max}), 1, wxGROW);
		}
	}
		
	$vsizer->Add ($self->{buttonSizer} = new Wx::FlexGridSizer (1, 0, BORDER, BORDER), 0, wxGROW);
	
	return $self;	
}

sub setStat {
	my ($self, $key, $value, $max) = @_;
	
	return unless $self->{stats}{$key};
	
	$self->{stats}{$key}{displayGauge}->SetRange ($max);
	$self->{stats}{$key}{displayGauge}->SetValue ($value);
	$self->{stats}{$key}{displayValue}->SetLabel ($value . ' / ' . $max);
}

1;
