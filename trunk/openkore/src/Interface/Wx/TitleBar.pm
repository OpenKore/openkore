#########################################################################
#  OpenKore - WxWidgets Interface
#  Title bar control
#
#  Copyright (c) 2004 OpenKore development team 
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
#
#  $Revision$
#  $Id$
#
#########################################################################
package Interface::Wx::TitleBar;

use strict;
use Wx ':everything';
use Wx::Event qw(EVT_BUTTON);
use base qw(Wx::Panel);

sub new {
	my $class = shift;
	my $parent = shift;
	my $title = shift;
	my $self = $class->SUPER::new($parent, -1);

	my $sizer = $self->{sizer} = new Wx::BoxSizer(wxHORIZONTAL);
	$self->SetBackgroundColour(new Wx::Colour(75, 0, 150));

	my $label = $self->{label} = new Wx::StaticText($self, -1, $title);
	$label->SetFont(new Wx::Font(10, wxDEFAULT, wxNORMAL, wxBOLD));
	$label->SetForegroundColour(new Wx::Colour(255, 255, 255));
	$sizer->Add($label, 1, wxGROW | wxLEFT | wxRIGHT | wxADJUST_MINSIZE, 3);

	Wx::Image::AddHandler(new Wx::PNGHandler);
	my $image = Wx::Image->newNameType(f('Interface', 'Wx', 'window.png'), wxBITMAP_TYPE_PNG);
	my $detachButton = $self->{detachButton} = new Wx::BitmapButton($self, 1024, new Wx::Bitmap($image));
	$sizer->Add($detachButton);
	$self->EVT_BUTTON(1024, sub {
		$self->{onDetach}->($self->{onDetachData}) if ($self->{onDetach});
	});

	$image = Wx::Image->newNameType(f('Interface', 'Wx', 'close.png'), wxBITMAP_TYPE_PNG);
	my $closeButton = $self->{closeButton} = new Wx::BitmapButton($self, 1025, new Wx::Bitmap($image));
	$sizer->Add($closeButton);
	$self->EVT_BUTTON(1025, sub {
		$self->{onClose}->($self->{onCloseData}) if ($self->{onClose});
	});

	$self->SetSizer($sizer);
	$self->SetSizeHints($closeButton->GetBestSize->GetWidth * 2 + 8, -1);
	$self->{title} = $title;
	return $self;
}

sub title {
	my $self = shift;
	if ($_[0]) {
		if ($self->{title} ne $_[0]) {
			$self->{title} = $_[0];
			$self->{label}->SetLabel($_[0]);
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
	return File::Spec->catfile('src', @_);
}

1;
