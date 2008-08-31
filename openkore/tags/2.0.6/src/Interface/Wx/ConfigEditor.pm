package Interface::Wx::ConfigEditor;

use strict;
use Wx ':everything';
use Wx::Event qw(EVT_LISTBOX);
use base qw(Wx::Panel);
use Interface::Wx::ConfigEditor;
use encoding 'utf8';


sub new {
	my $class = shift;
	my ($parent, $id) = @_;
	my $self;

	$self = $class->SUPER::new($parent, $id);

	my $hsizer = $self->{hsizer} = new Wx::BoxSizer(wxHORIZONTAL);
	$self->SetSizer($hsizer);

	my $vsizer = new Wx::BoxSizer(wxVERTICAL);
	$hsizer->Add($vsizer, 0, wxGROW | wxRIGHT, 8);

	my $label = new Wx::StaticText($self, -1, 'Categories:');
	$vsizer->Add($label, 0);

	my $list = $self->{list} = new Wx::ListBox($self, 81, wxDefaultPosition, wxDefaultSize,
		[], wxLB_SINGLE);
	$vsizer->Add($list, 1);

	$self->_displayIntro;
	EVT_LISTBOX($self, 81, \&_selectCategory);

	return $self;
}

sub setConfig {
	my $self = shift;
	my $hash = shift;
	$self->{hash} = $hash;
}

sub addCategory {
	my ($self, $name, $editor, $keys) = @_;
	$self->{list}->Append($name);
	$self->{categories}{$name}{editor} = $editor;
	$self->{categories}{$name}{keys} = $keys;
}

sub revert {
	my $self = shift;
	return unless ($self->{backup} && $self->{editor});
	foreach my $key (keys %{$self->{backup}}) {
		my $val1 = $self->{editor}->getValue($key);
		if (defined($val1) && $val1 ne $self->{backup}{$key}) {
			$self->{editor}->setValue($key, $self->{backup}{$key});
		}
	}
}

sub onChange {
	my ($self, $callback) = @_;
	$self->{callback} = $callback;
	$self->{editor}->onChange($callback) if ($self->{editor});
}

sub onRevertEnable {
	my ($self, $callback) = @_;
	$self->{revertEnableCallback} = $callback;
}

sub _displayIntro {
	my $self = shift;
	my $label = $self->{intro} = new Wx::StaticText($self, -1,
		'Click on one of the categories on the left to begin.',
		wxDefaultPosition, wxDefaultSize, wxALIGN_CENTRE);
	$self->{hsizer}->Add($label, 1, wxALIGN_CENTER);
}

sub _selectCategory {
	my ($self, $event) = @_;
	my $list = $self->{list};
	my $name = $list->GetString($list->GetSelection);
	return unless ($self->{selectedCategory} ne $name);

	my $editorName = $self->{categories}{$name}{editor};
	my $editor;
	if ($editorName) {
		$editor = eval "Interface::Wx::ConfigEditor::${editorName}->new(\$self, -1);";
	}
	if (!$editor) {
		$editor = Interface::Wx::ConfigEditor::Grid->new($self, -1);
	}

	if ($self->{intro}) {
		$self->{hsizer}->Detach($self->{intro});
		$self->{intro}->Destroy;
		delete $self->{intro};
	} elsif ($self->{editor}) {
		$self->{hsizer}->Detach($self->{editor});
		$self->{editor}->Destroy;
		delete $self->{editor};
	}

	$editor->onChange($self->{callback});
	$self->{backup} = {%{$self->{hash}}};
	if ($self->{categories}{$name}{keys}) {
		my %hash;
		foreach (@{$self->{categories}{$name}{keys}}) {
			$hash{$_} = $self->{hash}{$_};
		}
		$editor->setConfig(\%hash);
	} else {
		$editor->setConfig($self->{hash});
	}

	if ($self->{revertEnableCallback}) {
		$self->{revertEnableCallback}->(0);
		$editor->onRevertEnable($self->{revertEnableCallback});
	}

	$self->{editor} = $editor;
	$self->{hsizer}->Add($editor, 1, wxGROW);
	$self->Layout;
	$self->{selectedCategory} = $name;
	$event->Skip;
}


package Interface::Wx::ConfigEditor::Grid;

use Wx ':everything';
use Wx::Grid;
use Wx::Event qw(EVT_GRID_CELL_CHANGE EVT_GRID_CELL_LEFT_CLICK EVT_TIMER EVT_BUTTON);
use Wx::Html;
use base qw(Wx::Panel);

use Utils::HttpReader;

our $manual;


sub new {
	my $class = shift;
	my ($parent, $id) = @_;
	my $style = wxTAB_TRAVERSAL;
	$style |= wxSUNKEN_BORDER if ($^O ne 'MSWin32');
	my $self = $class->SUPER::new($parent, $id, wxDefaultPosition, wxDefaultSize,
		$style);

	my $sizer = new Wx::BoxSizer(wxVERTICAL);
	$self->SetSizer($sizer);

	my $splitter = new Wx::SplitterWindow($self, -1, wxDefaultPosition, wxDefaultSize,
		wxSP_3D | wxSP_LIVE_UPDATE);
	$sizer->Add($splitter, 1, wxGROW);

	my $grid = $self->{grid} = new Wx::Grid($splitter, -1);
	$grid->CreateGrid(0, 2);
	$grid->SetRowLabelSize(0);
	$grid->SetColLabelSize(22);
	$grid->SetColLabelValue(0, "Option");
	$grid->SetColLabelValue(1, "Value");
	$grid->EnableDragRowSize(0);
	EVT_GRID_CELL_LEFT_CLICK($grid, sub { $self->_onClick(@_); });
	EVT_GRID_CELL_CHANGE($grid, sub { $self->_changed(@_); });

	if (!defined $manual) {
		$self->downloadManual($parent);
	}

	my $html = $self->{html} = new Wx::HtmlWindow($splitter, -1);
	if ($^O ne 'MSWin32') {
		$html->SetFonts('Bitstream Vera Sans', 'Bitstream Vera Sans Mono',
			[10, 10, 10, 10, 10, 10, 10]);
	}
	$splitter->SplitHorizontally($grid, $html);
	$splitter->SetSashPosition(-100);

	return $self;
}

sub downloadManual {
	my ($self, $parent) = @_;
	my ($file, $f, $time);

	$file = Settings::getControlFilename("manual.html");

	$time = (stat($file))[9];
	# Download manual if it hasn't been downloaded yet,
	# or if the local copy is more than 3 days old
	if ($file && time - $time <= 60 * 60 * 24 * 3 && open($f, "<", $file)) {
		binmode F;
		local($/);
		$manual = <$f>;
		close $f;

	} else {
		my $dialog = new Wx::Dialog($parent->GetGrandParent, -1, "Downloading");
		my $sizer = new Wx::BoxSizer(wxVERTICAL);
		my $label = new Wx::StaticText($dialog, -1, "Downloading manual, please wait...");
		$sizer->Add($label, 1, wxGROW | wxALL, 8);
		my $gauge = new Wx::Gauge($dialog, -1, 100, wxDefaultPosition,
			[0, 16], wxGA_SMOOTH | wxGA_HORIZONTAL);
		$sizer->Add($gauge, 0, wxGROW | wxLEFT | wxRIGHT, 8);
		my $button = new Wx::Button($dialog, 475, '&Cancel');
		$sizer->Add($button, 0, wxALL | wxALIGN_CENTRE_HORIZONTAL, 8);
		EVT_BUTTON($dialog, 475, sub {
			$dialog->Close;
		});
		$dialog->SetSizerAndFit($sizer);

		my $timer = new Wx::Timer($dialog, 476);
		my $downloader = new StdHttpReader('http://openkore.sourceforge.net/manual/config/');
		EVT_TIMER($dialog, 476, sub {
			if ($downloader->getStatus() != HttpReader::CONNECTING) {
				my $size = $downloader->getSize();
				my $progress = 0;
				if ($size > 0) {
					my $len = 0;
					$size->getData($len);
					$progress = $len / $size * 100;
				}
				$gauge->SetValue($progress);
			}

			if ($downloader->getStatus() == HttpReader::DONE) {
				my $len;
				$gauge->SetValue(100);
				$dialog->Close;
				$manual = $downloader->getData($len);
				$timer->Destroy;
				undef $timer;
			} elsif ($downloader->getStatus() == HttpReader::ERROR) {
				$gauge->SetValue(100);
				$dialog->Close;
				$timer->Destroy;
				undef $timer;
			}
		});
		$timer->Start(100);
		$dialog->ShowModal;

		if (!defined $file) {
			my @folders = Settings::getControlFolders();
			$file = "$folders[0]/manual.html";
		}
		if ($manual && open($f, ">", $file)) {
			binmode F;
			print $f $manual;
			close $f;
		}
	}
}

sub onChange {
	my ($self, $callback) = @_;
	$self->{onChanged} = $callback;
}

sub onRevertEnable {
	my ($self, $callback) = @_;
	$self->{revertEnableCallback} = $callback;
}

sub setConfig {
	my ($self, $hash) = @_;
	my $grid = $self->{grid};
	my @keys = sort keys %{$hash};

	$grid->DeleteRows(0, $grid->GetNumberRows);
	$grid->AppendRows(scalar @keys);
	for (my $i = 0; $i < @keys; $i++) {
		$grid->SetCellValue($i, 0, $keys[$i]);
		$grid->SetCellValue($i, 1, $hash->{$keys[$i]});
		$grid->SetReadOnly($i, 0, 1);
		$self->{rows}{$keys[$i]} = $i;
	}
	$grid->AutoSize;
	$self->{config} = {%{$hash}};

	$self->{html}->SetPage(_help($keys[0]));
}

sub getValue {
	my ($self, $key) = @_;
	return $self->{config}{$key};
}

sub setValue {
	my ($self, $key, $value) = @_;
	my $i = $self->{rows}{$key};
	$self->{grid}->SetCellValue($i, 1, $value);
	$self->{config}{$key} = $value;
	if ($self->{onChanged}) {
		$self->{onChanged}->($key, $value);
	}
	if ($self->{revertEnableCallback}) {
		$self->{revertEnableCallback}->(1);
	}
}

sub _onClick {
	my ($self, $grid, $event) = @_;
	my $row = $event->GetRow;
	$self->{html}->SetPage(_help($grid->GetCellValue($row, 0)));
	$event->Skip;
}

sub _changed {
	my ($self, $grid, $event) = @_;
	my $key = $grid->GetCellValue($event->GetRow, 0);
	my $value = $grid->GetCellValue($event->GetRow, 1);
	$self->{config}{$key} = $value;
	$event->Skip;
	if ($self->{onChanged}) {
		$self->{onChanged}->($key, $value);
	}
	if ($self->{revertEnableCallback}) {
		$self->{revertEnableCallback}->(1);
	}
}

sub _help {
	my ($name) = @_;
	if ($manual eq '') {
		return 'Unable to download the manual.';
	} else {
		my $tmp = quotemeta "<dt class=\"item\"><b>$name";
		my ($found) = $manual =~ /<a name=\"$name\"><\/a>.*?<dl class=\"primaryList\">\n(${tmp}.*?)<\/dl>/s;
		$found = "No help available for \"$name\"." if ($found eq '');
		return $found;
	}
}

1;