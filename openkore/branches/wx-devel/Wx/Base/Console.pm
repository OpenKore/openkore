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
##
# MODULE DESCRIPTION: Console control.
#
# This control emulates a console, similar to xterm/gnome-terminal/the DOS box.
# It supports automatic scrolling, colored text, and a bounded scrollback buffer.
package Interface::Wx::Base::Console;

use strict;
use Wx ':everything';
use Wx::RichText;
use base qw(Wx::RichTextCtrl);
use encoding 'utf8';

use Globals qw(%consoleColors);
use Utils::StringScanner;

use constant STYLE_SLOT => 4;
use constant MAX_LINES => 1000;

our (%fgcolors, %bgcolors);
# Maps color names to color codes and font weights.
# Format: [R, G, B, bold]
%fgcolors = %bgcolors = (
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
%fgcolors = (
	%fgcolors,
	'reset'		=> [255, 255, 255],
	'default'	=> [255, 255, 255],
	'input'   => [200, 200, 200],
);
%bgcolors = (
	%bgcolors,
	'reset'		=> [0, 0, 0],
	'default'	=> [0, 0, 0],
	'input'   => [0, 0, 0],
);

##
# Interface::Wx::Console->new(Wx::Window parent)
#
# Create a new Interface::Wx::Console control, with $parent as its parent
# control.
sub new {
	my ($class, $parent) = @_;

	my $self = $class->SUPER::new($parent, wxID_ANY, '',
		wxDefaultPosition, wxDefaultSize,
		wxTE_MULTILINE | wxVSCROLL | wxTE_NOHIDESEL);
	$self->SetEditable(0);
	$self->BeginSuppressUndo();
	$self->SetForegroundColour(wxWHITE);
	$self->SetBackgroundColour(wxBLACK);

	$self->{defaultStyle} = new Wx::TextAttrEx();
	$self->{defaultStyle}->SetTextColour($self->GetForegroundColour());
	$self->{defaultStyle}->SetBackgroundColour($self->GetBackgroundColour());

	my $font;
	if (Wx::wxMSW()) {
		$font = new Wx::Font(9, wxMODERN, wxNORMAL, wxNORMAL, 0, 'Courier New');
	} elsif ($^O eq 'freebsd') {
		$font = new Wx::Font(10, wxMODERN, wxNORMAL, wxNORMAL, 0, 'Monospace');
	} else {
		$font = new Wx::Font(10, wxMODERN, wxNORMAL, wxNORMAL, 0, 'MiscFixed');
	}
	$self->setFont($font);

=pod
	$self->{inputStyle} = {
		color => new Wx::Colour(200, 200, 200)
	};
=cut

	return $self;
}

##
# void $Interface_Wx_Console->setFont(Wx::Font font)
#
# Set the font used in this console.
sub setFont {
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

	$self->{defaultStyle}->SetFont($font);
	$self->SetDefaultStyle($self->{defaultStyle});
	$self->Refresh();

	foreach my $colorName (keys %fgcolors) {
		delete $fgcolors{$colorName}[STYLE_SLOT];
	}
}

##
# void $Wx_Interface_Console->selectFont(Wx::Window parent)
#
# Show a font dialog and let the user pick a font. This font
# will be used in this console.
sub selectFont {
	my ($self, $parent) = @_;

	my $fontData = new Wx::FontData;
	$fontData->SetInitialFont($self->{font});
	$fontData->EnableEffects(0);

	my $dialog = new Wx::FontDialog($parent, $fontData);
	$dialog->Show();
	if ($dialog->ShowModal == wxID_OK) {
		$self->setFont($dialog->GetFontData->GetChosenFont());
	}
	$dialog->Destroy();
}

sub copyLastLines {
	my ($self, $limit) = @_;
	my $startLine = $self->GetNumberOfLines() - $limit;
	my $startPos = $self->XYToPosition(0, $startLine < 0 ? 0 : $startLine);
	my $endPos = $self->XYToPosition(0, $self->GetNumberOfLines() - 1);
	$self->SetSelection($startPos, $endPos);
	$self->Copy();
}

sub determineFontStyle {
	my ($self, $type, $domain) = @_;

	return ($self->{defaultStyle}, 0) unless $consoleColors{$type};
	
	my $fgcolor = $consoleColors{$type}{$domain} || $consoleColors{$type}{default};
	my ($bgcolor) = $fgcolor =~ s~/(.*)~~;
	
	my ($fg, $bg) = ($fgcolors{$fgcolor} || $fgcolors{default}, $bgcolors{$bgcolor} || $bgcolors{default});
	
	$fg->[STYLE_SLOT] ||= {
		color => new Wx::Colour(@$fg[0..2]),
		bold => $fg->[3],
	};
	$bg->[STYLE_SLOT] ||= {
		color => new Wx::Colour(@$bg[0..2]),
	};
	
	my $style = new Wx::TextAttrEx;
	$style->SetTextColour($fg->[STYLE_SLOT]{color});
	$style->SetBackgroundColour($bg->[STYLE_SLOT]{color});
	#$style->SetFontWeight(wxBOLD) if $fg->[STYLE_SLOT]{bold};
	return ($style, $fg->[STYLE_SLOT]{bold});
}

sub isAtBottom {
	my ($self) = @_;
	return $self->IsPositionVisible($self->GetLastPosition()-5);
}

sub finalizePrinting {
	my ($self, $wasAtBottom) = @_;

	# Limit the number of lines in the console.
	if ($self->GetNumberOfLines() > MAX_LINES) {
		$self->_CaretSave(); # Save Caret and Selection position
		my $linesToDelete = $self->GetNumberOfLines() - MAX_LINES;
		my $pos = $self->XYToPosition(0, $linesToDelete + MAX_LINES / 10);
		$self->Remove(0, $pos);
		
		$self->_CaretAdjustXY(0, 0 - ($linesToDelete + MAX_LINES / 10)); # Adjust Caret and Selection
		$self->_CaretRestore(); # Restore Caret and Selection position
	}

	$self->ShowPosition($self->GetLastPosition()) if ($wasAtBottom);
}

##
# void $Interface_Wx_Console->add(String type, String message, String domain)
#
# Print a text to this console, with the given type and domain. See the
# logging framework (@MODULE(Log)) for more information about message
# types and message domains.
sub add {
	my ($self, $type, $msg, $domain) = @_;
	my $atBottom = $self->isAtBottom();

	$self->_CaretSave(); # Save Caret position
	$self->SetInsertionPointEnd(); # Move Caret to the End

	# Apply the appropriate font style, then add the text, then revert
	# back to the previous font style.
	my ($style, $bold) = $self->determineFontStyle($type, $domain);
	
	if ($style) {
		$self->BeginStyle($style);
		$self->BeginBold if $bold;
	}
	$self->AppendText($msg);
	if ($style) {
		$self->EndBold if $bold;
		$self->EndStyle;
	}
	
	$self->_CaretRestore(); # Restore Caret and Selection position
	$self->finalizePrinting($atBottom);
}

sub addColoredText {
	my ($self, $text) = @_;
	my $atBottom = $self->isAtBottom();

	$self->_CaretSave(); # Save Caret position
	$self->SetInsertionPointEnd(); # Move Caret to the End

	my $style = new Wx::TextAttrEx();
	$style->SetTextColour(wxBLACK);
	$style->SetBackgroundColour(wxWHITE);
	$self->BeginStyle($style);

	my $scanner = new Utils::StringScanner($text);
	my $colorCodeEncountered;
	while (!$scanner->eos()) {
		my $text = $scanner->scanUntil(qr/\^[a-fA-F0-9]{6}/o);
		if (defined($text) && length($text) > 0) {
			# Process text.
			$self->AppendText($text);
		} else {
			$text = $scanner->scan(qr/\^[a-fA-F0-9]{6}/o);
			if (defined $text) {
				# Process color code.
				$text =~ /([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})/i;
				$self->EndTextColour() if ($colorCodeEncountered);
				$self->BeginTextColour(new Wx::Colour(hex($1), hex($2), hex($3)));
				$colorCodeEncountered = 1;
			} else {
				# Process text until end-of-string.
				# $self->AppendText($scanner->rest()); # AppendText is broken when compiling with MingW
				$self->WriteText($scanner->rest());
				$scanner->terminate();
			}
		}
	}

	$self->EndTextColour() if ($colorCodeEncountered);
	$self->EndStyle();
	$self->finalizePrinting($atBottom);
}


#####################################

# Caret Anjusting Functions
sub _CaretSave {
	my $self = shift;
	my ($caret_x, $caret_y) = $self->PositionToXY($self->GetCaretPosition());
	my $has_selection = $self->HasSelection();
	my ($sel_st_x,$sel_st_y) = $has_selection ? $self->PositionToXY($self->GetSelectionRange()->GetStart()) : (0, 0);
	my ($sel_end_x,$sel_end_y) = $has_selection ? $self->PositionToXY($self->GetSelectionRange()->GetEnd()) : (0, 0);
	
	$self->{caret} = {
		caret_x => $caret_x,
		caret_y => $caret_y,
		is_selection => $has_selection,
		selection_start_x => $sel_st_x,
		selection_start_y => $sel_st_y,
		selection_end_x => $sel_end_x,
		selection_end_y => $sel_end_y,
	};
}

sub _CaretRestore {
	my $self = shift;
	if ( $self->{caret}{is_selection} ) {
		$self->SetSelection($self->XYToPosition($self->{caret}{selection_start_x}, $self->{caret}{selection_start_y}), $self->XYToPosition($self->{caret}{selection_end_x}, $self->{caret}{selection_end_y}));
	};
	$self->SetCaretPosition($self->XYToPosition($self->{caret}{caret_x}, $self->{caret}{caret_y}));
}

sub _CaretAdjustXY {
	my ($self, $delta_x, $delta_y) = @_;

	$self->{caret}{caret_x} = $self->{caret}{caret_x} + $delta_x >= 0 ? $self->{caret}{caret_x} + $delta_x : 0;
	$self->{caret}{caret_y} = $self->{caret}{caret_y} + $delta_y >= 0 ? $self->{caret}{caret_y} + $delta_y : 0;
	if ( $self->{caret}{is_selection} ) {
		$self->{caret}{selection_start_x} = $self->{caret}{selection_start_x} + $delta_x >= 0 ? $self->{caret}{selection_start_x} + $delta_x : 0;
		$self->{caret}{selection_start_y} = $self->{caret}{selection_start_y} + $delta_y >= 0 ? $self->{caret}{selection_start_y} + $delta_y : 0;
		$self->{caret}{selection_end_x} = $self->{caret}{selection_end_x} + $delta_x >= 0 ? $self->{caret}{selection_end_x} + $delta_x : 0;
		$self->{caret}{selection_end_y} = $self->{caret}{selection_end_y} + $delta_y >= 0 ? $self->{caret}{selection_end_y} + $delta_y : 0;
	};
}

1;
