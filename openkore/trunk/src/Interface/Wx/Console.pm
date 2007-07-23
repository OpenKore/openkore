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
use Wx::RichText;
use base qw(Wx::RichTextCtrl);
require DynaLoader;
use encoding 'utf8';

use Globals;
use constant STYLE_SLOT => 4;
use constant MAX_LINES => 1000;

our %fgcolors;

sub new {
	my ($class, $parent) = @_;

	my $self = $class->SUPER::new($parent, -1, '',
		wxDefaultPosition, wxDefaultSize,
		wxTE_MULTILINE | wxVSCROLL | wxTE_NOHIDESEL);
	$self->SetEditable(0);
	$self->BeginSuppressUndo();
	$self->SetBackgroundColour(new Wx::Colour(0, 0, 0));

	my $font;
	if (Wx::wxMSW()) {
		$font = new Wx::Font(9, wxMODERN, wxNORMAL, wxNORMAL, 0, 'Courier New');
	} else {
		$font = new Wx::Font(10, wxMODERN, wxNORMAL, wxNORMAL, 0, 'MiscFixed');
	}
	$self->changeFont($font);

	$self->{inputStyle} = new Wx::TextAttrEx();
	$self->{inputStyle}->SetTextColour(new Wx::Colour(200, 200, 200));

	return $self;
}

sub changeFont {
	my ($self, $font) = @_;
	return unless $font->Ok;

	$self->{font} = $font;
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
	my ($self, $type, $msg, $domain) = @_;

	my $atBottom = $self->IsPositionVisible($self->GetLastPosition());

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
					$style = new Wx::TextAttrEx();
					$style->SetTextColour($color);
					$style->SetFont($self->{boldFont});
				} else {
					$style = new Wx::TextAttrEx();
					$style->SetTextColour($color);
				}
				$fgcolors{$colorName}[STYLE_SLOT] = $style;
			}

			$self->SetDefaultStyle($style);
			$revertStyle = 1;
		}
	}
	
	$self->AppendText($msg);
	$self->SetDefaultStyle($self->{defaultStyle}) if ($revertStyle);

	# Limit the number of lines in the console
	if ($self->GetNumberOfLines() > MAX_LINES) {
		my $linesToDelete = $self->GetNumberOfLines() - MAX_LINES;
		my $pos = $self->XYToPosition(0, $linesToDelete + MAX_LINES / 10);
		$self->Remove(0, $pos);
	}

	if ($atBottom) {
		$self->ShowPosition($self->GetLastPosition());
	}
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
