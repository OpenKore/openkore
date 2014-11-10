#!/usr/bin/perl
#########################################################################
#  OpenKore - Interface::Console::Curses
#  You need Curses (the Perl bindings for (n)curses)
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
package Interface::Console::Curses;

use strict;
use Curses;
use Time::HiRes qw(time usleep);

use Globals;
use Utils;
use base qw(Interface::Console);
use Modules;
use Settings qw/%sys/;

use constant MAXHISTORY => 50;

our $keymap = {
	'[11~' => KEY_F( 1 ),
	'[12~' => KEY_F( 2 ),
	'[13~' => KEY_F( 3 ),
	'[14~' => KEY_F( 4 ),
};

our $attrtable;

sub new {
	my %interface = ();
	bless \%interface, __PACKAGE__;
	my $self = \%interface;

	foreach ( keys %$keymap ) {
		my $h = $keymap;
		$h = $h->{$_} ||= {} foreach split //, $_;
		$h->{match} = $keymap->{$_};
	}

	initscr;
	idlok 1;
	idcok 1;
	nonl;
	cbreak;
	noecho;
	intrflush 1;
	keypad 1;
	nodelay 1;
	start_color;
	use_default_colors;
	init_pair(1, COLOR_BLACK, -1);
	init_pair(2, COLOR_RED, -1);
	init_pair(3, COLOR_GREEN, -1);
	init_pair(4, COLOR_YELLOW, -1);
	init_pair(5, COLOR_BLUE, -1);
	init_pair(6, COLOR_MAGENTA, -1);
	init_pair(7, COLOR_CYAN, -1);
	init_pair(8, COLOR_WHITE, -1);
	init_pair(9, -1, COLOR_BLACK);
	init_pair(10, -1, COLOR_RED);
	init_pair(11, -1, COLOR_GREEN);
	init_pair(12, -1, COLOR_YELLOW);
	init_pair(13, -1, COLOR_BLUE);
	init_pair(14, -1, COLOR_MAGENTA);
	init_pair(15, -1, COLOR_CYAN);
	init_pair(16, -1, COLOR_WHITE);
	$attrtable = {
		normal     => A_NORMAL,
		underline  => A_UNDERLINE,
		reverse    => A_REVERSE,
		blink      => A_BLINK,
		dim        => A_DIM,
		bold       => A_BOLD,
		black      => COLOR_PAIR( 1 ),
		red        => COLOR_PAIR( 2 ),
		green      => COLOR_PAIR( 3 ),
		yellow     => COLOR_PAIR( 4 ),
		blue       => COLOR_PAIR( 5 ),
		magenta    => COLOR_PAIR( 6 ),
		cyan       => COLOR_PAIR( 7 ),
		white      => COLOR_PAIR( 8 ),
		bg_black   => COLOR_PAIR( 9 ),
		bg_red     => COLOR_PAIR( 10 ),
		bg_green   => COLOR_PAIR( 11 ),
		bg_yellow  => COLOR_PAIR( 12 ),
		bg_blue    => COLOR_PAIR( 13 ),
		bg_magenta => COLOR_PAIR( 14 ),
		bg_cyan    => COLOR_PAIR( 15 ),
		bg_white   => COLOR_PAIR( 16 ),
	};

	$self->{winStatus} = newwin(4, 0, 0, 0);
	$self->{winObjects} = newwin($LINES-5, 15, 4, $COLS-15);
	$self->{winLog} = newwin($LINES-5, $COLS-15, 4, 0);
	scrollok $self->{winLog}, 1;
	$self->{winInput} = newwin(1, 0, $LINES-1, 0);
	$self->updateLayout;
	$self->setCursor;

	$self->{time_start} = time;

	$self->{revision} = Settings::getSVNRevision;
	$self->{revision} = " (r$self->{revision})" if defined $self->{revision};

	$self->{loading} = {
		current => 0,
		total => 1,
		text => 'Initializing',
	};

	$self->{loadingHooks} = Plugins::addHooks (
		['loadfiles', sub { $self->loadfiles (@_); }],
		['postloadfiles', sub { $self->loadfiles (@_); }],
	);

	$self->{inputPos}    = 0;
	$self->{inputBuffer} = '';
	$self->history_init;

	return \%interface;
}

sub DESTROY {
	my $self = shift;

	delwin $self->{winHelp} if ($self->{winHelp});
	delwin $self->{winInput};
	delwin $self->{winChat} if ($self->{winChat});
	delwin $self->{winLog};
	delwin $self->{winFight} if ($self->{winFight});
	delwin $self->{winObjects} if ($self->{winObjects});
	delwin $self->{winStatus};
	endwin;
}

sub iterate {
	my $self = shift;

	return if (!timeOut($self->{time_refresh}, 0.5));
	$self->{time_refresh} = time;

	if ($self->{lines} != $LINES || $self->{cols} != $COLS) {
		$self->updateLayout;
	} else {
		$self->updatePeriodic;
	}
	$self->setCursor;
}

sub getInput {
	my $self = shift;
	my $timeout = shift;

	my $msg;
	if ($timeout < 0) {
		while (!defined($msg)) {
			$msg = $self->readEvents;
			usleep 10000 unless defined $msg;
		}

	} elsif ($timeout > 0) {
		my $startTime = time;
		while (!timeOut($startTime, $timeout)) {
			$msg = $self->readEvents;
			last if (defined $msg);
			usleep 10000;
		}

	} else {
		$msg = $self->readEvents;
	}

	undef $msg if (defined $msg && $msg eq "");
	return $msg;
}

sub writeOutput {
	my $self = shift;
	my $type = shift;
	my $msg = shift;
	my $domain = shift;

	my @localtime = localtime time;
	my $time = sprintf("%02d:%02d:%02d", $localtime[2], $localtime[1], $localtime[0]);
	my $color = $consoleColors{$type}{$domain} ne "" ? lc($consoleColors{$type}{$domain}) : lc($consoleColors{$type}{default});
	$color = "bold|" . $color unless $color eq "" || $color =~ /^dark/;
	$color =~ s/^dark//g;
	$color =~ s/gr[ae]y/white/g;
	$color = "{" . $color . "}" unless $color eq "";
	foreach my $s (split("\n", $msg)) {
		if ($self->{winFight} && existsInList("attackMon,attackMonMiss,attacked,attackedMiss,skill,parseMsg_damage", $domain)) {
			scroll $self->{winFight};
			$self->printw($self->{winFight}, $self->{winFightHeight} - 2, 0, "{normal}@<<<<<<< $color@*", $time, $s);
		} elsif ($self->{winChat} && existsInList("emotion,gmchat,guildchat,partychat,pm,publicchat,selfchat", $domain)) {
			scroll $self->{winChat};
			$self->printw($self->{winChat}, $self->{winChatHeight} - 2, 0, "{normal}@<<<<<<< $color@*", $time, $s);
		} else {
			scroll $self->{winLog};
			$self->printw($self->{winLog}, $self->{winLogHeight} - 1, 0, "{normal}$color@*", $s);
		}
	}
	noutrefresh $self->{winFight} if $self->{winFight};
	noutrefresh $self->{winLog};
	noutrefresh $self->{winChat} if $self->{winChat};
	$self->updatePopups;
	$self->setCursor;
}

sub title {
	my $self = shift;
	my $title = shift;
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

	# FIXME: Need better error dialog
	#print "ERROR: $msg";
	$self->writeOutput('error', $msg, 'default');
}

################################

sub readEvents {
	my $self = shift;

	my $ch = getch();
	return undef if ($ch eq ERR);

	my $event_was_yank = 0;

	my $ret;
	while ($ch ne ERR) {
		if ( ord( $ch ) == 27 ) {

			# Escape sequence. These should be caught by Curses, but sometimes are not.
			# Attempt to translate.
			my $h = $keymap;
			my @seq;
			my $ch2;
			while ( $h && ( $ch2 = getch() ) ne ERR ) {
				push @seq, $ch2;
				if ( defined $h->{$ch2}->{match} ) {
					$ch  = $h->{$ch2}->{match};
					@seq = ();
					last;
				}
				$h = $h->{$ch2};
			}
			ungetch( pop @seq ) while @seq;
		}

		if ($ch eq "\r" || $ch eq KEY_ENTER) {
			# Enter
			$self->history_add( $self->{inputBuffer} );
			$ret = $self->{inputBuffer};
			undef $self->{inputBuffer};
			$self->{inputPos} = 0;
			last;
		} elsif (ord($ch) == 8 || ord($ch) == 127 || $ch eq KEY_BACKSPACE) {
			# Backspace
			if ($self->{inputBuffer} ne '' && $self->{inputPos} > 0) {
				$self->{inputBuffer} = substr($self->{inputBuffer}, 0, $self->{inputPos} - 1) . substr($self->{inputBuffer}, $self->{inputPos});
				$self->{inputPos}--;
			}
		} elsif (ord($ch) == 4 || ord($ch) == 330) {
			# Delete
			if ($self->{inputBuffer} ne '' && $self->{inputPos} < length $self->{inputBuffer}) {
				$self->{inputBuffer} = substr($self->{inputBuffer}, 0, $self->{inputPos}) . substr($self->{inputBuffer}, $self->{inputPos} + 1);
			}
		} elsif (ord($ch) == 12 || $ch eq KEY_RESIZE) {
			# Ctrl-L: Redraw screen
			clear;
			$self->updateLayout;
		} elsif (ord($ch) == 25) {
			# Ctrl-Y: Paste yank buffer
			$self->{inputBuffer} = substr($self->{inputBuffer}, 0, $self->{inputPos}) . $self->{yankBuffer} . substr($self->{inputBuffer}, $self->{inputPos});
			$self->{inputPos} += length $self->{yankBuffer};
		} elsif (ord($ch) == 21) {
			# Ctrl-U: Clear left of cursor
			$self->{yankBuffer} = substr( $self->{inputBuffer}, 0, $self->{inputPos} ) . $self->{yankAccumulator};
			$self->{inputBuffer} = substr $self->{inputBuffer}, $self->{inputPos};
			$self->{inputPos} = 0;
			$event_was_yank = 1;
		} elsif ($ch == KEY_LEFT) {
			# Cursor left
			$self->{inputPos}-- if ($self->{inputPos} > 0);
		} elsif ($ch == KEY_RIGHT) {
			# Cursor right
			$self->{inputPos}++ if ($self->{inputPos} < length($self->{inputBuffer}));
		} elsif ($ch == KEY_UP) {
			# Input history
			$self->{inputBuffer} = $self->history_back;
			$self->{inputPos} = length($self->{inputBuffer});
		} elsif ($ch == KEY_DOWN) {
			# Input history
			$self->{inputBuffer} = $self->history_forward;
			$self->{inputPos} = length($self->{inputBuffer});
		} elsif ($ch == KEY_PPAGE) {
			# TODO: Scrollback buffer
		} elsif ($ch == KEY_NPAGE) {
			# TODO: Scrollback buffer
		} elsif ($ch == KEY_F(1)) {
			# Toggle help window
			$self->toggleWindow("Help");
			$self->updateLayout;
		} elsif ($ch == KEY_F(2)) {
			# Toggle objects window
			$self->toggleWindow("Objects");
			$self->updateLayout;
		} elsif ($ch == KEY_F(3)) {
			# Toggle fight window
			$self->toggleWindow("Fight");
			$self->updateLayout;
		} elsif ($ch == KEY_F(4)) {
			# Toggle chat window
			$self->toggleWindow("Chat");
			$self->updateLayout;
		} elsif (ord($ch) == 18) {
			# Ctrl+R: Rotate objectsMode
			$self->{objectsMode}
				= !$self->{objectsMode} ? 'skills'
				: $self->{objectsMode} eq 'skills' ? 'inventory'
				:                                    undef;
		} elsif (ord($ch) == 1 || $ch == KEY_HOME) {
			# Ctrl+A: Beginning of line
			$self->{inputPos} = 0;
		} elsif (ord($ch) == 5 || $ch == KEY_END) {
			# Ctrl+E: End of line
			$self->{inputPos} = length $self->{inputBuffer};
		} elsif (ord($ch) == 23) {
			# Ctrl+W: Erase word
			my $pos = $self->{inputPos};
			$pos-- while $pos && substr( $self->{inputBuffer}, $pos - 1, 1 ) =~ /\s/o;
			$pos-- while $pos && substr( $self->{inputBuffer}, $pos - 1, 1 ) =~ /\S/o;
			$self->{yankBuffer} = substr( $self->{inputBuffer}, $pos, $self->{inputPos} - $pos ) . $self->{yankAccumulator};
			$self->{inputBuffer} = substr( $self->{inputBuffer}, 0, $pos ) . substr( $self->{inputBuffer}, $self->{inputPos} );
			$self->{inputPos} = $pos;
			$event_was_yank = 1;
		} elsif (length $ch > 1) {
			# Unhandled Curses special character. Ignore.
			Log::message("Console::Curses: Unknown special character [$ch]. Ignoring.\n");
		} elsif (ord($ch) >= 32 && ord($ch) <= 126) {
			# Normal character
			$self->{inputBuffer} = substr($self->{inputBuffer}, 0, $self->{inputPos}) . $ch . substr($self->{inputBuffer}, $self->{inputPos});
			$self->{inputPos} += length($ch);
		}
		$ch = getch();
	}

	$self->{yankAccumulator} = $event_was_yank ? $self->{yankBuffer} : '';

	my $pos = 0;
	$pos += 10 while length $self->{inputBuffer} >= $pos + $COLS;
	erase $self->{winInput};
	addstr $self->{winInput}, 0, 0, substr($self->{inputBuffer}, $pos);
	noutrefresh $self->{winInput};
	$self->setCursor;

	return ($ret ne "") ? $ret : undef;
}

sub swrite {
	my $self = shift;
	my $picture = shift;
	$^A = '';
	formline $picture, @_;
	return "$^A";
}

sub printw {
	my $self = shift;
	my $win = shift;
	my $line = shift;
	my $col = shift;
	my $picture = shift;
	my @params = @_;

	$^A = '';
	formline $picture, @params;
	my @text = split(/{([^}]+)}/, $^A);
	move $win, $line, $col;
	for (my $i = 0; $i < @text; $i += 2) {
		if (grep { exists $attrtable->{$_} } split /\|/, $text[$i+1]) {
			addstr $win, $text[$i];
			attrset $win, A_NORMAL;
			foreach my $attr (split(/\|/, $text[$i+1])) {
				attron $win, $attrtable->{$attr} if $attrtable->{$attr};
			}
		} else {
			addstr $win, $text[$i] . (defined $text[$i+1] ? "{$text[$i+1]}" : '');
		}
=pod
		addstr $win, $text[$i];
		if ($text[$i+1] ne "") {
			attrset $win, A_NORMAL;
			foreach my $attr (split(/\|/, $text[$i+1])) {
				attron $win, $attrtable->{$attr} if $attrtable->{$attr};
			}
		}
=cut
	}
}

sub makeBar {
	my $self = shift;
	my $len = shift;
	my $cur = shift;
	my $max = shift;
	my $color1 = shift;
	my $treshold = shift;
	my $color2 = shift;

	$len -= 2;
	my $pct = $max ? ($cur / $max * 100) : 0;
	my $cnt = int($len * $pct / 100);

	my $color = ($color1 ne "") ? (($pct >= $treshold && $color2 ne "") ? $color2 : $color1) : undef;
	my $bar = "";
	$bar .= "{normal}" if $color ne "";
	$bar .= "[";
	if (!$cur && !$max) {
		$bar .= (" " x $len);
	} else {
		$bar .= "{".$color."}" if $color ne "";
		$bar .= ("#" x $cnt);
		$bar .= "{normal}" if $color ne "";
		$bar .= ("-" x ($len-$cnt));
	}
	$bar .= "]";

	return $bar;
}

sub toggleWindow {
	my $self = shift;
	my $name = shift;

	if (!$self->{"win".$name}) {
		$self->{"win".$name} = newwin(5, 0, 0, 0);
		scrollok $self->{"win".$name}, 1 if ($name eq "Fight" || $name eq "Chat");
	} else {
		delwin $self->{"win".$name};
		undef $self->{"win".$name};
	}
}

sub updateLayout {
	my $self = shift;

	# Calculate window sizes
	$self->{winStatusHeight} = 5;
	$self->{winStatusWidth} = $COLS;
	$self->{winObjectsHeight} = $LINES - $self->{winStatusHeight} - 2;
	$self->{winObjectsWidth} = int($COLS * 0.20);
	$self->{winObjectsWidth} = 0 unless ($self->{winObjects});
	$self->{winChatHeight} = int(($LINES - $self->{winStatusHeight} - 2) * 0.20);
	$self->{winChatHeight} = 0 unless ($self->{winChat});
	$self->{winChatWidth} = $COLS - $self->{winObjectsWidth};
	$self->{winFightHeight} = int(($LINES - $self->{winStatusHeight} - 2) * 0.20);
	$self->{winFightHeight} = 0 unless ($self->{winFight});
	$self->{winFightWidth} = $COLS - $self->{winObjectsWidth};
	$self->{winLogHeight} = $LINES - $self->{winStatusHeight} - $self->{winFightHeight} - $self->{winChatHeight} - 2;
	$self->{winLogWidth} = $COLS - $self->{winObjectsWidth};

	# Status window
	resize $self->{winStatus}, $self->{winStatusHeight}-1, $self->{winStatusWidth};
	mvwin $self->{winStatus}, 0, 0;
	hline $self->{winStatusHeight}-1, 0, 0, $self->{winStatusWidth};
	# Objects window
	if ($self->{winObjects}) {
		resize $self->{winObjects}, $self->{winObjectsHeight}, $self->{winObjectsWidth}-1;
		mvwin $self->{winObjects}, $self->{winStatusHeight}, $self->{winLogWidth}+1;
		vline $self->{winStatusHeight}, $self->{winLogWidth}, 0, $self->{winObjectsHeight};
	}
	# Fight window
	if ($self->{winFight}) {
		resize $self->{winFight}, $self->{winFightHeight}-1, $self->{winFightWidth};
		mvwin $self->{winFight}, $self->{winStatusHeight}, 0;
		hline $self->{winStatusHeight} + $self->{winFightHeight} - 1, 0, 0, $self->{winFightWidth};
	}
	# Log Window
	if ($self->{winLog}) {
		resize $self->{winLog}, $self->{winLogHeight}, $self->{winLogWidth};
		mvwin $self->{winLog}, $self->{winStatusHeight} + $self->{winFightHeight}, 0;
	}
	# Chat window
	if ($self->{winChat}) {
		hline $self->{winStatusHeight} + $self->{winFightHeight} + $self->{winLogHeight}, 0, 0, $self->{winChatWidth};
		resize $self->{winChat}, $self->{winChatHeight}-1, $self->{winChatWidth};
		mvwin $self->{winChat}, $self->{winStatusHeight} + $self->{winFightHeight} + $self->{winLogHeight} + 1, 0;
	}
	# Input window
	hline $LINES-2, 0, 0, $COLS;
	resize $self->{winInput}, 1, $COLS;
	mvwin $self->{winInput}, $LINES-1, 0;
	noutrefresh;

	$self->{lines} = $LINES;
	$self->{cols} = $COLS;

	$self->updateAll;
}

sub updateAll {
	my $self = shift;

	$self->updateStatus;
	$self->updateObjects;
	noutrefresh $self->{winFight} if ($self->{winFight});
	noutrefresh $self->{winLog};
	noutrefresh $self->{winChat} if ($self->{winChat});
	noutrefresh $self->{winInput};
	$self->updatePopups;
}

sub updatePeriodic {
	my $self = shift;

	$self->updateStatus;
	$self->updateObjects;
	$self->updatePopups;
}

sub updatePopups {
	my $self = shift;

	$self->updateHelp;
}

sub updateStatus {
	my $self = shift;

	return unless $self->{winStatus};

	if ($self->{loading} && $self->{loading}{finish} != 2) {
		erase $self->{winStatus};
		my $width = int($self->{winStatusWidth});
		my $title = "$Settings::NAME ${Settings::VERSION}$self->{revision}";
		$self->printw($self->{winStatus}, 0, 0, "{bold|yellow}          @*{bold|blue} @".(">"x($width - length ($title) - 20)),
			$title, $Settings::WEBSITE);
		my $loadingbar = $self->makeBar($width-18, $self->{loading}{current}, $self->{loading}{total});
		$self->printw($self->{winStatus}, 1, 0, " {bold|green}Loading: $loadingbar (@##%)",
			$self->{loading}{current} ? $self->{loading}{current} / $self->{loading}{total} * 100 : 0);
		$self->printw($self->{winStatus}, 2, 0, "{green}          @*",
			$self->{loading}{text});
		
		$self->{loading}{finish} = 2 if $self->{loading}{finish};
		
		noutrefresh $self->{winStatus};
		return;
	}

	return unless $char;

	my $homun = $char->{homunculus} || {};
	my $bar_types = {
		char       => { title => 'Char' },
		status     => { title => 'Status' },
		hom_status => { title => 'HStatu' },
		location   => { title => 'Map' },

		base => { title => 'Base', cur => $char->{exp},     max => $char->{exp_max},     valtext => sprintf '%3d', $char->{lv} },
		job  => { title => 'Job',  cur => $char->{exp_job}, max => $char->{exp_job_max}, valtext => sprintf '%3d', $char->{lv_job} },

		hp       => { title => 'HP',     cur => $char->{hp},        max => $char->{hp_max},     color1 => 'bold|red',  color2 => 'bold|green', threshold => 15 },
		sp       => { title => 'SP',     cur => $char->{sp},        max => $char->{sp_max},     color1 => 'bold|blue', color2 => '',           threshold => 0 },
		weight   => { title => 'Weight', cur => $char->{weight},    max => $char->{weight_max}, color1 => 'cyan',      color2 => 'red',        threshold => 50 },
		hunger   => { title => 'Hunger', cur => $homun->{hunger},   max => 100,                 color1 => 'red',       color2 => 'green',      threshold => 0 },
		intimacy => { title => 'Loyal',  cur => $homun->{intimacy}, max => 1000,                color1 => 'red',       color2 => 'green',      threshold => 10 },
		hom_hp   => { title => 'Hom HP', cur => $homun->{hp},       max => $homun->{hp_max},    color1 => 'bold|red',  color2 => 'bold|green', threshold => 0 },
		hom_sp   => { title => 'Hom SP', cur => $homun->{sp},       max => $homun->{sp_max},    color1 => 'bold|blue', color2 => '',           threshold => 0 },

		attack_target_hp => { title => 'Atk HP' },
	};
	my $bars = [
		{ col => 0, row => 0, type => $config{"bar_1_1"} || 'char' },
		{ col => 0, row => 1, type => $config{"bar_1_2"} || 'base' },
		{ col => 0, row => 2, type => $config{"bar_1_3"} || 'job' },
		{ col => 0, row => 3, type => $config{"bar_1_4"} || 'location' },
		{ col => 1, row => 0, type => $config{"bar_2_1"} || 'hp' },
		{ col => 1, row => 1, type => $config{"bar_2_2"} || 'sp' },
		{ col => 1, row => 2, type => $config{"bar_2_3"} || 'weight' },
		{ col => 1, row => 3, type => $config{"bar_2_4"} || 'status' },
		{ col => 2, row => 0, type => $config{"bar_3_1"} || $char->{homunculus} && 'hom_hp' || '' },
		{ col => 2, row => 1, type => $config{"bar_3_2"} || $char->{homunculus} && 'hunger' || '' },
		{ col => 2, row => 2, type => $config{"bar_3_3"} || $char->{homunculus} && 'intimacy' || '' },
		{ col => 2, row => 3, type => $config{"bar_3_4"} || $char->{homunculus} && 'hom_status' || '' },
	];
	my $cols = 2;
	foreach my $bar ( @$bars ) {
        next if !$bar_types->{ $bar->{type} };

		$bar->{$_} = $bar_types->{ $bar->{type} }->{$_} foreach keys %{ $bar_types->{ $bar->{type} } };

		if ( $bar->{type} eq 'char' ) {
			$bar->{text} = $self->swrite( '{bold|white}@*{normal} (@* - @*)', $char->{name}, $jobs_lut{ $char->{jobID} }, $sex_lut{ $char->{sex} } );
		} elsif ( $bar->{type} eq 'status' ) {
			$bar->{text} = $char->statusesString;
		} elsif ( $bar->{type} eq 'hom_status' ) {
			$bar->{text} = eval { $homun->can( 'statusesString' ) } ? $homun->statusesString : 'No homunculus summoned.';
		} elsif ( $bar->{type} eq 'location' ) {
			my $pos = calcPosition( $char );
			$bar->{title} = 'City' if $field->isCity;
			$bar->{text} = $self->swrite( '@* (@*,@*)', $field->name, $pos->{x}, $pos->{y} );
			my ( $i, $args );
			if ( ( $i = AI::findAction( 'attack' ) ) ne '' and $args = AI::args( $i ) and $args = Actor::get( $args->{ID} ) ) {
				$bar->{text} .= $self->swrite( ' => {red}@*{normal}', $args->name );
			} elsif ( ( $i = AI::findAction( 'follow' ) ) ne '' and $args = AI::args( $i ) and $args->{following} || $args->{ai_follow_lost} ) {
				$bar->{text} .= $self->swrite( ' => {cyan}@*{normal}', $args->{name} );
			} elsif ( ( $i = Utils::DataStructures::binFindReverse( \@AI::ai_seq, 'route' ) ) ne '' and $args = AI::args( $i ) ) {
				if ( $args->{dest}{map} eq $field->baseName ) {
					$bar->{text} .= $self->swrite( ' => (@*,@*)', $args->{dest}{pos}{x}, $args->{dest}{pos}{y} );
				} elsif ( !defined $args->{dest}{pos}{x} ) {
					$bar->{text} .= $self->swrite( ' => @*', $args->{dest}{map} );
				} else {
					$bar->{text} .= $self->swrite( ' => @* (@*,@*)', $args->{dest}{map}, $args->{dest}{pos}{x}, $args->{dest}{pos}{y} );
				}
			}
		} elsif ( $bar->{type} eq 'intimacy' ) {
			$bar->{title} = 'Cordial' if $homun->{intimacy} <= 910;
			$bar->{title} = 'Neutral' if $homun->{intimacy} <= 750;
			$bar->{title} = 'Shy'     if $homun->{intimacy} <= 250;
			$bar->{title} = 'Awkwrd'  if $homun->{intimacy} <= 100;
			$bar->{title} = 'Hate'    if $homun->{intimacy} <= 10;
		} elsif ( $bar->{type} eq 'attack_target_hp' ) {
			my $target;
			my $i = AI::findAction('attack');
			if ( $i ne '' && ( $target = Actor::get( AI::args( $i )->{ID} ) ) ) {
				$bar->{cur} = $target->{hp};
				$bar->{max} = $target->{hp_max};
			}
		}
		$cols = max( $cols, $bar->{col} + 1 ) if $bar->{type};
	}

	erase $self->{winStatus};
	my $width = int( ( $self->{winStatusWidth} + 3 ) / $cols - 3 );

	foreach ( 1 .. ( $cols - 1 ) ) {
		vline $self->{winStatus}, 0, ( $width + 3 ) * $_ - 2, 0, $self->{winStatusHeight};
	}
	foreach my $bar ( @$bars ) {
		next if !$bar->{type};
        next if !$bar_types->{ $bar->{type} };
		if ( !defined $bar->{text} ) {
			my $val_str = $self->swrite( $bar->{valtext} || '@####/@####', $bar->{cur}, $bar->{max} );
			my $bar_str = $self->makeBar( $width - 18 - length $val_str, $bar->{cur}, $bar->{max}, $bar->{color1}, $bar->{threshold}, $bar->{color2} );
			$bar->{text} = $self->swrite( "$val_str $bar_str (@##.#%)", !$bar->{max} ? 0 : 100 * $bar->{cur} / $bar->{max} );
		}
		$self->printw( $self->{winStatus}, $bar->{row}, $bar->{col} * ( $width + 3 ), "{bold|yellow}@>>>>>:{normal} @*", $bar->{title}, $bar->{text} );
	}

	$self->{heartBeat} = !$self->{heartBeat};
	addstr $self->{winStatus}, 0, 0, $self->{heartBeat} ? ":" : ".";

	Plugins::callHook( 'curses/updateStatus' );

	noutrefresh $self->{winStatus};
}

sub updateObjects {
	my $self = shift;

	return if (!$self->{winObjects});
	return unless $char;

	my $line = 0;
	my $namelen = $self->{winObjectsWidth} - 9;
	erase $self->{winObjects};

	my $display = $self->{objectsMode} ? $self->{objectsMode} : $sys{curses_objects} || 'players, monsters, slaves, items, npcs';
	
	for (split /\s*,\s*/, $display) {
		my ($objectsID, $objects, $style) = ([], {}, 'normal');
		if ($_ eq 'players') {
			($objectsID, $objects, $style) = (\@playersID, \%players, 'cyan');
		} elsif ($_ eq 'monsters') {
			($objectsID, $objects, $style) = (\@monstersID, \%monsters, 'red');
		} elsif ($_ eq 'slaves') {
			($objectsID, $objects, $style) = (\@slavesID, \%slaves, 'green');
		} elsif ($_ eq 'items') {
			($objectsID, $objects, $style) = (\@itemsID, \%items, 'green');
		} elsif ($_ eq 'npcs') {
			($objectsID, $objects, $style) = (\@npcsID, \%npcs, 'blue');
		} elsif ($_ eq 'skills') {
			($objectsID, $objects, $style) = (\@skillsID, $char->{skills}, 'cyan');
		} elsif ($_ eq 'inventory') {
			for my $item (@{$char->inventory->getItems}) {
				$objectsID->[$item->{invIndex}] = $item->{invIndex};
				$objects->{$item->{invIndex}} = $item;
			}
			$style = 'normal';
		} else {
			next;
		}
		for (my $i = 0; $i < @$objectsID && $line < $self->{winObjectsHeight}; $i++) {
			my $id = $objectsID->[$i];
			next if ($id eq "");
			next if $config{monster_filter} && $objectsID == \@monstersID && $objects->{$id}->{name_given} !~ /$config{monster_filter}/igs;
			
			my $lineStyle = $style;
			my $idx = $i;
			my $name;
			my $count;
			if ($_ eq 'skills') {
				($idx,$name,$count) = ($objects->{$id}{ID}, Skill->new(handle => $id)->getName, $objects->{$id}{lv});
				$lineStyle = 'normal' unless $objects->{$id}{sp};
				$lineStyle = 'blue' unless $objects->{$id}{lv} || $objects->{$id}{up};
			} elsif ($_ eq 'inventory') {
				($idx,$name,$count) = ($i, $objects->{$id}{name}, $objects->{$id}{amount});
				if ($objects->{$id}->usable) {
					$lineStyle = 'green';
				} elsif ($objects->{$id}{equipped}) {
					$lineStyle = 'cyan';
				} elsif ($objects->{$id}->equippable) {
					$lineStyle = 'blue';
				}
			} else {
				($idx,$name,$count) = ($i, $objects->{$id}->name, distance($char->{pos}, $objects->{$id}{pos}));
				$lineStyle = 'yellow' if $char->{party}{users}{$id};
			}

			if ($_ eq 'slaves') {
				$name .= " [$objects->{$id}->{given_name}]" if $objects->{$id}->{given_name} && $objects->{$id}->name ne $objects->{$id}->{given_name};
			}

			if ($namelen > 10 + 1 + 10 && $objects->{$id}->{hp_max}) {
				my $bar = $self->makeBar( 10, $objects->{$id}->{hp}, $objects->{$id}->{hp_max} );
				$name = $self->swrite( '@' . ( '<' x ($namelen - 11) ) . ' @' . ( '<' x 9 ), $name, $bar );
			}

			$self->printw($self->{winObjects}, $line++, 0, "{bold|$lineStyle}@## {$lineStyle}@".("<"x$namelen)." {normal}@#",
				$idx, $name, $count
			);
		}
		if ($_ eq 'skills' && $line < $self->{winObjectsHeight}) {
			$self->printw($self->{winObjects}, $line++, 0, "    {red}@".("<"x$namelen)." {bold|red}@#",
				'Skill Points', $char->{points_skill}
			);
		}
	}

=pod
	# Players
	for (my $i = 0; $i < @playersID && $line < $self->{winObjectsHeight}; $i++) {
		my $id = $playersID[$i];
		next if ($id eq "");
		my $name = $players{$id}{name};
		my $dist = distance($char->{pos}, $players{$id}{pos});
		$self->printw($self->{winObjects}, $line++, 0, "{bold|cyan}@# {cyan}@".("<"x$namelen)." {normal}@#", $i, $name, $dist);
	}

	# Monsters
	for (my $i = 0; $i < @monstersID && $line < $self->{winObjectsHeight}; $i++) {
		my $id = $monstersID[$i];
		next if ($id eq "");
		my $name = $monsters{$id}{name};
		my $dist = distance($char->{pos}, $monsters{$id}{pos});
		$self->printw($self->{winObjects}, $line++, 0, "{bold|red}@# {red}@".("<"x$namelen)." {normal}@#", $i, $name, $dist);
	}

	# Items
	for (my $i = 0; $i < @itemsID && $line < $self->{winObjectsHeight}; $i++) {
		my $id = $itemsID[$i];
		next if ($id eq "");
		my $name = $items{$id}{name};
		my $dist = distance($char->{pos}, $items{$id}{pos});
		$self->printw($self->{winObjects}, $line++, 0, "{bold|green}@# {green}@".("<"x$namelen)." {normal}@#", $i, $name, $dist);
	}

	# NPCs
	for (my $i = 0; $i < @npcsID && $line < $self->{winObjectsHeight}; $i++) {
		my $id = $npcsID[$i];
		next if ($id eq "");
		my $name = $npcs{$id}{name};
		my $dist = distance($char->{pos}, $npcs{$id}{pos});
		$self->printw($self->{winObjects}, $line++, 0, "{bold|blue}@# {blue}@".("<"x$namelen)." {normal}@#", $i, $name, $dist);
	}
=cut

	Plugins::callHook( 'curses/updateObjects' );

	noutrefresh $self->{winObjects};
}

sub updateHelp {
	my $self = shift;

	return if (!$self->{winHelp});

	my $height = 15;
	my $width = 70;
	resize $self->{winHelp}, $height, $width;
	mvwin $self->{winHelp}, int(($LINES-$height)/2), int(($COLS-$width)/2);

	erase $self->{winHelp};
	box $self->{winHelp}, 0, 0;
	my $center = "@" . ("|" x ($width-7));
	$self->printw($self->{winHelp}, 1, 1, " {bold|white} $center {normal}",
		"OpenKore v$Settings::VERSION");
	$self->printw($self->{winHelp}, 3, 1, " {bold|white}<F1>{normal}        Show/hide this help window");
	$self->printw($self->{winHelp}, 4, 1, " {bold|white}<F2>{normal}        Show/hide objects (players,monsters,items,NPCs) pane");
	$self->printw($self->{winHelp}, 5, 1, " {bold|white}<F3>{normal}        Show/hide fight message pane");
	$self->printw($self->{winHelp}, 6, 1, " {bold|white}<F4>{normal}        Show/hide chat message pane");
	$self->printw($self->{winHelp}, 8, 1, " {bold|white}<Ctrl-L>{normal}    Redraw screen");
	$self->printw($self->{winHelp}, 9, 1, " {bold|white}<Ctrl-U>{normal}    Clear input line");
	$self->printw($self->{winHelp}, 11, 1, " {bold|white}<Up>{normal}/{bold|white}<Down>{normal} Input history");
	$self->printw($self->{winHelp}, 13, 1, " {bold|blue} $center {normal}",
		"Visit http://openkore.sourceforge.net/ for more stuff");

	noutrefresh $self->{winHelp};
}

sub setCursor {
	my $self = shift;

	my $pos = $self->{inputPos};
	$pos -= 10 while ($pos >= $COLS);
	move $LINES - 1, $pos;
	noutrefresh;
	doupdate;
}

sub loadfiles {
	my ($self, $hook, $param) = @_;
	
	if ($hook eq 'loadfiles') {
		$self->{loading} = {
			current => $param->{current},
			total => scalar @{$param->{files}},
			text => $param->{files}[$param->{current} - 1]{name},
		};
	} else {
		$self->history_load;

		Plugins::delHooks ($self->{loadingHooks});
		delete $self->{loadingHooks};
		$self->{loading} = {
			current => 1,
			total => 1,
			text => 'Ready',
			finish => 1,
		};
	}
	
	$self->updateStatus;
}

# This history stuff should be extracted into a separate object that can work with any interface.

sub history_max {
	$config{history_max} || MAXHISTORY
}

sub history_file {
	File::Spec->catfile( $Settings::logs_folder, sprintf '%s_%s_%s.txt', 'history', $config{username}, $config{char} );
}

sub history_init {
	my ( $self ) = @_;

	$self->{inputHistoryPos} = 0;
	$self->{inputHistory}    = [];
}

sub history_load {
	my ( $self ) = @_;

	$self->history_init;

	my $log_fp;
	return if !open $log_fp, '<', $self->history_file;
	seek $log_fp, 0, 2;

	# Load up log lines from the end of the file.
	my $pos = tell $log_fp;
	my $buf = '';
	while ( $pos && scalar( split $buf, "\n" ) <= $self->history_max ) {
		my $offset = $pos < 8192 ? $pos : 8192;
		$pos -= $offset;
		seek $log_fp, $pos, 0;
		my $tmp = '';
		read $log_fp, $tmp, $offset;
		substr $buf, 0, 0, $tmp;
	}
	@{ $self->{inputHistory} } = reverse split /[\r\n]+/, $buf;
	splice @{ $self->{inputHistory} }, $self->history_max if @{ $self->{inputHistory} } > $self->history_max;

	# Strip the timestamps.
	s/^\[.*?\] // foreach @{ $self->{inputHistory} };
}

sub history_forward {
	my ( $self ) = @_;
	$self->{inputHistoryPos}-- if $self->{inputHistoryPos};
	$self->history_get;
}

sub history_back {
	my ( $self ) = @_;
	$self->{inputHistoryPos}++ if $self->{inputHistoryPos} < @{ $self->{inputHistory} };
	$self->history_get;
}

sub history_get {
	my ( $self ) = @_;
	return '' if !$self->{inputHistoryPos};
	$self->{inputHistory}->[ $self->{inputHistoryPos} - 1 ];
}

sub history_add {
	my ( $self, $msg ) = @_;

	$self->{inputHistoryPos} = 0;

	return if !$msg;
	return if @{ $self->{inputHistory} } && $msg eq $self->{inputHistory}->[0];

	unshift @{ $self->{inputHistory} }, $msg;
	pop @{ $self->{inputHistory} } while @{ $self->{inputHistory} } > $self->history_max;

	my $log_fp = $self->{log_fp};
	if ( !$log_fp || $self->{log_file} ne $self->history_file ) {
		open $log_fp, '>>', $self->history_file;
		select( ( select( $log_fp ), $|++ )[0] ) if $log_fp;
		$self->{log_fp}   = $log_fp;
		$self->{log_file} = $self->history_file;
	}
	print $log_fp "[" . localtime() . "] $msg\n" if $log_fp;
}

1;
