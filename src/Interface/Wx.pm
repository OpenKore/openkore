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
package Interface::Wx;

# Note: don't use wxTimer for anything important. It's known to cause reentrancy issues!

# Note: some wx constants are defined by Wx::Event only if corresponding events are imported

BEGIN {
	require Wx::Perl::Packager if ($^O eq 'MSWin32');
}

use strict;
use Wx ':everything';
use Wx::Event qw(EVT_CLOSE EVT_MENU EVT_MENU_OPEN EVT_LISTBOX_DCLICK
		EVT_CHOICE EVT_TIMER EVT_TASKBAR_LEFT_DOWN EVT_KEY_DOWN
		EVT_BUTTON);
use Time::HiRes qw(time sleep);
use File::Spec;
use FindBin qw($RealBin);


use Globals;
use Interface;
use base qw(Wx::App Interface);
use Modules;
use Field;
use I18N qw/bytesToString/;

use Interface::Wx::Dock;
use Interface::Wx::MapViewer;
use Interface::Wx::LogView;
use Interface::Wx::Console;
use Interface::Wx::Input;
use Interface::Wx::ItemList;
use Interface::Wx::DockNotebook;
use Interface::Wx::PasswordDialog;
use AI;
use Settings qw(%sys);
use Plugins;
use Misc;
use Commands;
use Utils;
use Translation qw/T TF/;
use FileParsers;

our $CVS;
our ($iterationTime, $updateUITime, $updateUITime2);


sub OnInit {
	my $self = shift;

	$CVS = ($Settings::SVN =~ /SVN/);
	$self->createInterface;
	$self->iterate;

	my $onChat =            sub { $self->onChatAdd(@_); };
	my $onSelfStatChange  = sub { $self->onSelfStatChange (@_); };
	my $onSlaveStatChange = sub { $self->onSlaveStatChange (@_); };
	my $onPetStatChange   = sub { $self->onPetStatChange (@_); };

	$self->{hooks} = Plugins::addHooks(
		['loadfiles',                           sub { $self->onLoadFiles(@_); }],
		['postloadfiles',                       sub { $self->onLoadFiles(@_); }],
		['parseMsg/addPrivMsgUser',             sub { $self->onAddPrivMsgUser(@_); }],
		['initialized',                         sub { $self->onInitialized(@_); }],
		['ChatQueue::add',                      $onChat],
		['packet_selfChat',                     $onChat],
		['packet_mainChat',                     $onChat],
		['packet_privMsg',                      $onChat],
		['packet_sentPM',                       $onChat],
		['mainLoop_pre',                        sub { $self->onUpdateUI(); }],
		['captcha_file',                        sub { $self->onCaptcha(@_); }],
		['packet/minimap_indicator',            sub { $self->onMapIndicator (@_); }],
		['start3',                              sub { $interface->{mapViewer}->parsePortals(); }],

		# stat changes
		['packet/map_changed',                  sub { $self->onSelfStatChange (@_); $self->onSlaveStatChange (@_); $self->onPetStatChange (@_); }],
		['packet/hp_sp_changed',                $onSelfStatChange],
		['packet/stat_info',                    $onSelfStatChange],
		['packet/stat_info2',                   $onSelfStatChange],
		['packet/stats_points_needed',          $onSelfStatChange],
		['changed_status',                      $onSelfStatChange],
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

sub DESTROY {
	my $self = shift;
	Plugins::delHooks($self->{hooks});
}


######################
## METHODS
######################


sub mainLoop {
	my ($self) = @_;
	my $timer = new Wx::Timer($self, 246);
	# Start the real main loop in 100 msec, so that the UI has
	# the chance to layout correctly.
	EVT_TIMER($self, 246, sub { $self->realMainLoop(); });
	$timer->Start(100, 1);
	$self->MainLoop;
}

sub realMainLoop {
	my ($self) = @_;
	my $timer = new Wx::Timer($self, 247);
	my $sleepTime = $config{sleepTime};
	my $quitting;
	my $sub = sub {
		return if ($quitting);
		if ($quit) {
			$quitting = 1;
			$self->ExitMainLoop;
			$timer->Stop;
			return;
		} elsif ($self->{iterating}) {
			return;
		}

		$self->{iterating}++;

		if ($sleepTime ne $config{sleepTime}) {
			$sleepTime = $config{sleepTime};
			$timer->Start(($sleepTime / 1000) > 0
				? ($sleepTime / 1000)
				: 10);
		}
		main::mainLoop();

		$self->{iterating}--;
	};

	EVT_TIMER($self, 247, $sub);
	$timer->Start(($sleepTime / 1000) > 0
		? ($sleepTime / 1000)
		: 10);
}

sub iterate {
	my $self = shift;

	if ($self->{iterating} == 0) {
		$self->{console}->Refresh;
		$self->{console}->Update;
	}
	$self->Yield();
	$iterationTime = time;
}

sub getInput {
	my $self = shift;
	my $timeout = shift;
	my $msg;

	if ($timeout < 0) {
		while (!defined $self->{input} && !$quit) {
			$self->iterate;
			sleep 0.01;
		}
		$msg = $self->{input};

	} elsif ($timeout == 0) {
		$msg = $self->{input};

	} else {
		my $begin = time;
		until (defined $self->{input} || time - $begin > $timeout || $quit) {
			$self->iterate;
			sleep 0.01;
		}
		$msg = $self->{input};
	}

	undef $self->{input};
	undef $msg if (defined($msg) && $msg eq "");

	# Make sure we update the GUI. This is to work around the effect
	# of functions that block for a while
	$self->iterate if (timeOut($iterationTime, 0.05));

	return $msg;
}

sub query {
	my $self = shift;
	my $message = shift;
	my %args = @_;

	$args{title} = T("Query") if (!defined $args{title});
	$args{cancelable} = 1 if (!exists $args{cancelable});

	$message = wrapText($message, 70);
	$message =~ s/\n$//s;
	my $dialog;
	if ($args{isPassword}) {
		# WxPerl doesn't support wxPasswordEntryDialog :(
		$dialog = new Interface::Wx::PasswordDialog($self->{frame}, $message, $args{title});
	} else {
		$dialog = new Wx::TextEntryDialog($self->{frame}, $message, $args{title});
	}
	while (1) {
		my $result;
		if ($dialog->ShowModal == wxID_OK) {
			$result = $dialog->GetValue;
		}
		if (!defined($result) || $result eq '') {
			if ($args{cancelable}) {
				$dialog->Destroy;
				return undef;
			}
		} else {
			$dialog->Destroy;
			return $result;
		}
	}
}

sub showMenu {
	my $self = shift;
	my $message = shift;
	my $choices = shift;
	my %args = @_;

	$args{title} = T("Menu") if (!defined $args{title});
	$args{cancelable} = 1 if (!exists $args{cancelable});

	$message = wrapText($message, 70);
	$message =~ s/\n$//s;
	my $dialog = new Wx::SingleChoiceDialog($self->{frame},
		$message, $args{title}, $choices);
	while (1) {
		my $result;
		if ($dialog->ShowModal == wxID_OK) {
			$result = $dialog->GetSelection;
		}
		if (!defined($result)) {
			if ($args{cancelable}) {
				$dialog->Destroy;
				return -1;
			}
		} else {
			$dialog->Destroy;
			return $result;
		}
	}
}

sub writeOutput {
	my $self = shift;
	$self->{console}->add(@_);
	# Make sure we update the GUI. This is to work around the effect
	# of functions that block for a while
	$self->iterate if (timeOut($iterationTime, 0.05));
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

	my $title = ($fatal) ? T("Fatal error") : T("Error");
	$self->{iterating}++;
	Wx::MessageBox($msg, "$title - $Settings::NAME", wxICON_ERROR, $self->{frame});
	$self->{iterating}--;
}

sub beep {
	Wx::Bell();
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


	### Input field
	$self->createInputField;

	### Status bar
	my $statusbar = $self->{statusbar} = new Wx::StatusBar($frame, wxID_ANY, wxST_SIZEGRIP);
	$statusbar->SetFieldsCount(3);
	$statusbar->SetStatusWidths(-1, 65, 175);
	$frame->SetStatusBar($statusbar);


	#################

	$frame->SetSizeHints(300, 250);
	$frame->SetClientSize(730, 400);
	$frame->SetIcon(Wx::GetWxPerlIcon);
	$frame->Show(1);
	EVT_CLOSE($frame, \&onClose);

	# For some reason the input box doesn't get focus even if
	# I call SetFocus(), so do it in 100 msec.
	# And the splitter window's sash position is placed incorrectly
	# if I call SetSashGravity immediately.
	my $timer = new Wx::Timer($self, 73289);
	EVT_TIMER($self, 73289, sub {
		$self->{inputBox}->SetFocus;
		$self->{notebook}->switchPage(T('Console'));
#		$splitter->SetSashGravity(1);
	});
	$timer->Start(500, 1);

	# Hide console on Win32
	if ($^O eq 'MSWin32' && $sys{wxHideConsole}) {
		eval 'use Win32::Console; Win32::Console->new(STD_OUTPUT_HANDLE)->Free();';
	}
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
	$self->addMenu($infoMenu, T('&Status').'	Alt-S',	sub { Commands::run("s"); });
	$self->addMenu($infoMenu, T('S&tatistics'),	sub { Commands::run("st"); });
	$self->addMenu($infoMenu, T('&Inventory').'	Alt-I',	sub { Commands::run("i"); });
	$self->addMenu($infoMenu, T('S&kills'),		sub { Commands::run("skills"); });
	$infoMenu->AppendSeparator;
	$self->addMenu($infoMenu, T('&Players').'	Alt-P',	sub { Commands::run("pl"); });
	$self->addMenu($infoMenu, T('&Monsters').'	Alt-M',	sub { Commands::run("ml"); });
	$self->addMenu($infoMenu, T('&NPCs'),		sub { Commands::run("nl"); });
	$infoMenu->AppendSeparator;
	$self->addMenu($infoMenu, T('&Experience Report'),	sub { Commands::run("exp"); });
	$self->addMenu($infoMenu, T('&Item Change Report'),	sub { Commands::run("exp item"); });
	$self->addMenu($infoMenu, T('&Monster Kill Report'),	sub { Commands::run("exp monster"); });
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
		$self->openWindow (T('Report'), 'Interface::Wx::StatView::Exp', 1)
	});

	$viewMenu->AppendSeparator;

	$self->addMenu ($viewMenu, T('&Font...'), \&onFontChange, T('Change console font'));
	$self->addMenu($viewMenu, T('Clear Console'), sub {my $self = shift; $self->{console}->Remove(0, 40000)}, T('Clear content of console'));
	$self->addMenu($viewMenu, T('Clear Chat History'), sub {Commands::run("cl")}, T('Clear chat history'));
	$self->addMenu($viewMenu, T('Clear Item History'), sub {Commands::run("cil")}, T('Clear item history'));

	$menu->Append($viewMenu, T('&View'));

	# Merchant menu
	my $merchantMenu = new Wx::Menu;
	$menu->Append($merchantMenu, T('&Merchant'));
	$self->addMenu($merchantMenu, T('Accept deal'), sub {Commands::run("deal")}, T('Accept/Finalise current deal'));
	$self->addMenu($merchantMenu, T('Reject deal'), sub {Commands::run("deal no")}, T('Reject current deal'));
	$self->addMenu($merchantMenu, T('Deal information'), sub {Commands::run("dl")}, T('View the information of current deal'));

	$merchantMenu->AppendSeparator;
	$self->addMenu($merchantMenu, T('Ignore all deals (0)'), sub {Commands::run("conf dealAuto 0")}, T('Ignore all incoming deal requests'));
	$self->addMenu($merchantMenu, T('Reject all deals (1)'), sub {Commands::run("conf dealAuto 1")}, T('Reject all incoming deal requests'));
	$self->addMenu($merchantMenu, T('Accept all deals (2)'), sub {Commands::run("conf dealAuto 2")}, T('Accept all incoming deal requests'));

	$merchantMenu->AppendSeparator;
	$self->addMenu($merchantMenu, T('Open shop'), sub {Commands::run("openshop")}, T('Open shop'));
	$self->addMenu($merchantMenu, T('Close shop'), sub {Commands::run("closeshop")}, T('Close shop'));
	$self->addMenu($merchantMenu, T('Current shop status'), sub {Commands::run("al")}, T('View your shop status'));
	$self->addMenu($merchantMenu, T('Nearby shop list'), sub {Commands::run("vl")}, T('View shops nearby'));

	$merchantMenu->AppendSeparator;
	$self->addMenu($merchantMenu, T('Reload shop.txt'), sub {Commands::run("reload shop.txt")}, T('Reload shop.txt'));
	$self->addMenu($merchantMenu, T('Test your shop'), sub {Commands::run("testshop")}, T('Test your shop'));


	# Command menu
	my $commandMenu = new Wx::Menu;
	$menu->Append($commandMenu, T('&Command'));
	$self->addMenu($commandMenu, T('Teleport'), sub {Commands::run("tele")}, T('Teleport'));
	$self->addMenu($commandMenu, T('Memo position'), sub {Commands::run("memo")}, T('Memorise the current coordinate for teleport'));
	$commandMenu->AppendSeparator;
	$self->addMenu($commandMenu, T('Sit down'), sub {Commands::run("sit")}, T('Sit down'));
	$self->addMenu($commandMenu, T('Stand up'), sub {Commands::run("stand")}, T('Stand up'));
	$commandMenu->AppendSeparator;
	$self->addMenu($commandMenu, T('Auto storage'), sub {Commands::run("autostorage")}, T('Auto storage'));
	$self->addMenu($commandMenu, T('Auto buying'), sub {Commands::run("autobuy")}, T('Auto buying'));
	$self->addMenu($commandMenu, T('Auto selling'), sub {Commands::run("autosell")}, T('Auto selling'));
	$commandMenu->AppendSeparator;

	# Party menu
	$self->{partyMenu} = new Wx::Menu;
	$self->addMenu($self->{partyMenu}, T('Party information'), sub {Commands::run("party")}, T('Party information'));
	$self->{partyMenu}->AppendSeparator;
	$self->addMenu($self->{partyMenu}, T('Disable party share (0)'), sub {Commands::run("party share 0")}, T('Disable sharing party EXP'));
	$self->addMenu($self->{partyMenu}, T('Enable party share (1)'), sub {Commands::run("party share 1")}, T('Enable sharing party EXP'));
	$self->{partyMenu}->AppendSeparator;
	$self->addMenu($self->{partyMenu}, T('Auto ignore party request (0)'), sub {Commands::run("conf partyAuto 0")}, T('Ignore all incoming party request'));
	$self->addMenu($self->{partyMenu}, T('Auto reject party request (1)'), sub {Commands::run("conf partyAuto 1")}, T('Reject all incoming party request'));
	$self->addMenu($self->{partyMenu}, T('Auto accept party request (2)'), sub {Commands::run("conf partyAuto 2")}, T('Accept all incoming party request'));
	$self->{partyMenu}->AppendSeparator;
	$self->addMenu($self->{partyMenu}, T('Accept party request'), sub {Commands::run("party join 1")}, T('Accept incoming party request'));
	$self->addMenu($self->{partyMenu}, T('Reject party request'), sub {Commands::run("party join 0")}, T('Reject incoming party request'));
	$self->addMenu($self->{partyMenu}, T('Leave party'), sub {Commands::run("party leave")}, T('Leave the current party'));
	$commandMenu->AppendSubMenu($self->{partyMenu}, T('&Party'), T('Party'));

	#Friend menu
	$self->{friendMenu} = new Wx::Menu;
	$self->addMenu($self->{friendMenu}, T('Friend list'), sub {Commands::run("friend")}, 'Friend list');
	$self->{friendMenu}->AppendSeparator;
	$self->addMenu($self->{friendMenu}, T('Auto accept friend request'), sub {Commands::run("friend accept")}, T('Auto accept all incoming friend requests'));
	$self->addMenu($self->{friendMenu}, T('Auto reject friend request'), sub {Commands::run("friend reject")}, T('Auto reject all incoming friend requests'));
	$commandMenu->AppendSubMenu($self->{friendMenu}, T('&Friend'), T('Friend'));

	#Guild menu
	$self->{guildMenu} = new Wx::Menu;
	$self->addMenu($self->{guildMenu}, T('Guild information'), sub {Commands::run("guild info")}, T('Guild information'));
	$self->addMenu($self->{guildMenu}, T('Guild member'), sub {Commands::run("guild member")}, T('Guild memberinformation'));
	$self->{guildMenu}->AppendSeparator;
	$self->addMenu($self->{guildMenu}, T('Auto accept guild request'), sub {Commands::run("guild join 1")}, T('Auto accept all incoming guild requests'));
	$self->addMenu($self->{guildMenu}, T('Auto reject guild request'), sub {Commands::run("guild join 0")}, T('Auto reject all incoming guild requests'));
	$commandMenu->AppendSubMenu($self->{guildMenu}, T('&Guild'), T('Guild'));

	#Alias menu
	$self->{aliasMenu} = new Wx::Menu;
	$menu->Append($self->{aliasMenu}, T('&Alias'));

	# Settings menu
	my $settingsMenu = new Wx::Menu;
	$self->createSettingsMenu($settingsMenu) if ($self->can('createSettingsMenu'));
	$self->addMenu($settingsMenu, T('Reload config.txt'), sub {Commands::run("reload config.txt")}, T('Reload config.txt'));
	$self->addMenu($settingsMenu, T('Reload All Configs'), sub {Commands::run("reload all")}, T('Reload All Configs'));
	$settingsMenu->AppendSeparator;
	$self->{iDeal} = $self->addMenu($settingsMenu, T('Close All PM'), sub {Commands::run("conf ignoreAll 1")}, T('Ignore all PM from all people'));
	$self->{iDeal} = $self->addMenu($settingsMenu, T('Open All PM'), sub {Commands::run("conf ignoreAll 0")}, T('Accept all PM from all people'));
	$settingsMenu->AppendSeparator;
	$self->{iDeal} = $self->addMenu($settingsMenu, T('Turn off random routing'), sub {Commands::run("conf route_randomWalk 0")}, T('Not randomly walking in the map'));
	$self->{iDeal} = $self->addMenu($settingsMenu, T('Turn on random routing (1)'), sub {Commands::run("conf route_randomWalk 1")}, T('Randomly walking in the map'));
	$self->{iDeal} = $self->addMenu($settingsMenu, T('Turn on random routing (2)'), sub {Commands::run("conf route_randomWalk 2")}, T('Randomly walking in the map without walking into portals'));
	$settingsMenu->AppendSeparator;
	$self->{iDeal} = $self->addMenu($settingsMenu, T('Turn off auto attacking'), sub {Commands::run("conf attackAuto 0")}, T('Not attacking no matter being attacked'));
	$self->{iDeal} = $self->addMenu($settingsMenu, T('Turn on auto attacking (1)'), sub {Commands::run("conf attackAuto 1")}, T('Attack the enemy when the enemy is attacking you'));
	$self->{iDeal} = $self->addMenu($settingsMenu, T('Turn on auto attacking (2)'), sub {Commands::run("conf attackAuto 2")}, T('Auto attack enemies nearby'));
	$settingsMenu->AppendSeparator;
	$self->{iDeal} = $self->addMenu($settingsMenu, T('Turn off item picking'), sub {Commands::run("conf itemsTakeAuto 0")}, T('Not picking any items'));
	$self->{iDeal} = $self->addMenu($settingsMenu, T('Turn on item picking (1)'), sub {Commands::run("conf itemsTakeAuto 1")}, T('Picking items after killing all the enemies'));
	$self->{iDeal} = $self->addMenu($settingsMenu, T('Turn on item picking (2)'), sub {Commands::run("conf itemsTakeAuto 2")}, T('Picking items each time killing an enemy'));
	$settingsMenu->AppendSeparator;
	$self->addMenu($settingsMenu, T('&Advanced...'), \&onAdvancedConfig, T('Edit advanced configuration options.'));
	$menu->Append($settingsMenu, T('&Settings'));
	$self->createSettingsMenu2($settingsMenu) if ($self->can('createSettingsMenu2'));

	# Help menu
	my $helpMenu = new Wx::Menu();
	$self->addMenu($helpMenu, T('&Manual') . "\tF1", \&onManual, T('Read the manual'));
	$self->addMenu($helpMenu, T('&Forum') . "\tShift-F1", \&onForum, T('Visit the forum'));
	#Custom link for different localisation
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
	my $label = new Wx::StaticText($infoPanel, wxID_ANY, T("HP: "));
	$hsizer->Add($label, 0, wxLEFT, 3);


	## HP
	my $hpBar = $self->{hpBar} = new Wx::Gauge($infoPanel, wxID_ANY, 100,
		wxDefaultPosition, [0, $label->GetBestSize->GetHeight + 2],
		wxGA_HORIZONTAL | wxGA_SMOOTH);
	$hsizer->Add($hpBar, 1, wxRIGHT, 8);

	$label = new Wx::StaticText($infoPanel, wxID_ANY, T("SP: "));
	$hsizer->Add($label, 0);

	## SP
	my $spBar = $self->{spBar} = new Wx::Gauge($infoPanel, wxID_ANY, 100,
		wxDefaultPosition, [0, $label->GetBestSize->GetHeight + 2],
		wxGA_HORIZONTAL | wxGA_SMOOTH);
	$hsizer->Add($spBar, 1, wxRIGHT, 8);

	$label = new Wx::StaticText($infoPanel, wxID_ANY, T("Exp: "));
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

	$label = new Wx::StaticText($infoPanel, wxID_ANY, T("Weight: "));
	$hsizer->Add($label, 0);

	## Weight
	my $weightBar = $self->{weightBar} = new Wx::Gauge($infoPanel, wxID_ANY, 100,
		wxDefaultPosition, [0, $label->GetBestSize->GetHeight + 2],
		wxGA_HORIZONTAL | wxGA_SMOOTH);
	$hsizer->Add($weightBar, 1);


	$infoPanel->SetSizerAndFit($hsizer);
	$vsizer->Add($infoPanel, 0, wxGROW);
}

sub createInputField {
	my $self = shift;
	my $vsizer = $self->{vsizer};
	my $frame = $self->{frame};

	my $hsizer = new Wx::BoxSizer(wxHORIZONTAL);
	$vsizer->Add($hsizer, 0, wxGROW);

	my $targetBox = $self->{targetBox} = new Wx::ComboBox($frame, wxID_ANY, "", wxDefaultPosition,
		[115, 0]);
	$targetBox->SetName('targetBox');
	$hsizer->Add($targetBox, 0, wxGROW);
	EVT_KEY_DOWN($self, \&onTargetBoxKeyDown);

	my $inputBox = $self->{inputBox} = new Interface::Wx::Input($frame);
	$inputBox->onEnter($self, \&onInputEnter);
	$hsizer->Add($inputBox, 1, wxGROW);

	my $choice = $self->{inputType} = new Wx::Choice($frame, 456, wxDefaultPosition, wxDefaultSize,
			[T('Command'), T('Public chat'), T('Party chat'), T('Guild chat')]);
	$choice->SetSelection(0);
	EVT_CHOICE($self, 456, sub { $inputBox->SetFocus; });
	$hsizer->Add($choice, 0, wxGROW);
}

sub createSplitterContent {
	my $self = shift;
	my $splitter = $self->{splitter};
	my $frame = $self->{frame};

	## Dockable notebook with console and chat log
	my $notebook = $self->{notebook} = new Interface::Wx::DockNotebook($splitter, wxID_ANY);
	$notebook->SetName('notebook');
	my $page = $notebook->newPage(0, T('Console'));
	my $console = $self->{console} = new Interface::Wx::Console($page);
	$page->set($console);

	$page = $notebook->newPage(1, T('Chat Log'), 0);
	my $chatLog = $self->{chatLog} = new Interface::Wx::LogView($page);
	$page->set($chatLog);
	$chatLog->addColor("selfchat", 0, 148, 0);
	$chatLog->addColor("pm", 142, 120, 0);
	$chatLog->addColor("p", 164, 0, 143);
	$chatLog->addColor("g", 0, 177, 108);
	$chatLog->addColor("warning", 214, 93, 0);

	# $page = $notebook->newPage(2, T('Team Chat Log'), 1);
	# my $TchatLog = $self->{TchatLog} = new Interface::Wx::LogView($page);
	# $page->set($TchatLog);
	# $TchatLog->addColor("p", 164, 0, 143);

	# $page = $notebook->newPage(3, T('Guild Chat Log'), 2);
	# my $GchatLog = $self->{GchatLog} = new Interface::Wx::LogView($page);
	# $page->set($GchatLog);
	# $GchatLog->addColor("g", 0, 177, 108);

	## Parallel to the notebook is another sub-splitter
	my $subSplitter = new Wx::SplitterWindow($splitter, 583,
		wxDefaultPosition, wxDefaultSize, wxSP_LIVE_UPDATE);

	## Inside this splitter is a player/monster/item list, and a dock with map viewer

	my $itemList = $self->{itemList} = new Interface::Wx::ItemList($subSplitter, T('Players, Monsters & Items'));
	$itemList->onActivate(\&onItemListActivate, $self);
	$self->customizeItemList($itemList) if ($self->can('customizeItemList'));
	$subSplitter->Initialize($itemList);


	# Dock
	my $mapDock = $self->{mapDock} = new Interface::Wx::Dock($subSplitter, wxID_ANY, T('Map'));
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
	if ($field && $char) {
		$mapView->set($field->baseName, $char->{pos_to}{x}, $char->{pos_to}{y}, $field);
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


sub onUpdateUI {
	my $self = shift;

	if (timeOut($updateUITime, 0.15)) {
		$self->updateStatusBar;
		$self->updateMapViewer;
		$updateUITime = time;
	}
	if (timeOut($updateUITime2, 0.35)) {
		$self->updateItemList;
		$updateUITime2 = time;
	}
}

sub updateStatusBar {
	my $self = shift;

	my ($statText, $xyText, $aiText) = ('', '', '');

	if ($self->{loadingFiles}) {
		$statText = TF("Loading files... %.0f%%", $self->{loadingFiles}{percent} * 100);
	} elsif (!$conState) {
		$statText = T("Initializing...");
	} elsif ($conState == 1) {
		$statText = T("Not connected");
	} elsif ($conState > 1 && $conState < 5) {
		$statText = T("Connecting...");
	} elsif ($self->{mouseMapText}) {
		$statText = $self->{mouseMapText};
	}

	if ($conState == 5) {
		$xyText = "$char->{pos_to}{x}, $char->{pos_to}{y}";

		if (AI::state) {
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

	$map->set($field->baseName, $myPos->{x}, $myPos->{y}, $field, $char->{look});

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
	$map->setParty ([values %{$char->{party}{users}}]) if $char->{party}{joined} && $char->{party}{users};
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
			$value = $char->exp_base_percent;
			$self->{expBar}->SetValue ($value);
			$self->{expBar}->SetToolTip (sprintf '%s / %s (%.2f%)', formatNumber ($char->{exp}), formatNumber ($char->{exp_max}), $value);
		}
		if ($char->{exp_job_max}) {
			$value = $char->exp_job_percent;
			$self->{jobExpBar}->SetValue ($value);
			$self->{jobExpBar}->SetToolTip (sprintf '%s / %s (%.2f%)', formatNumber ($char->{exp_job}), formatNumber ($char->{exp_job_max}), $value);
		}
		if ($char->{weight_max}) {
			$value = $char->weight_percent;
			$self->{weightBar}->SetValue ($value);
			$self->{weightBar}->SetToolTip (sprintf '%s / %s (%.2f%)', formatNumber ($char->{weight}), formatNumber ($char->{weight_max}), $value);
			if ($char->statusActive('EFST_WEIGHTOVER90')) {
				$self->{weightBar}->SetForegroundColour (new Wx::Colour (255, 0, 50));
			} elsif ($char->statusActive('EFST_WEIGHTOVER50')) {
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


sub onInputEnter {
	my $self = shift;
	my $text = shift;
	my $command;

	my $n = $self->{inputType}->GetSelection;
	if ($n == 0 || $text =~ /^\/(.*)/) {
		my $command = ($n == 0) ? $text : $1;
		$self->{console}->add("input", "$command\n");
		$self->{inputBox}->Remove(0, -1);
		$self->{input} = $command;
		return;
	}

	if ($conState != 5) {
		$self->{console}->add("error", T("You're not logged in.\n"));
		return;
	}

	if ($self->{targetBox}->GetValue ne "") {
		sendMessage($messageSender, "pm", $text, $self->{targetBox}->GetValue);
	} elsif ($n == 1) { # Public chat
		sendMessage($messageSender, "c", $text);
	} elsif ($n == 2) { # Party chat
		sendMessage($messageSender, "p", $text);
	} else { # Guild chat
		sendMessage($messageSender, "g", $text);
	}
}

sub onMenuOpen {
	my $self = shift;
	$self->{mPause}->Enable(AI::state != AI::OFF);
	$self->{mManual}->Enable(AI::state != AI::MANUAL);
	$self->{mResume}->Enable(AI::state != AI::AUTO);
	$self->{infoBarToggle}->Check($self->{infoPanel}->IsShown);
	$self->{chatLogToggle}->Check(defined $self->{notebook}->hasPage(T('Chat Log')) ? 1 : 0);

	while (my ($setting, $menu) = each (%{$self->{mBooleanSetting}})) {
		$menu->Check ($config{$setting} ? 1 : 0);
	}

	my $menu;
	while ($menu = $self->{aliasMenu}->FindItemByPosition (0)) {
		$self->{aliasMenu}->Delete ($menu);
	}

	for $menu (sort map {/^alias_(.+)$/} keys %config) {
		$self->addMenu ($self->{aliasMenu}, $menu, sub { Commands::run ($menu) });
		$self->{aliasMenu}->AppendSeparator;
	}
}

sub onLoadFiles {
	my ($self, $hook, $param) = @_;
	if ($hook eq 'loadfiles') {
		$self->{loadingFiles}{percent} = $param->{current} / scalar(@{$param->{files}});
	} else {
		delete $self->{loadingFiles};
	}

	$self->updateStatusBar;
}

sub onEnableAI {
	AI::state(AI::AUTO);
}

sub onManualAI {
	AI::state(AI::MANUAL);
}

sub onDisableAI {
	AI::state(AI::OFF);
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

	my $font;
	if (Wx::wxMSW()) {
		$font = Wx::Font->new(9, wxMODERN, wxNORMAL, wxNORMAL, 0, 'Courier New');
	} elsif ($^O eq 'freebsd') {
		$font = Wx::Font->new(9, wxMODERN, wxNORMAL, wxNORMAL, 0, 'Monospace');
	} else {
		$font = Wx::Font->new(10, wxMODERN, wxNORMAL, wxNORMAL, 0, 'MiscFixed');
	}

	my $fontData = Wx::FontData->new();
	$fontData->SetInitialFont($font);
	$fontData->SetColour(wxWHITE);

	my $fontDialog = Wx::FontDialog->new($self->{console}, $fontData);

	my $fontDialogStatus = $fontDialog->ShowModal();

	$fontData = $fontDialog->GetFontData();
	my $selectedfont = $fontData->GetChosenFont();
	my $selectedcolour = $fontData->GetColour();
	$self->{console}->SetFont($selectedfont);
}

sub onBooleanSetting {
	my ($self, $setting) = @_;

	configModify ($setting, !$config{$setting}, 1);
}

sub onAdvancedConfig {
	my $self = shift;
	if ($self->{notebook}->hasPage(T('Advanced Configuration'))) {
		$self->{notebook}->switchPage(T('Advanced Configuration'));
		return;
	}

	my $page = $self->{notebook}->newPage(1, T('Advanced Configuration'));
	my $panel = new Wx::Panel($page, wxID_ANY);

	my $vsizer = new Wx::BoxSizer(wxVERTICAL);
	$panel->SetSizer($vsizer);

	require Interface::Wx::ConfigEditor;
	my $cfg = new Interface::Wx::ConfigEditor($panel, wxID_ANY);
	$cfg->setConfig(\%config);
	$cfg->addCategory(T('All'), 'Grid');
	$cfg->addCategory('server', 'Grid', ['master', 'server', 'username', 'password', 'char']);
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

	my $revert = new Wx::Button($panel, 46, T('&Revert'));
	$revert->SetToolTip(T('Revert settings to before you opened the selected category'));
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

	my $close = new Wx::Button($panel, 47, T('&Close'));
	$close->SetToolTip(T('Close this panel/dialog'));
	$close->SetDefault;
	$sizer->Add($close, 0);
	EVT_BUTTON($close, 47, sub {
		$self->{notebook}->closePage(T('Advanced Configuration'));
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
		$self->{notebook}->closePage(T('Chat Log'));

	} elsif (!$self->{notebook}->hasPage(T('Chat Log'))) {
		my $page = $self->{notebook}->newPage(1, T('Chat Log'), 0);
		my $chatLog = $self->{chatLog} = new Interface::Wx::LogView($page);
		$page->set($chatLog);
		$chatLog->addColor("selfchat", 0, 148, 0);
		$chatLog->addColor("pm", 142, 120, 0);
		$chatLog->addColor("p", 164, 0, 143);
		$chatLog->addColor("g", 0, 177, 108);
		$chatLog->addColor("warning", 214, 93, 0);
		$page->set($chatLog);

	} else {
		$self->{notebook}->switchPage(T('Chat Log'));
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
	my ($page, $window) = $self->openWindow (T('Status'), 'Interface::Wx::StatView::You', $create);

	return ($page, $window);
}

sub openHomunculus {
	my ($self, $create) = @_;
	my ($page, $window) = $self->openWindow (T('Homunculus'), 'Interface::Wx::StatView::Homunculus', $create);

	return ($page, $window);
}

sub openMercenary {
	my ($self, $create) = @_;
	my ($page, $window) = $self->openWindow (T('Mercenary'), 'Interface::Wx::StatView::Mercenary', $create);

	return ($page, $window);
}

sub openPet {
	my ($self, $create) = @_;
	my ($page, $window) = $self->openWindow (T('Pet'), 'Interface::Wx::StatView::Pet', $create);

	return ($page, $window);
}

sub openInventory {
	my ($self, $create) = @_;
	my ($page, $window) = $self->openWindow (T('Inventory'), 'Interface::Wx::List::ItemList::Inventory', $create);

	return ($page, $window);
}

sub openCart {
	my ($self, $create) = @_;
	my ($page, $window) = $self->openWindow (T('Cart'), 'Interface::Wx::List::ItemList::Cart', $create);

	return ($page, $window);
}

sub openStorage {
	my ($self, $create) = @_;
	my ($page, $window) = $self->openWindow (T('Storage'), 'Interface::Wx::List::ItemList::Storage', $create);

	return ($page, $window);
}

sub openEmotions {
	my ($self, $create) = @_;
	my ($page, $window) = $self->openWindow (T('Emotions'), 'Interface::Wx::EmotionList', $create);

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
	my ($page, $window) = $self->openWindow (T('NPC Talk'), 'Interface::Wx::NpcTalk', $create);

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
	my $url;
	if ($config{'manualURL'}) {
		$url = $config{'manualURL'};
	} else {
		$url = 'https://openkore.com/wiki/Manual';
	}
	launchURL($url);
}

sub onForum {
	my $self = shift;
	my $url;
	if ($config{'forumURL'}) {
		$url = $config{'forumURL'};
	} else {
		$url = 'https://forums.openkore.com/';
	}
	launchURL($url);
}

sub onItemListActivate {
	my ($self, $actor) = @_;

	if ($actor->isa('Actor::Player')) {
		Commands::run("lookp " . $actor->{binID});
		Commands::run("pl " . $actor->{binID});

	} elsif ($actor->isa('Actor::Monster')) {
		main::attack($actor->{ID});

	} elsif ($actor->isa('Actor::Item')) {
		$self->{console}->add("message", TF("Taking item %s\n", $actor->nameIdx), "info");
		main::take($actor->{ID});

	} elsif ($actor->isa('Actor::NPC')) {
		Commands::run("talk " . $actor->{binID});
	}

	$self->{inputBox}->SetFocus;
}

sub onTargetBoxKeyDown {
	my $self = shift;
	my $event = shift;

	if ($event->GetKeyCode == WXK_TAB && !$event->ShiftDown) {
		$self->{inputBox}->SetFocus;

	} else {
		$event->Skip;
	}
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

sub onChatAdd {
	my ($self, $hook, $params) = @_;
	my @tmpdate = localtime();
	if ($tmpdate[1] < 10) {$tmpdate[1] = "0".$tmpdate[1]};
	if ($tmpdate[2] < 10) {$tmpdate[2] = "0".$tmpdate[2]};

	return if (!$self->{notebook}->hasPage(T('Chat Log')));
	if ($hook eq "ChatQueue::add" && $params->{type} ne "pm") {
		my $msg = '';
		if ($params->{type} ne "c") {
			$msg = "[$params->{type}] ";
		}
		$msg .= "[$tmpdate[2]:$tmpdate[1]] $params->{user}: $params->{msg}\n";
		$self->{chatLog}->add($msg, $params->{type});

	} elsif ($hook eq "packet_selfChat") {
		# only display this message if it's a real self-chat
		$self->{chatLog}->add("[$tmpdate[2]:$tmpdate[1]] $params->{user}: $params->{msg}\n", "selfchat") if ($params->{user});
	} elsif ($hook eq "packet_mainChat") {
		$self->{chatLog}->add("[$tmpdate[2]:$tmpdate[1]] $params->{MsgUser}: $params->{Msg}\n", "schat") if ($params->{MsgUser});
	} elsif ($hook eq "packet_privMsg") {
		$self->{chatLog}->add("([$tmpdate[2]:$tmpdate[1]] From: $params->{privMsgUser}): $params->{privMsg}\n", "pm");
	} elsif ($hook eq "packet_sentPM") {
		$self->{chatLog}->add("([$tmpdate[2]:$tmpdate[1]] To: $params->{to}): $params->{msg}\n", "pm");
	}
}

sub onMapMouseMove {
	# Mouse moved over the map viewer control
#vcl code	my ($self, undef, $args) = @_;
#vcl code	my ($x, $y) = @{$args};
	my ($self, $x, $y) = @_;
	my $walkable;

	$walkable = $field->isWalkable($x, $y);
	if ($x >= 0 && $y >= 0 && $walkable) {
		$self->{mouseMapText} = TF("Mouse over: %s, %s", $x, $y);

		foreach my $portal (@{$self->{mapViewer}->{portals}->{$field->baseName}}) {
			if (distance($portal,{x=>$x,y=>$y}) <= ($config{wx_map_portalSticking} || 5)) {
					if ($portal->{npcType}) {
						# this is a Warp NPC
						$self->{mouseMapText} = TF("Warp NPC at %d %d", $x, $y);
					} else {
						# this is a portal
						$self->{mouseMapText} = TF("Portal at %d %d  -  Destination: %s, at %d %d", $x, $y, $portal->{destination}{field}, $portal->{destination}{x}, $portal->{destination}{y});
					}
				}
			}
		foreach my $monster (@{$self->{mapViewer}->{monsters}}) {
			if (distance($monster->{pos},{x=>$x,y=>$y}) <= ($config{wx_map_monsterSticking} || 1)) {
				$self->{mouseMapText} = TF("%s at %d, %d", Actor::get($monster->{ID}), $x, $y);
			}
		}
		foreach my $players (@{$self->{mapViewer}->{players}}) {
			if (distance($players->{pos},{x=>$x,y=>$y}) <= ($config{wx_map_playersSticking} || 1)) {
				$self->{mouseMapText} = TF("%s at %d, %d  -  Class: %s", Actor::get($players->{ID}), $x, $y, $jobs_lut{$players->{jobID}});
			}
		}
		foreach my $npc (@{$self->{mapViewer}->{npcs}}){
			if (distance($npc->{pos},{x=>$x,y=>$y}) <= ($config{wx_map_npcSticking} || 1)) {
				$self->{mouseMapText} = TF("%s at %d, %d", Actor::get($npc->{ID}), $x, $y);
			}
		}
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

	if ($currentChatRoom ne "") {
		$self->writeOutput("error", T("Error in function 'move' (Move Player)\n" .
										"Unable to walk while inside a chat room!\n" .
										"Use the command: chat leave\n"));
	} elsif ($shopstarted) {
		$self->writeOutput("error", T("Error in function 'move' (Move Player)\n" .
										"Unable to walk while the shop is open!\n" .
										"Use the command: closeshop\n"));
	} else {
		delete $self->{mouseMapText};
		if ($self->{mapViewer} && $self->{mapViewer}->{portals}
			&& $self->{mapViewer}->{portals}->{$field->baseName}
			&& @{$self->{mapViewer}->{portals}->{$field->baseName}}){

			foreach my $portal (@{$self->{mapViewer}->{portals}->{$field->baseName}}){
				if (distance($portal,{x=>$x,y=>$y}) <= ($config{wx_map_portalSticking} || 5)) {
					$x = $portal->{x};
					$y = $portal->{y};#{O}_{O}#
					$self->writeOutput("message", TF("Moving to Portal %s, %s\n", $x, $y), "info");
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
			$self->writeOutput("message", TF("Moving to %s, %s\n", $x, $y), "info") unless $checkPortal;
			AI::clear("mapRoute", "route", "move");
			main::ai_route($field->baseName, $x, $y, attackOnRoute => 1);
		}
		$self->{inputBox}->SetFocus;
	}
}

sub onMap_MapChange {
#vcl code	my (undef, undef, undef, $mapDock) = @_;
	my ($mapDock) = @_;
	$mapDock->title($field->baseName);
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

	if ($conState == Network::IN_GAME) {
		$messageSender->sendMacroDetectorAnswer($result);
	} else {
		$messageSender->sendCaptchaAnswer($result);
	}

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

1;
