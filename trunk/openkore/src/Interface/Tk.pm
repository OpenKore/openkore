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
#
#  $Revision$
#  $Id$
#
#########################################################################

package Interface::Tk;
use strict;
use warnings;

use Interface;
use base qw/Interface/;
use Plugins qw/addHook/;
use Globals;

use Carp qw/carp croak confess/;
use Time::HiRes qw/time/;
use Tk;
use Tk::ROText;
use Tk::BrowseEntry;


#these should go in a config file at some point.
our $line_limit = 1000;
our $default_font = "MS_Sans_Serif";

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
		input_type => "Command",
		input_pm => undef,
		total_lines => 0,
		last_line_end => 0,
		colors => {},
	};
	bless $self, $class;
	$self->initTk;

#	if ($^O eq 'MSWin32' || $^O eq 'cygwin') {
#		require Win32::Console;	import Win32::Console;
#		Win32::Console->new(&STD_OUTPUT_HANDLE())->Free or warn "could not free console: $!\n";
#	}

	addHook('postloadfiles', \&resetColors, $self);
	return $self;
}

sub getInput{
	my $self = shift;
	my $timeout = shift;
	my $msg;
	if ($timeout < 0) {
		until ($msg) {
			$self->update();
			if (@{ $self->{input_que} }) { 
				$msg = shift @{ $self->{input_que} }; 
			} 
		}
	} elsif ($timeout > 0) {
		my $end = time + $timeout;
		until ($end < time || $msg) {
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
	return $msg;
}


sub writeOutput {
	my $self = shift;
	my $type = shift;
	my $message = shift;
	my $domain = shift;

	my $scroll = 0;
	$scroll = 1 if (($self->{console}->yview)[1] == 1);
	
	#keep track of lines to limit the number of lines in the text widget
	$self->{total_lines} += $message =~ s/\r?\n/\n/g;

	$self->{console}->insert('end', "\n") if $self->{last_line_end};
	$self->{last_line_end} = $message =~ s/\n$//;

	$self->{console}->insert('end', $message, "$type $type.$domain");

	#remove extra lines
	if ($self->{total_lines} > $line_limit) {
		my $overage = $self->{total_lines} - $line_limit;
		$self->{console}->delete('1.0', $overage+1 . ".0");
		$self->{total_lines} -= $overage;
	}

	$self->{console}->see('end') if $scroll;

	$self->update();
}

sub update{
	my $self = shift;
	$self->{mw}->update();
}

sub updatePos {
	my $self = shift;
	my ($x,$y) = @_;
	$self->{status_posx}->configure( -text =>$x);
	$self->{status_posy}->configure( -text =>$y);
#	if (Exists $map_mw ) {
#		$map_mw{'canvas'}->delete($map_mw{'player'}) if($map_mw{'player'});
#		$map_mw{'canvas'}->delete($map_mw{'range'}) if ($map_mw{'range'});
#		$map_mw{'player'} = $map_mw{'canvas'}->createOval(
#			$x-2,$map_mw{'map'}{'y'} - $y-2,
#			$x+2,$map_mw{'map'}{'y'} - $y+2,
#			,-fill => '#ffcccc', -outline=>'#ff0000');
#		my $dis = $main::config{'attackDistance'};
#		$map_mw{'range'} = $map_mw{'canvas'}->createOval(
#			$x-$dis,$map_mw{'map'}{'y'} - $y-$dis,
#			$x+$dis,$map_mw{'map'}{'y'} - $y+$dis,
#			,-outline=>'#ff0000');
#	}
}

sub updateStatus {
	my $self = shift;
	my $text = shift;
	$self->{status_gen}->configure(-text => $text);
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

################################################################
# Private? Method
################################################################
#FIXME many of thise methods don't support OO calls yet, update them and all their references
sub initTk {
	my $self = shift;
	
	$self->{mw} = MainWindow->new();
	$self->{mw}->protocol('WM_DELETE_WINDOW', [\&OnExit, $self]);
	#$self->{mw}->Icon(-image=>$self->{mw}->Photo(-file=>"hyb.gif"));
	$self->{mw}->title("OpenKore Tk Interface");
#	$self->{mw}->configure(-menu => $self->{mw}->Menu(-menuitems=>
#	[ map 
#		['cascade', $_->[0], -tearoff=> 0, -font=>[-family=>"Tahoma",-size=>8], -menuitems => $_->[1]],
#		['~modKore',
#			[[qw/command E~xit  -accelerator Ctrl+X/, -font=>[-family=>"Tahoma",-size=>8], -command=>[\&OnExit]],]
#		],
#		['~View',
#			[
#				[qw/command Map  -accelerator Ctrl+M/, -font=>[-family=>"Tahoma",-size=>8], -command=>[\&OpenMap, $class]],
#				'',
#				[qw/command Status -accelerator Alt+D/, -font=>[-family=>"Tahoma",-size=>8], -command=>sub{push(@input_que, "s");}],
#				[qw/command Skill -accelerator Alt+S/, -font=>[-family=>"Tahoma",-size=>8], -command=>sub{push(@input_que, "skills");}],
#				[qw/command Equipment -accelerator Alt+Q/, -font=>[-family=>"Tahoma",-size=>8], -command=>sub{push(@input_que, "i eq");}],
#				[qw/command Stat -accelerator Alt+A/, -font=>[-family=>"Tahoma",-size=>8], -command=>sub{push(@input_que, "st");}],
#				[qw/command Usable -accelerator Alt+E/, -font=>[-family=>"Tahoma",-size=>8], -command=>sub{push(@input_que, "i u");}],
#				[qw/command Non-Usable -accelerator Alt+W/, -font=>[-family=>"Tahoma",-size=>8], -command=>sub{push(@input_que, "i nu");}],
#				[qw/command Exp -accelerator Alt+Z/, -font=>[-family=>"Tahoma",-size=>8], -command=>sub{push(@input_que, "exp");}],
#				[qw/command Cart -accelerator Alt+C/, -font=>[-family=>"Tahoma",-size=>8], -command=>sub{push(@input_que, "cart");}],
#				'',
#				[cascade=>"Guild", -tearoff=> 0, -font=>[-family=>"Tahoma",-size=>8], -menuitems =>
#					[
#						[qw/command Info -accelerator ALT+F/, -font=>[-family=>"Tahoma",-size=>8], -command=>sub{push(@input_que, "guild i");}],
#						[qw/command Member -accelerator ALT+G/, -font=>[-family=>"Tahoma",-size=>8], -command=>sub{push(@input_que, "guild m");}],
#						[qw/command Position -accelerator ALT+H/, -font=>[-family=>"Tahoma",-size=>8], -command=>sub{push(@input_que, "guild p");}],
#					 ],
#				],
#				'',
#				[cascade=>"Font Weight", -tearoff=> 0, -font=>[-family=>"Tahoma",-size=>8], -menuitems => 
#					[
#						[Checkbutton  => '~Bold', -variable => \$is_bold,-font=>[-family=>"Tahoma",-size=>8],-command => [\&change_fontWeight]],
#					]
#				],
#			],
#		],
#		['~Reload',
#			[
#				[qw/command config -accelerator Ctrl+C/, -font=>[-family=>"Tahoma",-size=>8], -command=>sub{push(@input_que, "reload conf");}],
#				[qw/command mon_control  -accelerator Ctrl+W/, -font=>[-family=>"Tahoma",-size=>8], -command=>sub{push(@input_que, "reload mon_");}],
#				[qw/command item_control  -accelerator Ctrl+Q/, -font=>[-family=>"Tahoma",-size=>8], -command=>sub{push(@input_que, "reload items_");}],
#				[qw/command cart_control  -accelerator Ctrl+E/, -font=>[-family=>"Tahoma",-size=>8], -command=>sub{push(@input_que, "reload cart_");}],
#				[qw/command ppl_control  -accelerator Ctrl+D/, -font=>[-family=>"Tahoma",-size=>8], -command=>sub{push(@input_que, "reload ppl_");}],
#				[qw/command timeouts  -accelerator Ctrl+Z/, -font=>[-family=>"Tahoma",-size=>8], -command=>sub{push(@input_que, "reload timeouts");}],
#				[qw/command pickupitems  -accelerator Ctrl+V/, -font=>[-family=>"Tahoma",-size=>8], -command=>sub{push(@input_que, "reload pick");}],
#				[qw/command chatAuto  -accelerator Ctrl+A/, -font=>[-family=>"Tahoma",-size=>8], -command=>sub{push(@input_que, "reload chatAuto");}],
#				'',
#				[qw/command All  -accelerator Ctrl+S/, -font=>[-family=>"Tahoma",-size=>8], -command=>sub{push(@input_que, "reload all");}],
#			]
#		],
#	]
#	));

	$self->{console} = $self->{mw}->Scrolled('ROText',
		-bg=>'black',
		-fg=>'grey',
		-scrollbars => 'e',
		-height => 20,
		-wrap => 'word',
		-width => 80,
		-insertontime => 0,
		-background => 'black',
		-foreground => 'grey',
		-font=>[ -family => $default_font ,-size=>10,],
		-relief => 'sunken',
	)->pack(
		-expand => 1,
		-fill => 'both',
		-side => 'top',
	);

	$self->{input_frame} = $self->{mw}->Frame(
		-bg=>'black'
	)->pack(
		-side => 'top',
		-expand => 0,
		-fill => 'x',
	);

	$self->{status_frame} = $self->{mw}->Frame()->pack(
		-side => 'top',
		-expand => 0,
		-fill => 'x',
	);

	#------ subclass in input frame
	$self->{pminput} = $self->{input_frame}->BrowseEntry(
		-bg=>'black',
		-fg=>'grey',
		-variable => \$self->{input_pm},
		-width => 8,
		-choices => $self->{pm_list},
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
		-font=>[ -family => $default_font ,-size=>10,],
	)->pack(
		-expand=>1,
		-fill => 'x',
		-side => 'left',
	);

	$self->{sinput} = $self->{input_frame}->BrowseEntry(
		-bg=>'black',
		-fg=>'grey',
		-variable => \$self->{input_type},
		-choices => [qw(Command Public Party Guild)],
		-width => 8,
		-state =>'readonly',
		-relief => 'flat',
	)->pack	(
		-expand=>0,
		-fill => 'x',
		-side => 'left',
	);

	#------ subclass in status frame
	$self->{status_gen} = $self->{status_frame}->Label(
		-anchor => 'w',
		-text => 'Ready',
		-font => ['Arial', 8],
		-bd=>0,
		-relief => 'sunken',
	)->pack(
		-side => 'left',
		-expand => 1,
		-fill => 'x',
	);

	$self->{status_ai} = $self->{status_frame}->Label(
		-text => 'Ai - Status',
		-font => ['Arial', 8],
		-width => 25,
		-relief => 'ridge',
	)->pack(
		-side => 'left',
		-expand => 0,
		-fill => 'x',
	);

	$self->{status_posx} = $self->{status_frame}->Label(
		-text => '0',
		-font => ['Arial', 8],
		-width => 4,
		-relief => 'ridge',
	)->pack(
		-side => 'left',
		-expand => 0,
		-fill => 'x',
	);

	$self->{status_posy} = $self->{status_frame}->Label(
		-text => '0',
		-font => ['Arial', 8],
		-width => 4,
		-relief => 'ridge',
	)->pack(
		-side => 'left',
		-expand => 0,
		-fill => 'x',
	);

	#Binding
	#FIXME Do I want to quit on cut? ... NO!
	#$self->{mw}->bind('all','<Control-x>'=>[\&OnExit]);
	#$self->{mw}->bind('all','<Control-m>'=>[\&OpenMap, $self]);
	#FIXME hey that's copy....
	#$self->{mw}->bind('all','<Control-c>'=>sub{push(@input_que, "reload conf");});
	#$self->{mw}->bind('all','<Control-w>'=>sub{push(@input_que, "reload mon_");});
	#$self->{mw}->bind('all','<Control-q>'=>sub{push(@input_que, "reload items_");});
	#$self->{mw}->bind('all','<Control-e>'=>sub{push(@input_que, "reload cart_");});
	#$self->{mw}->bind('all','<Control-d>'=>sub{push(@input_que, "reload ppl_");});
	#$self->{mw}->bind('all','<Control-z>'=>sub{push(@input_que, "reload timeouts");});
	#FIXME hey that's paste....
	#$self->{mw}->bind('all','<Control-v>'=>sub{push(@input_que, "reload pick");});
	#$self->{mw}->bind('all','<Control-a>'=>sub{push(@input_que, "reload chatAuto");});
	#$self->{mw}->bind('all','<Control-s>'=>sub{push(@input_que, "reload all");});
	#$self->{mw}->bind('all','<Alt-d>'=>sub{push(@input_que, "s");});
	#$self->{mw}->bind('all','<Alt-s>'=>sub{push(@input_que, "skills");});
	#$self->{mw}->bind('all','<Alt-q>'=>sub{push(@input_que, "i eq");});
	#$self->{mw}->bind('all','<Alt-a>'=>sub{push(@input_que, "st");});
	#$self->{mw}->bind('all','<Alt-e>'=>sub{push(@input_que, "i u");});
	#$self->{mw}->bind('all','<Alt-w>'=>sub{push(@input_que, "i nu");});
	#$self->{mw}->bind('all','<Alt-z>'=>sub{push(@input_que, "exp");});
	#cookiemaster cart shortcut
	#$self->{mw}->bind('all','<Alt-c>'=>sub{push(@input_que, "cart");});
	#digitalpheer guild shortcut 
	#$self->{mw}->bind('all','<Alt-f>'=>sub{push(@input_que, "guild i");});
	#$self->{mw}->bind('all','<Alt-g>'=>sub{push(@input_que, "guild m");});
	#$self->{mw}->bind('all','<Alt-h>'=>sub{push(@input_que, "guild p");});

	$self->{input}->bind('<Up>' => [\&inputUp, $self]);
	$self->{input}->bind('<Down>' => [\&inputDown, $self]);
	$self->{input}->bind('<Return>' => [\&inputEnter, $self]);

	if ($^O eq 'MSWin32' || $^O eq 'cygwin') {
		$self->{input}->bind('<MouseWheel>' => [\&w32mWheel, $self, Ev('k')]);
		$self->{console}->bind('<MouseWheel>' => [\&w32mWheel, $self, Ev('k')]);
	} else {
		#I forgot the X code. will insert later
	}

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
	return unless $line;

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
#	print "'$line'\n";

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
	push(@{ $self->{input_que} }, 'quit');
}

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
		$self->{console}->configure(%gdefault);
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
			$self->{console}->tagConfigure($type, %tdefault);
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
				$self->{console}->tagConfigure("$type.$domain", %color);
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
}

sub parseColorFile {
	my $file = shift;
	my $self = shift;
	my $r_hash = $self->{colors};
	my @old_tags = keys %$r_hash;
	undef %{$r_hash};
	open FILE, $file;
	foreach (<FILE>) {
		next if (/^(?:#|$)/);
		tr/\r\n//d;
		s/\s+$//g;
		my ($key, $fgcolor, $bgcolor) =m!([\S\S]+)\s+([^/]+)?(?:/(.+))?$!;
		if ($key eq 'default_only') {
			$r_hash->{$key} = $fgcolor;
		} elsif ($key ne '') {
			$r_hash->{$key} = {-foreground => $fgcolor, -background => $bgcolor};
		} else {
			warn "Error reading $file at $.\n";
		}
	}
	close FILE;
	eval {
		$self->{console}->configure(%{ $r_hash->{default} });
		$self->{input}->configure(%{ $r_hash->{default} });
		$self->{pminput}->configure(%{ $r_hash->{default} });
		$self->{sinput}->configure(%{ $r_hash->{default} });
	};
	if ($@) {
		if ($@ =~ /unknown color name "(.*)" at/) {
			Log::error("Color '$1' not recognised in tkcolors.txt directive 'default'.\n");
			return undef if isTrue($r_hash->{default_only}); #don't bother throwing a lot of errors in the next section.
		} else {
			die $@;
		}
	}
	if (isTrue($r_hash->{default_only})) {
		foreach my $tag (@old_tags) {
			next if $tag eq 'default' || $tag eq 'default_only';
			#this is not checked like above because it should not run when the above has thrown an error
			$self->{console}->tagConfigure(
				$tag,
				%{ $r_hash->{default} }
			);
		}
	} else {
		foreach my $tag (keys %$r_hash) {
			next if $tag eq 'default' || $tag eq 'default_only';
			eval {
				$self->{console}->tagConfigure(
					$tag,
					%{ $r_hash->{$tag} }
				);
			};
			if ($@) {
				if ($@ =~ /unknown color name "(.*)" at/) {
					Log::error("Color '$1' not recognised in tkcolors.txt directive '$tag'.\n");
				} else {
					die $@;
				}
			}
		}
	}
}

sub isTrue {
	my $value = shift;
	return 0 unless defined $value;
	return ($value =~ /^\d+$/) ? #if it's a number
		($value != 0) : #return true if it's not 0
		($value eq 'true' || $value eq 'yes' || $value eq 'on'); #if it's not a number return true if it's a synonym for true
}



1 #end of module
