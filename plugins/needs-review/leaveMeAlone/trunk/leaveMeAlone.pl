#############################################################################
# leaveMeAlone! revision 05 plugin by imikelance										
#																			
# Openkore: http://openkore.com/											
# Openkore Brazil: http://openkore.com.br/	
#
# 15:13 sexta-feira, 16 de março de 2012
#	- added support to loading .txt files from control folder, this way you can have different or specific lists
#	- supressed messages shown while blocking players (from this plugin and kore's default message too)
#	- added openkore rev check to avoid unnecessary posts :P
#	- show blacklist size when we start blocking the list
# 
# 16:20 segunda-feira, 20 de fevereiro de 2012
#	- changed default block queue from AI-dependent to non-AI-dependent. now we won't flood AI.
#	- added AI_MODE to revert back to AI-dependent block queue
#	- now we won't re-block players on map change
#
# 10:50 segunda-feira, 30 de janeiro de 2012
#	- changed AI_pre hook to mainLoop_pre
#
# 06:05 segunda-feira, 30 de janeiro de 2012
#	- added whitelist sub commands
#	- added blacklist command
#	- now block users command is queued into kore's AI
#	- won't keep opening and closing .txt, now we're storing DBs into @blacklist and @whitelist
#	- added BLOCKDELAY constant to avoid DCs
#	- auto create files and folders
#	- added checks to detect .txt files changes
#	- added commands help, use "whitelist help" and "blacklist help"
#	- added checks to verify if we're blocking a "whitelisted" user
#	- [DEV] added AI_pre hook
#	- [DEV] added sub msg to handle console messages properly
#
# 17:08 sexta-feira, 27 de janeiro de 2012
#	- added whitelist.txt and whitelist command					
#																			
# 06:22 sexta-feira, 27 de janeiro de 2012
# 	- released !					
#																			
# This source code is licensed under the									
# GNU General Public License, Version 3.									
# See http://www.gnu.org/licenses/gpl.html									
#############################################################################
package leaveMeAlone;

use strict;
use Plugins;
use Actor;
use Log qw( warning message error );
use Time::HiRes qw(time);
use AI;
use Globals;

# Plugin
Plugins::register("leaveMeAlone", "keeps a list of ignored players and block spammers", \&unload);

	my $myHooks = Plugins::addHooks(
		['start3',       	\&start, undef],
		['packet_privMsg',	\&messages, undef],
		['packet_pubMsg',	\&messages, undef],
		['packet/map_loaded',			\&ingame],
		['mainLoop_pre',	\&AI_hook], # AI_pre freezes if AI = manual
		['packet/received_characters',	\&turnOn],
		['packet_pre/ignore_player_result', \&hideResultPacketMsg],
	);
		
	my $myCmds = Commands::register(
		['whitelist', 		"Use \"whitelist help\" for instructions.", 			\&comm_White],
		['blacklist', 		"Use \"whitelist help\" for instructions.", 			\&comm_Black],
		['block', 			"Use \"blacklist\" instead of this.", 					\&comm_Block],
		['unblock', 		"Use \"blacklist rm\" instead of this.", 	 			\&comm_Unblock],
	);

my $pluginsFolder = $Plugins::current_plugin_folder;
my $blackListFile;
my $whiteListFile;
my %userlist;
my $lastblocktime;
my %lastAccess;
my @whitelist;
my @blacklist;
my $mustBlock;
my $blacklist_pos;

# LOAD WHITE AND BLACKLIST
#&start;

# you can change some of this plugin settings below !
use constant {
	PLUGINNAME				=>	"leaveMeAlone",
	# set to 1 to show debug messages
	DEBUG					=>	0,
	# disable almost every message. error messages will still be shown
	SILENT					=>	0,
	#### SPAM BLOCKING OPTIONS ###
	
	# self-explaining.
	DISABLESPAMCHECKS		=>	0,
	# if set to 1, won't check players with guilds for spamming
	SPAMONLYGUILDLESS		=>	1,
	# start checking PM/second after receiving <value> PMs
	MINPMCOUNT				=>	2,
	# if character exceeds <value> PMs per seconds will be considered a SPAMMER
	MAXPMPERSECOND			=>	1.2,
	# reset data about character that has not sent any PMs in the last <value> seconds
	RESETCOUNT				=>	4,
	# even zero should be fine, but you can increase this if you're having trouble with DCs
	BLOCKDELAY				=>	0.3,
	# queue blocks into AI if set to 1
	AI_MODE					=>	0,
	# enable this to show status messages when we're blocking users
	SHOW_BLOCK_STEPS		=>	0,
};

# Plugin unload
sub unload {
	message("\nleaveMeAlone unloading.\n\n");
	Plugins::delHooks($myHooks);
	Commands::unregister($myCmds);
	undef $myHooks;
	undef $myCmds;
	undef @whitelist;
	undef @blacklist;
	undef $pluginsFolder;
	undef $blackListFile;
	undef $whiteListFile;
	undef %userlist;
	undef $lastblocktime;
	undef $blacklist_pos;
}

# Subs

sub hideResultPacketMsg {
	my (undef, $args) = @_;
	$args->{return} = 1;
}

sub turnOn {
	$mustBlock = 1;
	$blacklist_pos = 0;
	$lastblocktime = Time::HiRes::time + (BLOCKDELAY * 4);
}
	

sub start {
	if (!&Settings::getSVNRevision()) {
		msg("[".PLUGINNAME."] We couldn't check your OpenKore Revision. Please make sure that you're using at least revision 7970, or use version 4 for older revisions.", 3);
	} elsif (&Settings::getSVNRevision() < 7970) {
		msg("[".PLUGINNAME."] Seems like you're using OpenKore r".&Settings::getSVNRevision().". Please make sure that you're using at least revision 7970, otherwise some functions may not work properly.", 3);
	}
	my @ha = &Settings::getControlFolders();	
	if ($config{leaveMeAlone_useControlFolder}) {
		$blackListFile = &Settings::getControlFilename("blacklist.txt");
		$whiteListFile = &Settings::getControlFilename("whitelist.txt");
		if (($blackListFile eq '')||($whiteListFile eq '')) {
			die "Please create whitelist.txt and blacklist.txt inside control folder or disable leaveMeAlone_useControlFolder flag.\n";
		}
	} else {
		$blackListFile = $pluginsFolder."/leaveMeAlone/blacklist.txt";
		$whiteListFile = $pluginsFolder."/leaveMeAlone/whitelist.txt";
		unless (-d $pluginsFolder."/leaveMeAlone") {
			mkdir ($pluginsFolder."/leaveMeAlone");
		}
		unless (-e $blackListFile) {
			open BLACKLIST, ">:utf8", $blackListFile;
			close BLACKLIST;
		}
		unless (-e $whiteListFile) {
			open WHITELIST, ">:utf8", $whiteListFile;
			close WHITELIST;
		}
		
	}
	&load_whitelist;
	&load_blacklist;
}

sub load_blacklist {
	undef @blacklist;
	open BLACKLIST, "<:utf8", $blackListFile
		or die "cannot open $blackListFile: $!";
		while (<BLACKLIST>) {
			chomp;
			my $currline = $_;
			$currline =~ s/^\s*//; $currline =~ s/\s*$//; 
			if (($currline !~ /^#/) and ($currline ne "")){
				push(@blacklist, $currline);
			}
			
		}
	close BLACKLIST;
	$lastAccess{blacklist}{path} = $blackListFile;
	$lastAccess{blacklist}{lastSize} = -s $lastAccess{blacklist}{path};
	msg("[".PLUGINNAME."] Blacklist loaded ! \n",0,1);
}

sub load_whitelist {
	undef @whitelist;
	open WHITELIST, "<:utf8", $whiteListFile
		or die "cannot open $whiteListFile: $!";
		while (<WHITELIST>) {
			chomp;
			my $currline = $_;
			$currline =~ s/^\s*//; $currline =~ s/\s*$//; 
			if (($currline !~ /^#/) and ($currline ne "")){
				push(@whitelist, $currline);
			}
		}
		close WHITELIST;
	$lastAccess{whitelist}{path} = $whiteListFile;
	$lastAccess{whitelist}{lastSize} = -s $lastAccess{whitelist}{path};
	msg("[".PLUGINNAME."] Whitelist loaded ! \n",0,1);
}

sub ingame {
	if ($mustBlock) {
		unless (@blacklist == 0) {
			msg("[".PLUGINNAME."] Blocking ".@blacklist." players from blacklist ! \n");
		}
		lastAccessVerify(1);
		if (AI_MODE) {
			foreach (@blacklist) {
				my %args;
				$args{name} = $_;
				# add AI task
				AI::queue("leavemealone", \%args);		
			}
			
		} else {
			$blacklist_pos = 0;
		}
		$mustBlock = 0;
	}
}

sub AI_hook {
	if (AI_MODE) {
		if (AI::action eq "leavemealone") {
			return 0 unless (defined AI::args->{name});
			if (Time::HiRes::time >= ($lastblocktime + BLOCKDELAY)) {
				$lastblocktime = Time::HiRes::time;
				msg("[".PLUGINNAME."] Player ".AI::args->{name}." has been blocked.\n") if (SHOW_BLOCK_STEPS);
				#Commands::run("ignore 1 ".AI::args->{name});
				$messageSender->sendIgnore(AI::args->{name}, 0);
				AI::dequeue;
			}
		}
	} else {
		unless ($::net->getState() > 3) {
			$blacklist_pos = 0;
			return;
		}
		if ($blacklist_pos < @blacklist) {
			if (Time::HiRes::time >= ($lastblocktime + BLOCKDELAY)) {
						$lastblocktime = Time::HiRes::time;
						msg("[".PLUGINNAME."] Player ".$blacklist[$blacklist_pos]." has been blocked.\n") if (SHOW_BLOCK_STEPS);
						#Commands::run("ignore 1 ".$blacklist[$blacklist_pos]);
						$messageSender->sendIgnore($blacklist[$blacklist_pos], 0);
						$blacklist_pos++;
			}
		}
	}
}

# used this for a while: unlike openkore's default AI::queue, this sub adds actions at lowest priority.
# someday it should be useful, so we're keeping it
# sub ai_queue_low_priority {
	# push @AI::ai_seq, shift;
	# my $args = shift;
	# push @AI::ai_seq_args, ((defined $args) ? $args : {});
# }

sub messages {
	return unless(DISABLESPAMCHECKS ne 1);
	my (undef, $args) = @_;
	my $charname;
	my $actor;
	if (defined $args->{pubMsgUser}) {
		$charname = $args->{pubMsgUser};
		$actor = Actor::get($args->{pubID});
		if ($actor->{guild}{name} ne '' && SPAMONLYGUILDLESS eq 1) { return; }
	} elsif (defined $args->{privMsgUser}) {
		$charname = $args->{privMsgUser};
	}
	lastAccessVerify(2);
	if (@whitelist) {
		foreach (@whitelist) {
			if ($charname eq $_) {
				msg("[".PLUGINNAME."] Player ".$charname." is whitelisted, we won't check him.\n", undef, 1);
				return;
			}
		}
	}
	
	if (($userlist{$charname}{'lastPMtime'} - $userlist{$charname}{'time'}) > RESETCOUNT) { delete $userlist{$charname}; };
	
	#delete $userlist{$charname};
	if (!$userlist{$charname}{'pmcount'}) {
		$userlist{$charname}{'time'} = time - 1;
	}
	$userlist{$charname}{'pmcount'}++;

	$userlist{$charname}{'lastPMtime'} = time;
	
	my $pmpersecond = $userlist{$charname}{'pmcount'}/(time - $userlist{$charname}{'time'});
	
	if ($pmpersecond > MAXPMPERSECOND && $userlist{$charname}{'pmcount'} > MINPMCOUNT) {
		msg("[".PLUGINNAME."] Blocking ".$charname." for spamming.\n");
		comm_Black(undef, $charname);
	}
	
	msg(
		"[".PLUGINNAME."] Player        : ".$charname."\n               Guild         : ".$actor->{guild}{name}."\n               Level         : ".$actor->{lv}."\n".
		"               PM Per Second : ".$pmpersecond."\n               PMs Received  : ".$userlist{$charname}{'pmcount'}."\n"
		,undef,1
		); 
}

sub comm_White {
	my (undef, $argument) = @_;
	
	if ($argument eq '' || $argument eq '?' || $argument eq 'help') {
			msg ("[".PLUGINNAME."] Syntax Error in function 'whitelist'\n".
					"[".PLUGINNAME."] Usage: \n\n".
					"[".PLUGINNAME."] Add player              :  whitelist <username>\n".
					"[".PLUGINNAME."] Remove player           :  whitelist rem <username>\n".
					"[".PLUGINNAME."] Clear whitelist.txt     :  whitelist clear\n".
					"[".PLUGINNAME."] Print whitelist content :  whitelist print\n".
					"[".PLUGINNAME."] Syntax help             :  whitelist ?, whitelist help\n"
					, 3); return 0;
	} elsif ($argument eq 'print') {
		warning("[whitelist.txt]\n\n");
		foreach (@whitelist) {
			warning($_."\n");
		}
		return 1;
	} elsif ($argument eq 'clear') {
		@whitelist = undef;
		open WHITELIST, ">:utf8", $whiteListFile
			or die "cannot open $whiteListFile: $!";
		close WHITELIST;
		$lastAccess{whitelist}{lastSize} = -s $lastAccess{whitelist}{path};
		return 1;
	} elsif ($argument =~ /^rem (.*)|^rem$/) {
		$argument = $1;
		if ($argument eq '') { msg("[".PLUGINNAME."] Syntax Error in function 'whitelist rem'\n[".PLUGINNAME."] Usage: block <username>\n", 3); return; }
		# search for <username> to remove, throw an error if not found
		unless (isInlist(2, $argument)) { msg("[".PLUGINNAME."] ".$argument." not found in whitelist.\n", 3); return; }	
		
		my @temp = @whitelist;
		@whitelist = undef;
		foreach (@temp) {
			push (@whitelist, $_) unless ($_ eq $argument || $_ eq "");
		}
		
		open WHITELIST, ">:utf8", $whiteListFile
			or die "cannot open $whiteListFile: $!";
				foreach (@whitelist) {
					print WHITELIST $_."\n";
				}	
		close WHITELIST;
		msg("[".PLUGINNAME."] Player ".$argument." has been removed from whitelist.\n");
		$lastAccess{whitelist}{lastSize} = -s $lastAccess{whitelist}{path};
		return 1;
	} else {
			unless (!isInlist(1, $argument)) { 
				error("[".PLUGINNAME."] ".$argument." is already in whitelist.\n");
				return;
			}
			unless (!isInlist(2, $argument)) {
				error("[".PLUGINNAME."] ".$argument." is already in blacklist. Use \"blacklist rm <username>\" to remove him first.\n");
				return;
			}
			# add to array
			push (@whitelist, $argument);
			
			open WHITELIST, ">:utf8", $whiteListFile
				or die "cannot open $whiteListFile: $!";
					foreach (@whitelist) {
						print WHITELIST $_."\n";
					}		
			close WHITELIST;
			msg("[".PLUGINNAME."] Player ".$argument." has been added to whitelist.\n");
			$lastAccess{whitelist}{lastSize} = -s $lastAccess{whitelist}{path};
			return 1;
	}
}

sub comm_Black {
	my (undef, $argument) = @_;
	if ($argument eq '' || $argument eq '?' || $argument eq 'help') {
			msg ("[".PLUGINNAME."] Syntax Error in function 'blacklist'\n".
					"[".PLUGINNAME."] Usage: \n\n".
					"[".PLUGINNAME."] Add and block player    :  blacklist <username>\n".
					"[".PLUGINNAME."] Remove player           :  blacklist rem <username>\n".
					"[".PLUGINNAME."] Clear blacklist.txt     :  blacklist clear\n".
					"[".PLUGINNAME."] Print blacklist content :  blacklist print\n".
					"[".PLUGINNAME."] Syntax help             :  blacklist ?, blacklist help\n"
					, 3); return 0;
	} elsif ($argument eq 'print') {
		warning("[blacklist.txt]\n\n");
		foreach (@blacklist) {
			warning($_."\n");
		}
		return 1;
	} elsif ($argument eq 'clear') {
		@blacklist = undef;
		open BLACKLIST, ">:utf8", $blackListFile
			or die "cannot open $blackListFile: $!";
		close BLACKLIST;
		$lastAccess{blacklist}{lastSize} = -s $lastAccess{blacklist}{path};
		return 1;
	} elsif ($argument =~ /^rem (.*)|^rem$/) {
		$argument = $1;
		# search for <username> to remove, throw an error if not found
		unless (isInlist(1, $argument)) { msg("[".PLUGINNAME."] ".$argument." not found in blacklist.\n", 3); return; }	
		
		my @temp = @blacklist;
		@blacklist = undef;
		foreach (@temp) {
			push (@blacklist, $_) unless ($_ eq $argument || $_ eq "");
		}
		
		open BLACKLIST, ">:utf8", $blackListFile
			or die "cannot open $blackListFile: $!";
				foreach (@blacklist) {
					print BLACKLIST $_."\n";
				}
		close BLACKLIST;
		#Commands::run("ignore 0 ".$argument);
		$messageSender->sendIgnore($argument, 0);
		msg("[".PLUGINNAME."] Player ".$argument." has been unblocked and removed from blacklist.\n");
		$lastAccess{blacklist}{lastSize} = -s $lastAccess{blacklist}{path};
		return 1;
	} else {
		unless (!isInlist(1, $argument)) { 
			error("[".PLUGINNAME."] ".$argument." is already in whitelist. Use \"whitelist rm <username>\" to remove him first.\n");
			return;
		}
		unless (!isInlist(2, $argument)) {
			error("[".PLUGINNAME."] ".$argument." is already in blacklist.\n");
			return;
		}
		
		# add to array
		push (@blacklist, $argument);
		
		open BLACKLIST, ">:utf8", $blackListFile
			or die "cannot open $blackListFile: $!";
				foreach (@blacklist) {
					print BLACKLIST $_."\n";
				}
		close BLACKLIST;
		#Commands::run("ignore 1 ".$argument);
		$messageSender->sendIgnore($argument, 0);
		msg("[".PLUGINNAME."] Player ".$argument." has been blocked and added to blacklist.\n");
		$lastAccess{blacklist}{lastSize} = -s $lastAccess{blacklist}{path};
		return 1;
	}
}

sub msg {
	# SILENT constant support and sprintf.
	my ($msg, $msglevel, $debug) = @_;
	
	unless ($debug eq 1 && DEBUG ne 1) {
		if (!defined $msglevel || $msglevel == "" || $msglevel == 0) {
			warning($msg) unless (SILENT == 1);
		} elsif ($msglevel == 1) {
			message($msg) unless (SILENT == 1);
		} elsif ($msglevel == 2) {
			warning($msg) unless (SILENT == 1);
		} elsif ($msglevel == 3) {
			error($msg);
		}
	}
	return 1;
}

sub isInlist {
	my ($list, $name) = @_;
	&lastAccessVerify($list);
	
	if ($list == 1) {
		foreach	(@whitelist) {
				if ($name eq $_) {
					msg("[".PLUGINNAME."] ".$name." found in whitelist !.\n", undef, 1);
				return 1;
			}
		}
		return 0;
	} elsif ($list == 2) {
		foreach	(@blacklist) {
				if ($name eq $_) {
					msg("[".PLUGINNAME."] ".$name." found in black !.\n", undef, 1);
				return 1;
			}
		}
		return 0;
	} else {
		msg("[".PLUGINNAME."] Error in isInlist() while accessing list ".$list.", please report this\n", 3);
	}
	
	
}

sub lastAccessVerify {
	my $arg = shift;
	# 1 for blacklist, 2 for whitelist
	if ($arg == 1 && ((-s $lastAccess{blacklist}{path}) ne $lastAccess{blacklist}{lastSize})) {
		msg("[".PLUGINNAME."] blacklist changed, reloading.\n", 3, 1);
		&load_blacklist;
		return 1;
	} elsif ($arg == 2 && ((-s $lastAccess{whitelist}{path}) ne $lastAccess{whitelist}{lastSize})) {
		msg("[".PLUGINNAME."] whitelist changed, reloading.\n", 3, 1);
		&load_whitelist;
		return 1;
	} elsif ($arg ne 1 && $arg ne 2) {
		msg("[".PLUGINNAME."] Error in lastAccessVerify() while accessing ".$arg.", please report this\n", 3);
		die;
	}
	
	msg("[".PLUGINNAME."] .txt files are okay, same size as before.\n", 3, 1);
}
		

######################################
######## KEPT FOR COMPATIBILITY

sub comm_Block {
	my (undef, $argument) = @_;
	comm_Black(undef, $argument);
	return 1;
}

sub comm_Unblock {
	my (undef, $argument) = @_;
	comm_Black(undef, "rem ".$argument);
	return 1;
}

1;
# i luv u mom