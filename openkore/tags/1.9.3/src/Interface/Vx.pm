#########################################################################
#  OpenKore :: Vx Interface Module
#  Based on OO
#  Originally By Star-Kung - http://modkore.sourceforge.net.
#
#  Copyright (c) 2005 OpenKore development team 
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

package Interface::Vx;
use strict;
use warnings;

use AI;
use Interface;
use base qw/Interface/;
use Plugins;
use Globals;
use Field;
use Settings qw(%sys);
use Misc;
use Utils;
#use Log qw(message warning);

use Carp qw/carp croak confess/;
use File::Spec;
use Time::HiRes qw/time usleep/;
use Tk;
use Tk::ROText;
use Tk::BrowseEntry;

# parse panelTwo_domains into a hash
my %panelTwo_domains;
$sys{panelTwo_domains} ||= "publicchat, pm, guildchat, partychat, pm/sent, list, info, selfchat, schat, error, warning";
my @array = split / *, */, $sys{panelTwo_domains};
foreach (@array) {
	s/^\s+//;
	s/\s+$//;
	s/\s+/ /g;
	$panelTwo_domains{$_} = 1;
}

my $buildType = 1;
# main interface functions

sub new {
	my $class = shift;
	my $self = {
		input_list => [], # input history
		input_offset => 0, # position while scrolling through input history
		input_que => [], # queued input data
		default_font => "MS Sans Serif",
		input_type => "Command",
		input_pm => undef,
		total_lines => {"panelOne" => 0, "panelTwo" => 0},
		last_line_end => {"panelOne" => 0, "panelTwo" => 0},
		line_limit => {"panelOne" => $sys{panelOne_lineLimit} || 900, "panelTwo" => $sys{panelTwo_lineLimit} || 100},
		mapDir => 'map'
	};

	if ($buildType == 0) {
		eval "use Win32::API;";
		$self->{ShellExecute} = new Win32::API("shell32", "ShellExecute",
			"NPPPPN", "V");
	}

	bless $self, $class;
	$self->initTk;

	$self->{hooks} = Plugins::addHooks(
		['mainLoop_pre',		\&updateHook,	$self],
		['postloadfiles',		\&resetColors,	$self],
		['parseMsg/pre', 		\&packet,		$self],
		['attack_start',		sub { $_[2]->followObj($_[1]->{ID}); }, $self]
	);
	return $self;
}

sub DESTROY {
	my $self = shift;
	Plugins::delHooks($self->{hooks});
}

sub update {
	my $self = shift;
	$self->{mw}->update();
}

sub getInput {
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

sub writeOutput {
	my $self = shift;
	my $type = shift || '';
	my $message = shift || '';
	my $domain = shift || '';

	my $panel;
	# FIXME: you can put message types like error and warning in the list because I wanted to see them
	# FIXME: a default list of domains should be given to the user if they didn't configure any
	if ($panelTwo_domains{$domain} || ($domain eq 'console' && $panelTwo_domains{$type})) {
		$panel = "panelTwo";
	} else {
		$panel = "panelOne";
	}

	my $scroll = 0;
	$scroll = 1 if (($self->{$panel}->yview)[1] == 1);
	
	#keep track of lines to limit the number of lines in the text widget
	$self->{total_lines}{panel} += $message =~ s/\r?\n/\n/g;

	$self->{$panel}->insert('end', "\n") if $self->{last_line_end}{$panel};
	$self->{last_line_end}{$panel} = $message =~ s/\n$//;

	$self->{$panel}->insert('end', $message, "$type $type.$domain");

	#remove extra lines
	if ($self->{total_lines}{$panel} > $self->{line_limit}{$panel}) {
		my $overage = $self->{total_lines}{$panel} - $self->{line_limit}{$panel};
		$self->{$panel}->delete('1.0', $overage+1 . ".0");
		$self->{total_lines}{$panel} -= $overage;
	}

	$self->{$panel}->see('end') if $scroll;
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

# interface construction

sub initTk {
	my $self = shift;
	my $panelFont = $sys{panelFont} || 'Verdana';
	my $menuFont = $sys{menuFont} || 'Lucida Console';
	my $sbarFont = $sys{sbarFont} || 'Arial';

	# create main window

	$self->{mw} = MainWindow->new();
	#$self->{mw}->minsize(316,290);
	$self->{mw}->protocol('WM_DELETE_WINDOW', [\&OnExit, $self]);
	#$self->{mw}->Icon(-image=>$self->{mw}->Photo(-file=>"hyb.gif"));
	$self->{mw}->title("$Settings::NAME");

	# Main window menu

	$self->{mw}->configure(-menu => $self->{mw}->Menu(-menuitems=>
	[ map 
		['cascade', $_->[0], -tearoff=> 0, -font=>[-family=>$menuFont,-size=>8], -menuitems => $_->[1]],
		['~OpenKore',
			[[qw/command E~xit  -accelerator Alt+P/, -font=>[-family=>$menuFont,-size=>8], -command=>[\&OnExit, $self]],]
		],
		['~View',
			[
				[qw/command Map  -accelerator Alt+M/, -font=>[-family=>$menuFont,-size=>8], -command=>[\&OpenMap, $self]],
				'',
				[qw/command Status -accelerator Alt+D/, -font=>[-family=>$menuFont,-size=>8], -command => sub{ Commands::run("s") }],
				[qw/command Storage -accelerator Alt+X/, -font=>[-family=>$menuFont,-size=>8], -command => sub{ Commands::run("storage") }],
				[qw/command Skill -accelerator Alt+S/, -font=>[-family=>$menuFont,-size=>8], -command => sub{ Commands::run("skills") }],
				[qw/command Stat -accelerator Alt+A/, -font=>[-family=>$menuFont,-size=>8], -command => sub{ Commands::run("st") }],
				[qw/command Exp -accelerator Alt+Z/, -font=>[-family=>$menuFont,-size=>8], -command => sub{ Commands::run("exp") }],
				[qw/command Usable -accelerator Alt+E/, -font=>[-family=>$menuFont,-size=>8], -command => sub{ Commands::run("i u") }],
				[qw/command Equipped -accelerator Alt+Q/, -font=>[-family=>$menuFont,-size=>8], -command => sub{ Commands::run("i eq") }],
				[qw/command Unequipped -accelerator Alt+C/, -font=>[-family=>$menuFont,-size=>8], -command => sub{ Commands::run("i neq") }],
				[qw/command Non-Usable -accelerator Alt+W/, -font=>[-family=>$menuFont,-size=>8], -command => sub{ Commands::run("i nu") }],
				'',
				[cascade=>"Guild", -tearoff=> 0, -font=>[-family=>$menuFont,-size=>8], -menuitems =>
					[
						[qw/command Info -accelerator ALT+F/, -font=>[-family=>$menuFont,-size=>8], -command => sub{ Commands::run("guild info") }],
						[qw/command Member -accelerator ALT+G/, -font=>[-family=>$menuFont,-size=>8], -command => sub{ Commands::run("guild member") }]
					],
				],
				'',
				[cascade=>"Font Weight", -tearoff=> 0, -font=>[-family=>$menuFont,-size=>8], -menuitems => 
					[
						[Checkbutton  => '~Bold', -variable => \$self->{is_bold},-font=>[-family=>$sbarFont,-size=>8],-command => [\&change_fontWeight, $self]],
					]
				],
			],
		],
		['~Reload',
			[
				[qw/command config -accelerator Ctrl+Shift+C/, -font=>[-family=>$menuFont,-size=>8], -command => sub{ Commands::run("reload config") }],
				[qw/command mon_control  -accelerator Ctrl+Shift+W/, -font=>[-family=>$menuFont,-size=>8], -command => sub{ Commands::run("reload mon_control") }],
				[qw/command item_control  -accelerator Ctrl+Shift+Q/, -font=>[-family=>$menuFont,-size=>8], -command => sub{ Commands::run("reload items_control") }],
				[qw/command cart_control  -accelerator Ctrl+Shift+E/, -font=>[-family=>$menuFont,-size=>8], -command=>sub{ Commands::run("reload avoid") }],
				[qw/command timeouts  -accelerator Ctrl+Shift+Z/, -font=>[-family=>$menuFont,-size=>8], -command=>sub{ Commands::run("reload timeouts") }],
				[qw/command pickupitems  -accelerator Ctrl+Shift+V/, -font=>[-family=>$menuFont,-size=>8], -command=>sub{ Commands::run("reload pickupitems") }],
				[qw/command chatresp  -accelerator Ctrl+Shift+T/, -font=>[-family=>$menuFont,-size=>8], -command=>sub{ Commands::run("reload chat_resp") }],
				'',
				[qw/command All  -accelerator Ctrl+Shift+A/, -font=>[-family=>$menuFont,-size=>8], -command=>sub{ Commands::run("reload all") }],
			]
		],
		['~Help',
			[[qw/command Manual  -accelerator Alt+H/, -font=>[-family=>$menuFont,-size=>8], -command=>[\&showManual, $self]],]
		]
	]
	));

	# subclasses of main window

	# status frame

	$self->{status_frame} = $self->{mw}->Frame()->pack(
		-side => 'bottom',
		-expand => 0,
		-fill => 'x',
	);

	#------ subclass in status frame

	$self->{status_gen} = $self->{status_frame}->Label(
		-anchor => 'w',
		-text => 'Ready',
		-font => [$sbarFont, 8],
		-bd=>0,
		-relief => 'sunken',
	)->pack(
		-side => 'left',
		-expand => 1,
		-fill => 'x',
	);

	$self->{status_ai} = $self->{status_frame}->Label(
		-text => 'Ai - Status',
		-font => [$sbarFont, 8],
		-width => 25,
		-relief => 'ridge',
	)->pack(
		-side => 'left',
		-expand => 0,
		-fill => 'x',
	);

	$self->{status_posx} = $self->{status_frame}->Label(
		-text => '0',
		-font => [$sbarFont, 8],
		-width => 4,
		-relief => 'ridge',
	)->pack(
		-side => 'left',
		-expand => 0,
		-fill => 'x',
	);

	$self->{status_posy} = $self->{status_frame}->Label(
		-text => '0',
		-font => [$sbarFont, 8],
		-width => 4,
		-relief => 'ridge',
	)->pack(
		-side => 'left',
		-expand => 0,
		-fill => 'x',
	);

	# input frame

	$self->{input_frame} = $self->{mw}->Frame(
		-bg=>'black'
	)->pack(
		-side => 'bottom',
		-expand => 0,
		-fill => 'x',
	);

	#------ subclass in input frame

	$self->{pminput} = $self->{input_frame}->BrowseEntry(
		-bg=>'black',
		-fg=>'grey',
		-variable => \$self->{input_pm},
		-width => 8,
		-font=>[ -family => $panelFont ,-size=>10,],
		-autolimitheight => 1,
		-state =>'normal',
		-relief => 'flat',
	)->pack(
		-expand=>0,
		-fill => 'x',
		-side => 'left',
	);

	$self->{input} = $self->{input_frame}->Entry(
		-bg => 'black',
		-fg => 'grey',
		-insertbackground => 'grey',
		-relief => 'sunken',
		-font=>[ -family => $panelFont ,-size=>10,],
	)->pack(
		-expand=>1,
		-fill => 'x',
		-side => 'left',
	);

	$self->{sinput} = $self->{input_frame}->BrowseEntry(
		-bg=>'black',
		-fg=>'grey',
		-disabledbackground => 'black',
		-disabledforeground => 'grey',
		-variable => \$self->{input_type},
		-autolimitheight => 1,
		-listwidth => 30,
		-font=>[ -family => $panelFont ,-size=>10,],
		-width => 8,
		-state => 'readonly',
		-relief => 'flat',
	)->pack (
		-expand=>0,
		-fill => 'x',
		-side => 'left',
	);
	$self->{sinput}->insert("end", qw(Command Public Party Guild));

	### panelOne and panelTwo
	
	$self->{panelOne} = $self->{mw}->Scrolled('ROText',
		-bg=>'black',
		-fg=>'grey',
		-scrollbars => 'e',
		-height => $sys{panelOne_height} || 8,
		-width => $sys{panelOne_width} || 60,
		-wrap => 'word',
		-insertontime => 0,
		-background => 'black',
		-foreground => 'grey',
		-font=>[ -family => $panelFont ,-size=>$sys{panelOne_fontsize} || 8,],
		-relief => 'sunken',
	)->pack(
		-expand => 1,
		-fill => 'both',
		-side => $sys{panelOne_side} || 'top',
	);

	$self->{panelTwo} = $self->{mw}->Scrolled('ROText',
		-bg=>'black',
		-fg=>'grey',
		-scrollbars => 'e',
		-height => $sys{panelTwo_height} || 4,
		-width => $sys{panelTwo_width} || 40,
		-wrap => 'word',
		-insertontime => 0,
		-background => 'black',
		-foreground => 'grey',
		-font=>[ -family => $panelFont ,-size=>$sys{panelTwo_fontsize} || 8,],
		-relief => 'sunken',
	)->pack(
		-expand => 1,
		-fill => 'both',
		-side => $sys{panelTwo_side} || 'top',
	);

	# button frame, removed
	#$self->{btn_frame} = $self->{mw}->Frame(
	#	#-bg=>'black'
	#)->pack(
	#	-side => 'right',
	#	-expand => 0,
	#	-fill => 'y',
	#);

	### Binding ###
	$self->{mw}->bind('all', '<Alt-p>' => 		[\&OnExit, $self]);
	$self->{mw}->bind('all', '<Alt-m>' =>		[\&OpenMap, $self]);
	$self->{mw}->bind('all', '<Control-Shift-C>' =>	sub{ Commands::run("reload config") });
	$self->{mw}->bind('all', '<Control-Shift-W>' => sub{ Commands::run("reload mon_control") });
	$self->{mw}->bind('all', '<Control-Shift-Q>' => sub{ Commands::run("reload items_control") });
	$self->{mw}->bind('all', '<Control-Shift-E>' => sub{ Commands::run("reload avoid") });
	$self->{mw}->bind('all', '<Control-Shift-Z>' => sub{ Commands::run("reload timeouts") });
	$self->{mw}->bind('all', '<Control-Shift-V>' => sub{ Commands::run("reload pickupitems") });
	$self->{mw}->bind('all', '<Control-Shift-T>' => sub{ Commands::run("reload chat_resp") });
	$self->{mw}->bind('all', '<Control-Shift-A>' => sub{ Commands::run("reload all") });
	$self->{mw}->bind('all', '<Alt-d>' => 		sub{ Commands::run("s") });
	$self->{mw}->bind('all', '<Alt-x>' => 		sub{ Commands::run("storage") });
	$self->{mw}->bind('all', '<Alt-s>' => 		sub{ Commands::run("skills") });
	$self->{mw}->bind('all', '<Alt-q>' => 		sub{ Commands::run("i eq") });
	$self->{mw}->bind('all', '<Alt-a>' => 		sub{ Commands::run("st") });
	$self->{mw}->bind('all', '<Alt-e>' => 		sub{ Commands::run("i u") });
	$self->{mw}->bind('all', '<Alt-w>' => 		sub{ Commands::run("i nu") });
	$self->{mw}->bind('all', '<Alt-z>' => 		sub{ Commands::run("exp") });
	$self->{mw}->bind('all', '<Alt-c>' => 		sub{ Commands::run("i neq") });
	$self->{mw}->bind('all', '<Alt-f>' => 		sub{ Commands::run("guild info") });
	$self->{mw}->bind('all', '<Alt-g>' => 		sub{ Commands::run("guild member") });
	$self->{mw}->bind('all', '<Alt-h>' => 		[\&showManual, $self]);

	$self->{input}->bind('<Up>' => [\&inputUp, $self]);
	$self->{input}->bind('<Down>' => [\&inputDown, $self]);
	$self->{input}->bind('<Return>' => [\&inputEnter, $self]);
	$self->{input}->focus();

	if ($buildType == 0) {
		$self->{input}->bind('<MouseWheel>' => [\&w32mWheel, $self, Ev('k'), "panelTwo"]);
		$self->{panelTwo}->bind('<MouseWheel>' => [\&w32mWheel, $self, Ev('k'), "panelTwo"]);
		$self->{panelOne}->bind('<MouseWheel>' => [\&w32mWheel, $self, Ev('k'), "panelOne"]);

		my $console;
		eval 'use Win32::Console; $console = new Win32::Console(STD_OUTPUT_HANDLE);';
		$console->Free();
	}

	$self->{mw}->raise();
}

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
sub w32mWheel {
	my $action_area = shift;
	my $self = shift;
	my $zDist = shift;
	my $panel = shift;
	
	$self->{$panel}->yview('scroll', -int($zDist/40), "units");
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
	$self->{input}->delete('0', 'end');

	# add input to input history
	$self->{input_list}[0] = $line;
	unshift(@{$self->{input_list}}, "");

	# modify the input based on what modes we are using
	if ($line =~ /^\/(.*)/) {
		$line = $1;
	} else {
		if ($self->{input_pm} eq "") {
			if ($self->{input_type} eq "Public") {
				$line = "c ".$line;
			} elsif ($self->{input_type} eq "Party"){
				$line = "p ".$line;
			} elsif ($self->{input_type} eq "Guild"){
				$line = "g ".$line;
			}
		} else {
			$self->pm_add($self->{input_pm});
			$line = "pm \"$self->{input_pm}\" $line";
		}
	}

	return unless defined $line;

	$self->{input_offset} = 0;

	# add to interface input queue for processing
	push(@{ $self->{input_que} }, $line);
}

sub updateHook {
	my $hookname = shift;
	my $r_args = shift;
	my $self = shift;
	return unless defined $self->{mw};
	$self->updatePos();
	$self->{mw}->update();
	$self->setAiText("@ai_seq");
	#if ($field{name} eq $config{lockMap} || !$config{lockMap}) {
	#	$self->status_update("On Map: $field{name}");
	#} else {
	#	$self->status_update("On Map: $field{name} | LockMap: $config{lockMap}");
	#}
}

sub updatePos {
	my $self = shift;
	return unless (defined $char && defined $char->{pos_to});
	my ($x,$y) = @{$char->{pos_to}}{'x', 'y'};
	$self->{status_posx}->configure( -text =>$x);
	$self->{status_posy}->configure( -text =>$y);
	if ($self->mapIsShown()) {
		# show player coords
		$self->{map}{'canvas'}->delete($self->{map}{'player'}) if ($self->{map}{'player'});
		$self->{map}{'player'} = $self->{map}{'canvas'}->createOval(
			$x-2,$self->{map}{'map'}{'y'} - $y-2,
			$x+2,$self->{map}{'map'}{'y'} - $y+2,
			,-fill => '#ffcccc', -outline=>'#ff0000');
		$self->{map}{'canvas'}->delete($self->{map}{'dest'}) if ($self->{map}{'dest'});

		# show route destination
		my $action = AI::findAction("route");
		if (defined $action) {
			my $args = AI::args($action);
			if ($args->{dest}{map} eq $field{name}) {
				my ($x,$y) = @{$args->{dest}{pos}}{'x', 'y'};
				$self->{map}{'dest'} = $self->{map}{'canvas'}->createOval(
					$x-2,$self->{map}{'map'}{'y'} - $y-2,
					$x+2,$self->{map}{'map'}{'y'} - $y+2,
					,-fill => '#0000ff', -outline=>'#ccccff');
			}
		}

		# show circle of attack range
		$self->{map}{'canvas'}->delete($self->{map}{'range'}) if ($self->{map}{'range'});
		my $dis = $config{'attackDistance'};
		$self->{map}{'range'} = $self->{map}{'canvas'}->createOval(
			$x-$dis,$self->{map}{'map'}{'y'} - $y-$dis,
			$x+$dis,$self->{map}{'map'}{'y'} - $y+$dis,
			,-outline=>'#ff0000');
	}
}

sub status_update {
	my $self = shift;
	my $text = shift;
	$self->{status_gen}->configure(-text => $text);
}

sub setAiText {
	my $self = shift;
	my ($text) = shift;
	$self->{status_ai}->configure(-text => $text);
}

sub OnExit {
	my $self = shift;
	if ($conState) {
		push(@{ $self->{input_que} }, "\n");
		quit();
	} else {
		exit();
	}
}

sub showManual {
	my $self = shift;
	$self->{ShellExecute}->Call(0, '', 'http://openkore.sourceforge.net/manual/', '', '', 1);
}

sub change_fontWeight {
	my $self = shift;
	my $panelFont = $sys{panelFont} || 'Verdana';
	if ($self->{is_bold}) {
		$self->{panelOne}->configure(-font=>[-family => $panelFont ,-size=>10,-weight=>'bold']);
		$self->{panelTwo}->configure(-font=>[-family => $panelFont ,-size=>10,-weight=>'bold']);
		$self->{input}->configure(-font=>[-family => $panelFont ,-size=>10,-weight=>'bold']);
	}else{
		$self->{panelOne}->configure(-font=>[-family => $panelFont ,-size=>10,-weight=>'normal']);
		$self->{panelTwo}->configure(-font=>[-family => $panelFont ,-size=>10,-weight=>'normal']);
		$self->{input}->configure(-font=>[-family => $panelFont ,-size=>10,-weight=>'normal']);
	}
}

sub pm_add {
	my $self = shift;
	my $name = shift;
	$self->{pminput}->insert("end",$name) if !defined binFind($self->{pminput}->get(0,'end'), $name);
}

# map functions

sub OpenMap {
	my ($self, $param2) = @_;
	$self = $param2 if ($param2);

	if (!exists $self->{map}) {
		undef $self->{obj};
		my ($x,$y);
		$self->{map} = $self->{mw}->Toplevel();
		$self->{map}->transient($self->{mw});
		$self->{map}->title("Map View : ".$field{name});
		$self->{map}->protocol('WM_DELETE_WINDOW', 
			sub {
				undef $self->{obj};
				$self->{map}->destroy();
				delete $self->{map};
			}
		);
		$self->{map}->resizable(0,0);
		$self->{map}{'canvas'} = $self->{map}->Canvas(-width => 200, -height => 200,-background => 'white')->pack(-side => 'top');
		$self->loadMap;
		$x = $self->{status_posx}->cget(-text);
		$y = $self->{status_posy}->cget(-text);
		$self->{map}{'player'} = $self->{map}{'canvas'}->createOval(
			$x-2,$self->{map}{'map'}{'y'} - $y-2,
			$x+2,$self->{map}{'map'}{'y'} - $y+2,
			,-fill => '#ffcccc', -outline=>'#ff0000');
		my $dis = $config{'attackDistance'};
		$self->{map}{'range'} = $self->{map}{'canvas'}->createOval(
			$x-$dis,$self->{map}{'map'}{'y'} - $y-$dis,
			$x+$dis,$self->{map}{'map'}{'y'} - $y+$dis,
			,-outline=>'#ff0000');
		$self->{map}->bind('<1>', [\&dblchk, $self, Ev('x') , Ev('y')]);
		$self->{map}->bind('<Motion>', [\&pointchk, $self, Ev('x') , Ev('y')]); 
	} else {
		undef $self->{obj};
		$self->{map}->destroy();
		delete $self->{map};
	}
}

# map image loader functions

sub _map {
	my $self = shift;
	return File::Spec->catfile($self->{mapDir}, @_);
}

sub loadMap {
	my $self = shift;
	$self->{map}{'canvas'}->delete('map');
	$self->{map}{'canvas'}->createText(50,20,-text =>'Processing..',-tags=>'map');

	my $name = $field{baseName};
	if (-f $self->_map("$name.jpg")) {
		require Tk::JPEG;
		$self->{map}{'map'} = $self->{map}{'canvas'}->Photo(-format => 'jpeg', -file=> $self->_map("$name.jpg"));
	} elsif (-f $self->_map("$name.png")) {
		require Tk::PNG;
		$self->{map}{'map'} = $self->{map}{'canvas'}->Photo(-format => 'png', -file=> $self->_map("$name.png"));
	} elsif (-f $self->_map("$name.gif")) {
		$self->{map}{'map'} = $self->{map}{'canvas'}->Photo(-format => 'gif', -file=> $self->_map("$name.gif"));
	} elsif (-f $self->_map("$name.bmp")) {
		$self->{map}{'map'} = $self->{map}{'canvas'}->Bitmap(-file => $self->_map("$name.bmp"));
	} else {
		$self->{map}{'map'} = $self->{map}{'canvas'}->Photo(-format => 'xpm', -data => Utils::xpmmake($field{width}, $field{height}, $field{rawMap}));
	}

	$self->{map}{'canvas'}->delete('map');
	$self->{map}{'canvas'}->createImage(2,2,-image =>$self->{map}{'map'},-anchor => 'nw',-tags=>'map');
	$self->{map}{'canvas'}->configure(
			-width => $field{'width'},
			-height => $field{'height'}
	);
	$self->{map}{'map'}{'x'} = $field{'width'};
	$self->{map}{'map'}{'y'} = $field{'height'};
}

# mouse moving over map viewer shows coordinates
sub pointchk {
	my $actionArea = shift;
	my $self = shift;
	my $mvcpx = $_[0];
	my $mvcpy = $self->{map}{'map'}{'y'} - $_[1];
	$self->{map}->title("Map View : ".$field{'name'}." \[$mvcpx , $mvcpy\]");
	$self->{map}->update;
}

# click on map viewer to move to coordinates
sub dblchk {
	my $actionarea = shift;
	my $self = shift;
	my $mvcpx = $_[0];
	my $mvcpy = $self->{map}{'map'}{'y'} - $_[1];
	push(@{$self->{input_que}}, "move $mvcpx $mvcpy"); 
} 

sub mapIsShown {
	my $self = shift;
	return defined $self->{map};
}

sub addObj {
	my $self = shift;
	my ($id,$type) = @_;
	my ($fg,$bg);
	return if (!$self->mapIsShown());
	if ($type eq "npc") {
		$fg = "#ABD5BD";
		$bg = "#005826";
	}elsif ($type eq "m") {
		$fg = "#A9D3E3";
		$bg = "#0076A3";
	}elsif ($type eq "p") {
		$fg = "#FFFFCC";
		$bg = "#FF6600";
	}else {
		$fg = "#666666";
		$bg = "#FF6600";
	}
	$self->{objc}{$id}[0] = $fg;
	$self->{objc}{$id}[1] = $bg;
}

sub moveObj {
	my $self = shift;
	return if (!$self->mapIsShown());
	my ($id,$type,$x,$y,$newx,$newy) = @_;
	my $range;
	if ($self->{obj}{$id}){
		$self->{map}{'canvas'}->delete($self->{obj}{$id});
	} else {
		$self->addObj($id,$type);
	}
	if (defined $newx && defined $newy) {
		$x = $newx;
		$y = $newy;
	}
	$self->{obj}{$id} = $self->{map}{'canvas'}->createOval(
			$x-2,$self->{map}{'map'}{'y'} - $y-2,
			$x+2,$self->{map}{'map'}{'y'} - $y+2,
			,-fill => $self->{objc}{$id}[0], -outline=>$self->{objc}{$id}[1]); 
}

sub removeObj {
	my $self = shift;
	my ($id) = shift;
	return if (!$self->{obj}{$id} || !$self->mapIsShown());
	$self->{map}{'canvas'}->delete($self->{obj}{$id});
	undef $self->{obj}{$id};
}

sub removeAllObj {
	my $self = shift;
	return if (!$self->mapIsShown());
	foreach (keys %{$self->{obj}}) {
		$self->{map}{'canvas'}->delete($self->{obj}{$_}) if ($self->{obj}{$_});
		undef $self->{obj}{$_};
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

# load color tags

sub resetColors {
	my $hookname = shift;
	my $r_args = shift;
	my $self = shift;
	return if $hookname ne 'postloadfiles';
	my $colors_loaded = 0;
	foreach my $filehash (@{ $r_args->{files} }) {
		if ($filehash->{file} =~ /consolecolors.txt$/) {
			$colors_loaded = 1;
			last;
		}
	}
	return unless $colors_loaded;
	my %gdefault = (-foreground => 'grey', -background => 'black');
	eval {
		$self->{panelOne}->configure(%gdefault);
		$self->{panelTwo}->configure(%gdefault);
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
	foreach my $type (keys %consoleColors) {
		next if $type eq '';
		my %tdefault =%gdefault;
		if ($consoleColors{''}{'useColors'} && $consoleColors{$type}{'default'}) {
			$consoleColors{$type}{'default'} =~ m|([^/]*)(?:/(.*))?|;
			$tdefault{-foreground} = defined($1) && $1 ne 'default' ? $1 : $gdefault{-foreground};
			$tdefault{-background} = defined($2) && $2 ne 'default' ? $2 : $gdefault{-background};
		}
		eval {
			# FIXME: loading colors for both panels is pointless
			$self->{panelOne}->tagConfigure($type, %tdefault);
			$self->{panelTwo}->tagConfigure($type, %tdefault);
		};
		if ($@) {
			if ($@ =~ /unknown color name "(.*)" at/) {
				Log::message("Color '$1' not recognised in consolecolors.txt at [$type]: default.\n");
			} else {
				die $@;
			}
		}
		foreach my $domain (keys %{ $consoleColors{$type} }) {
			my %color = %tdefault;
			if ($consoleColors{''}{'useColors'} && $consoleColors{$type}{$domain}) {
				$consoleColors{$type}{$domain} =~ m|([^/]*)(?:/(.*))?|;
				$color{-foreground} = defined($1) && $1 ne 'default' ? $1 : $tdefault{-foreground};
				$color{-background} = defined($2) && $2 ne 'default' ? $2 : $tdefault{-background};
			}
			eval {
				# FIXME: loading colors for both panels is pointless
				$self->{panelOne}->tagConfigure("$type.$domain", %color);
				$self->{panelTwo}->tagConfigure("$type.$domain", %color);
			};
			if ($@) {
				if ($@ =~ /unknown color name "(.*)" at/) {
					Log::message("Color '$1' not recognised in consolecolors.txt at [$type]: $domain.\n");
				} else {
					die $@;
				}
			}
		}
	}


	# FIXME: find a better spot to fix the initial window scrolling
	$self->{panelOne}->see('end');
	$self->{panelTwo}->see('end');
}

# packet parsing hook
# maybe this should be replaced by proper hooks in the future

sub packet {
	my $hookName = shift;
	my $args = shift;
	my $self = shift;
	my $switch = $args->{switch};
	my $msg = $args->{msg};

	if ($switch eq "0071") {
		#0071 <character ID> l <map name> 16B <ip> l <port> w 
		#Character selection success & map name & game IP/port
		my ($map_name) = substr($msg, 6, 16) =~ /([\s\S]*?)\000/;
		($map_name) = $map_name =~ /([\s\S]*)\./;
		if (!$config{lockMap} || $map_name eq $config{lockMap}) {
			$self->status_update("On Map : $map_name");
		} else {
			$self->status_update("On Map : $map_name | LockMap : $config{lockMap}");
		}

	#} elsif ($switch eq "0073") {
	#	#0073 <server tick> l <coordinate> 3B? 2B 
	#	#Game connection success & server side 1ms clock & appearance position
	#	my %pos;
	#	makeCoords(\%pos, substr($msg, 6, 3));
	#	$self->updatePos($pos{x},$pos{y});

	} elsif ($switch eq "0078" || $switch eq "01D8") {
		#0078 <ID> l <speed> w <opt1> w <opt2> w <option> w <class> w <hair> w <weapon> w <head option bottom> w <shield> w <head option top> w <head option mid> w <hair color> w? W <head dir> w <guild> l <emblem> l <manner> w <karma> B <sex> B <X_Y_dir> 3B? B? B <sit> B <Lv> B
		#01d8 <ID>.l <speed>.w <opt1>.w <opt2>.w <option>.w <class>.w <hair>.w <item id1>.w <item id2>.w <head option bottom>.w <head option top>.w <head option mid>.w <hair color>.w ?.w <head dir>.w <guild>.l <emblem>.l <manner>.w <karma>.B <sex>.B <X_Y_dir>.3B ?.B ?.B <sit>.B <Lv>.B ?.B
		#0078 mainly is monster , portal
		#01D8 = npc + player for episode 4+
		my $ID = substr($msg, 2, 4);
		my $type = unpack("v*",substr($msg, 14,  2));
		my $pet = unpack("C*",substr($msg, 16,  1));
		my %coords;
		makeCoords(\%coords, substr($msg, 46, 3));

		if ($jobs_lut{$type}) {
			if (!$players{$ID}) {
				$self->addObj($ID,"p");
			}
		} elsif ($type >= 1000) {
			if ($pet) {
				if ($monsters{$ID}) {
					$self->removeObj($ID);
				}
			} else {
				$self->addObj($ID,"m");
			}
		} elsif ($type < 1000) {
			if (!$npcs{$ID}) {
				$self->addObj($ID,"npc");
			}
		}
		$self->moveObj($ID,"un",$coords{x},$coords{y}) if ($type != 45 && !$pet);

	} elsif ($switch eq "0079" || $switch eq "01D9") {
		#0079 <ID>.l <speed>.w <opt1>.w <opt2>.w <option>.w <class>.w <hair>.w <weapon>.w <head option bottom>.w <sheild>.w <head option top>.w <head option mid>.w <hair color>.w ?.w <head dir>.w <guild>.l <emblem>.l <manner>.w <karma>.B <sex>.B <X_Y_dir>.3B ?.B ?.B <Lv>.B
		#01d9 <ID>.l <speed>.w <opt1>.w <opt2>.w <option>.w <class>.w <hair>.w <item id1>.w <item id2>.w.<head option bottom>.w <head option top>.w <head option mid>.w <hair color>.w ?.w <head dir>.w <guild>.l <emblem>.l <manner>.w <karma>.B <sex>.B <X_Y_dir>.3B ?.B ?.B <Lv>.B ?.B
		#For boiling Character inside the indicatory range of teleport and the like, it faces and is not attached Character information? 
		my $ID = substr($msg, 2, 4);
		my %coords;
		makeCoords(\%coords, substr($msg, 46, 3));
		$self->moveObj($ID,"p",$coords{x},$coords{y});

	} elsif ($switch eq "007B" || $switch eq "01DA") {
		#007b <ID> l <speed> w <opt1> w <opt2> w <option> w <class> w <hair> w <weapon> w <head option bottom> w <server tick> l <shield> w <head option top> w <head option mid> w <hair color> w? W <head dir> w <guild> l <emblem> l <manner> w <karma> B <sex> B <X_Y_X_Y> 5B? B? B? B <Lv> B 
		#01da <ID>.l <speed>.w <opt1>.w <opt2>.w <option>.w <class>.w <hair>.<item id1>.w <item id2>.w <head option bottom>.w <server tick>.l <head option top>.w <head option mid>.w <hair color>.w ?.w <head dir>.w <guild>.l <emblem>.l <manner>.w <karma>.B <sex>.B <X_Y_X_Y>.5B ?.B ?.B ?.B <Lv>.B ?.B
		#Information of Character movement inside indicatory range
		my $ID = substr($msg, 2, 4);
		my %coordsFrom;
		makeCoords(\%coordsFrom, substr($msg, 50, 3));
		my %coordsTo;
		makeCoords2(\%coordsTo, substr($msg, 52, 3));
		my $type = unpack("v1",substr($msg, 14,  2));
		my $pet = unpack("C1",substr($msg, 16,  1));

		if ($jobs_lut{$type}) {
			if (!$players{$ID}) {
				$self->addObj($ID,"p");
			}
		} elsif ($type >= 1000) {
			if ($pet) {
				if ($monsters{$ID}) {
					$self->removeObj($ID);
				}
			} else {
				if (!$monsters{$ID}) {
					$self->addObj($ID,"m");
				}
			}
		}
		$self->moveObj($ID,"un",$coordsFrom{x},$coordsFrom{y},$coordsTo{x},$coordsTo{y});

	} elsif ($switch eq "007C") {
		#007c <ID> l <speed> w? 6w <class> w? 7w <X_Y> 3B? 2B 
		#Character information inside the indicatory range for NPC
		my $ID = substr($msg, 2, 4);
		my %coords;
		makeCoords(\%coords, substr($msg, 36, 3));
		my $type = unpack("v*",substr($msg, 20,  2));
		if ($jobs_lut{$type}) {
				$self->addObj($ID,"p");
		} elsif ($type >= 1000) {
			$self->addObj($ID,"m");
		}
		$self->moveObj($ID,"un",$coords{x},$coords{y});

	} elsif ($switch eq "0080") {
		#0080 <ID> l <type> B
		#Character Status (include other)
		my $ID = substr($msg, 2, 4);
		$self->removeObj($ID);

	#} elsif ($switch eq "0087") {
	#	#0087 <server tick> l <X_Y_X_Y> 5B? B 
	#	#Movement response 
	#	my %coordsFrom;
	#	makeCoords(\%coordsFrom, substr($msg, 6, 3));
	#	my %coordsTo;
	#	makeCoords2(\%coordsTo, substr($msg, 8, 3));
	#	$self->updatePos($coordsTo{x},$coordsTo{y});

	} elsif ($switch eq "0091") {
		#0091 <map name> 16B <X> w <Y> w 
		#Business such as movement, teleport and fly between maps inside 
		my ($map_name) = substr($msg, 2, 16) =~ /([\s\S]*?)\000/;
		($map_name) = $map_name =~ /([\s\S]*)\./;
		if ($map_name ne $field{name}) {
			eval {
				$field = new Field(name => $map_name);
				if (!$config{lockMap} || $map_name eq $config{lockMap}) {
					$self->status_update("On Map : $map_name");
				} else {
					$self->status_update("On Map : $map_name | LockMap : $config{lockMap}");
				}
				$self->loadMap() if ($self->mapIsShown());
			};
			if ($@) {
				undef $field;
			}
		}
		#my %coords;
		#$coords{x} = unpack("v1", substr($msg, 18, 2));
		#$coords{y} = unpack("v1", substr($msg, 20, 2));
		#$self->updatePos($coords{x},$coords{y});
		$self->removeAllObj();

	} elsif ($switch eq "0092") {
		#0092 <map name> 16B <X> w <Y> w <IP> l <port> w 
		#Movement between
		my ($map_name) = substr($msg, 2, 16) =~ /([\s\S]*?)\000/;
		($map_name) = $map_name =~ /([\s\S]*)\./;
		if ($map_name ne $field{'name'}) {
			eval {
				$field = new Field(name => $map_name);
				$self->loadMap() if ($self->mapIsShown());
				$self->removeAllObj();
				if (!$config{lockMap} || $map_name eq $config{lockMap}) {
					$self->status_update("On Map : $map_name");
				} else {
					$self->status_update("On Map : $map_name | LockMap : $config{lockMap}");
				}
			};
			if ($@) {
				undef $field;
			}
		}

	} elsif ($switch eq "0097") {
		# Private message
		my $msg_size = length($msg);
		my $newmsg;
		main::decrypt(\$newmsg, substr($msg, 28, length($msg)-28));
		$msg = substr($msg, 0, 28) . $newmsg;
		my ($privMsgUser) = substr($msg, 4, 24) =~ /([\s\S]*?)\000/;
		my $privMsg = substr($msg, 28, $msg_size - 29);
		$self->pm_add($privMsgUser);

	} elsif ($switch eq "01A4") {
		#01a4 < type >.B < ID >.l < val >.l 
		#pet spawn
		my $ID = substr($msg, 3, 4);
		if ($monsters{$ID}) {
			$self->removeObj($ID);
		}
	}
}


1;
