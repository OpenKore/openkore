#########################################################################
#  OpenKore - WxWidgets Interface
#  Log viewer control
#  A text control with a limited line capacity. It will automatically
#  remove the first line(s) if you insert more lines than the capacity
#  allows.
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
package Interface::Wx::Base::LogView;

use strict;
use Wx ':everything';
use base qw(Wx::TextCtrl);
require DynaLoader;

use Globals;
use Utils qw(binFind);
use constant MAX_LINES => 1000;

our $platform;

sub new {
	my ($class, $parent) = @_;

	if (!$platform) {
		if ($^O eq 'MSWin32') {
			$platform = 'win32';
		} else {
			my $mod = 'use IPC::Open2; use POSIX;';
			eval $mod;
			if (DynaLoader::dl_find_symbol_anywhere('pango_font_description_new')) {
				# wxGTK is linked to GTK 2
				$platform = 'gtk2';
				# GTK 2 will segfault if we try to use non-UTF 8 characters,
				# so we need functions to convert them to UTF-8
				$mod = 'use utf8; use Encode;';
				eval $mod;
			} else {
				$platform = 'gtk1';
			}
		}
	}

	my $self = $class->SUPER::new($parent, wxID_ANY, '',
		wxDefaultPosition, wxDefaultSize,
		wxTE_MULTILINE | wxTE_RICH | wxTE_NOHIDESEL);
	$self->SetEditable(0);

	### Fonts
	my $font;
	if ($platform eq 'win32') {
		$font = new Wx::Font(9, wxDEFAULT, wxNORMAL, wxNORMAL, 0, 'Courier New');

	} elsif ($platform eq 'gtk2') {
		my $enum = new Wx::FontEnumerator;
		$enum->EnumerateFacenames(wxFONTENCODING_SYSTEM, 1);
		my @fonts = $enum->GetFacenames;

		my $name;
		if (defined binFind(\@fonts, 'Bitstream Vera Sans Mono')) {
			$name = 'Bitstream Vera Sans Mono';
		} else {
			$name = 'monospace';
		}
		$font = new Wx::Font(10, wxDEFAULT, wxNORMAL, wxNORMAL, 0, $name);

	} else {
		$font = Wx::SystemSettings::GetFont(wxSYS_ANSI_FIXED_FONT);
	}

	$self->{font} = $font;
	$self->{defaultStyle} = new Wx::TextAttr(
		Wx::SystemSettings::GetColour(wxSYS_COLOUR_WINDOWTEXT),
		Wx::SystemSettings::GetColour(wxSYS_COLOUR_WINDOW),
		$font);
	$self->SetDefaultStyle($self->{defaultStyle});

	$self->{styles} = {};
	return $self;
}

sub setDefaultColor {
	my ($self, $fg, $bg) = @_;

	if (!$fg && !$bg) {
		$self->{defaultStyle} = new Wx::TextAttr(
			Wx::SystemSettings::GetColour(wxSYS_COLOUR_WINDOWTEXT),
			Wx::SystemSettings::GetColour(wxSYS_COLOUR_WINDOW),
			$self->{font});
		$self->SetBackgroundColour(Wx::SystemSettings::GetColour(wxSYS_COLOUR_WINDOW));
	} else {
		$self->{defaultStyle} = new Wx::TextAttr($fg, $bg, $self->{font});
		$self->SetBackgroundColour($bg);
	}
	$self->SetDefaultStyle($self->{defaultStyle});

	foreach my $name (keys %{$self->{styles}}) {
		my $color = $self->{styles}{$name}->GetTextColour;
		$self->addColor($name, $color->Red, $color->Green, $color->Blue);
	}
}

sub addColor {
	my ($self, $name, $r, $g, $b) = @_;
	my $style = new Wx::TextAttr(
		new Wx::Colour($r, $g, $b),
		$self->GetBackgroundColour,
		$self->{font}
	);
	$self->{styles}{$name} = $style;
}

sub add {
	my ($self, $text, $color) = @_;
	my $revertStyle;

	$self->Freeze;

	if ($platform eq 'gtk2') {
		my $utf8;
		# Convert to UTF-8 so we don't segfault.
		# Conversion to ISO-8859-1 will always succeed
		foreach my $encoding ("EUC-KR", "EUCKR", "ISO-2022-KR", "ISO8859-1") {
			$utf8 = Encode::encode($encoding, $text);
			last if $utf8;
		}
		$text = Encode::encode_utf8($utf8);
	}

	if ($self->{styles}{$color}) {
		$revertStyle = 1;
		$self->SetDefaultStyle($self->{styles}{$color});
	}

	$self->AppendText($text);
	$self->SetDefaultStyle($self->{defaultStyle}) if ($revertStyle);

	# Limit the number of lines in the console
	if ($self->GetNumberOfLines > MAX_LINES) {
		my $linesToDelete = $self->GetNumberOfLines - MAX_LINES;
		my $pos = $self->XYToPosition(0, $linesToDelete + MAX_LINES / 10);
		$self->Remove(0, $pos);
	}

	$self->SetInsertionPointEnd;
	$self->Thaw;
}

1;
