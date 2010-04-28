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

use Wx ':everything';
use base 'Wx::Frame';
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

use Interface::Wx::MainMenu;
use Interface::Wx::Window::Input;
use Interface::Wx::Window::Console;
use Interface::Wx::Window::ChatLog;
use Interface::Wx::Window::Exp;

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
	
	$self->{menu} = new Interface::Wx::MainMenu($self);
	$self->createStatusBar;
	
	#$self->SetSizeHints(300, 250);
	$self->SetClientSize(950, 680);
	if (-f (my $icon = "$RealBin/src/build/openkore.ico")) {
		$self->SetIcon(new Wx::Icon($icon, wxBITMAP_TYPE_ICO));
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
	
	$self->{windows} = {};
	
	($self->{aui} = new Wx::AuiManager)->SetManagedWindow($self);
	
	$self->{aui}->AddPane(
		$self->{notebook} = new Wx::AuiNotebook($self, wxID_ANY, wxDefaultPosition, wxDefaultSize,
			# no close buttons for tabs
			wxAUI_NB_TOP | wxAUI_NB_TAB_SPLIT | wxAUI_NB_TAB_MOVE | wxAUI_NB_SCROLL_BUTTONS
		),
		Wx::AuiPaneInfo->new->CenterPane
	);
	
	my $input = new Interface::Wx::Window::Input($self);
	$self->{aui}->AddPane($input,
		Wx::AuiPaneInfo->new->ToolbarPane->Bottom->BestSize($input->GetBestSize)->CloseButton(0)->Resizable->LeftDockable(0)->RightDockable(0)
	);
	
	$self->toggleWindow('console', T('Console'), 'Interface::Wx::Window::Console', 'notebook');
	$self->toggleWindow('chatLog', T('Chat log'), 'Interface::Wx::Window::ChatLog', 'notebook');
	$self->toggleWindow('exp', T('Experience report'), 'Interface::Wx::Window::Exp', 'right');
	
	$self->{aui}->Update;
	
	#$self->{notebook}->Split(1, wxBOTTOM);
	$self->{notebook}->SetSelection(0);
	
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
	$self->{statusBar}->SetStatusWidths(-1, 65, 350);
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
=pod
				my @seqs = @ai_seq;
				foreach (@seqs) {
					s/^route_//;
					s/_/ /g;
					s/([a-z])([A-Z])/$1 $2/g;
					$_ = lc $_;
				}
				substr($seqs[0], 0, 1) = uc substr($seqs[0], 0, 1);
				$aiText = join(', ', @seqs);
=cut
				my @seqs = ();
				for (@ai_seq) {
					push @seqs, do {
						my $args = AI::args(scalar @seqs);
						
						return sprintf('%s (%s)', $_, $Macro::Data::queue->name) if /^macro$/ and (
							$Macro::Data::queue && ref $Macro::Data::queue && $Macro::Data::queue->can('name')
						);
						
						$_;
					}
				}
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

sub toggleWindow {
	my ($self, $key, $title, $class, $target) = @_;
	
	unless ($self->{windows}{$key}) {
		eval "require $class";
		if ($@) {
			Log::warning "Unable to load $class\n$@", 'interface';
			return;
		}
		unless ($class->can('new')) {
			Log::warning "Unable to create instance of $class\n", 'interface';
			return;
		}
		
		my $window = $class->new($self);
		
		if (my $pos = {
			'float' => wxAUI_DOCK_NONE,
			'top' => wxAUI_DOCK_TOP,
			'right' => wxAUI_DOCK_RIGHT,
			'bottom' => wxAUI_DOCK_BOTTOM,
			'left' => wxAUI_DOCK_LEFT,
		}->{$target}) {
			$self->{aui}->AddPane($window,
				Wx::AuiPaneInfo->new->Caption($title)->Direction($pos)->BestSize(250, 250)->DestroyOnClose
			);
			$self->{aui}->Update;
		} elsif ($target eq 'notebook') {
			$self->{notebook}->AddPage($window, $title, 1);
		}
		
		Scalar::Util::weaken($self->{windows}{$key} = $window);
	} else {
		if ($self->{aui}->GetPane($self->{windows}{$key})->IsOk) {
			# TODO: close window in AuiManager
		} else {
			ref $self->{notebook}->GetPage($_) eq ref $self->{windows}{$key} && $self->{notebook}->DeletePage($_)
			for (0 .. $self->{notebook}->GetPageCount-1);
		}
	}
}

=pod
sub OnInit {
	my $self = shift;
	
	$self->createInterface;
	$self->iterate;
	
	$self->{hooks} = Plugins::addHooks(
		['initialized',                         sub { $self->onInitialized(@_); }],
		['packet/minimap_indicator',            sub { $self->onMapIndicator (@_); }],
		
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
	
	return 1;
}

#########################
## INTERFACE CREATION
#########################

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

##################
## Callbacks
##################

sub onBooleanSetting {
	my ($self, $setting) = @_;
	
	configModify ($setting, !$config{$setting}, 1);
}

sub onMapToggle {
	my $self = shift;
	$self->{mapDock}->attach;
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

### Map ###

sub onMapIndicator {
	my ($self, undef, $args) = @_;
	
	if ($self->{mapViewer}) {
		$self->{mapViewer}->mapIndicator ($args->{type} != 2, $args->{x}, $args->{y}, $args->{red}, $args->{green}, $args->{blue}, $args->{alpha});
	}
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
