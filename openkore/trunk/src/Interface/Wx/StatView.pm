package Interface::Wx::StatView;

use strict;
use base 'Wx::Panel';
use Wx ':everything';
use Wx::Event qw/EVT_BUTTON/;
use Utils qw/formatNumber/;

use constant {
	BORDER => 2,
};

sub new {
	my ($class, $parent, $id, $stats) = @_;
	
	my $self = $class->SUPER::new ($parent, $id);
	
	my ($vsizer, $hsizer);
	
	$self->SetSizer ($vsizer = new Wx::BoxSizer (wxVERTICAL));
	
	$vsizer->Add ($hsizer = new Wx::BoxSizer (wxHORIZONTAL), 0, wxGROW | wxTOP | wxLEFT | wxRIGHT, BORDER);
	
	$hsizer->Add ($self->{sizer}{name} = new Wx::FlexGridSizer (1, 0, BORDER, BORDER), 0, wxGROW);
	$hsizer->AddStretchSpacer;
	$hsizer->Add ($self->{sizer}{type} = new Wx::FlexGridSizer (1, 0, BORDER, BORDER), 0, wxGROW);
	
	$vsizer->Add ($self->{sizer}{gauge} = new Wx::GridSizer (1, 0, BORDER, BORDER), 0, wxGROW | wxTOP | wxLEFT | wxRIGHT, BORDER);
	
	$vsizer->Add ($hsizer = new Wx::BoxSizer (wxHORIZONTAL), 0, wxGROW | wxTOP | wxLEFT | wxRIGHT, BORDER);
	
	$hsizer->Add ($self->{sizer}{stat} = new Wx::FlexGridSizer (0, 9, BORDER, BORDER), 1, wxGROW);
	$hsizer->Add ($self->{sizer}{substat} = new Wx::FlexGridSizer (0, 9, BORDER, BORDER), 1, wxGROW | wxLEFT, BORDER);
	$hsizer->Add ($self->{sizer}{control} = new Wx::FlexGridSizer (0, 1, BORDER, BORDER), 0, wxGROW | wxLEFT, BORDER);
	$hsizer->Add (my $vsizer2 = new Wx::BoxSizer (wxVERTICAL), 0, wxGROW | wxLEFT, BORDER);
	
	$vsizer2->Add ($self->{image} = new Wx::StaticBitmap ($self, wxID_ANY, new Wx::Bitmap (0, 0, -1)));
	$self->{image}->Show (0);
	$vsizer2->AddStretchSpacer;
	
	$vsizer->AddStretchSpacer;
	
	$vsizer->Add ($self->{status} = new Wx::StaticText ($self, wxID_ANY, ''), 0, wxGROW | wxBOTTOM | wxLEFT | wxRIGHT, BORDER);
	
	foreach my $stat (@$stats) {
		next unless $stat->{key} && $stat->{type} && $self->{sizer}{$stat->{type}};
		
		$self->{stats}{$stat->{key}} = $stat;
		
		my $sizer = $self->{sizer}{$stat->{type}};
		
		my $label = new Wx::StaticText ($self, wxID_ANY, $stat->{title});
		
		if ($stat->{type} eq 'gauge') {
			$sizer->Add (my $sizer2 = new Wx::BoxSizer (wxVERTICAL), 1, wxGROW);
			
			$sizer2->Add (my $sizer3 = new Wx::BoxSizer (wxHORIZONTAL), 0, wxGROW);
			
			$sizer3->Add ($label, 0, wxGROW);
			
			$sizer3->Add ($self->{display}{$stat->{key}}{value} = new Wx::Gauge (
				$self, wxID_ANY, 100,
				wxDefaultPosition, [0, $label->GetBestSize->GetHeight + 2],
				wxGA_HORIZONTAL | wxGA_SMOOTH
			), 1, wxGROW | wxLEFT, BORDER);
			
			$sizer2->Add ($self->{display}{$stat->{key}}{label} = new Wx::StaticText (
				$self, wxID_ANY, ''
			), 0, wxGROW | wxTOP, BORDER);
		} elsif ($stat->{type} eq 'control') {
			$label->Destroy;
			$sizer->Add ($self->{display}{$stat->{key}}{value} = new Wx::Button ($self, wxID_ANY, $stat->{title}), 0, wxGROW);
			$self->{display}{$stat->{key}}{value}->Enable (0);
			{
				my $key = $stat->{key};
				EVT_BUTTON ($self, $self->{display}{$stat->{key}}{value}->GetId, sub {
					$self->_onControl ($key);
					$Globals::interface->{inputBox}->SetFocus;
				});
			}
		} else {
			if ($stat->{title}) {
				$sizer->Add ($label);
			} else {
				$label->Destroy;
			}
			$sizer->Add ($self->{display}{$stat->{key}}{value} = new Wx::StaticText ($self, wxID_ANY, ''));
		}
		
		if ($stat->{type} eq 'stat' || $stat->{type} eq 'substat') {
			if ($stat->{range}) {
				$sizer->Add (new Wx::StaticText ($self, wxID_ANY, '~'));
				$sizer->Add ($self->{display}{$stat->{key}}{range} = new Wx::StaticText ($self, wxID_ANY, ''));
			}
			
			if ($stat->{bonus}) {
				$sizer->Add (new Wx::StaticText ($self, wxID_ANY, '+'));
				$sizer->Add ($self->{display}{$stat->{key}}{bonus} = new Wx::StaticText ($self, wxID_ANY, ''));
			}
			
			unless ($stat->{range}) {
				$sizer->AddSpacer (0);
				$sizer->AddSpacer (0);
			}
			
			unless ($stat->{bonus}) {
				$sizer->AddSpacer (0);
				$sizer->AddSpacer (0);
			}
			
			if ($stat->{increment}) {
				$sizer->Add (new Wx::StaticText ($self, wxID_ANY, '#'));
				$sizer->Add ($self->{display}{$stat->{key}}{points} = new Wx::StaticText ($self, wxID_ANY, ''));
				$sizer->Add ($self->{display}{$stat->{key}}{increment} = new Wx::Button (
					$self, wxID_ANY, '+', wxDefaultPosition, [-1, $label->GetBestSize->GetHeight + 2], wxBU_EXACTFIT
				));
				$self->{display}{$stat->{key}}{increment}->Enable (0);
				{
					my $key = $stat->{key};
					EVT_BUTTON ($self, $self->{display}{$stat->{key}}{increment}->GetId, sub {
						$self->_onIncrement ($key);
						$Globals::interface->{inputBox}->SetFocus;
					});
				}
			} else {
				$sizer->AddSpacer (0);
				$sizer->AddSpacer (0);
				$sizer->AddSpacer (0);
			}
		}
	}
	
	$self->{sizer}{gauge}->SetCols (scalar (() = $self->{sizer}{gauge}->GetChildren));
	
	return $self;
}

sub set {
	my ($self, $key, $value, $range, $bonus, $points, $increment) = @_;
	
	return unless $self->{display}{$key};
	
	if ($self->{stats}{$key}{type} eq 'gauge') {
		my ($current, $max) = @$value;
		my $percent = 100 * $current / $max;
		$self->{display}{$key}{value}->SetValue ($percent);
		$self->{display}{$key}{label}->SetLabel (sprintf '%s / %s', formatNumber ($current), formatNumber ($max));
		
		if ($^O eq 'MSWin32' && $self->{stats}{$key}{color}) {
			if ($self->{stats}{$key}{color} eq 'smooth') {
				$self->{display}{$key}{value}->SetForegroundColour (new Wx::Colour ((100 - $percent) * 2.55, $percent * 1.27, 50));
			} elsif ($self->{stats}{$key}{color} eq 'weight') {
				if ($percent >= 90) {
					$self->{display}{$key}{value}->SetForegroundColour (new Wx::Colour (255, 0, 50));
				} elsif ($percent >= 50) {
					$self->{display}{$key}{value}->SetForegroundColour (new Wx::Colour (127, 63, 50));
				} else {
					$self->{display}{$key}{value}->SetForegroundColour (new Wx::Colour (0, 127, 50));
				}
			} elsif ($self->{stats}{$key}{color} eq 'hunger') {
				if ($percent > 90) {
					$self->{display}{$key}{value}->SetForegroundColour (new Wx::Colour (255, 0, 50));
				} elsif ($percent > 75) {
					$self->{display}{$key}{value}->SetForegroundColour (new Wx::Colour (255, 0, 50));
				} elsif ($percent > 25) {
					$self->{display}{$key}{value}->SetForegroundColour (new Wx::Colour (127, 63, 50));
				} elsif ($percent > 10) {
					$self->{display}{$key}{value}->SetForegroundColour (new Wx::Colour (0, 127, 50));
				} else {
					$self->{display}{$key}{value}->SetForegroundColour (new Wx::Colour (255, 0, 50));
				}
			}
		}
	} elsif ($self->{stats}{$key}{type} eq 'control') {
		$self->{display}{$key}{value}->Enable ($value ? 1 : 0);
	} else {
		$self->{display}{$key}{value}->SetLabel ($value);
	}
	
	$self->{display}{$key}{range}->SetLabel ($range) if $self->{display}{$key}{range};
	$self->{display}{$key}{bonus}->SetLabel ($bonus) if $self->{display}{$key}{bonus};
	$self->{display}{$key}{points}->SetLabel ($points) if $self->{display}{$key}{points};
	$self->{display}{$key}{increment}->Enable ($increment ? 1 : 0) if $self->{display}{$key}{increment};
}

sub setStatus {
	my ($self, $status) = @_;
	
	$self->{status}->SetLabel ($status);
}

sub setImage {
	my ($self, $file, $tiles) = @_;
	
	return if $self->{currentImageFile} eq $file;
	$self->{currentImageFile} = $file;
	
	if (-f $file) {
		my $bitmap = new Wx::Bitmap (new Wx::Image ($file, wxBITMAP_TYPE_ANY));
		if ($tiles) {
			my ($w, $h) = ($bitmap->GetWidth / $tiles->{w}, $bitmap->GetHeight / $tiles->{h});
			$bitmap = $bitmap->GetSubBitmap (new Wx::Rect ([$w * $tiles->{x}, $h * $tiles->{y}], [$w, $h]));
		}
		$self->{image}->SetBitmap ($bitmap);
		$self->{image}->Show (1);
	} else {
		$self->{image}->Show (0);
	}
}

1;
