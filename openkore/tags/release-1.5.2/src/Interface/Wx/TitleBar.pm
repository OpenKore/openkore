#########################################################################
#  OpenKore - WxWidgets Interface
#  Title bar control
#
#  Copyright (c) 2004,2005 OpenKore development team 
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  $Revision$
#  $Id$
#
#########################################################################
package Interface::Wx::TitleBar;

use strict;
use Wx ':everything';
use Wx::Event qw(EVT_BUTTON EVT_PAINT);
use base qw(Wx::Panel);


our (@brushes, $font, $dark, $light);


sub new {
	my ($class, $parent, $title, $no_buttons) = @_;
	my $self = $class->SUPER::new($parent, -1);

	$self->SetBackgroundColour(new Wx::Colour(98, 165, 241));
	EVT_PAINT($self, \&onPaint);

	if (!$font) {
		if ($^O eq 'MSWin32') {
			$font = new Wx::Font(8, wxDEFAULT, wxNORMAL, wxBOLD, 0, 'Tahoma');
		} else {
			$font = new Wx::Font(9, wxDEFAULT, wxNORMAL, wxBOLD, 0, 'Nimbus Sans L');
		}
	}

	my $size = $self->{size} = 20;

	if (!$no_buttons) {
		my $sizer = $self->{sizer} = new Wx::BoxSizer(wxVERTICAL);
		my $hsizer = new Wx::BoxSizer(wxHORIZONTAL);
		$sizer->Add($hsizer, 1, wxALIGN_RIGHT);

		Wx::Image::AddHandler(new Wx::PNGHandler);
		my $image = Wx::Image->newNameType(f('Interface', 'Wx', 'window.png'), wxBITMAP_TYPE_PNG);
		my $detachButton = new Wx::BitmapButton($self, 1024, new Wx::Bitmap($image),
			wxDefaultPosition, [$size, $size]);
		$self->{detachButton} = $detachButton;
		$detachButton->SetBackgroundColour(Wx::SystemSettings::GetColour(wxSYS_COLOUR_BTNFACE));
		$hsizer->Add($detachButton, 0, wxGROW);

		$image = Wx::Image->newNameType(f('Interface', 'Wx', 'close.png'), wxBITMAP_TYPE_PNG);
		my $closeButton = new Wx::BitmapButton($self, 1025, new Wx::Bitmap($image),
			wxDefaultPosition, [$size, $size]);
		$self->{closeButton} = $closeButton;
		$closeButton->SetBackgroundColour(Wx::SystemSettings::GetColour(wxSYS_COLOUR_BTNFACE));
		$hsizer->Add($closeButton, 0, wxGROW);

		$self->EVT_BUTTON(1024, sub {
			$self->{onDetach}->($self->{onDetachData}) if ($self->{onDetach});
		});
		$self->EVT_BUTTON(1025, sub {
			$self->{onClose}->($self->{onCloseData}) if ($self->{onClose});
		});

		$self->SetSizeHints($closeButton->GetBestSize->GetWidth * 2 + 8, $size);
		$self->SetSizer($sizer);
	} else {
		$self->SetSizeHints(8, $size);
	}

	$self->{title} = $title;

	createBrushes() if (!@brushes);
	if (!$dark) {
		$dark = new Wx::Pen(new Wx::Colour(164, 164, 164), 1, wxSOLID);
		$light = new Wx::Pen(new Wx::Colour(241, 241, 241), 1, wxSOLID);
	}

	return $self;
}

sub title {
	my $self = shift;
	if ($_[0]) {
		if ($self->{title} ne $_[0]) {
			$self->{title} = $_[0];
			$self->Update;
		}
	} else {
		return $self->{title};
	}
}

sub onDetach {
	my $self = shift;
	my $cb = shift;
	my $data = shift;
	$self->{onDetach} = $cb;
	$self->{onDetachData} = $data;
}

sub onClose {
	my $self = shift;
	my $cb = shift;
	my $data = shift;
	$self->{onClose} = $cb;
	$self->{onCloseData} = $data;
}


#### Private ####

sub max {
	return ($_[0] > $_[1]) ? $_[0] : $_[1];
}

sub f {
	my $f = File::Spec->catfile('src', @_);
	$f = File::Spec->catfile(@_) if (! -f $f);
	return $f;
}

sub createBrushes {
	my @from = (0, 40, 130);
	my @to = (129, 188, 255);

	# Create brushes for drawing the gradient
	@brushes = ();
	for (my $i = 0; $i < 255; $i++) {
		my $color = new Wx::Colour(
			$from[0] + ($to[0] - $from[0]) / 255 * $i,
			$from[1] + ($to[1] - $from[1]) / 255 * $i,
			$from[2] + ($to[2] - $from[2]) / 255 * $i
		);
		my $brush = new Wx::Brush($color, wxSOLID);
		push @brushes, $brush;
	}
}

sub onPaint {
	my $self = shift;
	my $dc = new Wx::PaintDC($self);

	my $width = $self->GetSize->GetWidth;
	if ($self->{detachButton}) {
		$width -= $self->{detachButton}->GetSize->GetWidth + $self->{closeButton}->GetSize->GetWidth;
	}

	eval {
	# The app can crash if I don't use eval here.
	# Something about "the invocant is not a reference".
	# This'll do for now, I just hope it doesn't corrupt memory...

	my $x = 0;
	my $block = $width / 255;
	my $height = $self->GetSize->GetHeight;
	$dc->SetPen(wxTRANSPARENT_PEN);
	for (my $i = 0; $i < 255; $i++) {
		my $x = $block * $i;
		$dc->SetBrush($brushes[$i]);
		$dc->DrawRectangle($x, 0, $block + 1, $height);
	}

	$dc->SetBrush(wxTRANSPARENT_BRUSH);
	if ($^O eq 'MSWin32') {
		$dc->SetPen($dark);
		$dc->DrawLine(0, 0, $width, 0);
		$dc->DrawLine(0, 0, 0, $height);
		#$dc->DrawLine(1, $height - 2, $width - 2, $height - 2);
		#$dc->DrawLine($width - 2, 2, $width - 2, $height - 1);

		$dc->SetPen($light);
		$dc->DrawLine(0, $height - 1, $width - 1, $height - 1);
		$dc->DrawLine($width - 1, 1, $width - 1, $height);
		#$dc->DrawLine(1, 1, $width - 1, 1);
		#$dc->DrawLine(1, 2, 1, $height - 2);
	} else {
		$dc->SetPen($light);
		$dc->DrawLine(0, 0, $width, 0);
		$dc->DrawLine(0, 0, 0, $height);
		$dc->SetPen($dark);
		$dc->DrawLine(0, $height - 1, $width - 1, $height - 1);
		$dc->DrawLine($width - 1, 0, $width - 1, $height - 1);
	}

	$dc->SetFont($font);
	$dc->SetTextForeground(wxWHITE);
	my (undef, $textHeight) = $dc->GetTextExtent($self->{title}, $font);
	$dc->DrawText($self->{title}, 6, $height / 2 - $textHeight / 2);

	};
	undef $@;
}

1;
