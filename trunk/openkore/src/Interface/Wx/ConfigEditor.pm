package Interface::Wx::ConfigEditor;

use strict;
use Wx ':everything';
use Wx::Grid;
use Wx::Event qw(EVT_GRID_CELL_CHANGE);
use base qw(Wx::Panel);

sub new {
	my $class = shift;
	my ($parent, $id) = @_;
	my $self;

	$self = $class->SUPER::new($parent, $id);

	my $hsizer = new Wx::BoxSizer(wxHORIZONTAL);
	$self->SetSizer($hsizer);

if (0) {
	my $vsizer = new Wx::BoxSizer(wxVERTICAL);
	$hsizer->Add($vsizer, 0, wxGROW | wxRIGHT, 8);

	my $label = new Wx::StaticText($self, -1, 'Category:');
	$vsizer->Add($label, 0);

	my $list = $self->{categories} = new Wx::ListBox($self, -1, wxDefaultPosition, wxDefaultSize,
		[], wxLB_SINGLE);
	$vsizer->Add($list, 1);
}
	my $panel = new Wx::Panel($self, -1, wxDefaultPosition, wxDefaultSize, wxSUNKEN_BORDER | wxTAB_TRAVERSAL);
	my $sizer = new Wx::BoxSizer(wxVERTICAL);
	$panel->SetSizer($sizer);

	my $grid = $self->{grid} = new Wx::Grid($panel, -1);
	$grid->CreateGrid(0, 2);
	$grid->SetRowLabelSize(0);
	$grid->SetColLabelSize(22);
	$grid->SetColLabelValue(0, "Option");
	$grid->SetColLabelValue(1, "Value");
	$grid->EnableDragRowSize(0);
	EVT_GRID_CELL_CHANGE($grid, sub { $self->_changed(@_); });
	$sizer->Add($grid, 1, wxGROW);
	$hsizer->Add($panel, 1, wxGROW);

	return $self;
}

sub setConfig {
	my $self = shift;
	my $hash = shift;
	my @keys = sort keys %{$hash};
	my $grid = $self->{grid};

	$self->{backup} = {%{$hash}};
	$grid->DeleteRows(0, $grid->GetNumberRows);
	$grid->AppendRows(scalar @keys);
	for (my $i = 0; $i < @keys; $i++) {
		$grid->SetCellValue($i, 0, $keys[$i]);
		$grid->SetCellValue($i, 1, $hash->{$keys[$i]});
		$grid->SetReadOnly($i, 0, 1);
	}
	$grid->AutoSize;
}

sub revert {
	my $self = shift;
	if ($self->{backup}) {
		my $grid = $self->{grid};
		for (my $i = 0; $i < $grid->GetNumberRows; $i++) {
			my $key = $grid->GetCellValue($i, 0);
			my $value = $grid->GetCellValue($i, 0);
			if ($self->{backup}{$key} ne $value) {
				if ($self->{onChanged}) {
					$self->{onChanged}->($key, $self->{backup}{$key});
				}
				$grid->SetCellValue($i, 1, $self->{backup}{$key});
			}
		}
	}
}

sub onChange {
	my ($self, $callback) = @_;
	$self->{onChanged} = $callback;
}

sub _changed {
	my ($self, $grid, $event) = @_;
	my $key = $grid->GetCellValue($event->GetRow, 0);
	my $value = $grid->GetCellValue($event->GetRow, 1);
	$event->Skip;

	if ($self->{onChanged}) {
		$self->{onChanged}->($key, $value);
	}
}

1;
