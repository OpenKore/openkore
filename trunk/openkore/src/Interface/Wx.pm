#########################################################################
#  OpenKore - WxWidgets Interface
#  You need:
#  * WxWidgets - http://www.wxwidgets.org/
#  * WxPerl (the Perl bindings for WxWidgets) - http://wxperl.sourceforge.net/
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
package Interface::Wx;

use strict;
use Wx ':everything';
use Wx::Event qw(EVT_CLOSE EVT_MENU EVT_TEXT_ENTER);
use Time::HiRes qw(time sleep);

use Globals;
use Interface;
use base qw(Wx::App Interface);
use Settings;
use Utils;

use constant MAX_CONSOLE_LINES => 2000;

our %fgcolors;


sub OnInit {
	my $self = shift;
	$self->createInterface();
	$self->iterate();
	$self->{iterationTimeout}{timeout} = 0.05;
	$self->{aiBarTimeout}{timeout} = 0.1;
	return 1;
}

sub iterate {
	my $self = shift;

	$self->updateStatusBar();
	while ($self->Pending()) {
		$self->Dispatch();
	}
	$self->Yield();
	$self->{iterationTimeout}{time} = time;
}

sub getInput {
	my $self = shift;
	my $timeout = shift;
	my $msg;

	if ($timeout < 0) {
		while (!defined $self->{input} && !$quit) {
			$self->iterate();
			sleep 0.01;
		}
		$msg = $self->{input};

	} elsif ($timeout == 0) {
		$msg = $self->{input};

	} else {
		my $begin = time;
		until (defined $self->{input} || time - $begin > $timeout || $quit) {
			$self->iterate();
			sleep 0.01;
		}
		$msg = $self->{input};
	}

	undef $self->{input};
	undef $msg if (defined($msg) && $msg eq "");

	# Make sure we update the GUI. This is to work around the effect
	# of functions that block for a while
	$self->iterate() if (timeOut($self->{iterationTimeout}));

	return $msg;
}

sub writeOutput {
	my $self = shift;
	my $type = shift;
	my $msg = shift;
	my $domain = shift;

	$self->{console}->Freeze();

	# Determine color
	my $revertStyle;
	if ($consoleColors{$type}) {
		$domain = 'default' if (!$consoleColors{$type}{$domain});

		my $colorName = $consoleColors{$type}{$domain};
		if ($fgcolors{$colorName} && $colorName ne "default" && $colorName ne "reset") {
			my $style;
			if ($fgcolors{$colorName}[9]) {
				$style = $fgcolors{$colorName}[9];
			} else {
				my $color = new Wx::Colour(
					$fgcolors{$colorName}[0],
					$fgcolors{$colorName}[1],
					$fgcolors{$colorName}[2]);
				if ($fgcolors{$colorName}[3]) {
					$style = new Wx::TextAttr($color, wxNullColour, $self->{fonts}{bold});
				} else {
					$style = new Wx::TextAttr($color);
				}
				$fgcolors{$colorName}[9] = $style;
			}

			$self->{console}->SetDefaultStyle($style);
			$revertStyle = 1;
		}
	}

	# Add text
	$self->{console}->AppendText($msg);
	$self->{console}->SetDefaultStyle($self->{defaultStyle}) if ($revertStyle);

	# Limit the number of lines in the console
	if ($self->{console}->GetNumberOfLines() > MAX_CONSOLE_LINES) {
		my $linesToDelete = $self->{console}->GetNumberOfLines() - MAX_CONSOLE_LINES;
		my $pos = $self->{console}->XYToPosition(0, $linesToDelete);
		$self->{console}->Remove(0, $pos);
	}

	$self->{console}->SetInsertionPointEnd();
	$self->{console}->Thaw();

	# Make sure we update the GUI. This is to work around the effect
	# of functions that block for a while
	$self->iterate() if (timeOut($self->{iterationTimeout}));
}

sub title {
	my $self = shift;
	my $title = shift;

	if (defined $title) {
		if ($title ne $self->{title}) {
			$self->{frame}->SetTitle($title);
			$self->{title} = $title;
		}
	} else {
		return $self->{title};
	}
}

sub displayUsage {
	my $self = shift;
	my $text = shift;
	print $text;
}

sub errorDialog {
	my $self = shift;
	my $msg = shift;
	my $fatal = shift;

	my $title = ($fatal) ? "Fatal error" : "Error";
	Wx::MessageBox($msg, "$title - $Settings::NAME", wxICON_ERROR, $self->{frame});
}


################################


sub createInterface {
	my $self = shift;

	### Main window
	my $frame = $self->{frame} = new Wx::Frame(undef, -1, $Settings::NAME);
	$self->{title} = $frame->GetTitle();


	### Menu bar
	my $menu = new Wx::MenuBar();
	$frame->SetMenuBar($menu);

		# Program menu
		my $opMenu = new Wx::Menu();
		$self->addMenu($opMenu, 'E&xit', \&main::quit);
		$menu->Append($opMenu, '&Program');

		if (0) {
		# Test menu
		my $testMenu = new Wx::Menu();
		#$self->addMenu($testMenu, 'Test');
		$menu->Append($testMenu, '&Test');
		}

		# Help menu
		my $helpMenu = new Wx::Menu();
		$self->addMenu($helpMenu, '&Manual', \&onManual);
		$self->addMenu($helpMenu, '&Forum', \&onForum);
		$menu->Append($helpMenu, '&Help');


	### Vertical box sizer
	my $vsizer = new Wx::BoxSizer(wxVERTICAL);
	$frame->SetSizer($vsizer);


	### Fonts
	my ($fontName, $fontSize);
	if ($buildType == 0) {
		$fontSize = 10;
		$fontName = 'Courier New';
	} else {
		require DynaLoader;
		if (DynaLoader::dl_find_symbol_anywhere('pango_font_description_new')) {
			# wxGTK is linked to GTK 2
			$fontSize = 10;
			$fontName = 'MiscFixed';
		} else {
			$fontSize = 12;
		}
	}
	if ($fontName) {
		$self->{fonts}{default} = new Wx::Font($fontSize, wxMODERN, wxNORMAL, wxNORMAL, 0, $fontName);
		$self->{fonts}{bold} = new Wx::Font($fontSize, wxMODERN, wxNORMAL, wxBOLD, 0, $fontName);
	} else {
		$self->{fonts}{default} = new Wx::Font($fontSize, wxMODERN, wxNORMAL, wxNORMAL);
		$self->{fonts}{bold} = new Wx::Font($fontSize, wxMODERN, wxNORMAL, wxBOLD);
	}

	$self->{inputStyle} = new Wx::TextAttr(
		new Wx::Colour(200, 200, 200),
		wxNullColour
	);


	## Console
	my $console = $self->{console} = new Wx::TextCtrl($frame, -1, '',
		wxDefaultPosition, wxDefaultSize,
		wxTE_MULTILINE | wxTE_RICH | wxTE_NOHIDESEL);
	$vsizer->Add($console, 1, wxALL | wxGROW);
	$console->SetEditable(0);
	$console->SetBackgroundColour(new Wx::Colour(0, 0, 0));
	$self->{defaultStyle} = new Wx::TextAttr(
		new Wx::Colour(255, 255, 255),
		$console->GetBackgroundColour(),
		$self->{fonts}{default}
	);
	$console->SetDefaultStyle($self->{defaultStyle});


	### Input field
	my $inputBox = $self->{inputBox} = new Wx::TextCtrl($frame, 1, '',
		wxDefaultPosition, wxDefaultSize, wxTE_PROCESS_ENTER);
	$vsizer->Add($inputBox, 0, wxALL | wxGROW);
	EVT_TEXT_ENTER($inputBox, 1, sub { $self->onInputEnter(); });


	### Status bar
	my $statusbar = $self->{statusbar} = new Wx::StatusBar($frame, -1, wxST_SIZEGRIP);
	$statusbar->SetFieldsCount(2);
	$statusbar->SetStatusWidths(-1, 175);
	$frame->SetStatusBar($statusbar);


	#################

	$frame->SetClientSize(665, 420);
	$frame->SetIcon(Wx::GetWxPerlIcon());
	$frame->Show(1);
	$self->SetTopWindow($frame);
	$inputBox->SetFocus();
	EVT_CLOSE($frame, \&onClose);

	# Hide console on Win32
	if ($buildType == 0) {
		#eval 'use Win32::Console; Win32::Console->new(STD_OUTPUT_HANDLE)->Free();';
	}
}

sub addMenu {
	my ($self, $menu, $label, $callback) = @_;

	$self->{menuIDs}++;
	$menu->Append($self->{menuIDs}, $label);
	EVT_MENU($self->{frame}, $self->{menuIDs}, sub { $callback->($self) });
}

sub updateStatusBar {
	my $self = shift;
	return unless (timeOut($self->{aiBarTimeout}));

	my ($statText, $aiText);

	if (!$conState) {
		$statText = "Initializing...";
	} elsif ($conState == 1) {
		$statText = "Not connected";
	} elsif ($conState > 1 && $conState < 5) {
		$statText = "Connecting...";
	} elsif ($conState == 5) {
		$statText = '';
	}

	if ($conState == 5) {
		if (@ai_seq) {
			my @seqs = @ai_seq;
			foreach (@seqs) {
				s/^route_//;
				s/_/ /g;
				s/([a-z])([A-Z])/$1 $2/g;
			}
			substr($seqs[0], 0, 1) = uc substr($seqs[0], 0, 1);
			$aiText = join(', ', @seqs);
		} else {
			$aiText = "";
		}
	}

	# Only set status bar text if it has changed
	my $i = 0;
	my $setStatus = sub {
		if ($self->{$_[0]} ne $_[1]) {
			$self->{$_[0]} = $_[1];
			$self->{statusbar}->SetStatusText($_[1], $i);
		}
		$i++;
	};

	$setStatus->('statText', $statText);
	$setStatus->('aiText', $aiText);
	$self->{aiBarTimeout}{time} = time;
}

sub onClose {
	my $self = shift;
	$self->Show(0);
	main::quit();
}

sub onInputEnter {
	my $self = shift;
	$self->{input} = $self->{inputBox}->GetValue();
	$self->{console}->SetDefaultStyle($self->{inputStyle});
	$self->{console}->AppendText("$self->{input}\n");
	$self->{console}->SetDefaultStyle($self->{defaultStyle});
	$self->{inputBox}->Remove(0, -1);
}

sub onManual {
}

sub onForum {
	
}


###############################


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
