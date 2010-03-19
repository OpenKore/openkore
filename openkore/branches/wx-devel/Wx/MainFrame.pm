#########################################################################
#  OpenKore - WxWidgets Interface
#  You need:
#  * WxPerl (the Perl bindings for WxWidgets) - http://wxperl.sourceforge.net/
#
#  More information about WxWidgets here: http://www.wxwidgets.org/
#
#  Copyright (c) 2004,2005,2006,2007 OpenKore development team
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
package Interface::Wx::MainFrame;
use strict;
use base 'Wx::Frame';

use Wx ':everything';
use Wx::AUI;
use Wx::Event ':everything';
use Time::HiRes qw(time sleep);
use File::Spec;
use FindBin qw($RealBin);


use Globals;
use Interface;
use base qw(Wx::App Interface);
use Modules;
use Field;
use I18N qw/bytesToString/;

use Interface::Wx::Window::Input;
use Interface::Wx::Window::Console;
use Interface::Wx::Window::ChatLog;
#use Interface::Wx::Dock;
#use Interface::Wx::MapViewer;
#use Interface::Wx::LogView;
use Interface::Wx::Console;
#use Interface::Wx::ItemList;
#use Interface::Wx::DockNotebook;
#use Interface::Wx::PasswordDialog;
use Interface::Wx::StatView::You;
use Interface::Wx::StatView::Exp;

use AI;
use Settings qw(%sys);
use Plugins;
use Misc;
use Commands;
use Utils;
use Translation qw/T TF/;

our ($iterationTime, $updateUITime, $updateUITime2);

sub new {
	my ($class, $parent, $id, $title, @args) = @_;
	
	my $self = $class->SUPER::new($parent, $id || wxID_ANY, $title || $Settings::NAME);
	
	$self->createStatusBar;
	
	#$self->SetSizeHints(300, 250);
	$self->SetClientSize(950, 680);
	if (-f (my $icon = "$RealBin/src/build/openkore.ico")) {
		$self->SetIcon(new Wx::Icon($icon, wxBITMAP_TYPE_ANY));
	}
	
	EVT_CLOSE($self, sub {
		my ($self, $event) = @_;
		quit();
		if ($event->CanVeto) {
			$self->Show(0);
		}
	});
	
	$self->{hooks} = Plugins::addHooks(
		['loadfiles',     \&onLoadFiles, $self],
		['postloadfiles', \&onLoadFiles, $self],
		['mainLoop_pre',  \&onUpdate, $self],
	);
	
	# initialize default windows
	
	($self->{aui} = new Wx::AuiManager)->SetManagedWindow($self);
	
	$self->{aui}->AddPane(
		$self->{notebook} = new Wx::AuiNotebook(
			$self, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxAUI_NB_DEFAULT_STYLE | wxAUI_NB_CLOSE_ON_ALL_TABS
		),
		Wx::AuiPaneInfo->new->CenterPane
	);
	
	$self->{notebook}->AddPage(new Interface::Wx::Window::Console($self), T('Console'), 1);
	
	$self->{notebook}->AddPage(new Interface::Wx::Window::ChatLog($self), T('Chat log'), 0);
	
	my $input = new Interface::Wx::Window::Input($self);
	$self->{aui}->AddPane($input,
		Wx::AuiPaneInfo->new->ToolbarPane->Bottom->BestSize($input->GetBestSize)->CloseButton(0)->Resizable->LeftDockable(0)->RightDockable(0)
	);
	
	$self->{aui}->AddPane(new Interface::Wx::StatView::You($self),
		Wx::AuiPaneInfo->new->Caption(T('Character'))->Right->BestSize(250, 250)
	);
	
	$self->{aui}->AddPane(new Interface::Wx::StatView::Exp($self),
		Wx::AuiPaneInfo->new->Caption(T('Experience report'))->Right->BestSize(250, 250)
	);
	
	$self->{aui}->Update;
	
	return $self;
}

sub DESTROY {
	my ($self) = @_;
	
	$self->{aui}->UnInit;
	
	Plugins::delHooks($self->{hooks});
}

sub onLoadFiles {
	my ($hook, $args, $self) = @_;
	if ($hook eq 'loadfiles') {
		$self->{loadingFiles}{percent} = $args->{current} / (1 + scalar @{$args->{files}});
		$self->{loadingFiles}{file} = $args->{files}[$args->{current} - 1]
	} else {
		delete $self->{loadingFiles};
	}
	
	$self->updateStatusBar;
}

sub onUpdate {
	my (undef, undef, $self) = @_;
	
	if (timeOut($updateUITime, 0.15)) {
		$self->updateStatusBar;
		#$self->updateMapViewer;
		$updateUITime = time;
	}
	if (timeOut($updateUITime2, 0.35)) {
		#$self->updateItemList;
		$updateUITime2 = time;
	}
}

sub createStatusBar {
	my ($self) = @_;
	
	$self->{statusBar} = $self->CreateStatusBar(3, wxST_SIZEGRIP | wxFULL_REPAINT_ON_RESIZE, wxID_ANY);
	$self->{statusBar}->SetStatusWidths(-1, 65, 175);
}

sub updateStatusBar {
	my $self = shift;

	my ($statText, $xyText, $aiText) = ('', '', '');

	if ($self->{loadingFiles}) {
		$statText = sprintf(T("Loading files... %.0f%% (%s)"), $self->{loadingFiles}{percent} * 100, $self->{loadingFiles}{file}{name});
	} elsif (!$conState) {
		$statText = T("Initializing...");
	} elsif ($conState == Network::NOT_CONNECTED) {
		$statText = T("Not connected");
	} elsif ($conState > Network::NOT_CONNECTED && $conState < Network::IN_GAME) {
		$statText = T("Connecting...");
	} elsif ($self->{mouseMapText}) {
		$statText = $self->{mouseMapText};
	}

	if ($conState == Network::IN_GAME) {
		$xyText = "$char->{pos_to}{x}, $char->{pos_to}{y}";

		if ($AI) {
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
		} else {
			$aiText = T("Paused");
		}
	}

	# Only set status bar text if it has changed
	my $i = 0;
	my $setStatus = sub {
		if (defined $_[1] && $self->{$_[0]} ne $_[1]) {
			$self->{$_[0]} = $_[1];
			$self->{statusBar}->SetStatusText($_[1], $i);
		}
		$i++;
	};

	$setStatus->('statText', $statText);
	$setStatus->('xyText', $xyText);
	$setStatus->('aiText', $aiText);
}

=pod
sub OnInit {
	my $self = shift;
	
	$self->createInterface;
	$self->iterate;
	
	my $onSlaveStatChange = sub { $self->onSlaveStatChange (@_); };
	my $onPetStatChange   = sub { $self->onPetStatChange (@_); };
	
	$self->{hooks} = Plugins::addHooks(
		['parseMsg/addPrivMsgUser',             sub { $self->onAddPrivMsgUser(@_); }],
		['initialized',                         sub { $self->onInitialized(@_); }],
		['captcha_file',                        sub { $self->onCaptcha(@_); }],
		['packet/minimap_indicator',            sub { $self->onMapIndicator (@_); }],
		
		# stat changes
		['packet/map_changed',                  sub { $self->onSlaveStatChange (@_); $self->onPetStatChange (@_); }],
		['packet/homunculus_info',              $onSlaveStatChange],
		['packet/mercenary_init',               $onSlaveStatChange],
		['packet/homunculus_property',          $onSlaveStatChange],
		['packet/mercenary_param_change',       $onSlaveStatChange],
		['packet/mercenary_off',                $onSlaveStatChange],
		['packet/message_string',               $onSlaveStatChange],
		['packet/pet_info',                     $onPetStatChange],
		['packet/pet_info2',                    $onPetStatChange],
		
		# npc
		['packet/npc_image',              sub { $self->onNpcImage (@_); }],
		['npc_talk',                      sub { $self->onNpcTalk (@_); }],
		['packet/npc_talk',               sub { $self->onNpcTalkPacket (@_); }],
		['packet/npc_talk_continue',      sub { $self->onNpcContinue (@_); }],
		['npc_talk_responses',            sub { $self->onNpcResponses (@_); }],
		['packet/npc_talk_number',        sub { $self->onNpcNumber (@_); }],
		['packet/npc_talk_text',          sub { $self->onNpcText (@_); }],
		['npc_talk_done',                 sub { $self->onNpcClose (@_); }],
	);
	
	$self->{history} = [];
	$self->{historyIndex} = -1;

	$self->{frame}->Update;
	
	Wx::Image::AddHandler (new Wx::XPMHandler);
	Wx::Image::AddHandler (new Wx::BMPHandler);
	Wx::Image::AddHandler (new Wx::PNGHandler);
	Wx::Image::AddHandler (new Wx::GIFHandler);
	Wx::Image::AddHandler (new Wx::JPEGHandler);
	Wx::Image::AddHandler (new Wx::ICOHandler);
	
	{
		my $icon = [$0 =~ m{^(.*?)((\w|\.)*)$}]->[0] . 'src/build/openkore.ico';
		$self->{frame}->SetIcon(new Wx::Icon($icon, wxBITMAP_TYPE_ANY)) if -f $icon;
	}
	
	return 1;
}

#########################
## INTERFACE CREATION
#########################


sub createInterface {
	my $self = shift;

	### Main window
	my $frame = $self->{frame} = new Wx::Frame(undef, wxID_ANY, $Settings::NAME);
	$self->{title} = $frame->GetTitle();


	### Menu bar
	$self->createMenuBar;

	### Vertical box sizer
	my $vsizer = $self->{vsizer} = new Wx::BoxSizer(wxVERTICAL);
	$frame->SetSizer($vsizer);

	### Horizontal panel with HP/SP/Exp box
	$self->createInfoPanel;


	## Splitter with console and another splitter
	my $splitter = new Wx::SplitterWindow($frame, 928, wxDefaultPosition, wxDefaultSize,
		wxSP_LIVE_UPDATE);
	$self->{splitter} = $splitter;
	$vsizer->Add($splitter, 1, wxGROW);
#	$splitter->SetMinimumPaneSize(50);
	$self->createSplitterContent;
}


sub createMenuBar {
	my $self = shift;
	my $menu = $self->{menu} = new Wx::MenuBar;
	my $frame = $self->{frame};
	$frame->SetMenuBar($menu);
	EVT_MENU_OPEN($self->{frame}, sub { $self->onMenuOpen; });

	# Program menu
	my $opMenu = new Wx::Menu;
	$self->{mPause}  = $self->addMenu($opMenu, T('&Pause Botting'), \&onDisableAI, T('Pause all automated botting activity'));
	$self->{mManual} = $self->addMenu($opMenu, T('&Manual Botting'), \&onManualAI, T('Pause automated botting and allow manual control'));
	$self->{mResume} = $self->addMenu($opMenu, T('&Automatic Botting'), \&onEnableAI, T('Resume all automated botting activity'));
	$opMenu->AppendSeparator;
	$self->addMenu($opMenu, T('Copy Last 100 Lines of Text'), \&onCopyLastOutput);
	$self->addMenu($opMenu, T('Minimize to &Tray'), \&onMinimizeToTray, T('Minimize to a small task bar tray icon'));
	$opMenu->AppendSeparator;
	$self->addMenu($opMenu, T('Respawn'), sub { Commands::run ("respawn") }, T('Teleport to save point'));
	$self->addMenu($opMenu, T('&Relog'), sub { Commands::run ("relog") }, T('Disconnect and reconnect'));
	$self->addMenu($opMenu, T('&Character Select'), sub {
		configModify ('char', undef, 1);
		Commands::run ("charselect");
	}, T('Exit to the character selection screen'));
	$self->addMenu($opMenu, T('E&xit') . "\tCtrl-W", \&quit, T('Exit this program'));
	$menu->Append($opMenu, T('P&rogram'));

	# Info menu
	my $infoMenu = new Wx::Menu;
	$self->addMenu($infoMenu, '&Status	Alt-S',	sub { Commands::run("s"); });
	$self->addMenu($infoMenu, 'S&tatistics',	sub { Commands::run("st"); });
	$self->addMenu($infoMenu, '&Inventory	Alt-I',	sub { Commands::run("i"); });
	$self->addMenu($infoMenu, 'S&kills',		sub { Commands::run("skills"); });
	$infoMenu->AppendSeparator;
	$self->addMenu($infoMenu, '&Players	Alt-P',	sub { Commands::run("pl"); });
	$self->addMenu($infoMenu, '&Monsters	Alt-M',	sub { Commands::run("ml"); });
	$self->addMenu($infoMenu, '&NPCs',		sub { Commands::run("nl"); });
	$infoMenu->AppendSeparator;
	$self->addMenu($infoMenu, '&Experience Report',	sub { Commands::run("exp"); });
	$menu->Append($infoMenu, T('I&nfo'));

	# View menu
	my $viewMenu = $self->{viewMenu} = new Wx::Menu;
	$self->addMenu (
		$viewMenu, T('&Map') . "\tCtrl-M", \&onMapToggle, T('Show where you are on the current map')
	);
	$self->{infoBarToggle} = $self->addCheckMenu (
		$viewMenu, T('&Info Bar'), \&onInfoBarToggle, T('Show or hide the information bar.')
	);
	$self->{chatLogToggle} = $self->addCheckMenu (
		$viewMenu, T('Chat &Log'), \&onChatLogToggle, T('Show or hide the chat log.')
	);
	$self->addMenu ($viewMenu, T('Status') . "\tAlt+A", sub { $self->openStats (1) });
	$self->addMenu ($viewMenu, T('Homunculus') . "\tAlt+R", sub { $self->openHomunculus (1) });
	$self->addMenu ($viewMenu, T('Mercenary') . "\tCtrl+R", sub { $self->openMercenary (1) });
	$self->addMenu ($viewMenu, T('Pet') . "\tAlt+J", sub { $self->openPet (1) });
	
	$viewMenu->AppendSeparator;
	
	$self->addMenu ($viewMenu, T('Inventory') . "\tAlt+E", sub { $self->openInventory (1) });
	$self->addMenu ($viewMenu, T('Cart') . "\tAlt+W", sub { $self->openCart (1) });
	$self->addMenu ($viewMenu, T('Storage'), sub { $self->openStorage (1) });
	
	$viewMenu->AppendSeparator;
	
	$self->addMenu ($viewMenu, T('Emotions'). "\tAlt+L", sub { $self->openEmotions (1) });
	
	$viewMenu->AppendSeparator;
	
	$self->addMenu($viewMenu, T('&Experience Report') . "\tCtrl+E", sub {
		$self->openWindow ('Report', 'Interface::Wx::StatView::Exp', 1) 
	});
	
	$viewMenu->AppendSeparator;
	
	$self->addMenu ($viewMenu, T('&Font...'), \&onFontChange, T('Change console font'));
	$self->addMenu($viewMenu, T('Clear Console'), sub {my $self = shift; $self->{console}->Remove(0, 40000)}, T('Clear content of console'));
	
	$menu->Append($viewMenu, T('&View'));
	
	$self->{aliasMenu} = new Wx::Menu;
	$menu->Append ($self->{aliasMenu}, T('&Alias'));
	
	# Settings menu
	my $settingsMenu = new Wx::Menu;
	$self->createSettingsMenu($settingsMenu) if ($self->can('createSettingsMenu'));
	$self->addMenu($settingsMenu, T('&Advanced...'), \&onAdvancedConfig, T('Edit advanced configuration options.'));
	$menu->Append($settingsMenu, T('&Settings'));
	$self->createSettingsMenu2($settingsMenu) if ($self->can('createSettingsMenu2'));
	
	# Help menu
	my $helpMenu = new Wx::Menu();
	$self->addMenu($helpMenu, T('&Manual') . "\tF1", \&onManual, T('Read the manual'));
	$self->addMenu($helpMenu, T('&Forum') . "\tShift-F1", \&onForum, T('Visit the forum'));
	$self->createHelpMenu($helpMenu) if ($self->can('createHelpMenu'));
	$menu->Append($helpMenu, T('&Help'));
}

sub createSettingsMenu {
	my ($self, $parentMenu) = @_;
	
# 	foreach my $menuData (@{$data}) {
# 		my $subMenu = new Wx::Menu;
# 		
# 		foreach my $itemData (@{$menuData->{items}}) {
# 			if ($itemData->{type} eq 'boolean') {
# 				$self->{mBooleanSetting}{$itemData->{key}} = $self->addCheckMenu (
# 					$subMenu, $itemData->{title} || $itemData->{key}, sub { $self->onBooleanSetting ($itemData->{key}); },
# 					"$itemData->{help} [$itemData->{key}]"
# 				);
# 			} elsif ($itemData->{type} eq 'separator') {
# 				$subMenu->AppendSeparator;
# 			}
# 		}
# 		
# 		$self->addSubMenu ($parentMenu, $menuData->{title}, $subMenu, $menuData->{help});
# 	}
	
	$self->{mBooleanSetting}{'wx_npcTalk'} = $self->addCheckMenu (
		$parentMenu, T('Use Wx NPC Talk'), sub { $self->onBooleanSetting ('wx_npcTalk'); },
		T('Open a dialog when talking with NPCs')
	);
	
	$self->{mBooleanSetting}{'wx_captcha'} = $self->addCheckMenu (
		$parentMenu, T('Use Wx captcha'), sub { $self->onBooleanSetting ('wx_captcha'); },
		T('Open a dialog when receiving a captcha')
	);
	
	$self->{mBooleanSetting}{'wx_map_route'} = $self->addCheckMenu (
		$parentMenu, T('Show route on map'), sub { $self->onBooleanSetting ('wx_map_route'); },
		T('Show route solution steps')
	);
	
	$parentMenu->AppendSeparator;
}

sub createInfoPanel {
	my $self = shift;
	my $frame = $self->{frame};
	my $vsizer = $self->{vsizer};
	my $infoPanel = $self->{infoPanel} = new Wx::Panel($frame, wxID_ANY);

	my $hsizer = new Wx::BoxSizer(wxHORIZONTAL);
	my $label = new Wx::StaticText($infoPanel, wxID_ANY, "HP: ");
	$hsizer->Add($label, 0, wxLEFT, 3);


	## HP
	my $hpBar = $self->{hpBar} = new Wx::Gauge($infoPanel, wxID_ANY, 100,
		wxDefaultPosition, [0, $label->GetBestSize->GetHeight + 2],
		wxGA_HORIZONTAL | wxGA_SMOOTH);
	$hsizer->Add($hpBar, 1, wxRIGHT, 8);

	$label = new Wx::StaticText($infoPanel, wxID_ANY, "SP: ");
	$hsizer->Add($label, 0);

	## SP
	my $spBar = $self->{spBar} = new Wx::Gauge($infoPanel, wxID_ANY, 100,
		wxDefaultPosition, [0, $label->GetBestSize->GetHeight + 2],
		wxGA_HORIZONTAL | wxGA_SMOOTH);
	$hsizer->Add($spBar, 1, wxRIGHT, 8);

	$label = new Wx::StaticText($infoPanel, wxID_ANY, "Exp: ");
	$hsizer->Add($label, 0);

	## Exp and job exp
	my $expBar = $self->{expBar} = new Wx::Gauge($infoPanel, wxID_ANY, 100,
		wxDefaultPosition, [0, $label->GetBestSize->GetHeight + 2],
		wxGA_HORIZONTAL | wxGA_SMOOTH);
	$hsizer->Add($expBar, 1);
	my $jobExpBar = $self->{jobExpBar} = new Wx::Gauge($infoPanel, wxID_ANY, 100,
		wxDefaultPosition, [0, $label->GetBestSize->GetHeight + 2],
		wxGA_HORIZONTAL | wxGA_SMOOTH);
	$hsizer->Add($jobExpBar, 1, wxRIGHT, 8);

	$label = new Wx::StaticText($infoPanel, wxID_ANY, "Weight: ");
	$hsizer->Add($label, 0);

	## Weight
	my $weightBar = $self->{weightBar} = new Wx::Gauge($infoPanel, wxID_ANY, 100,
		wxDefaultPosition, [0, $label->GetBestSize->GetHeight + 2],
		wxGA_HORIZONTAL | wxGA_SMOOTH);
	$hsizer->Add($weightBar, 1);


	$infoPanel->SetSizerAndFit($hsizer);
	$vsizer->Add($infoPanel, 0, wxGROW);
}

sub createSplitterContent {
	my $self = shift;
	my $splitter = $self->{splitter};
	my $frame = $self->{frame};

	## Parallel to the notebook is another sub-splitter
	my $subSplitter = new Wx::SplitterWindow($splitter, 583,
		wxDefaultPosition, wxDefaultSize, wxSP_LIVE_UPDATE);

	## Inside this splitter is a player/monster/item list, and a dock with map viewer

	my $itemList = $self->{itemList} = new Interface::Wx::ItemList($subSplitter);
	$itemList->onActivate(\&onItemListActivate, $self);
	$self->customizeItemList($itemList) if ($self->can('customizeItemList'));
	$subSplitter->Initialize($itemList);


	# Dock
	my $mapDock = $self->{mapDock} = new Interface::Wx::Dock($subSplitter, wxID_ANY, 'Map');
	$mapDock->Show(0);
	$mapDock->setHideFunc($self, sub {
		$subSplitter->Unsplit($mapDock);
		$mapDock->Show(0);
		$self->{inputBox}->SetFocus;
	});
	$mapDock->setShowFunc($self, sub {
		$subSplitter->SplitVertically($itemList, $mapDock, -$mapDock->GetBestSize->GetWidth);
		$mapDock->Show(1);
		$self->{inputBox}->SetFocus;
	});

	# Map viewer
	my $mapView = $self->{mapViewer} = new Interface::Wx::MapViewer($mapDock);
	$mapDock->setParentFrame($frame);
	$mapDock->set($mapView);
# vcl code 	$mapView->onMouseMove($self, \&onMapMouseMove);
# vcl code 	$mapView->onClick->add($self, \&onMapClick);
# vcl code 	$mapView->onMapChange($self, \&onMap_MapChange, $mapDock);
	$mapView->onMouseMove(\&onMapMouseMove, $self);
	$mapView->onClick(\&onMapClick, $self);
	$mapView->onMapChange(\&onMap_MapChange, $mapDock);
	$mapView->parsePortals(Settings::getTableFilename("portals.txt"));
	if ($field && $char) {
		$mapView->set($field->name(), $char->{pos_to}{x}, $char->{pos_to}{y}, $field);
	}

	my $position;
	if (Wx::wxMSW()) {
		$position = 600;
	} else {
		$position = 545;
	}
	$splitter->SplitVertically($notebook, $subSplitter, $position);
}


sub addMenu {
	my ($self, $menu, $label, $callback, $help) = @_;

	$self->{menuIDs}++;
	my $item = new Wx::MenuItem(undef, $self->{menuIDs}, $label, $help);
	$menu->Append($item);
	EVT_MENU($self->{frame}, $self->{menuIDs}, sub { $callback->($self); });
	return $item;
}

sub addSubMenu {
	my ($self, $menu, $label, $subMenu, $help) = @_;

	$self->{menuIDs}++;
	my $item = new Wx::MenuItem(undef, $self->{menuIDs}, $label, $help, wxITEM_NORMAL, $subMenu);
	$menu->Append($item);
	return $item;
}

sub addCheckMenu {
	my ($self, $menu, $label, $callback, $help) = @_;

	$self->{menuIDs}++;
	my $item = new Wx::MenuItem(undef, $self->{menuIDs}, $label, $help, wxITEM_CHECK);
	$menu->Append($item);
	EVT_MENU($self->{frame}, $self->{menuIDs}, sub { $callback->($self); }) if ($callback);
	return $item;
}


##########################
## INTERFACE UPDATING
##########################


sub updateStatusBar {
	my $self = shift;

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

		if ($AI) {
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
		} else {
			$aiText = "Paused";
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
}

sub updateMapViewer {
	my $self = shift;
	my $map = $self->{mapViewer};
	return unless ($map && $field && $char);

	my $myPos;
	$myPos = calcPosition($char);

	$map->set($field->name(), $myPos->{x}, $myPos->{y}, $field, $char->{look});
	
	my ($i, $args, $routeTask, $solution);
	if (
		defined ($i = AI::findAction ('route')) && ($args = AI::args ($i)) && (
			($routeTask = $args->getSubtask) && %{$routeTask} && ($solution = $routeTask->{solution}) && @$solution
			||
			$args->{dest} && $args->{dest}{pos} && ($solution = [{x => $args->{dest}{pos}{x}, y => $args->{dest}{pos}{y}}])
		)
	) {
		$map->setRoute ([@$solution]);
	} else {
		$map->setRoute;
	}
	
	$map->setPlayers ([values %players]);
	$map->setParty ([values %{$char->{party}{users}}]) if $char->{party} && $char->{party}{users};
	$map->setMonsters ([values %monsters]);
	$map->setNPCs ([values %npcs]);
	$map->setSlaves ([values %slaves]);
	
	$map->update;
	$self->{mapViewTimeout}{time} = time;
}

sub updateItemList {
	my $self = shift;
	my $value;
	
	if ($conState == 5) {
		if ($char->{hp_max}) {
			$value = $char->{hp} / $char->{hp_max} * 100;
			$self->{hpBar}->SetValue ($value);
			$self->{hpBar}->SetToolTip (sprintf '%s / %s (%.2f%)', formatNumber ($char->{hp}), formatNumber ($char->{hp_max}), $value);
			$self->{hpBar}->SetForegroundColour (new Wx::Colour ((100 - $value) * 2.55, $value * 1.27, 50));
		}
		if ($char->{sp_max}) {
			$value = $char->{sp} / $char->{sp_max} * 100;
			$self->{spBar}->SetValue ($value);
			$self->{spBar}->SetToolTip (sprintf '%s / %s (%.2f%)', formatNumber ($char->{sp}), formatNumber ($char->{sp_max}), $value);
			$self->{spBar}->SetForegroundColour (new Wx::Colour ((100 - $value) * 2.55, $value * 1.27, 50));
		}
		if ($char->{exp_max}) {
			$value = $char->{exp} / $char->{exp_max} * 100;
			$self->{expBar}->SetValue ($value);
			$self->{expBar}->SetToolTip (sprintf '%s / %s (%.2f%)', formatNumber ($char->{exp}), formatNumber ($char->{exp_max}), $value);
		}
		if ($char->{exp_job_max}) {
			$value = $char->{exp_job} / $char->{exp_job_max} * 100;
			$self->{jobExpBar}->SetValue ($value);
			$self->{jobExpBar}->SetToolTip (sprintf '%s / %s (%.2f%)', formatNumber ($char->{exp_job}), formatNumber ($char->{exp_job_max}), $value);
		}
		if ($char->{weight_max}) {
			$value = $char->{weight} / $char->{weight_max} * 100;
			$self->{weightBar}->SetValue ($value);
			$self->{weightBar}->SetToolTip (sprintf '%s / %s (%.2f%)', formatNumber ($char->{weight}), formatNumber ($char->{weight_max}), $value);
			if (whenStatusActive ('Owg 90%')) {
				$self->{weightBar}->SetForegroundColour (new Wx::Colour (255, 0, 50));
			} elsif (whenStatusActive ('Owg 50%')) {
				$self->{weightBar}->SetForegroundColour (new Wx::Colour (127, 63, 50));
			} else {
				$self->{weightBar}->SetForegroundColour (new Wx::Colour (0, 127, 50));
			}
		}
	}
}


##################
## Callbacks
##################

sub onMenuOpen {
	my $self = shift;
	$self->{mPause}->Enable($AI);
	$self->{mManual}->Enable($AI != 1);
	$self->{mResume}->Enable($AI != 2);
	$self->{infoBarToggle}->Check($self->{infoPanel}->IsShown);
	$self->{chatLogToggle}->Check(defined $self->{notebook}->hasPage('Chat Log') ? 1 : 0);
	
	while (my ($setting, $menu) = each (%{$self->{mBooleanSetting}})) {
		$menu->Check ($config{$setting} ? 1 : 0);
	}
	
	my $menu;
	while ($menu = $self->{aliasMenu}->FindItemByPosition (0)) {
		$self->{aliasMenu}->Delete ($menu);
	}
	
	for $menu (sort map {/^alias_(.+)$/} keys %config) {
		$self->addMenu ($self->{aliasMenu}, $menu, sub { Commands::run ($menu) });
	}
}

sub onEnableAI {
	$AI = 2;
}

sub onManualAI {
	$AI = 1;
}

sub onDisableAI {
	$AI = 0;
}

sub onCopyLastOutput {
	my ($self) = @_;
	$self->{console}->copyLastLines(100);
}

sub onMinimizeToTray {
	my $self = shift;
	my $tray = new Wx::TaskBarIcon;
	my $title = ($char) ? "$char->{name} - $Settings::NAME" : "$Settings::NAME";
	$tray->SetIcon($self->{frame}->GetIcon, $title);
	EVT_TASKBAR_LEFT_DOWN($tray, sub {
		$tray->RemoveIcon;
		undef $tray;
		$self->{frame}->Show(1);
	});
	$self->{frame}->Show(0);
}

sub onClose {
	my ($self, $event) = @_;
	quit();
	if ($event->CanVeto) {
		$self->Show(0);
	}
}

sub onFontChange {
	my $self = shift;
	$self->{console}->selectFont($self->{frame});
}

sub onBooleanSetting {
	my ($self, $setting) = @_;
	
	configModify ($setting, !$config{$setting}, 1);
}

sub onAdvancedConfig {
	my $self = shift;
	if ($self->{notebook}->hasPage('Advanced Configuration')) {
		$self->{notebook}->switchPage('Advanced Configuration');
		return;
	}

	my $page = $self->{notebook}->newPage(1, 'Advanced Configuration');
	my $panel = new Wx::Panel($page, wxID_ANY);

	my $vsizer = new Wx::BoxSizer(wxVERTICAL);
	$panel->SetSizer($vsizer);

	require Interface::Wx::ConfigEditor;
	my $cfg = new Interface::Wx::ConfigEditor($panel, wxID_ANY);
	$cfg->setConfig(\%config);
	$cfg->addCategory('All', 'Grid');
	$cfg->addCategory('server', 'Grid', ['master', 'server', 'username', 'password', 'char', 'serverType']);
	$cfg->addCategory('X-Kore', 'Grid', ['XKore', 'XKore_silent', 'XKore_bypassBotDetection', 'XKore_exeName', 'XKore_listenIp', 'XKore_listenPort', 'XKore_publicIp', 'secureAdminPassword', 'adminPassword', 'callSign', 'commandPrefix']);
	$cfg->addCategory('lockMap', 'Grid', ['lockMap', 'lockMap_x', 'lockMap_y', 'lockMap_randX', 'lockMap_randY']);
	$cfg->addCategory('attack', 'Grid', ['attackAuto', 'attackAuto_party', 'attackAuto_onlyWhenSafe', 'attackAuto_followTarget', 'attackAuto_inLockOnly', 'attackDistance', 'attackDistanceAuto', 'attackMaxDistance', 'attackMaxRouteDistance', 'attackMaxRouteTime', 'attackMinPlayerDistance', 'attackMinPortalDistance', 'attackUseWeapon', 'attackNoGiveup', 'attackCanSnipe', 'attackCheckLOS', 'attackLooters', 'attackChangeTarget', 'aggressiveAntiKS']);
	$cfg->addCategory('route', 'Grid', ['route_escape_reachedNoPortal', 'route_escape_randomWalk', 'route_escape_shout', 'route_randomWalk', 'route_randomWalk_inTown', 'route_randomWalk_maxRouteTime', 'route_maxWarpFee', 'route_maxNpcTries', 'route_teleport', 'route_teleport_minDistance', 'route_teleport_maxTries', 'route_teleport_notInMaps', 'route_step']);
	$cfg->addCategory('teleport', 'Grid', ['teleportAuto_hp', 'teleportAuto_sp', 'teleportAuto_idle', 'teleportAuto_portal', 'teleportAuto_search', 'teleportAuto_minAggressives', 'teleportAuto_minAggressivesInLock', 'teleportAuto_onlyWhenSafe', 'teleportAuto_maxDmg', 'teleportAuto_maxDmgInLock', 'teleportAuto_deadly', 'teleportAuto_useSkill', 'teleportAuto_useChatCommand', 'teleportAuto_allPlayers', 'teleportAuto_atkCount', 'teleportAuto_atkMiss', 'teleportAuto_unstuck', 'teleportAuto_dropTarget', 'teleportAuto_dropTargetKS', 'teleportAuto_attackedWhenSitting', 'teleportAuto_totalDmg', 'teleportAuto_totalDmgInLock', 'teleportAuto_equip_leftAccessory', 'teleportAuto_equip_rightAccessory', 'teleportAuto_lostHomunculus']);
	$cfg->addCategory('follow', 'Grid', ['follow', 'followTarget', 'followEmotion', 'followEmotion_distance', 'followFaceDirection', 'followDistanceMax', 'followDistanceMin', 'followLostStep', 'followSitAuto', 'followBot']);
	$cfg->addCategory('items', 'Grid', ['itemsTakeAuto', 'itemsTakeAuto_party', 'itemsGatherAuto', 'itemsMaxWeight', 'itemsMaxWeight_sellOrStore', 'itemsMaxNum_sellOrStore', 'cartMaxWeight']);
	$cfg->addCategory('sellAuto', 'Grid', ['sellAuto', 'sellAuto_npc', 'sellAuto_standpoint', 'sellAuto_distance']);
	$cfg->addCategory('storageAuto', 'Grid', ['storageAuto', 'storageAuto_npc', 'storageAuto_distance', 'storageAuto_npc_type', 'storageAuto_npc_steps', 'storageAuto_password', 'storageAuto_keepOpen', 'storageAuto_useChatCommand', 'relogAfterStorage']);
	$cfg->addCategory('disconnect', 'Grid', ['dcOnDeath', 'dcOnDualLogin', 'dcOnDisconnect', 'dcOnEmptyArrow', 'dcOnMute', 'dcOnPM', 'dcOnZeny', 'dcOnStorageFull', 'dcOnPlayer']);

	$cfg->onChange(sub {
		my ($key, $value) = @_;
		configModify($key, $value) if ($value ne $config{$key});
	});
	$vsizer->Add($cfg, 1, wxGROW | wxALL, 8);


	my $sizer = new Wx::BoxSizer(wxHORIZONTAL);
	$vsizer->Add($sizer, 0, wxGROW | wxLEFT | wxRIGHT | wxBOTTOM, 8);

	my $revert = new Wx::Button($panel, 46, '&Revert');
	$revert->SetToolTip('Revert settings to before you opened the selected category');
	$sizer->Add($revert, 0);
	EVT_BUTTON($revert, 46, sub {
		$cfg->revert;
	});
	$revert->Enable(0);
	$cfg->onRevertEnable(sub {
		$revert->Enable($_[0]);
	});

	my $pad = new Wx::Window($panel, wxID_ANY);
	$sizer->Add($pad, 1);

	my $close = new Wx::Button($panel, 47, '&Close');
	$close->SetToolTip('Close this panel/dialog');
	$close->SetDefault;
	$sizer->Add($close, 0);
	EVT_BUTTON($close, 47, sub {
		$self->{notebook}->closePage('Advanced Configuration');
	});

	$page->set($panel);
}

sub onMapToggle {
	my $self = shift;
	$self->{mapDock}->attach;
}

sub onInfoBarToggle {
	my $self = shift;
	$self->{vsizer}->Show($self->{infoPanel}, $self->{infoBarToggle}->IsChecked);
	$self->{frame}->Layout;
}

sub onChatLogToggle {
	my $self = shift;
	if (!$self->{chatLogToggle}->IsChecked) {
		$self->{notebook}->closePage('Chat Log');

	} elsif (!$self->{notebook}->hasPage('Chat Log')) {
		my $page = $self->{notebook}->newPage(1, 'Chat Log', 0);
		my $chatLog = $self->{chatLog} = new Interface::Wx::LogView($page);
		$page->set($chatLog);
		$chatLog->addColor("selfchat", 0, 148, 0);
		$chatLog->addColor("pm", 142, 120, 0);
		$chatLog->addColor("p", 164, 0, 143);
		$chatLog->addColor("g", 0, 177, 108);
		$chatLog->addColor("warning", 214, 93, 0);
		$page->set($chatLog);

	} else {
		$self->{notebook}->switchPage('Chat Log');
	}
}

sub openWindow {
	my ($self, $title, $class, $create) = @_;
	my ($page, $window);
	
	if ($page = $self->{notebook}->hasPage ($title)) {
		$window = $page->{child};
	} elsif ($create) {
		eval "require $class";
		if ($@) {
			Log::warning "Unable to load $class\n$@", 'interface';
			return;
		}
		unless ($class->can ('new')) {
			Log::warning "Unable to create instance of $class\n", 'interface';
			return;
		}
		$page = $self->{notebook}->newPage (1, $title, 0);
		$page->set ($window = $class->new ($page, wxID_ANY));
		
		$window->init if $conState == Network::IN_GAME && $window->can ('init');
	}
	
	$self->{notebook}->switchPage ($title) if $page && $create;
	
	return ($page, $window);
}

sub openStats {
	my ($self, $create) = @_;
	my ($page, $window) = $self->openWindow ('Status', 'Interface::Wx::StatView::You', $create);
	
	return ($page, $window);
}

sub openHomunculus {
	my ($self, $create) = @_;
	my ($page, $window) = $self->openWindow ('Homunculus', 'Interface::Wx::StatView::Homunculus', $create);
	
	return ($page, $window);
}

sub openMercenary {
	my ($self, $create) = @_;
	my ($page, $window) = $self->openWindow ('Mercenary', 'Interface::Wx::StatView::Mercenary', $create);
	
	return ($page, $window);
}

sub openPet {
	my ($self, $create) = @_;
	my ($page, $window) = $self->openWindow ('Pet', 'Interface::Wx::StatView::Pet', $create);
	
	return ($page, $window);
}

sub openInventory {
	my ($self, $create) = @_;
	my ($page, $window) = $self->openWindow ('Inventory', 'Interface::Wx::List::ItemList::Inventory', $create);
	
	return ($page, $window);
}

sub openCart {
	my ($self, $create) = @_;
	my ($page, $window) = $self->openWindow ('Cart', 'Interface::Wx::List::ItemList::Cart', $create);
	
	return ($page, $window);
}

sub openStorage {
	my ($self, $create) = @_;
	my ($page, $window) = $self->openWindow ('Storage', 'Interface::Wx::List::ItemList::Storage', $create);
	
	return ($page, $window);
}

sub openEmotions {
	my ($self, $create) = @_;
	my ($page, $window) = $self->openWindow ('Emotions', 'Interface::Wx::EmotionList', $create);
	
	if ($window) {
		$window->onEmotion (sub {
			Commands::run ('e ' . shift);
			$self->{inputBox}->SetFocus;
		});
		$window->setEmotions (\%emotions_lut);
	}
	
	return ($page, $window);
}

sub openNpcTalk {
	my ($self, $create) = @_;
	return unless $config{wx_npcTalk};
	my ($page, $window) = $self->openWindow ('NPC Talk', 'Interface::Wx::NpcTalk', $create);
	
	if ($window) {
		$window->onContinue  (sub { Commands::run ('talk cont'); });
		$window->onResponses (sub { Commands::run ('talk resp ' . shift); });
		$window->onNumber    (sub { Commands::run ('talk num ' . shift); });
		$window->onText      (sub { Commands::run ('talk text ' . shift); });
		$window->onCancel    (sub { Commands::run ('talk no'); });
	}
	
	return ($page, $window);
}

sub onManual {
	my $self = shift;
	launchURL('http://wiki.openkore.com/index.php?title=Manual');
}

sub onForum {
	my $self = shift;
	launchURL('http://forums.openkore.com/');
}

sub onItemListActivate {
	my ($self, $actor) = @_;

	if ($actor->isa('Actor::Player')) {
		Commands::run("lookp " . $actor->{binID});
		Commands::run("pl " . $actor->{binID});

	} elsif ($actor->isa('Actor::Monster')) {
		main::attack($actor->{ID});

	} elsif ($actor->isa('Actor::Item')) {
		$self->{console}->add("message", "Taking item " . $actor->nameIdx . "\n", "info");
		main::take($actor->{ID});

	} elsif ($actor->isa('Actor::NPC')) {
		Commands::run("talk " . $actor->{binID});
	}

	$self->{inputBox}->SetFocus;
}

sub onInitialized {
	my ($self) = @_;
	$self->{itemList}->init($npcsList, new Wx::Colour(103, 0, 162),
			$slavesList, new Wx::Colour(200, 100, 0),
			$playersList, undef,
			$monstersList, new Wx::Colour(200, 0, 0),
			$itemsList, new Wx::Colour(0, 0, 200));
}

sub onAddPrivMsgUser {
	my $self = shift;
	my $param = $_[1];
	$self->{targetBox}->Append($param->{user});
}

sub onMapMouseMove {
	# Mouse moved over the map viewer control
#vcl code	my ($self, undef, $args) = @_;
#vcl code	my ($x, $y) = @{$args};
	my ($self, $x, $y) = @_;
	my $walkable;

	$walkable = $field->isWalkable($x, $y);
	if ($x >= 0 && $y >= 0 && $walkable) {
		$self->{mouseMapText} = "Mouse over: $x, $y";
	} else {
		delete $self->{mouseMapText};
	}
	$self->{statusbar}->SetStatusText($self->{mouseMapText}, 0);
}

sub onMapClick {
	# Clicked on map viewer control
#vcl code	my ($self, undef, $args) = @_;
#vcl code	my ($x, $y) = @{$args};
	my ($self, $x, $y) = @_;
	my $checkPortal = 0;
	my $noMove = 0;
	delete $self->{mouseMapText};
	if ($self->{mapViewer} && $self->{mapViewer}->{portals}
		&& $self->{mapViewer}->{portals}->{$field->name()}
		&& @{$self->{mapViewer}->{portals}->{$field->name()}}){

		foreach my $portal (@{$self->{mapViewer}->{portals}->{$field->name()}}){
			if (distance($portal,{x=>$x,y=>$y}) <= ($config{wx_map_portalSticking} || 5)) {
				$x = $portal->{x};
				$y = $portal->{y};
				$self->writeOutput("message", "Moving to Portal $x, $y\n", "info");
				$checkPortal = 1;
				last;
			}
		}
		
		foreach my $monster (@{$self->{mapViewer}->{monsters}}){
			if (distance($monster->{pos},{x=>$x,y=>$y}) <= ($config{wx_map_monsterSticking} || 1)) {
				main::attack($monster->{ID});
				$noMove = 1;
				last;
			}
		}
		
		foreach my $npc (@{$self->{mapViewer}->{npcs}}){
			if (distance($npc->{pos},{x=>$x,y=>$y}) <= ($config{wx_map_npcSticking} || 1)) {
				Commands::run("talk " . $npc->{binID});
				$noMove = 1;
				last;
			}
		}
	}
	
	unless ($noMove) {
		$self->writeOutput("message", "Moving to $x, $y\n", "info") unless $checkPortal;
		AI::clear("mapRoute", "route", "move");
		main::ai_route($field->name(), $x, $y, attackOnRoute => 1);
	}
	$self->{inputBox}->SetFocus;
}

sub onMap_MapChange {
#vcl code	my (undef, undef, undef, $mapDock) = @_;
	my ($mapDock) = @_;
	$mapDock->title($field->name());
	$mapDock->Fit;
}

### Captcha ###

sub onCaptcha {
	my ($self, undef, $args) = @_;
	
	return unless $config{wx_captcha};
	
	require Interface::Wx::CaptchaDialog;
	my $dialog = new Interface::Wx::CaptchaDialog ($self->{frame}, $args->{file});
	my $result;
	if ($dialog->ShowModal == wxID_OK) {
		$result = $dialog->GetValue;
	}
	$dialog->Destroy;
	return unless defined $result && $result ne '';
	
	$messageSender->sendCaptchaAnswer ($result);
	
	$args->{return} = 1;
}

### Map ###

sub onMapIndicator {
	my ($self, undef, $args) = @_;
	
	if ($self->{mapViewer}) {
		$self->{mapViewer}->mapIndicator ($args->{type} != 2, $args->{x}, $args->{y}, $args->{red}, $args->{green}, $args->{blue}, $args->{alpha});
	}
}

### Stat View ###

sub onSelfStatChange {
	my ($self, $hook, $args) = @_;
	
	return if $hook eq 'changed_status' && $args->{actor}{ID} ne $accountID;
	
	my (undef, $window) = $self->openStats;
	$window->update if $window;
}

sub onSlaveStatChange {
	my ($self, $hook, $args) = @_;
	my $window;
	
	(undef, $window) = $self->openHomunculus;
	$window->update if $window;
	
	(undef, $window) = $self->openMercenary;
	$window->update if $window;
}

sub onPetStatChange {
	my ($self, $hook, $args) = @_;
	
	my (undef, $window) = $self->openPet;
	$window->update if $window;
}

### NPC Talk ###

sub onNpcImage {
	my ($self, undef, $args) = @_;
	
	if (my ($npcTalk) = $self->openNpcTalk (1)) {
		$npcTalk->{child}->npcImage ($args->{type} == 2, bytesToString ($args->{npc_image}));
	}
}

sub onNpcTalk {
	my ($self, undef, $args) = @_;
	
	if (my ($npcTalk) = $self->openNpcTalk (1)) {
		$npcTalk->{child}->npcName ($args->{ID}, $args->{name});
	}
}

sub onNpcTalkPacket {
	my ($self, undef, $args) = @_;
	
	if (my ($npcTalk) = $self->openNpcTalk (1)) {
		$npcTalk->{child}->npcTalk (bytesToString ($args->{msg}));
	}
}

sub onNpcContinue {
	my ($self, undef, $args) = @_;
	
	if (my ($npcTalk) = $self->openNpcTalk (1)) {
		$npcTalk->{child}->npcContinue unless $config{autoTalkCont};
	}
}

sub onNpcResponses {
	my ($self, undef, $args) = @_;
	
	if (my ($npcTalk) = $self->openNpcTalk (1)) {
		$npcTalk->{child}->npcResponses ($args->{responses});
	}
}

sub onNpcNumber {
	my ($self) = @_;
	
	if (my ($npcTalk) = $self->openNpcTalk (1)) {
		$npcTalk->{child}->npcNumber;
	}
}

sub onNpcText {
	my ($self) = @_;
	
	if (my ($npcTalk) = $self->openNpcTalk (1)) {
		$npcTalk->{child}->npcText;
	}
}

sub onNpcClose {
	my ($self) = @_;
	
	if (my ($npcTalk) = $self->openNpcTalk (1)) {
		$npcTalk->{child}->npcClose;
	}
}
=cut
1;
