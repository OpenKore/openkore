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
use Wx::Event qw(EVT_CLOSE EVT_MENU EVT_TEXT_ENTER EVT_PAINT EVT_SPLITTER_DOUBLECLICKED);
use Time::HiRes qw(time sleep);
use File::Spec;
require DynaLoader;

use Globals;
use Interface;
use base qw(Wx::App Interface);
use Modules;
use Interface::Wx::Dock;
use Interface::Wx::MapViewer;
use Interface::Wx::Console;
use AI;
use Settings;
use Plugins;
use Misc;
use Commands;
use Utils;

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
	$self->{console}->add(@_);
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
		$menu->Append($opMenu, 'P&rogram');

		my $infoMenu = new Wx::Menu();
		$self->addMenu($infoMenu, '&Status	Alt-S', sub { Commands::run("s"); });
		$self->addMenu($infoMenu, 'S&tatistics', sub { Commands::run("st"); });
		$self->addMenu($infoMenu, '&Inventory	Alt-I', sub { Commands::run("i"); });
		$self->addMenu($infoMenu, 'S&kills', sub { Commands::run("skills"); });
		$infoMenu->AppendSeparator();
		$self->addMenu($infoMenu, '&Players	Alt-P', sub { Commands::run("pl"); });
		$self->addMenu($infoMenu, '&Monsters	Alt-M', sub { Commands::run("ml"); });
		$menu->Append($infoMenu, 'I&nfo');

		# View menu
		my $viewMenu = new Wx::Menu();
		$self->addMenu($viewMenu, '&Map	Ctrl-M', \&onMapToggle);
		$viewMenu->AppendSeparator();
		$self->addMenu($viewMenu, '&Font...', \&onFontChange);
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


	## Splitter with console, dock and map viewer
	my $splitter = new Wx::SplitterWindow($frame, 928, wxDefaultPosition, wxDefaultSize,
		wxSP_LIVE_UPDATE);
	$splitter->SetMinimumPaneSize(25);
	$vsizer->Add($splitter, 1, wxGROW);
	EVT_SPLITTER_DOUBLECLICKED($self, 928, sub { $_[1]->Skip; });

		my $console = $self->{console} = new Interface::Wx::Console($splitter);

		my $mapDock = $self->{mapDock} = new Interface::Wx::Dock($splitter, -1, 'Map');
		$mapDock->Show(0);
		$mapDock->setHideFunc($self, sub {
			$splitter->Unsplit($mapDock);
			$mapDock->Show(0);
		});
		$mapDock->setShowFunc($self, sub {
			$splitter->SplitVertically($console, $mapDock, -$mapDock->GetBestSize->GetWidth);
			$mapDock->Show(1);
		});

		my $mapView = $self->{mapViewer} = new Interface::Wx::MapViewer($mapDock);
		$mapDock->setParentFrame($frame);
		$mapDock->set($mapView);
		$mapView->onMouseMove(sub {
			# Mouse moved over the map viewer control
			my (undef, $x, $y) = @_;
			my $walkable;

			if ($Settings::CVS =~ /CVS/) {
				$walkable = checkFieldWalkable(\%field, $x, $y);
			} else {
				$walkable = !ord(substr($field{rawMap}, $y * $field{width} + $x, 1));
			}

			if ($x >= 0 && $y >= 0 && $walkable) {
				$self->{mouseMapText} = "Mouse over: $x, $y";
			} else {
				delete $self->{mouseMapText};
			}
			$self->{statusbar}->SetStatusText($self->{mouseMapText}, 0);
		});
		$mapView->onClick(sub {
			# Clicked on map viewer control
			my (undef, $x, $y) = @_;
			delete $self->{mouseMapText};
			$self->writeOutput("message", "Moving to $x, $y\n", "info");
			#AI::clear("mapRoute", "route", "move");
			main::aiRemove("mapRoute");
			main::aiRemove("route");
			main::aiRemove("move");
			main::ai_route($field{name}, $x, $y);
			$self->{inputBox}->SetFocus;
		});
		$mapView->onMapChange(sub {
			$mapDock->title($field{name});
			$mapDock->Fit;
		});
		if (%field && $char) {
			$mapView->set($field{name}, $char->{pos_to}{x}, $char->{pos_to}{y}, \%field);
		}

	$splitter->Initialize($console);

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
	if ($buildType == 0 && !($Settings::CVS =~ /CVS/)) {
		eval 'use Win32::Console; Win32::Console->new(STD_OUTPUT_HANDLE)->Free();';
	}
}

sub addMenu {
	my ($self, $menu, $label, $callback, $help) = @_;

	$self->{menuIDs}++;
	$menu->Append($self->{menuIDs}, $label, $help);
	EVT_MENU($self->{frame}, $self->{menuIDs}, sub { $callback->($self) });
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
				$_ = lc $_;
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


################## Callbacks ##################

sub onInputEnter {
	my $self = shift;
	$self->{input} = $self->{inputBox}->GetValue();
	$self->{console}->SetDefaultStyle($self->{console}{inputStyle});
	$self->{console}->AppendText("$self->{input}\n");
	$self->{console}->SetDefaultStyle($self->{console}{defaultStyle});
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
	$self->{console}->selectFont($self->{frame});
}

sub onMapToggle {
	my $self = shift;
	$self->{mapDock}->attach;
}

sub onManual {
	my $self = shift;
	launchURL('http://openkore.sourceforge.net/manual/');
}

sub onForum {
	my $self = shift;
	launchURL('http://openkore.sourceforge.net/forum.php');
}

1;
