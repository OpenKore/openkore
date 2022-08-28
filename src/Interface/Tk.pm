#########################################################################
#  OpenKore - Tk Interface
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
#########################################################################

# package
package Interface::Tk;

#perl imports
use strict;
use warnings;

use Carp qw/carp croak confess/;
use Time::HiRes qw/time usleep/;
use Tk;
use Tk::ROText;
use Tk::BrowseEntry;
use Tk::NoteBook;
use Tk::ProgressBar;
use Tk::TList;

# openkore imports
use Interface;
use base qw/Interface/;
use Plugins;
use Globals;
use Field;
use Settings;
use Misc;
use Utils qw /distance makeCoordsDir makeCoordsFromTo swrite timeOut/;

# global vars
our $line_limit = 1000;
our %fgcolors;
our $statText;
our @actorNameList;
our %actorIDList;
our @inventoryNameList;
our %inventoryIDList;
our $interface_timeout = {timeout => 0.5, time => time};

# Maps color names to color codes and font weights.
# Format: [R, G, B, bold]
%fgcolors = (
	'reset'		=> '#ffffff', #[255, 255, 255]
	'default'	=> '#ffffff', #[255, 255, 255]
	'input'   => '#c8c8c8', #[200, 200, 200],

	'black'		=> '#000000', #[0, 0, 0],
	'darkgray'	=> '#555555', #[85, 85, 85],
	'darkgrey'	=> '#555555', #[85, 85, 85],

	'darkred'	=> '#aa0000', #[170, 0, 0],
	'red'		=> '#ff0000', #[255, 0, 0, 1],

	'darkgreen'	=> '#00aa00', #[0, 170, 0],
	'green'		=> '#00ff00', #[0, 255, 0],

	'brown'		=> '#aa5500', #[170, 85, 0],
	'yellow'	=> '#ffff55', #[255, 255, 85],

	'darkblue'	=> '#5555ff', #[85, 85, 255],
	'blue'		=> '#7a9ae1', #[122, 154, 225],

	'darkmagenta'	=> '#aa00aa', #[170, 0, 170],
	'magenta'	=> '#ff55ff', #[255, 85, 255],

	'darkcyan'	=> '#00aaaa', #[0, 170, 170],
	'cyan'		=> '#55ffff', #[85, 255, 255],

	'gray'		=> '#222222', #[170, 170, 170],
	'grey'		=> '#222222', #[170, 170, 170],
	'white'		=> '#ffffff', #[255, 255, 255]
);

use constant {
	PC_TYPE => 0x0,
	NPC_TYPE => 0x1,
	ITEM_TYPE => 0x2,
	SKILL_TYPE => 0x3,
	UNKNOWN_TYPE => 0x4,
	NPC_MOB_TYPE => 0x5,
	NPC_EVT_TYPE => 0x6,
	NPC_PET_TYPE => 0x7,
	NPC_HO_TYPE => 0x8,
	NPC_MERSOL_TYPE => 0x9,
	NPC_ELEMENTAL_TYPE => 0xa
};

################################################################
# Public Method
################################################################

sub new {
	my $class = shift;

	my $self = {
		mw => undef,
		input_list => [],
		input_offset => 0,
		input_que => [],
		default_font=> "MS Sans Serif",
		input_type => "Command",
		input_pm => undef,
		total_lines => 0,
		last_line_end => 0,
		colors => {},
		is_bold => 0,
	};

	if ($^O eq 'MSWin32') {
		eval "use Win32::API;";
		$self->{ShellExecute} = new Win32::API("shell32", " ", "NPPPPN", "V");
	}

	if ($^O eq 'MSWin32') {
		$self->{default_font} = 'Lucida Console';
	} elsif ($^O eq 'freebsd') {
		$self->{default_font} = 'Monospace';
	} else {
		$self->{default_font} = 'MiscFixed';
	}

	bless $self, $class;

	$self->initTk;

	$self->addHooks;

	return $self;
}


####
# Interface overrided methods
###

sub getInput{
	my $self = shift;
	my $timeout = shift;
	my $msg;
	if ($timeout < 0) {
		until (defined $msg) {
			$self->update();
			if (@{ $self->{input_que} }) {
				$msg = shift @{ $self->{input_que} };
			}
		}
	} elsif ($timeout > 0) {
		my $end = time + $timeout;
		until ($end < time || defined $msg) {
			$self->update();
			if (@{ $self->{input_que} }) {
				$msg = shift @{ $self->{input_que} };
			}
		}
	} else {
		if (@{ $self->{input_que} }) {
			$msg = shift @{ $self->{input_que} };
		}
	}
	$self->update();
	$msg =~ s/\n// if defined $msg;
	return $msg;
}

sub update {
	my $self = shift;
	$interface_timeout->{'time'} = time;
	$self->{mw}->update();
	$self->updateStatus;

	if ($^O eq 'MSWin32' && $self->{SettingsObj}) {
		if ($self->{SettingsObj}->Wait(0)) {
			my $code;
			$self->{SettingsObj}->GetExitCode($code);
			Settings::parseReload("all") if $code == 0;
			delete $self->{SettingsObj};
		}
	}
}

sub writeOutput {
	my $self = shift;
	my $type = shift || '';
	my $message = shift || '';
	my $domain = shift || '';
	my ($color);

	# workaround to avoid console hang while loading file
	if(timeOut($interface_timeout)) {
		$interface_timeout->{'time'} = time;
		$self->{mw}->update();
	}

	$color = $consoleColors{$type}{$domain} if (defined $type && defined $domain && defined $consoleColors{$type});
	$color = $consoleColors{$type}{'default'} if (!defined $color && defined $type);
	$color = 'default' unless defined $color;

	my $scroll = 0;
	$scroll = 1 if (($self->{console}->yview)[1] == 1);

	#keep track of lines to limit the number of lines in the text widget
	$self->{total_lines} += $message =~ s/\r?\n/\n/g;
	
	$self->{console}->insert('end', "\n") if $self->{last_line_end};
	$self->{last_line_end} = $message =~ s/\n$//;
	
	$self->{console}->insert('end', $message, $color);

	#remove extra lines
	if ($self->{total_lines} > $line_limit) {
		my $overage = $self->{total_lines} - $line_limit;
		$self->{console}->delete('1.0', $overage+1 . ".0");
		$self->{total_lines} -= $overage;
	}

	$self->{console}->see('end') if $scroll;
	
	if ($domain eq "pm" || $domain eq "partychat" || $domain eq "pm/sent" || $domain eq "publicchat" || $domain eq "guildchat" || $domain eq "selfchat" || $domain eq "schat" || $domain eq "clanchat") {
		$self->{chatLog}->insert('end', $message, $color);
		$self->{chatLog}->insert('end', "\n");
	}
}

sub title {
	my $self = shift;
	my $title = shift;

	if (defined $title) {
		if (!defined $self->{currentTitle} || $self->{currentTitle} ne $title) {
			$self->{mw}->title($title);
			$self->{currentTitle} = $title;
		}
	} else {
		return $self->{mw}->title();
	}
}

sub errorDialog {
	my $self = shift;
	my $msg = shift;
	$self->{mw}->messageBox(
		-icon => 'error',
		-message => $msg,
		-title => 'Error',
		-type => 'Ok'
		);
}


################################################################
# Private? Method
################################################################
#FIXME many of thise methods don't support OO calls yet, update them and all their references
sub initTk {
	my $self = shift;
	
	# init window
	$self->{mw} = MainWindow->new();
	$self->{mw}->protocol('WM_DELETE_WINDOW', [\&OnExit, $self]);

	$self->{mw}->title("$Settings::NAME");
	$self->{mw}->minsize(700,500);

	$self->{mw}->iconbitmap('./src/build/openkore.ico');

	# init window content
	$self->initMenu;
	$self->initFrames;
	$self->fillFrames;
	$self->initAccelarator;
	$self->setColors;

	# show window
	$self->hideConsole;
	$self->{mw}->raise();
}

sub initMenu {
	my $self = shift;
	
	# Menu
	$self->{mw}->configure(-menu => $self->{mw}->Menu(-menuitems=>
	[ map
		['cascade', $_->[0], -tearoff=> 0, -menuitems => $_->[1]],

		# Program Menu
		["~$Settings::NAME",
			[
				[qw/command Respawn/, -command => sub{push(@{ $self->{input_que} }, "respawn");}],
				[qw/command CharSelect/, -command => sub{configModify ('char', undef, 1); push(@{ $self->{input_que} }, "charselect");}],
				[qw/command Relog/, -command => sub{push(@{ $self->{input_que} }, "relog");}],
				'',
				[qw/command Hide-To-Try  -accelerator Ctrl+X/, -command => sub{return;}],
				[qw/command E~xit  -accelerator Ctrl+W/, -command=>[\&OnExit]]
			]
		],

		# Info Menu
		['~Info',
			[
				[qw/command Status -accelerator Alt+V/, -command => sub{push(@{ $self->{input_que} }, "s");}],
				[qw/command Stat -accelerator Alt+A/, -command => sub{push(@{ $self->{input_que} }, "st");}],
				'',
				[qw/command Inventory -accelerator Alt+E/, -command => sub{push(@{ $self->{input_que} }, "i");}],
				[qw/command Cart -accelerator Alt+W/, -command =>sub{push(@{ $self->{input_que} }, "cart");}],
				[qw/command Equipment -accelerator Alt+Q/, -command =>sub{push(@{ $self->{input_que} }, "eq");}],
				[qw/command Storage -accelerator Alt+T/, -command =>sub{push(@{ $self->{input_que} }, "storage");}],
				'',
				[qw/command Skills -accelerator Alt+S/, -command => sub{push(@{ $self->{input_que} }, "skills");}],
				[qw/command Quests -accelerator Alt+U/, -command => sub{push(@{ $self->{input_que} }, "quest list");}],
				'',
				[qw/command Party -accelerator Alt+Z/, -command => sub{push(@{ $self->{input_que} }, "party");}],
				[qw/command Guild -accelerator Alt+G/, -command => sub{push(@{ $self->{input_que} }, "guild info");}],
				[qw/command Friends -accelerator Alt+H/, -command => sub{push(@{ $self->{input_que} }, "friend");}],
				[qw/command Clan -accelerator Ctrl+G/, -command => sub{push(@{ $self->{input_que} }, "clan info");}],
				'',
				[qw/command Pet -accelerator Alt+J/, -command => sub{push(@{ $self->{input_que} }, "pet s");}],
				[qw/command Homunculus -accelerator Alt+R/, -command => sub{push(@{ $self->{input_que} }, "homun s");}],
				[qw/command Mercenary -accelerator Ctrl+R/, -command => sub{push(@{ $self->{input_que} }, "merc s");}],
				'',
				[qw/command Rodex -accelerator Ctrl+T/, -command => sub{push(@{ $self->{input_que} }, "rodex open"); push(@{ $self->{input_que} }, "rodex list");}],
				[qw/command Bank -accelerator Ctrl+B/, -command => sub{push(@{ $self->{input_que} }, "skills");}],
				'',
				[qw/command Player-List -accelerator Alt+P/, -command => sub{push(@{ $self->{input_que} }, "pl");}],
				[qw/command Monster-List -accelerator Alt+M/, -command =>sub{push(@{ $self->{input_que} }, "ml");}],
				[qw/command NPC-List -accelerator Alt+N/, -command =>sub{push(@{ $self->{input_que} }, "nl");}],
				'',
				[qw/command Experience-Report/, -command => sub{push(@{ $self->{input_que} }, "exp");}],
				[qw/command Item-Report/, -command => sub{push(@{ $self->{input_que} }, "exp item");}],
				[qw/command Monster-Report/, -command => sub{push(@{ $self->{input_que} }, "exp monster");}],
				[qw/command Full-Report -accelerator Alt+X/, -command => sub{push(@{ $self->{input_que} }, "exp report");}],
				
			]
		],

		# View Menu
		['~View',
			[
				[qw/command Inventory/, -command => [\&OpenInventory, undef, $self]],
				[qw/command Map  -accelerator Ctrl+M/, -command => [\&OpenMap, undef, $self]],
				
			],
		],

		# Commands Menu
		['~Commands',
			[
				[qw/command Teleport/, -command => sub{push(@{ $self->{input_que} }, "tele");}],
				[qw/command Memo/, -command => sub{push(@{ $self->{input_que} }, "memo");}],
				[qw/command Respawn/, -command => sub{push(@{ $self->{input_que} }, "respawn");}],
				'',
				[qw/command Sit/, -command => sub{push(@{ $self->{input_que} }, "sit");}],
				[qw/command Stand/, -command => sub{push(@{ $self->{input_que} }, "stand up");}],
				'',
				[qw/command Auto-Store/, -command => sub{push(@{ $self->{input_que} }, "autostorage");}],
				[qw/command Auto-Sell/, -command => sub{push(@{ $self->{input_que} }, "autobuy");}],
				[qw/command Auto-Buy/, -command => sub{push(@{ $self->{input_que} }, "autosell");}],
				'',
				[cascade=>"AI", -tearoff=> 0, -menuitems =>
					[
						[qw/command Auto/, -command => sub{push(@{ $self->{input_que} }, "ai on");}],
						[qw/command Manual /, -command => sub{push(@{ $self->{input_que} }, "ai manual");}],
						[qw/command Off/, -command => sub{push(@{ $self->{input_que} }, "ai off");}],
					 ]
				],
				'',
				[cascade=>"Deal", -tearoff=> 0, -menuitems =>
					[
						[qw/command Accept/, -command => sub{push(@{ $self->{input_que} }, "deal");}],
						[qw/command Deny /, -command => sub{push(@{ $self->{input_que} }, "deal no");}],
						[qw/command OK/, -command => sub{push(@{ $self->{input_que} }, "deal");}],
					 ]
				],
				[cascade=>"Party", -tearoff=> 0, -menuitems =>
					[
						[qw/command Info/, -command => sub{push(@{ $self->{input_que} }, "party");}],
						[qw/command Leave /, -command => sub{push(@{ $self->{input_que} }, "party leave");}],
						[qw/command Share /, -command => sub{push(@{ $self->{input_que} }, "party share 1");}],
					 ]
				],
				[cascade=>"Guild", -tearoff=> 0, -menuitems =>
					[
						[qw/command Info/, -command => sub{push(@{ $self->{input_que} }, "guild info");}],
						[qw/command Members /, -command => sub{push(@{ $self->{input_que} }, "guild member");}],
						[qw/command Position/, -command => sub{push(@{ $self->{input_que} }, "guild p");}],
						[qw/command Leave/, -command => sub{push(@{ $self->{input_que} }, "guild leave");}],
					 ]
				],
				[cascade=>"Clan", -tearoff=> 0, -menuitems =>
					[
						[qw/command Info/, -command => sub{push(@{ $self->{input_que} }, "clan info");}],
					 ]
				],
				[cascade=>"Pet", -tearoff=> 0, -menuitems =>
					[
						[qw/command Info/, -command => sub{push(@{ $self->{input_que} }, "pet i");}],
						[qw/command Status /, -command => sub{push(@{ $self->{input_que} }, "pet s");}],
						[qw/command Feed/, -command => sub{push(@{ $self->{input_que} }, "pet f");}],
						[qw/command Return/, -command => sub{push(@{ $self->{input_que} }, "pet r");}],
					 ]
				],
				[cascade=>"Homunculus", -tearoff=> 0, -menuitems =>
					[
						[qw/command Status /, -command => sub{push(@{ $self->{input_que} }, "homun s");}],
						[qw/command Feed/, -command => sub{push(@{ $self->{input_que} }, "homun feed");}],
						[qw/command Skills/, -command => sub{push(@{ $self->{input_que} }, "homun skills");}],
						[qw/command AI/, -command => sub{push(@{ $self->{input_que} }, "homun ai");}],
					 ]
				],
				[cascade=>"Mercenary", -tearoff=> 0, -menuitems =>
					[
						[qw/command Status /, -command => sub{push(@{ $self->{input_que} }, "merc s");}],						
						[qw/command Skills/, -command => sub{push(@{ $self->{input_que} }, "merc skills");}],
						[qw/command AI/, -command => sub{push(@{ $self->{input_que} }, "merc ai");}],
						[qw/command Fire/, -command => sub{push(@{ $self->{input_que} }, "merc fire");}],
					]
				],
			],
		],

		# Settings Menu
		['~Settings',
			[
				[cascade=>"Attack", -tearoff=> 0, -menuitems =>
					[
						[qw/command Off(0)/, -command => sub{push(@{ $self->{input_que} }, "conf attackAuto 0");}],
						[qw/command React(1)/, -command => sub{push(@{ $self->{input_que} }, "conf attackAuto 1");}],
						[qw/command On(2)/, -command => sub{push(@{ $self->{input_que} }, "conf attackAuto 2");}],
					]
				],
				[cascade=>"Route", -tearoff=> 0, -menuitems =>
					[
						[qw/command Off(0)/, -command => sub{push(@{ $self->{input_que} }, "conf route_randomWalk  0");}],
						[qw/command RandomWalk(1)/, -command => sub{push(@{ $self->{input_que} }, "conf route_randomWalk  1");}],
					]
				],
				[cascade=>"Reload", -tearoff=> 0, -menuitems =>
					[
						[qw/command config/, -command => sub{push(@{ $self->{input_que} }, "reload conf");}],
						[qw/command mon_control/, -command => sub{push(@{ $self->{input_que} }, "reload mon_");}],
						[qw/command items_control/, -command => sub{push(@{ $self->{input_que} }, "reload items_");}],
						[qw/command cart_control/, -command => sub{push(@{ $self->{input_que} }, "reload cart_");}],
						[qw/command timeouts/, -command => sub{push(@{ $self->{input_que} }, "reload timeouts");}],
						[qw/command pickupitems/, -command => sub{push(@{ $self->{input_que} }, "reload pick");}],
						'',
						[qw/command All  -accelerator F5/, -command => sub{push(@{ $self->{input_que} }, "reload all");}],
					]
				],
				'',
				[cascade=>"Font Weight", -tearoff=> 0, -menuitems =>
					[
						[Checkbutton  => '~Bold', -variable => \$self->{is_bold}, -font=>[-size=>8],-command => [\&change_fontWeight]],
					]
				]			
			]
		],

		# Help Menu
		['~Help',
			[
				[qw/command Forum -accelerator F1/,			-command => [\&menuForumURL, $self] ],
				[qw/command Wiki  -accelerator Shift+F1/, 	-command => [\&menuWikiURL, $self] ],
				[qw/command Github/,			 			-command => [\&menuGithubURL, $self] ],
				'',
				[qw/command Report-Bug/,					-command => [\&menuGithubIssueURL, $self] ],
			]
		]
	]
	));
}


###
# Accelarators - bind
###

sub initAccelarator {
	my $self = shift;

	# Binding

	# In-Game commands
	$self->{mw}->bind('all','<Alt-v>' => sub{push(@{ $self->{input_que} }, "s");});
	$self->{mw}->bind('all','<Alt-a>' => sub{push(@{ $self->{input_que} }, "st");});
	$self->{mw}->bind('all','<Alt-s>' => sub{push(@{ $self->{input_que} }, "skills");});
	$self->{mw}->bind('all','<Alt-e>' => sub{push(@{ $self->{input_que} }, "i");});
	$self->{mw}->bind('all','<Alt-z>' => sub{push(@{ $self->{input_que} }, "party");});
	$self->{mw}->bind('all','<Alt-q>' => sub{push(@{ $self->{input_que} }, "i eq");});
	$self->{mw}->bind('all','<Alt-u>' => sub{push(@{ $self->{input_que} }, "quest list");});
	$self->{mw}->bind('all','<Alt-h>' => sub{push(@{ $self->{input_que} }, "friend");});
	$self->{mw}->bind('all','<Alt-w>' => sub{push(@{ $self->{input_que} }, "cart");});
	$self->{mw}->bind('all','<Alt-g>' => sub{push(@{ $self->{input_que} }, "guild info");});
	$self->{mw}->bind('all','<Alt-j>' => sub{push(@{ $self->{input_que} }, "pet s");});
	$self->{mw}->bind('all','<Alt-r>' => sub{push(@{ $self->{input_que} }, "homun s");});
	$self->{mw}->bind('all','<Control-r>' => sub{push(@{ $self->{input_que} }, "merc s");});
	$self->{mw}->bind('all','<Control-g>' => sub{push(@{ $self->{input_que} }, "clan info");});
	$self->{mw}->bind('all','<Control-b>' => sub{push(@{ $self->{input_que} }, "bank open");});
	$self->{mw}->bind('all','<Control-t>' => sub{push(@{ $self->{input_que} }, "rodex open"); push(@{ $self->{input_que} }, "rodex list");});

	# Custom commands
	$self->{mw}->bind('all','<Alt-p>' => sub{push(@{ $self->{input_que} }, "pl");});
	$self->{mw}->bind('all','<Alt-m>' => sub{push(@{ $self->{input_que} }, "ml");});
	$self->{mw}->bind('all','<Alt-n>' => sub{push(@{ $self->{input_que} }, "nl");});
	$self->{mw}->bind('all','<Alt-x>' => sub{push(@{ $self->{input_que} }, "exp report");});
	$self->{mw}->bind('all','<F5>' => sub{push(@{ $self->{input_que} }, "reload all");});
	

	# Window commands
	$self->{mw}->bind('all','<Control-w>' => sub{exit();});
	$self->{mw}->bind('all','<Control-m>' => [\&OpenMap, $self]);
	$self->{mw}->bind('all','<Tab>' => sub { $self->{input}->focus() } );
	$self->{input}->bind('<Up>' => [\&inputUp, $self]);
	$self->{input}->bind('<Down>' => [\&inputDown, $self]);
	$self->{input}->bind('<Return>' => [\&inputEnter, $self]);
	$self->{mw}->bind('all','<F1>' => [\&menuWikiURL, $self]);
	$self->{mw}->bind('all','<Shift-F1>' => [\&menuForumURL, $self]);
	$self->{mw}->bind('all','<Control-F4>' => sub {1;} ); # TODO: add hide to try here
	$self->{input}->focus();
	$self->{actor_list_box}->bind('<Double-Button-1>' => sub { $self->onActorListBoxClick($_[0]->curselection); });

	if ($^O eq 'MSWin32') {
		$self->{input}->bind('<MouseWheel>' => [\&w32mWheel, $self, Ev('k')]);
		$self->{console}->bind('<MouseWheel>' => [\&w32mWheel, $self, Ev('k')]);
	} else {
		#I forgot the X code. will insert later
	}
}

sub hideConsole {
	my $self = shift;
	if ($^O eq 'MSWin32') {
		# Hide Console
		my $console;
		eval 'use Win32::Console; $console = new Win32::Console(STD_OUTPUT_HANDLE);';
		$console->Free();
	}
}

###
# Init Frames - Frames Control
###

sub initFrames {
	my $self = shift;
	$self->{character_frame} = 	$self->{mw}->Frame()->pack(-side => 'top',-expand => 0,-fill => 'x',);
	$self->{character_info_frame} = 	$self->{character_frame}->Frame()->pack(-side => 'left',-expand => 0,-fill => 'y',);
	$self->{statuses} = 	$self->{mw}->Frame()->pack(-side => 'top',-expand => 0,-fill => 'x',);
	$self->{main_frame} = 		$self->{mw}->Frame()->pack(-side => 'top',-expand => 1,-fill => 'both',);
	$self->{input_frame} = 		$self->{mw}->Frame()->pack(-side => 'top',-expand => 0,-fill => 'x',);
	$self->{status_frame} = 	$self->{mw}->Frame()->pack(-side => 'top',-expand => 0,-fill => 'x',);
	$self->{console_frame} = 	$self->{main_frame}->Frame()->pack(-side => 'left',-expand => 1,-fill => 'both',);
	$self->{actor_list} = 	$self->{main_frame}->Frame()->pack(-side => 'right',-expand => 1,-fill => 'both',);
}


###
# Fill Frames
###

sub fillFrames {
	my $self = shift;
		
	#----- subclass in Character Frame
	
	#--- Character Info
	$self->{char_info} = $self->{character_info_frame}->Labelframe(
		-text => 'Character Info',
	)->pack(-side => 'left', -padx => 5, -pady => 5, -fill => 'y', -expand => 0);
	
	$self->{char_name} = $self->{char_info}->Label(
		-width => 30,
		-anchor => 'w',
		-text => 'Name:',
		-bd=>0,
		-relief => 'sunken',
	)->pack(
		-side => 'top',
		-expand => 0,
		-fill => 'x',
	);
	$self->{char_lvl_label} = $self->{char_info}->Label(
		-width => 30,
		-anchor => 'w',
		-text => 'Base: 0 / Job: 0',
		-bd=>0,
		-relief => 'sunken',
	)->pack(
		-side => 'top',
		-expand => 1,
		-fill => 'x',
	);
	$self->{char_job_name} = $self->{char_info}->Label(
		-width => 30,
		-anchor => 'w',
		-text => 'Job:',
		-bd=>0,
		-relief => 'sunken',
	)->pack(
		-side => 'top',
		-expand => 0,
		-fill => 'x',
	);
	$self->{char_sex_name} = $self->{char_info}->Label(
		-width => 30,
		-anchor => 'w',
		-text => 'Sex: ',
		-bd=>0,
		-relief => 'sunken',
	)->pack(
		-side => 'top',
		-expand => 0,
		-fill => 'x',
	);
	$self->{char_weight} = $self->{char_info}->Label(
		-width => 30,
		-anchor => 'w',
		-text => 'Weight: 0/0',
		-bd=>0,
		-relief => 'sunken',
	)->pack(
		-side => 'top',
		-expand => 0,
		-fill => 'x',
	);
	$self->{char_zeny} = $self->{char_info}->Label(
		-width => 30,
		-anchor => 'w',
		-text => 'Zeny: 0',
		-bd=>0,
		-relief => 'sunken',
	)->pack(
		-side => 'top',
		-expand => 0,
		-fill => 'x',
	);
	
	#--- Character Health
	$self->{char_health} = $self->{character_info_frame}->Labelframe(
			-text => 'Character Health',
		)->pack(-side => 'left', -padx => 5, -pady => 5, -fill => 'y', -expand => 0);

	$self->{char_hp_progressbar} = $self->{char_health}->ProgressBar(
		-width => 12,
		-length => 150,
		-anchor => 'w',
		-from => 0,
		-to => 100,
		-blocks => 0,
		-troughcolor => '#2D3D6D',
		-colors => [0, '#10EF21'],
		
    -variable => \$self->{progressbar_percert_hp}
	)->pack(
		-expand => 1,
		-side => 'top',
	);
	$self->{char_hp_progressbar}->value(0);
	$self->{char_hp_label} = $self->{char_health}->Label(
		-width => 24,
		-anchor => 'center',
		-text => '0/0 (0%)',
		-bd=>0,
		-relief => 'sunken',
	)->pack(
		-side => 'top',
		-expand => 1,
		-fill => 'x',
	);
	
	$self->{char_sp_progressbar} = $self->{char_health}->ProgressBar(
		-width => 12,
		-length => 150,
		-anchor => 'w',
		-from => 0,
		-to => 100,
		-blocks => 0,
		-troughcolor => '#2D3D6D',
		-colors => [0, '#1863DE'],
    -variable => \$self->{progressbar_percert_sp}
	)->pack(
		-expand => 1,
		-side => 'top',
	);
	$self->{char_sp_progressbar}->value(0);
	$self->{char_sp_label} = $self->{char_health}->Label(
		-width => 30,
		-anchor => 'center',
		-text => '0/0 (0%)',
		-bd=>0,
		-relief => 'sunken',
	)->pack(
		-side => 'top',
		-expand => 1,
		-fill => 'x',
	);

	#--- Character EXP
	$self->{char_exp} = $self->{character_info_frame}->Labelframe(
			-text => 'Character Exp',
		)->pack(-side => 'left', -padx => 5, -pady => 5, -fill => 'y', -expand => 0);
	
	$self->{char_base_exp_progressbar} = $self->{char_exp}->ProgressBar(
		-width => 15,
		-length => 150,
		-anchor => 'w',
		-from => 0,
		-to => 100,
		-blocks => 0,
		-colors => [0, '#3564C5'],
		
		-variable => \$self->{progressbar_percert_exp}
	)->pack(
		-expand => 1,
		-side => 'top',
	);
	$self->{char_base_exp_progressbar}->value(0);
	$self->{char_base_exp_label} = $self->{char_exp}->Label(
		-width => 30,
		-anchor => 'center',
		-text => '0/0 (0%)',
		-bd=>0,
		-relief => 'sunken',
	)->pack(
		-side => 'top',
		-expand => 1,
		-fill => 'x',
	);
	
	$self->{char_job_exp_progressbar} = $self->{char_exp}->ProgressBar(
		-width => 15,
		-length => 150,
		-anchor => 'w',
		-from => 0,
		-to => 100,
		-blocks => 0,
		-colors => [0, '#3564C5'],
		-variable => \$self->{progressbar_percert_exp_job}
	)->pack(
		-expand => 1,
		-side => 'top',
	);
	$self->{char_job_exp_progressbar}->value(0);
	$self->{char_job_exp_label} = $self->{char_exp}->Label(
		-width => 30,
		-anchor => 'center',
		-text => '0/0 (0%)',
		-bd=>0,
		-relief => 'sunken',
	)->pack(
		-side => 'top',
		-expand => 1,
		-fill => 'x',
	);
	
	#----- subclass in statuses
	$self->{status_string_label} = $self->{statuses}->Label(
		-anchor => 'w',
		-text => 'Status: ',
		-bd=> 0,
		-relief => 'sunken',
	)->pack(
		-side => 'left',
		-padx => 5, 
		-pady => 5,
		-expand => 0,
		-fill => 'x',
	);
	
	#------ subclass in console frame
	$self->{tabPane} = $self->{console_frame}->NoteBook()->pack(-expand => 1,-fill => 'both',-side => 'top',);
	
	# console pane
	$self->{consoleTab} = $self->{tabPane}->add("Console",-label=>'Console');
	$self->{console} = $self->{consoleTab}->Scrolled('ROText',-bg=>'black',-fg=>'grey',
		-scrollbars => 'e',
		-height => 15,
		-wrap => 'word',
		-width => 55,
		-insertontime => 0,
		-font=>[ -family => $self->{default_font}, -size=>10,],
		-relief => 'sunken',
	)->pack(
		-expand => 1,
		-fill => 'both',
		-side => 'top',
	);
	
	# chat 
	$self->{chatTab} = $self->{tabPane}->add("Chat",-label=>'Chat');
	$self->{chatLog} = $self->{chatTab}->Scrolled('ROText',-bg=>'black',-fg=>'grey',
		-scrollbars => 'e',
		-height => 15,
		-wrap => 'word',
		-width => 55,
		-insertontime => 0,
		-font=>[ -family => $self->{default_font},-size=>10,],
		-relief => 'sunken',
	)->pack(
		-expand => 1,
		-fill => 'both',
		-side => 'top',
	);
	
	$self->{actor_list_box} = $self->{actor_list}->Scrolled("Listbox", -scrollbars => "e", -selectmode => "single")->pack( -expand => 1,
		-fill => 'both',
		-side => 'top',
		-padx => 5,);
	tie @actorNameList, "Tk::Listbox", $self->{actor_list_box};

	#------ subclass in input frame
	$self->{pminput} = $self->{input_frame}->BrowseEntry(
		-bg => 'white',
		-variable => \$self->{input_pm},
		-width => 12,
		-choices => $self->{pm_list},
		-state =>'normal',
		-relief => 'sunken',
	)->pack(
		-expand=>0,
		-fill => 'x',
		-side => 'left',
	);

	$self->{input} = $self->{input_frame}->Entry(
		-bg => 'white',
		-relief => 'sunken',
		-font=>[ -family => $self->{default_font} ,-size=>8,],
	)->pack(
		-expand=>1,
		-fill => 'x',
		-side => 'left',
	);

	$self->{sinput} = $self->{input_frame}->BrowseEntry(
		-bg=>'white',
		-fg=>'black',
		-variable => \$self->{input_type},
		-choices => [qw(Command Public Party Guild Clan)],
		-width => 12,
		-state =>'readonly',
		-relief => 'sunken',
	)->pack	(
		-expand=>0,
		-fill => 'x',
		-side => 'left',
	);

	#------ subclass in status frame
	$self->{status_gen} = $self->{status_frame}->Label(
		-anchor => 'w',
		-text => 'Ready',
		-relief => 'groove',
	)->pack(
		-side => 'left',
		-expand => 1,
		-fill => 'x',
	);

	$self->{status_ai} = $self->{status_frame}->Label(
		-text => 'Ai - Status',
		-width => 60,
		-relief => 'groove',
	)->pack(
		-side => 'left',
		-expand => 0,
		-fill => 'x',
	);
	
	$self->{status_posMap} = $self->{status_frame}->Label(
		-text => '',
		-width => 20,
		-relief => 'groove',
	)->pack(
		-side => 'left',
		-expand => 0,
		-fill => 'x',
	);

	$self->{status_posx} = $self->{status_frame}->Label(
		-text => '0',
		-width => 5,
		-relief => 'groove',
	)->pack(
		-side => 'left',
		-expand => 0,
		-fill => 'x',
	);

	$self->{status_posy} = $self->{status_frame}->Label(
		-text => '0',
		-width => 5,
		-relief => 'groove',
	)->pack(
		-side => 'left',
		-expand => 0,
		-fill => 'x',
	);
}


###
# Keyboard Input Functions
###
sub inputUp {
	my $inputarea = shift; #this is redundant =\
	my $self = shift;

	my $line;

	chomp($line = $self->{input}->get);
	unless ($self->{input_offset}) {
		$self->{input_list}[$self->{input_offset}] = $line;
	}
	$self->{input_offset}++;
	$self->{input_offset} -= $#{$self->{input_list}} + 1 while $self->{input_offset} > $#{$self->{input_list}};

	$self->{input}->delete('0', 'end');
	$self->{input}->insert('end', "$self->{input_list}[$self->{input_offset}]");
}

sub inputDown {
	my $inputarea = shift; #this is redundant =\
	my $self = shift;

	my $line;

	chomp($line = $self->{input}->get);
	unless ($self->{input_offset}) {
		$self->{input_list}[$self->{input_offset}] = $line;
	}
	$self->{input_offset}--;
	$self->{input_offset} += $#{$self->{input_list}} + 1 while $self->{input_offset} < 0;

	$self->{input}->delete('0', 'end');
	$self->{input}->insert('end', "$self->{input_list}[$self->{input_offset}]");
}

sub inputEnter {
	my $inputarea = shift; #this is redundant =\
	my $self = shift;

	my $line;

	$line = $self->{input}->get;
	my $type = $self->{input_type};
	
	if (!defined $self->{input_pm} || $self->{input_pm} eq "") {
		if ($type eq 'Public') {
			$line = 'c '.$line;
		} elsif ($type eq 'Party') {
			$line = 'p '.$line;
		} elsif ($type eq 'Guild') {
			$line = 'g '.$line;
		} elsif ($type eq 'Clan') {
			$line = 'cln '.$line;
		}
	} else {
		$self->{pminput}->insert("end", $self->{input_pm});
		$line = "pm ".$self->{input_pm}." $line";
	}
	
	$self->{input}->delete('0', 'end');
	return unless defined $line;

	$self->{input_list}[0] = $line;
	unshift(@{$self->{input_list}}, "");
	$self->{input_offset} = 0;
	push(@{ $self->{input_que} }, $line);
}

sub inputPaste {
	my $inputarea = shift; #this is redundant =\
	my $self = shift;

	my $line;

	$line = $self->{input}->get;

	$self->{input}->delete('0', 'end');

	my @lines = split(/\n/, $line);
	$line = pop(@lines);
	push(@{ $self->{input_que} }, @lines);
	$self->{input}->insert('end', $line) if $line;
}

sub w32mWheel {
	my $action_area = shift;
	my $self = shift;
	my $zDist = shift;

	$self->{console}->yview('scroll', -int($zDist/40), "units");
}

sub OnExit{
	my $self = shift;
	if ($conState) {
		push(@{ $self->{input_que} }, "\n");
		quit();
	} else {
		exit();
	}
}

#######
#
# Menu onClick Handlers
#
#######
sub menuForumURL {
	my $url;
	if ($config{'forumURL'}) {
		$url = $config{'forumURL'};
	} else {
		$url = 'http://forums.openkore.com';
	}
	launchURL($url);
}

sub menuWikiURL {
	my $url;
	if ($config{'manualURL'}) {
		$url = $config{'manualURL'};
	} else {
		$url = 'http://wiki.openkore.com/index.php?title=Manual';
	}
	launchURL($url);
}

sub menuGithubURL {
	my $url;
	if ($config{'githubURL'}) {
		$url = $config{'githubURL'};
	} else {
		$url = 'https://github.com/OpenKore/openkore/';
	}
	launchURL($url);
}

sub menuGithubIssueURL {
	my $self = shift;
	my $url;
	if ($config{'githubIssueURL'}) {
		$url = $config{'githubIssueURL'};
	} else {
		$url = 'https://github.com/OpenKore/openkore/issues/new';
	}
	launchURL($url);
}

# FIXME, this sub is not changing the font to bold
sub change_fontWeight {
	my $self = shift;
	my $panelFont = $self->{default_font} || 'Segoe UI' || 'Verdana';
	if ($self->{is_bold}) {
		$self->{console}->configure(-font=>[-family => $panelFont ,-size=>10,-weight=>'bold']);
		$self->{chatLog}->configure(-font=>[-family => $panelFont ,-size=>10,-weight=>'bold']);
		$self->{input}->configure(-font=>[-family => $panelFont ,-size=>10,-weight=>'bold']);
	}else{
		$self->{console}->configure(-font=>[-family => $panelFont ,-size=>10,-weight=>'normal']);
		$self->{chatLog}->configure(-font=>[-family => $panelFont ,-size=>10,-weight=>'normal']);
		$self->{input}->configure(-font=>[-family => $panelFont ,-size=>10,-weight=>'normal']);
	}
}

sub onActorListBoxClick {
	my $self = shift;
	my $index = shift;

	if(defined($index) && $index >= 0) {
		foreach my $id (keys %actorIDList) {
			if($actorIDList{$id}{'listBoxIndex'} == $index) {
				my $actor = Actor::get($id);
				if ($actor->isa('Actor::Player')) {
					Log::warning("Requesting ".$actor->{name}." information\n");
					Commands::run("lookp " . $actor->{binID});
					Commands::run("pl " . $actor->{binID});

				} elsif ($actor->isa('Actor::Monster')) {
					Log::warning("Attacking ".$actor->{name}."\n");
					main::attack($actor->{ID});

				} elsif ($actor->isa('Actor::Item')) {
					Log::warning("Getting ".$actor->{name}."\n");
					main::take($actor->{ID});

				} elsif ($actor->isa('Actor::NPC')) {
					Log::warning("Talking with ".$actor->{name}."\n");
					Commands::run("talk " . $actor->{binID});

				} elsif ($actor->isa('Actor::Portal')) {
					Log::warning("Moving to the portal ".$actor->{name}."\n");
					Commands::run("move " . $actor->{binID});
				}

				$self->{input}->focus();
				last;
			}
		}		
	}
}


###
# Map Functions
###

sub OpenMap {
	my ($self, $param2) = @_;
	$self = $param2 if ($param2);

	return unless defined $field->baseName;

	if (!exists $self->{map}) {
		undef $self->{obj};
		$self->{map} = $self->{mw}->Toplevel();
		$self->{map}->transient($self->{mw});
		$self->{map}->title($field->baseName);
		$self->{map}->protocol('WM_DELETE_WINDOW', 
			sub {
				undef $self->{obj};
				$self->{map}->destroy();
				delete $self->{map};
			}
		);
		$self->{map}->resizable(0,0);
		$self->{map}->iconbitmap('./src/build/openkore.ico');
		$self->{map}{'canvas'} = $self->{map}->Canvas(-width => 200, -height => 200,-background => 'white')->pack(-side => 'top');
		$self->loadMap;
		$self->{map}->bind('<1>', [\&dblchk, $self, Ev('x') , Ev('y')]);
		$self->{map}->bind('<Motion>', [\&pointchk, $self, Ev('x') , Ev('y')]);
		$self->mapAddOtherPlayers;
		$self->mapAddMonsters;
		$self->mapAddSlaves;
		$self->mapAddNpcs;
		$self->mapAddParty;
		$self->mapAddGuild;
		$self->mapAddPortals;
	} else {
		undef $self->{obj};
		$self->{map}->destroy();
		delete $self->{map};
	}
}

sub OpenInventory {
	my ($self, $param2) = @_;
	$self = $param2 if ($param2);

	return unless defined $char;
	return unless $char->inventory->isReady();

	if (!exists $self->{inventory}) {
		$self->{inventory} = $self->{mw}->Toplevel();
		$self->{inventory}->transient($self->{mw});
		$self->{inventory}->title("Inventory View");
		$self->{inventory}->protocol('WM_DELETE_WINDOW', 
			sub {
				$self->{inventory}->destroy();
				delete $self->{inventory};
			}
		);
		$self->{inventory}->minsize(200,300);
		$self->{inventory}->geometry("200x300+".$self->{mw}->x."+".$self->{mw}->y);
		$self->{inventory}->iconbitmap('./src/build/openkore.ico');
		$self->{inventory_list_box} = $self->{inventory}->Scrolled("Listbox", -background => "white", -scrollbars => 'e', -selectmode => "single", -relief => 'groove',)->pack( -expand => 1,
		-fill => 'both',
		-side => 'top',
		-padx => 5);
		tie @inventoryNameList, "Tk::Listbox", $self->{inventory_list_box};

		$self->loadInventory;
		$self->{inventory_list_box}->bind( '<ButtonPress-3>', [ \&inventoryListBoxMenuContext, Ev('@'), $self, Ev('x'), Ev('y') ] );
	} else {
		$self->{inventory}->destroy();
		delete $self->{inventory};
	}
}


sub inventoryListBoxMenuContext {
    my ( $lb, $xy, $self, $x, $y ) = @_;

    $lb->selectionClear( 0, 'end' );
    my $index = $lb->index($xy);
	
	if(defined($index) && $index >= 0) {
		$lb->selectionSet($index);
		foreach my $id (keys %inventoryIDList) {
			if($inventoryIDList{$id}{'listBoxIndex'} == $index) {
				my $item = $char->inventory->getByID($id);
				my @menu_choices;
				Scalar::Util::weaken($item);
				
				if ($item->usable) {
					push(@menu_choices, [Button => "Use one on self",  -command => sub { $item->use; }]);
				}

				if ($item->equippable) {
					if ($item->{equipped}) {
						push(@menu_choices, [Button => "Unequip",  -command => sub { $item->unequip; }]);
					} elsif ($item->{identified}) {
						push(@menu_choices, [Button => "Equip",  -command => sub { $item->equip; }]);
					}
				}

				if ($item->mergeable) {
					push(@menu_choices, [Button => "Start card merging",  -command => sub { Commands::run ('card use ' . $item->{binID}); }]);
				}

				unless ($item->{equipped}) {
					push(@menu_choices, [Button => "Drop All",  -command => sub { Commands::run ('drop ' . $item->{binID} . ' ' . $item->{amount}); }]);
					if ($char->cart->isReady) {
						push(@menu_choices, [Button => "Move All to Cart",  -command => sub { Commands::run ('cart add ' . $item->{binID}); }]);
					}
					if ($char->storage->isReady) {
						push(@menu_choices, [Button => "Move All to Storage",  -command => sub { Commands::run ('storage add ' . $item->{binID}); }]);
					}
					push(@menu_choices, [Button => "Sell All",  -command => sub { Commands::run ('sell ' . $item->{binID} . ';;sell done'); }]);
				}

				my $menu = $lb->Menu(-tearoff => 0,-title=> $item->{name},
				  -menuitems => \@menu_choices,
				   );

				$x = $x + $self->{inventory}->x + 15;
				$y = $y + $self->{inventory}->y + 20;
				$menu->post($x, $y);
				last;
			}
		}
	}
}
	
sub loadInventory {
	my $self = shift;
	@inventoryNameList = ();
	%inventoryIDList = ();

	my @useable;
	my @equipment;
	my @uequipment;
	my @non_useable;

	for my $item (@{$char->inventory}) {
		if ($item->usable) {
			push @useable, $item->{binID};
		} elsif ($item->equippable && $item->{type_equip} != 0) {
			if ($item->{equipped}) {
				push @equipment,  $item->{binID};
			} else {
				push @uequipment,  $item->{binID};
			}
		} else {
			push @non_useable, $item->{binID};
		}
	}

	foreach my $index (@useable, @equipment, @uequipment, @non_useable) {
		my $item = $char->inventory->get($index);
		$inventoryIDList{$item->{ID}}{'listBoxIndex'} = @inventoryNameList;
		my $item_name =  " (" . $item->{binID} . ") " . $item->{name};
		if ($item->equippable && $item->{type_equip} != 0) {
			if ($item->{equipped}) {
				$item_name .= " - Equipped";
			} elsif (!$item->{identified}) {
				$item_name .= " - Not Identified";
			} else {
				$item_name .= " - Not Equipped";
			}
		} else {
			$item_name .= " x " .$item->{amount};
		}
		push(@inventoryNameList, $item_name);
	}
}

sub inventoryChanged {
	my $hookname = shift;
	my $args = shift;
	my $self = shift;

	return if(!$self->inventoryIsShown());
	$self->loadInventory;
}

sub inventoryIsShown {
	my $self = shift;
	return defined $self->{inventory};
}

sub inventoryClick {

}


# map image loader functions

sub _map {
	my $self = shift;
	return File::Spec->catfile($self->{mapDir}, @_);
}

sub loadMap {
	my $self = shift;
	return unless defined $field->baseName;
	return unless defined $self->{map}{'canvas'};
	$self->{map}{'canvas'}->delete('map');
	$self->{map}{'canvas'}->createText(50,20,-text =>'Processing..',-tags=>'map');

	my $name = $field->baseName;
	$self->{map}{'map'} = $self->{map}{'canvas'}->Photo(-format => 'xpm', -data => Utils::xpmmake($field->width, $field->height, $field->{rawMap}));

	$self->{map}{'canvas'}->delete('map');
	$self->{map}{'canvas'}->createImage(2,2,-image =>$self->{map}{'map'},-anchor => 'nw',-tags=>'map');
	$self->{map}{'canvas'}->configure(
			-width => $field->width,
			-height => $field->height
	);
	$self->{map}{'map'}{'x'} = $field->width;
	$self->{map}{'map'}{'y'} = $field->height;
}

# mouse moving over map viewer shows coordinates
sub pointchk {
	my $actionArea = shift;
	my $self = shift;
	my $mvcpx = $_[0];
	my $mvcpy = $self->{map}{'map'}{'y'} - $_[1];
	$self->{map}->title($field->name." \[$mvcpx , $mvcpy\]");
	$self->{map}->update;
}

# click on map viewer to move to coordinates
sub dblchk {
	my $actionarea = shift;
	my $self = shift;
	my $mvcpx = $_[0];
	my $mvcpy = $self->{map}{'map'}{'y'} - $_[1];
	
	if ($currentChatRoom ne "") {
		Log::error("Error in function 'move' (Move Player)\n" .
					"Unable to walk while inside a chat room!\n" .
					"Use the command: chat leave\n");
	} elsif ($shopstarted || $buyershopstarted) {
		Log::error("Error in function 'move' (Move Player)\n" .
										"Unable to walk while the shop/buying is open!\n" .
										"Use the command: closeshop or closebuyershop\n");
	} elsif (AI::is("NPC")) {
		Log::error("Error in function 'move' (Move Player)\n" .
										"Unable to walk while talking NPC!\n" .
										"Please finish the NPC conversation\n");
	} else {
		if($self->{portals} && $self->{portals}->{$field->baseName} && @{$self->{portals}->{$field->baseName}}) {
			foreach my $portal (@{$self->{portals}->{$field->baseName}}){
				if (distance($portal,{x=>$mvcpx,y=>$mvcpy}) <= 8) {
					$mvcpx = $portal->{x};
					$mvcpy = $portal->{y};
					Log::message("Moving to Portal $mvcpx, $mvcpy\n");
					last;
				}
			}
		}
		push(@{$self->{input_que}}, "move $mvcpx $mvcpy"); 
	}
} 

sub mapIsShown {
	my $self = shift;
	return defined $self->{map};
}

sub addObj {
	my $self = shift;
	my ($id,$type,$x,$y) = @_;
	my ($fg,$bg);
	return if (!$self->mapIsShown());
	
	if ($type eq "self") {
		$fg = "#97F9F9";
		$bg = "#222222";
	} elsif ($type eq "npc") {
		$fg = "#b400ff";
		$bg = "#222222";
	} elsif ($type eq "monster") {
		$fg = "#ff1500";
		$bg = "#222222";
	} elsif ($type eq "player") {
		$fg = "#5EFC8D";
		$bg = "#222222";
	} elsif ($type eq "slave") {
		$fg = "#FFFFCC";
		$bg = "#222222";
	} elsif ($type eq "party") {
		$fg = "#bbd196";
		$bg = "#222222";
	} elsif ($type eq "guild") {
		$fg = "#ffc1f3";
		$bg = "#222222";
	} elsif ($type eq "portal") {
		$fg = "#ff6b26";
		$bg = "#222222";
	} else {
		$fg = "#ffff00";
		$bg = "#222222";
	}
	$self->{obj}{$type}{$id} = $self->{map}{'canvas'}->createOval(
			$x-4,$self->{map}{'map'}{'y'} - $y-4,
			$x+4,$self->{map}{'map'}{'y'} - $y+4,
			,-fill => $fg, -outline=> $bg); 
}

sub moveObj {
	my $self = shift;
	return if (!$self->mapIsShown());
	my ($id,$type,$x,$y,,$newy) = @_;

	if ($self->{obj}{$type}{$id}){
		$self->{map}{'canvas'}->delete($self->{obj}{$type}{$id});
	}

	$self->addObj($id, $type, $x, $y);
}

sub moveObjByID {
	my $self = shift;
	return if (!$self->mapIsShown());
	my ($id,$x,$y,,$newy) = @_;
	my $type;

	foreach (keys %{$self->{obj}}) {
		$type = $_;
		foreach (keys %{$self->{obj}{$_}}) {
			my $current_id = $_;
			if($current_id eq $id) {
				$self->{map}{'canvas'}->delete($self->{obj}{$type}{$current_id}) if ($self->{obj}{$type}{$current_id});
				delete $self->{obj}{$type}{$current_id};
				$self->addObj($id, $type, $x, $y);
				last;
			}
		}
	}
}

sub removeObj {
	my $self = shift;
	my ($id) = shift;
	my ($type) = shift;
	return if (!$self->{obj}{$type}{$id} || !$self->mapIsShown());
	$self->{map}{'canvas'}->delete($self->{obj}{$type}{$id});
	delete $self->{obj}{$type}{$id};
}

sub removeObjByID {
	my $self = shift;
	my ($id) = shift;
	foreach (keys %{$self->{obj}}) {
		my $type = $_;
		foreach (keys %{$self->{obj}{$_}}) {
			my $current_id = $_;
			if($current_id eq $id) {
				$self->{map}{'canvas'}->delete($self->{obj}{$type}{$current_id}) if ($self->{obj}{$type}{$current_id});
				delete $self->{obj}{$type}{$current_id};
				last;
			}
		}
	}
}

sub removeAllObj {
	my $self = shift;
	return if (!$self->mapIsShown());
	foreach (keys %{$self->{obj}}) {
		my $type = $_;
		foreach (keys %{$self->{obj}{$_}}) {
			my $id = $_;
			$self->{map}{'canvas'}->delete($self->{obj}{$type}{$id}) if ($self->{obj}{$type}{$id});
			undef $self->{obj}{$type}{$id};
		}
	}
}

sub parsePortals {
	my $hookname = shift;
	my $args = shift;
	my $self = shift;

	delete $self->{portals};

	foreach my $portal (keys %portals_lut) {
		foreach my $dest (keys %{$portals_lut{$portal}{dest}}) {
			next if $portals_lut{$portal}{dest}{$dest}{map} eq '';
			if ($portals_lut{$portal}{dest}{$dest}{steps}) {
				# this is a Warp NPC
				push (@{$self->{portals}->{$portals_lut{$portal}{source}{map}}}, {
					x => $portals_lut{$portal}{source}{x},
					y => $portals_lut{$portal}{source}{y},
					npcType => '1',
				});
			last;
			} else {
				# this is a portal
				push (@{$self->{portals}->{$portals_lut{$portal}{source}{map}}}, {
					x => $portals_lut{$portal}{source}{x},
					y => $portals_lut{$portal}{source}{y},
					destination => {
						field => $portals_lut{$portal}{dest}{$dest}{map},
						x => $portals_lut{$portal}{dest}{$dest}{x},
						y => $portals_lut{$portal}{dest}{$dest}{y},
					},
				});
			}
		}
	}
}

sub mapAddOtherPlayers {
	my $self = shift;
	return if (!$self->mapIsShown());

	foreach my $actor (@{$playersList->getItems()}) {
		$self->addObj($actor->{ID}, "player", $actor->{pos_to}{x}, $actor->{pos_to}{y});
	}
}

sub mapAddMonsters {
	my $self = shift;
	return if (!$self->mapIsShown());

	foreach my $actor (@{$monstersList->getItems()}) {
		$self->addObj($actor->{ID}, "monster", $actor->{pos_to}{x}, $actor->{pos_to}{y});
	}
}

sub mapAddSlaves {
	my $self = shift;
	return if (!$self->mapIsShown());
	return;
}

sub mapAddParty {
	my $self = shift;
	return if (!$self->mapIsShown());
	return;
}

sub mapAddGuild {
	my $self = shift;
	return if (!$self->mapIsShown());
	return;
}

sub mapAddNpcs {
	my $self = shift;
	foreach my $actor (@{$npcsList->getItems()}) {
		$self->addObj($actor->{ID}, "npc", $actor->{pos}{x}, $actor->{pos}{y});
	}
}

sub mapAddPortals {
	my $self = shift;
	my $id = 0;
	if ($self->{portals} && $self->{portals}->{$field->baseName} && @{$self->{portals}->{$field->baseName}}) {
		foreach my $pos (@{$self->{portals}->{$field->baseName}}) {
			if ($pos->{npcType}) {
				# TODO: check if the npc is already in sight
			} else {
				$self->addObj($id, "portal", $pos->{x}, $pos->{y});
				$id++;
			}			
		}
	}
}

# FIXME: the color specified here is never used
sub followObj {
	my $self = shift;
	return if (!$self->mapIsShown());
	my ($id, $type) = @_;
	$self->{objc}{$id}[0] = "#FFCCFF";
	$self->{objc}{$id}[1] = "#CC00CC";
}


###
# OpenKore Hooks - update info section
####

sub addHooks {
	my $self = shift;
	Plugins::addHook('mainLoop_pre',						\&updateHook, $self);
	Plugins::addHook('postloadfiles',						\&parsePortals, $self);
	Plugins::addHook('packet/actor_exists',					\&mapAddActor, $self);
	Plugins::addHook('packet/actor_connected',				\&mapAddActor, $self);
	Plugins::addHook('packet/actor_spawned',				\&mapAddActor, $self);
	Plugins::addHook('packet/actor_display',				\&mapMoveActor, $self);
	Plugins::addHook('packet/actor_moved',					\&mapMoveActor, $self);
	Plugins::addHook('packet/actor_died_or_disappeared',	\&mapRemoveActor, $self);
	Plugins::addHook('packet/map_change', 					\&mapChangeUpdateInferface, $self);
	Plugins::addHook('packet/map_changed', 					\&mapChangeUpdateInferface, $self);
	Plugins::addHook('packet/map_loaded', 					\&mapChangeUpdateInferface, $self);
	Plugins::addHook('packet/item_exists', 					\&mapAddActor, $self);
	Plugins::addHook('packet/item_appeared', 				\&mapAddActor, $self);
	Plugins::addHook('packet/item_disappeared', 			\&mapRemoveActor, $self);
	Plugins::addHook('packet/arrow_equipped',               \&inventoryChanged, $self);
	Plugins::addHook('packet/card_merge_status',            \&inventoryChanged, $self);
	Plugins::addHook('packet/deal_add_you',                 \&inventoryChanged, $self);
	Plugins::addHook('packet/equip_item',                   \&inventoryChanged, $self);
	Plugins::addHook('packet/identify',                     \&inventoryChanged, $self);
	Plugins::addHook('packet/inventory_item_added',         \&inventoryChanged, $self);
	Plugins::addHook('packet/inventory_item_removed',       \&inventoryChanged, $self);
	Plugins::addHook('packet_useitem',                      \&inventoryChanged, $self);
	Plugins::addHook('packet/inventory_items_nonstackable', \&inventoryChanged, $self);
	Plugins::addHook('packet/inventory_items_stackable',    \&inventoryChanged, $self);
	Plugins::addHook('packet/item_upgrade',                 \&inventoryChanged, $self);
	Plugins::addHook('packet/unequip_item',                 \&inventoryChanged, $self);
	Plugins::addHook('packet/use_item',                     \&inventoryChanged, $self);
	Plugins::addHook('packet/mail_send',                    \&inventoryChanged, $self);
	Plugins::addHook('packet/item_list_end',                \&inventoryChanged, $self);
}

sub mapAddActor {
	my $hookname = shift;
	my $args = shift;
	my $self = shift;

	my $actor = Actor::get($args->{ID});

	unless ($actor->isa('Actor::Item')) {
		my $object_type = $args->{object_type} || $actor->{type};
		my $type = $args->{type} || $actor->{type};

		my $type_name = $self->defineType($object_type, $type, $actor->{hair_style});
		$self->addObj($args->{ID}, $type_name, $actor->{pos}{x}, $actor->{pos}{y}) if ($self->mapIsShown());
	}

	$self->updateListBox($actor);
}

sub mapMoveActor {
	my $hookname = shift;
	my $args = shift;
	my $self = shift;

	my $actor = Actor::get($args->{ID});
	my $object_type = $args->{object_type} || $actor->{type};
	my $type = $args->{type} || $actor->{type};

	my $type_name = $self->defineType($object_type, $type, $actor->{hair_style});

	$self->updateListBox($actor);

	my (%coordsFrom, %coordsTo);
	makeCoordsFromTo(\%coordsFrom, \%coordsTo, $args->{coords});
	if(defined $args->{object_type}) {
		my $type_name = $self->defineType($args->{object_type}, $args->{type}, $args->{hair_style});
		$self->moveObj($args->{ID}, $type_name, $coordsFrom{x}, $coordsFrom{y}, $coordsTo{x}, $coordsTo{y});
	} else {
		$self->moveObjByID($args->{ID}, $coordsFrom{x}, $coordsFrom{y}, $coordsTo{x}, $coordsTo{y});
	}
}

sub mapRemoveActor {
	my $hookname = shift;
	my $args = shift;
	my $self = shift;
	my $actor = Actor::get($args->{ID});

	$self->removeActorListBoxByID($args->{ID});

	unless ($actor->isa('Actor::Item')) {
		$self->removeObjByID($args->{ID}) if ($self->mapIsShown());
	}
}

sub mapChangeUpdateInferface {
	my $hookname = shift;
	my $args = shift;
	my $self = shift;

	$self->clearActorListBox;

	if ($self->mapIsShown()) {
		$self->removeAllObj;
		$self->loadMap;
		$self->{map}->title($field->baseName);
		$self->mapAddPortals;
	}
	
	if ($self->inventoryIsShown()) {
		$self->loadInventory;
	}
}

sub removeActorListBoxByID {
	my $self = shift;
	my $id = shift;

	delete $actorIDList{$id};
	$self->updateListBox;
}

sub updateListBox {
	my $self = shift;
	%actorIDList = ();
	@actorNameList = ();
	foreach my $list ($npcsList, $playersList, $monstersList, $itemsList, $portalsList) {
		foreach my $actor (@{$list->getItems()}) {
			$actorIDList{$actor->{ID}}{'listBoxIndex'} = @actorNameList;

			# Item with amount ("10 x Blue Herb")
			my $actor_name = $actor->{name};
			$actor_name = $actor->{amount}. " x ". $actor_name if ($actor->{amount} > 1);
			
			my $x = $actor->{pos_to}{x} || $actor->{pos}{x};
			my $y = $actor->{pos_to}{y} || $actor->{pos}{y};
			my $name = swrite("@<< @* (@<<, @<<)", [$actor->{binID}, $actor_name, $x, $y]);
			push(@actorNameList, $name);
			my $fg = "#000000";
			if ($actor->isa('Actor::NPC')) {
				$fg = "#b400ff";
			} elsif ($actor->isa('Actor::Portal')) {
				$fg = "#ff6b26";
			} elsif ($actor->isa('Actor::Monster')) {
				$fg = "#ff6242";
			} elsif ($actor->isa('Actor::Item')) {
				$fg = "#4169e1";
			}
			$self->{actor_list_box}->itemconfigure($self->{actor_list_box}->size()-1, -foreground=> $fg);
		}
	}
}

sub clearActorListBox {
	%actorIDList = ();
	@actorNameList = ();
}

sub setColors {
	my $self = shift;

	my %gdefault = (-foreground => 'black', -background => 'white');
	my %consoledefault = (-foreground => 'grey', -background => 'black');
	eval {
		$self->{console}->configure(%consoledefault);
		$self->{input}->configure(%gdefault);
		$self->{pminput}->configure(%gdefault);
		$self->{sinput}->configure(%gdefault);
	};
	if ($@) {
		if ($@ =~ /unknown color name "(.*)" at/) {
			Log::message("Color '$1' not recognised.\n");
			return undef if !$consoleColors{''}{'useColors'}; #don't bother throwing a lot of errors in the next section.
		} else {
			die $@;
		}
	}

	while (my ($color, $value) = each (%fgcolors)) {
		$self->{console}->tagConfigure($color, -foreground => $value);
		$self->{chatLog}->tagConfigure($color, -foreground => $value);
	}
}

sub updateHook {
	my $hookname = shift;
	my $args = shift;
	my $self = shift;
	return unless defined $self->{mw};
	$self->updateCharacter;
	$self->updatePos();
	$interface_timeout->{'time'} = time;
	$self->{mw}->update();
	$self->setAiText("@ai_seq");
}

sub updateCharacter {
		my $self = shift;
		return unless defined($char) && defined($char->{'weight'} && defined($char->{'exp'}));
		#---- Character Info
		$self->{char_name}->configure( -text => "Name: " . $char->{'name'});
		$self->{char_job_name}->configure( -text => "Job: " . $jobs_lut{$char->{'jobID'}});
		$self->{char_sex_name}->configure( -text => "Sex: " . $sex_lut{$char->{'sex'}});
		$self->{char_weight}->configure( -text => "Weight: $char->{'weight'} / $char->{'weight_max'}");
		$self->{char_zeny}->configure( -text => "Zeny: " . $char->{'zeny'});
		
		#---- Character Health
		my $percent_hp = sprintf("%i", $char->{'hp'} * 100 / $char->{'hp_max'});	
		my $percent_sp = sprintf("%i", $char->{'sp'} * 100 / $char->{'sp_max'});

		$self->{progressbar_percert_hp} = $percent_hp;
		$self->{char_hp_label}->configure( -text => "$char->{'hp'} / $char->{'hp_max'} ($percent_hp %)");
		$self->{progressbar_percert_sp} = $percent_sp;
		$self->{char_sp_label}->configure( -text => "$char->{'sp'} / $char->{'sp_max'} ($percent_sp %)");
		
		if ($percent_sp < 20) {
			$self->{char_hp_progressbar}->configure(-colors => [0, '#FF5959']);
		} elsif ($percent_sp < 50) {
			$self->{char_hp_progressbar}->configure(-colors => [0, '#DFDF00']);
		} else {
			$self->{char_hp_progressbar}->configure(-colors => [0, '#10EF21']);
		}
		Tk::ProgressBar::_layoutRequest($self->{char_hp_progressbar}, 1);
		
		# #---- Character Exp
		my ($percent_base_lv, $percent_job_lv);
		if (!$char->{'exp_max'}) {
			$percent_base_lv = 0;
		} else {
			$percent_base_lv = sprintf("%i", $char->{'exp'} * 100 / $char->{'exp_max'});
		}
		
		if (!$char->{'exp_job_max'}) {
			$percent_job_lv = 0;
		} else {
			$percent_job_lv = sprintf("%i", $char->{'exp_job'} * 100 / $char->{'exp_job_max'});
		}
		$self->{char_lvl_label}->configure( -text => "Base: $char->{'lv'} / Job: $char->{'lv_job'}");
		$self->{progressbar_percert_exp} = $percent_base_lv;
		$self->{char_base_exp_label}->configure( -text => "$char->{'exp'} / $char->{'exp_max'} ($percent_base_lv %)");
		$self->{progressbar_percert_exp_job} = $percent_job_lv;
		$self->{char_job_exp_label}->configure( -text => "$char->{'exp_job'} / $char->{'exp_job_max'} ($percent_job_lv %)");
		$self->{status_string_label}->configure( -text => "Status: ".$char->statusesString);
}

sub updatePos {
	my $self = shift;
	return unless (defined $char && defined $char->{pos_to});
	my ($x,$y) = @{$char->{pos_to}}{'x', 'y'};
	$self->{status_posx}->configure( -text =>$x);
	$self->{status_posy}->configure( -text =>$y);
	$self->{status_posMap}->configure( -text => $field->baseName) if defined $field->baseName;
	if ($self->mapIsShown()) {
		# show player coords
		$self->{map}{'canvas'}->delete($self->{obj}{'self'}{$accountID}) if ($self->{obj}{'self'}{$accountID});
		$self->{obj}{'self'}{$accountID} = $self->{map}{'canvas'}->createOval(
			$x-4,$self->{map}{'map'}{'y'} - $y-4,
			$x+4,$self->{map}{'map'}{'y'} - $y+4,
			,-fill => '#97F9F9', -outline=>'#222222');
		$self->{map}{'canvas'}->delete($self->{map}{'dest'}) if ($self->{map}{'dest'});

		# show route destination
		my $action = AI::findAction("route");
		if (defined $action) {
			my $args = AI::args($action);
			if ($args->{dest}{map} eq $field->baseName) {
				my ($x,$y) = @{$args->{dest}{pos}}{'x', 'y'};
				$self->{map}{'dest'} = $self->{map}{'canvas'}->createOval(
					$x-4,$self->{map}{'map'}{'y'} - $y-4,
					$x+4,$self->{map}{'map'}{'y'} - $y+4,
					,-fill => '#FD95EA', -outline=>'#222222');
			}
		}
		my ($i, $args, $routeTask, $solution);
		if (
			defined ($i = AI::findAction ('route')) && ($args = AI::args ($i)) && (
				($routeTask = $args->getSubtask) && %{$routeTask} && ($solution = $routeTask->{solution}) && @$solution
				||
				$args->{dest} && $args->{dest}{pos} && ($solution = [{x => $args->{dest}{pos}{x}, y => $args->{dest}{pos}{y}}])
			)
		) {
			$self->{route} = [@$solution];
		}
		if ($self->{route} && @{$self->{route}}) {
			$self->mapClearRoute;
			$i = 0;
			my $index = 1;
			for (grep {not $i++ % (8 * 2)} reverse @{$self->{route}}) {
				($x, $y) = ($_->{x}, $_->{y});
				$self->{obj}{'route'}{$index} = $self->{map}{'canvas'}->createOval(
						$x-2,$self->{map}{'map'}{'y'} - $y-2,
						$x+2,$self->{map}{'map'}{'y'} - $y+2,
						,-fill => '#FFA1EE', -outline=>'#FFA1EE');
					$index++;
			}
			undef $self->{route};
		}

		# show circle of attack range
		# $self->{map}{'canvas'}->delete($self->{map}{'range'}) if ($self->{map}{'range'});
		# my $dis = $config{'attackDistance'};
		# $self->{map}{'range'} = $self->{map}{'canvas'}->createOval(
			# $x-$dis,$self->{map}{'map'}{'y'} - $y-$dis,
			# $x+$dis,$self->{map}{'map'}{'y'} - $y+$dis,
			# ,-outline=>'#ff0000');
	}
}

sub mapClearRoute {
	my $self = shift;
	return if (!$self->mapIsShown());
	foreach (keys %{$self->{obj}{'route'}}) {
		my $id = $_;
		$self->{map}{'canvas'}->delete($self->{obj}{'route'}{$id});
		undef $self->{obj}{'route'}{$id};
	}
}

sub updateStatus {
	my $self = shift;
	my $oldStatText = $statText || '';
	if (!$conState) {
		$statText = "Initializing...";
	} elsif ($conState == 1) {
		$statText = "Not connected";
	} elsif ($conState > 1 && $conState < 5) {
		$statText = "Connecting...";
	} else {
		$statText = "Connected";
	}
	if($oldStatText ne $statText) {
		$self->{status_gen}->configure( -text => $statText);
	}
}

sub setTitle {
	my $self = shift;
	my $text = shift;
	$self->{mw}->title($text);
}

sub setAiText {
	my $self = shift;
	my ($text) = shift;
	$self->{status_ai}->configure(-text => $text);
}

sub addPM {
	my $self = shift;
	my $input_name = shift;
	my $found=1;
	my @pm_list = $self->{pminput}->cget('-choices');
	foreach (@pm_list){
		if ($_ eq $input_name) {
			$found = 0;
			last;
		}
	}
	if ($found) {
		$self->{pminput}->insert("end",$input_name);
	}
}

sub defineType {
	my $self = shift;
	my $object_type = shift;
	my $type = shift;
	my $hair_style = shift;

	my $object_class;
	if (defined $object_type) {
		if ($type == 45) { # portals use the same object_type as NPCs
			$object_class = 'portal';
		} else {
			$object_class = {
				PC_TYPE, 'player',
				# NPC_TYPE? # not encountered, NPCs are NPC_EVT_TYPE
				# SKILL_TYPE? # not encountered
				# UNKNOWN_TYPE? # not encountered
				NPC_MOB_TYPE, 'monster',
				NPC_EVT_TYPE, 'npc', # both NPCs and portals
				NPC_PET_TYPE, 'slave',
				NPC_HO_TYPE, 'slave',
				NPC_MERSOL_TYPE, 'slave',
				NPC_ELEMENTAL_TYPE, 'slave', # Sorcerer's Spirit
			}->{$object_type};
		}
	}

	unless (defined $object_class) {
		if ($jobs_lut{$type}) {
			if ($type <= 6000) {
				$object_class = 'player';
			} elsif (($type >= 6001 && $type <= 6016) || ($type >= 6048 && $type <= 6052)) {
				$object_class = 'slave';
			} elsif ($$type >= 6017 && $$type <= 6046) {
				$object_class = 'slave';
			} else {
				$object_class = 'monster';
			}
		} elsif ($type == 45) {
			$object_class = 'portal';
		} elsif ($type >= 1000) {
			if ($hair_style == 0x64) {
				$object_class = 'slave';
			} else {
				$object_class = 'monster';
			}
		} else {   # ($type < 1000 && $type != 45 && !$jobs_lut{$type})
			$object_class = 'npc';
		}
	}

	return $object_class || "monster";
}

1;
