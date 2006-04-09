#########################################################################
#  OpenKore - WxWidgets Interface
#  Console control
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
package Interface::Wx::Console;

use strict;
use Wx ':everything';
use base qw(Wx::TextCtrl);
require DynaLoader;
use encoding 'utf8';

use Globals;
use constant STYLE_SLOT => 4;
use constant MAX_LINES => 1000;

our %fgcolors;

sub new {
	my ($class, $parent, $noColors) = @_;

	my $self = $class->SUPER::new($parent, -1, '',
		wxDefaultPosition, wxDefaultSize,
		wxTE_MULTILINE | wxTE_RICH | wxTE_NOHIDESEL);
	$self->SetEditable(0);
	$self->{noColors} = $noColors;
	if (!$noColors) {
		$self->SetBackgroundColour(new Wx::Colour(0, 0, 0));
	}

	### Fonts
	my ($fontName, $fontSize);
	if (Wx::wxMSW()) {
		$fontSize = 9;
		$fontName = 'Courier New';
	} else {
		$fontSize = 10;
		$fontName = 'MiscFixed';
	}

	if ($fontName) {
		$self->changeFont(new Wx::Font($fontSize, wxMODERN, wxNORMAL, wxNORMAL, 0, $fontName));
	} else {
		$self->changeFont(new Wx::Font($fontSize, wxMODERN, wxNORMAL, wxNORMAL));
	}

	### Styles
	if (!$noColors) {
		$self->{defaultStyle} = new Wx::TextAttr(
			new Wx::Colour(255, 255, 255),
			$self->GetBackgroundColour,
			$self->{font}
		);
		$self->SetDefaultStyle($self->{defaultStyle});

		$self->{inputStyle} = new Wx::TextAttr(
			new Wx::Colour(200, 200, 200),
			wxNullColour
		);
	}

	return $self;
}

sub changeFont {
	my $self = shift;
	my $font = shift;
	return unless $font->Ok;

	$self->{font} = $font;

	if ($self->{noColors}) {
		#$self->{defaultStyle} = new Wx::TextAttr($self->{defaultStyle}->GetTextColour, wxNullColour, $font);
		#$self->SetDefaultStyle($self->{defaultStyle});
		$self->SetFont($font);

	} else {
		my $bold = new Wx::Font(
			$font->GetPointSize(),
			$font->GetFamily(),
			$font->GetStyle(),
			wxBOLD,
			$font->GetUnderlined(),
			$font->GetFaceName()
		);
		$self->{boldFont} = $bold;

		$self->{defaultStyle} = new Wx::TextAttr(
			new Wx::Colour(255, 255, 255),
			$self->GetBackgroundColour,
			$font
		);
		$self->SetDefaultStyle($self->{defaultStyle});

		foreach (keys %fgcolors) {
			delete $fgcolors{$_}[STYLE_SLOT];
		}
	}
}

sub selectFont {
	my $self = shift;
	my $parent = shift;

	my $fontData = new Wx::FontData;
	$fontData->SetInitialFont($self->{font});
	$fontData->EnableEffects(0);

	my $dialog = new Wx::FontDialog($parent, $fontData);
	if ($dialog->ShowModal == wxID_OK) {
		$self->changeFont($dialog->GetFontData->GetChosenFont);
	}
	$dialog->Destroy;
}

sub add {
	my $self = shift;
	my $type = shift;
	my $msg = shift;
	my $domain = shift;

	$self->Freeze();

	# Determine color
	my $revertStyle;
	if (!$self->{noColors} && $consoleColors{$type}) {
		$domain = 'default' if (!$consoleColors{$type}{$domain});

		my $colorName = $consoleColors{$type}{$domain};
		if ($fgcolors{$colorName} && $colorName ne "default" && $colorName ne "reset") {
			my $style;
			if ($fgcolors{$colorName}[STYLE_SLOT]) {
				$style = $fgcolors{$colorName}[STYLE_SLOT];
			} else {
				my $color = new Wx::Colour(
					$fgcolors{$colorName}[0],
					$fgcolors{$colorName}[1],
					$fgcolors{$colorName}[2]);
				if ($fgcolors{$colorName}[3]) {
					$style = new Wx::TextAttr($color, wxNullColour, $self->{boldFont});
				} else {
					$style = new Wx::TextAttr($color);
				}
				$fgcolors{$colorName}[STYLE_SLOT] = $style;
			}

			$self->SetDefaultStyle($style);
			$revertStyle = 1;
		}
	}

	# Add text
	$self->AppendText($msg);
	$self->SetDefaultStyle($self->{defaultStyle}) if ($revertStyle);

	# Limit the number of lines in the console
	if ($self->GetNumberOfLines > MAX_LINES) {
		my $linesToDelete = $self->GetNumberOfLines() - MAX_LINES;
		my $pos = $self->XYToPosition(0, $linesToDelete + MAX_LINES / 10);
		$self->Remove(0, $pos);
	}

	$self->SetInsertionPointEnd();
	$self->Thaw();
}


#####################################

# Format: [R, G, B, bold]
%fgcolors = (
	'reset'		=> [255, 255, 255],
	'default'	=> [255, 255, 255],

	'black'		=> [0, 0, 0],
	'darkgray'	=> [85, 85, 85],
	'darkgrey'	=> [85, 85, 85],

	'darkred'	=> [170, 0, 0],
	'red'		=> [255, 0, 0, 1],

	'darkgreen'	=> [0, 170, 0],
	'green'		=> [0, 255, 0],

	'brown'		=> [170, 85, 0],
	'yellow'	=> [255, 255, 85],

	'darkblue'	=> [85, 85, 255],
	'blue'		=> [122, 154, 225],

	'darkmagenta'	=> [170, 0, 170],
	'magenta'	=> [255, 85, 255],

	'darkcyan'	=> [0, 170, 170],
	'cyan'		=> [85, 255, 255],

	'gray'		=> [170, 170, 170],
	'grey'		=> [170, 170, 170],
	'white'		=> [255, 255, 255, 1],
);

1;
