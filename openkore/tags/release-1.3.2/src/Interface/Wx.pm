#########################################################################
#  OpenKore - WxWidgets Interface
#  You need:
#  * WxPerl (the Perl bindings for WxWidgets) - http://wxperl.sourceforge.net/
#
#  More information about WxWidgets here: http://www.wxwidgets.org/
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
use Wx::Event qw(EVT_CLOSE EVT_MENU EVT_TEXT_ENTER EVT_PAINT);
use Time::HiRes qw(time sleep);
use File::Spec;
require DynaLoader;

use Globals;
use Interface;
use base qw(Wx::App Interface);
use Modules;
use Interface::Wx::MapViewer;
use Settings;
use Plugins;
use Utils;

use constant MAX_CONSOLE_LINES => 2000;

our %fgcolors;


sub OnInit {
	my $self = shift;

	# Determine platform
	if ($buildType == 0) {
		$self->{platform} = 'win32';
	} else {
		my $mod = 'use IPC::Open2; use POSIX;';
		eval $mod;
		if (DynaLoader::dl_find_symbol_anywhere('pango_font_description_new')) {
			# wxGTK is linked to GTK 2
			$self->{platform} = 'gtk2';
			# GTK 2 will segfault if we try to use non-UTF 8 characters,
			# so we need functions to convert them to UTF-8
			$mod = 'use utf8; use Encode;';
			eval $mod;
		} else {
			$self->{platform} = 'gtk1';
		}
	}

	$self->createInterface();
	$self->iterate();
	$self->{iterationTimeout}{timeout} = 0.05;
	$self->{aiBarTimeout}{timeout} = 0.1;

	$self->{loadHook} = Plugins::addHook('loadfiles', sub { $self->onLoadFiles(@_); });
	$self->{postLoadHook} = Plugins::addHook('postloadfiles', sub { $self->onLoadFiles(@_); });

	Modules::register("Interface::Wx::MapViewer");
	return 1;
}

sub DESTROY {
	my $self = shift;
	Plugins::delHook($self->{loadHook});
	Plugins::delHook($self->{postLoadHook});
}

sub iterate {
	my $self = shift;

	$self->updateStatusBar();
	if ($self->{mapViewer} && %field && $char) {
		$self->{mapViewer}->set($field{name}, $char->{pos_to}{x}, $char->{pos_to}{y}, \%field);
		my $i = binFind(\@ai_seq, "route");
		if (defined $i) {
			$self->{mapViewer}->setDest($ai_seq_args[$i]{dest}{pos}{x}, $ai_seq_args[$i]{dest}{pos}{y});
		} else {
			$self->{mapViewer}->setDest();
		}
		$self->{mapViewer}->update();
	}

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
	if ($self->{platform} eq 'gtk2') {
		my $utf8;
		# Convert to UTF-8 so we don't segfault.
		# Conversion to ISO-8859-1 will always succeed
		my @encs = ("EUC-KR", "EUCKR", "ISO-2022-KR", "ISO8859-1");
		foreach (@encs) {
			$utf8 = Encode::encode($_, $msg);
			last if $utf8;
		}
		$msg = Encode::encode_utf8($utf8);
	}
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
	my $menu = $self->{menu} = new Wx::MenuBar();
	$frame->SetMenuBar($menu);

		# Program menu
		my $opMenu = new Wx::Menu();
		$self->addMenu($opMenu, 'E&xit	Ctrl-W', \&main::quit);
		$menu->Append($opMenu, '&Program');

		# View menu
		my $viewMenu = new Wx::Menu();
		$self->addMenu($viewMenu, '&Map	Ctrl-M', \&onMapToggle);
		$viewMenu->AppendSeparator();
		$self->addMenu($viewMenu, '&Font...	Ctrl-F', \&onFontChange);
		$menu->Append($viewMenu, '&View');

		$self->createCustomMenus() if $self->can('createCustomMenus');
		
		# Help menu
		my $helpMenu = new Wx::Menu();
		$self->addMenu($helpMenu, '&Manual	F1', \&onManual);
		$self->addMenu($helpMenu, '&Forum	Shift-F1', \&onForum);
		$menu->Append($helpMenu, '&Help');


	### Vertical box sizer
	my $vsizer = new Wx::BoxSizer(wxVERTICAL);
	$frame->SetSizer($vsizer);


	### Fonts
	my ($fontName, $fontSize);
	if ($self->{platform} eq 'win32') {
		$fontSize = 9;
		$fontName = 'Courier New';
	} elsif ($self->{platform} eq 'gtk2') {
		$fontSize = 10;
		$fontName = 'MiscFixed';
	} else {
		$fontSize = 12;
	}

	if ($fontName) {
		$self->changeFont(new Wx::Font($fontSize, wxMODERN, wxNORMAL, wxNORMAL, 0, $fontName));
	} else {
		$self->changeFont(new Wx::Font($fontSize, wxMODERN, wxNORMAL, wxNORMAL));
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
	$statusbar->SetFieldsCount(3);
	$statusbar->SetStatusWidths(-1, 65, 175);
	$frame->SetStatusBar($statusbar);


	#################

	$frame->SetSizeHints(300, 250);
	$frame->SetClientSize(630, 400);
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
	my ($self, $menu, $label, $callback, $help) = @_;

	$self->{menuIDs}++;
	$menu->Append($self->{menuIDs}, $label, $help);
	EVT_MENU($self->{frame}, $self->{menuIDs}, sub { $callback->($self) });
}

sub changeFont {
	my $self = shift;
	my $font = shift;

	$self->{fonts}{default} = $font;
	my $bold = new Wx::Font(
		$font->GetPointSize(),
		$font->GetFamily(),
		$font->GetStyle(),
		wxBOLD,
		$font->GetUnderlined(),
		$font->GetFaceName()
	);
	$self->{fonts}{bold} = $bold;

	if ($self->{console}) {
		$self->{defaultStyle} = new Wx::TextAttr(
			new Wx::Colour(255, 255, 255),
			$self->{console}->GetBackgroundColour(),
			$font
		);
		$self->{console}->SetDefaultStyle($self->{defaultStyle});
	}

	foreach (keys %fgcolors) {
		delete $fgcolors{$_}[9];
	}
}

sub updateStatusBar {
	my $self = shift;
	return unless (timeOut($self->{aiBarTimeout}));

	my ($statText, $xyText, $aiText) = ('', '', '');

	if ($self->{loadingFiles}) {
		$statText = sprintf("Loading files... %.0f%%", $self->{loadingFiles}{percent} * 100);
	} elsif (!$conState) {
		$statText = "Initializing...";
	} elsif ($conState == 1) {
		$statText = "Not connected";
	} elsif ($conState > 1 && $conState < 5) {
		$statText = "Connecting...";
	} elsif ($self->{mouseMapText}) {
		$statText = $self->{mouseMapText};
	}

	if ($conState == 5) {
		$xyText = "$char->{pos_to}{x}, $char->{pos_to}{y}";

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
		if (defined $_[1] && $self->{$_[0]} ne $_[1]) {
			$self->{$_[0]} = $_[1];
			$self->{statusbar}->SetStatusText($_[1], $i);
		}
		$i++;
	};

	$setStatus->('statText', $statText);
	$setStatus->('xyText', $xyText);
	$setStatus->('aiText', $aiText);
	$self->{aiBarTimeout}{time} = time;
}

sub launchApp {
	if ($buildType == 1) {
		my @args = @_;
		foreach (@args) {
			$_ = "\"$_\"";
		}

		my ($priority, $obj);
		eval 'use Win32::Process; use Win32; $priority = NORMAL_PRIORITY_CLASS;';
		Win32::Process::Create($obj, $_[0], "@args", 0, $priority, '.');
		return $obj;

	} else {
		my $pid = fork();
		if ($pid == 0) {
			open(STDOUT, "> /dev/null");
			open(STDERR, "> /dev/null");
			POSIX::setsid();
			exec(@_);
			POSIX::_exit(1);
		}
		return $pid;
	}
}

sub launchURL {
	my $self = shift;
	my $url = shift;

	if ($buildType == 0) {
		eval "use Win32::API;";
		my $ShellExecute = new Win32::API("shell32", "ShellExecute", "NPPPPN", "V");
		$ShellExecute->Call(0, '', $url, '', '', 1);

	} else {
		my $detectionScript = <<"		EOF";
			function detectDesktop() {
				if [[ "\$DISPLAY" = "" ]]; then
                			return 1
				fi

				local LC_ALL=C
				local clients
				if ! clients=`xlsclients`; then
			                return 1
				fi

				if echo "\$clients" | grep -qE '(gnome-panel|nautilus|metacity)'; then
					echo gnome
				elif echo "\$clients" | grep -qE '(kicker|slicker|karamba|kwin)'; then
        			        echo kde
				else
        			        echo other
				fi
				return 0
			}
			detectDesktop
		EOF

		my ($r, $w, $desktop);
		my $pid = IPC::Open2::open2($r, $w, '/bin/bash');
		print $w $detectionScript;
		close $w;
		$desktop = <$r>;
		$desktop =~ s/\n//;
		close $r;
		waitpid($pid, 0);

		sub checkCommand {
			foreach (split(/:/, $ENV{PATH})) {
				return 1 if (-x "$_/$_[0]");
			}
			return 0;
		}

		if ($desktop eq "gnome" && checkCommand('gnome-open')) {
			launchApp('gnome-open', $url);

		} elsif ($desktop eq "kde") {
			launchApp('kfmclient', 'exec', $url);

		} else {
			if (checkCommand('firefox')) {
				launchApp('firefox', $url);
			} elsif (checkCommand('mozillaa')) {
				launchApp('mozilla', $url);
			} else {
				$self->errorDialog("No suitable browser detected. " .
					"Please launch your favorite browser and go to:\n$url");
			}
		}
	}
}


################## Callbacks ##################

sub onInputEnter {
	my $self = shift;
	$self->{input} = $self->{inputBox}->GetValue();
	$self->{console}->SetDefaultStyle($self->{inputStyle});
	$self->{console}->AppendText("$self->{input}\n");
	$self->{console}->SetDefaultStyle($self->{defaultStyle});
	$self->{inputBox}->Remove(0, -1);
}

sub onLoadFiles {
	my ($self, $hook, $param) = @_;
	if ($hook eq 'loadfiles') {
		$self->{loadingFiles}{percent} = $param->{current} / scalar(@{$param->{files}});
	} else {
		delete $self->{loadingFiles};
	}
}

sub onClose {
	my $self = shift;
	$self->Show(0);
	main::quit();
}

sub onFontChange {
	my $self = shift;

	my $fontData = new Wx::FontData();
	$fontData->SetInitialFont($self->{fonts}{default});
	$fontData->EnableEffects(0);

	my $dialog = new Wx::FontDialog($self->{frame}, $fontData);
	if ($dialog->ShowModal() == wxID_OK) {
		$self->changeFont($dialog->GetFontData()->GetChosenFont());
	}
	$dialog->Destroy();
}

sub onMapToggle {
	my $self = shift;
	# Raise map window and return if it already exists
	if ($self->{mapFrame}) {
		$self->{mapFrame}->Raise();
		return;
	}

	# Create map window
	my $mapFrame;
	if ($self->{platform} eq 'win32') {
		$mapFrame = $self->{mapFrame} = new Wx::MiniFrame($self->{frame}, -1, 'Map');
	} else {
		$mapFrame = $self->{mapFrame} = new Wx::Dialog($self->{frame}, -1, 'Map');
	}
	$mapFrame->SetClientSize(128, 128);
	EVT_CLOSE($mapFrame, sub {
		# WxWidgets doesn't destroy this window until the next idle event.
		# Unfortunately, WxPerl doesn't have a binding for WxApp::SendIdleEvents().
		# And right now we don't have the ability to properly integrate with WxWidgets's
		# main loop. This should be fixed in the future.
		$mapFrame->Show(0);
		$mapFrame->Destroy();
		delete $self->{mapViewer};
		delete $self->{mapFrame};
	});

	my $mapViewer = $self->{mapViewer} = new Interface::Wx::MapViewer($mapFrame);

	$mapViewer->onMouseMove(sub {
			# Mouse moved over the map viewer control
			my (undef, $x, $y) = @_;
			if ($x >= 0 && $y >= 0) {
				$self->{mouseMapText} = "Mouse over: $x, $y";
			} else {
				delete $self->{mouseMapText};
			}
			$self->{statusbar}->SetStatusText($self->{mouseMapText}, 0);
		});

	$mapViewer->onClick(sub {
			# Clicked on map viewer control
			my (undef, $x, $y) = @_;
			delete $self->{mouseMapText};
			$self->writeOutput("message", "Moving to $x, $y\n", "info");
			main::aiRemove("mapRoute");
			main::aiRemove("route");
			main::aiRemove("move");
			main::ai_route($field{name}, $x, $y);
		});

	$mapViewer->onMapChange(sub {
			$mapFrame->SetClientSize($mapViewer->{bitmap}->GetWidth(), $mapViewer->{bitmap}->GetHeight());
			$mapFrame->SetTitle($maps_lut{$field{name} . '.rsw'} . " ($field{name})");
		});

	if (%field && $char) {
		$mapViewer->set($field{name}, $char->{pos_to}{x}, $char->{pos_to}{y}, \%field);
	}
	$mapFrame->Show(1);
}

sub onManual {
	my $self = shift;
	$self->launchURL('http://openkore.sourceforge.net/manual/');
}

sub onForum {
	my $self = shift;
	$self->launchURL('http://openkore.sourceforge.net/forum.php');
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
