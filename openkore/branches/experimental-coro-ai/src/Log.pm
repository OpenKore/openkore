#########################################################################
#  OpenKore - Message Logging Framework
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#########################################################################
##
# MODULE DESCRIPTION: Message Logging framework
#
# <h3>What is a logging framework and why is it needed?</h3>
#
# Kore used to print messages to the console using print(). There are several
# problems though:
# `l
# - Messages can only be printed to the console. If you want to print it
#   to elsewhere you have to resort to all kinds of hacks (take a look
#   at the code for sending console output to X-Kore, for example).
# - The messages have no classification. You have a message, but there's
#   no easy way for the program to find out what kind of message it is;
#   you don't know it's context. This means that the user can't really control
#   what kind of messages he does and doesn't want to see.
# - Debug messages are all in the form of print "bla\n" if ($config{'verbose'});
#   You can either enable all debug messages, or nothing at all. For developers,
#   the huge amount of debug messages can make things look cluttered.
# `l`
#
# The logging framework provides a new way to print messages:
# `l
# - You can print messages (of course).
# - You can classify messages: attaching a context (domain) to a message you print.
# - You can intercept messages and decide what else to do with it. You can write to
#   a file, send to X-Kore (based on the message's domain), or whatever you want.
# - You can attach certain colors to messages of a certain domains.
# - You can choose what kind of message you do and do not want to see.
# `l`
#
# The most important functions are:
# Log::message(), Log::warning(), Log::error(), Log::debug()
#
# You pass the following arguments to those functions:
# `l
# - message: The message you want to print.
# - domain: The message domain (context). This is used to classify a message.
# - level: The message's verbosity level. The message will only be printed if this number
#          is lower than or equal to $config{'verbose'} (or $config{'debug'} if this is a
#          debug message). Important messages should have a low verbosity level,
#          unimportant/redundant messages should have a high verbosity level.
# `l`

# Known domains:
# attacked		Monster attacks you
# attackedMiss		Monster attacks you but miss
# attackMon		You attack monster
# attackMonMiss		You attack monster but miss
# connection		Connection messages
# deal			Deal messages
# drop			Monster drop related
# emotion		Emoticon
# equip		        Equipment Switching
# gmchat		GM chat message
# guildchat		Guild chat message
# info			View info that's requested by the user (status, guild info, etc.)
# input			Waiting for user input
# inventory		Inventory related messages
# useItem		You used item
# list			List of information (monster list, player list, item list, etc.)
# load			Loading config files
# menu			Menu choices
# npc			NPC messages
# party			Party/follow related
# partychat		Party chat messages
# plugins		Messages about plugin handling
# pm			Private chat message
# publicchat		Public chat message
# route			Routing/pathfinding messages
# sold			Item sold while vending.
# skill			Skill use unrelated to attack
# selfSkill		Skills used by yourself
# startup		Messages that are printed during startup.
# storage		Storage item added/removed
# success		An operation succeeded
# syntax		Syntax check files
# system		System messages
# teleport		Teleporting
# xkore			X-Kore system messages

# Debug domains:
# ai_attack
# ai_autoCart
# ai_move
# parseInput
# parseMsg
# parseMsg_damage
# parseMsg_presence
# portalRecord
# sendPacket
# ai
# npc
# route
# useTeleport

package Log;

use strict;
use Coro;
use Exporter;
use base qw(Exporter);
use Time::HiRes;
# We don't have Environment yet.
# use Globals qw(%config $interface %consoleColors %field %cities_lut);
use Globals qw(%config $interface %consoleColors $log);
use Utils qw(binAdd existsInList getFormattedDate);
use Utils::DataStructures qw(binAdd existsInList);
use Modules 'register';

our @EXPORT_OK = qw(message warning error debug);


#################################
#################################
# PRIVATE FUNCTIONS
#################################
#################################


sub MODINIT {
	use Globals qw($log);
	$log = Log->new();
}

sub new {
	my $class = shift;
	my $self;
	$self->{warningVerbosity} = 1;
	$self->{errorVerbosity} = 1;
	$self->{logTimestamp} = 1;
	$self->{chatTimestamp} = 1;
	$self->{messageConsole} = {};
	$self->{warningConsole} = {};
	$self->{errorConsole} = {};
	$self->{debugConsole} = {};
	$self->{messageFiles} = {};
	$self->{warningFiles} = {};
	$self->{errorFiles} = {};
	$self->{debugFiles} = {};
	$self->{hooks} = [];
	bless $self, $class;
	return $self;
}

sub processMsg {
	my $self = shift;
	my $type = shift;
	my $message = shift;
	my $domain = (shift or "console");
	my $level = (shift or 0);
	my $currentVerbosity = shift;
	my $consoleVar = shift;
	my $files = shift;
	my (undef, undef, undef, $near) = caller(2);
	my (undef, undef, undef, $far) = caller(3);

	$currentVerbosity = 1 if ($currentVerbosity eq "");

	# We don't have Environment yet.
	# Beep on certain domains
	# $interface->beep() if existsInList($config{beepDomains}, $domain) &&
	# 	!(existsInList($config{beepDomains_notInTown}, $domain) &&
	# 	  $cities_lut{$field{name}.'.rsw'});

	# Add timestamp if domain was specified in config.txt/showTimeDomains
	if (existsInList($config{showTimeDomains}, $domain)) {
		my @tmpdate = localtime();
		$tmpdate[5] += 1900;
		for (my $i = 0; $i < @tmpdate; $i++) {
			if ($tmpdate[$i] < 10) {$tmpdate[$i] = "0".$tmpdate[$i]};
		}
		if (defined (my $format = $config{showTimeDomainsFormat})) {
			$format =~ s/H/$tmpdate[2]/g;
			$format =~ s/M/$tmpdate[1]/g;
			$format =~ s/S/$tmpdate[0]/g;
			$format =~ s/y/$tmpdate[5]/g;
			$format =~ s/m/$tmpdate[4]/g;
			$format =~ s/d/$tmpdate[3]/g;
			$message = "$format $message";
		} else {
			$message = "[$tmpdate[2]:$tmpdate[1]:$tmpdate[0]] $message";
		}
	};

	# Print to console if the current verbosity is high enough
	if ($level <= $currentVerbosity) {
		if (!defined($consoleVar->{$domain})) {
			$consoleVar->{$domain} = 1;	
		}
		if ($consoleVar->{$domain}) {
			if ($interface) {
				$message = "[$domain] " . $message if ($config{showDomain});
				my (undef, $microseconds) = Time::HiRes::gettimeofday;
				$microseconds = substr($microseconds, 0, 2);
				my $message2 = "[".getFormattedDate(int(time)).".$microseconds] ".$message;
				if ($config{showTime}) {
					$interface->writeOutput($type, $message2, $domain);
				} else {
					$interface->writeOutput($type, $message, $domain);
				}

				if ($config{logConsole} &&
					open(F, ">>:utf8", "$Settings::logs_folder/console.txt")) {
					print F $message2;
					close(F);
				}
			} else {
				print $message;
			}
		}
	}

	# Print to files
	foreach my $file (@{$files->{$domain}}) {
		if (open(F, ">>:utf8", "$Settings::logs_folder/$file")) {
			print F '['. getFormattedDate(int(time)) .'] ' if ($self->{logTimestamp});
			print F $message;
			close(F);
		}
	}

	# Call hooks
	foreach (@{$self->{hooks}}) {
		next if (!defined($_));
		$_->{'func'}->($type, $domain, $level, $currentVerbosity, $message, $_->{'user_data'}, $near, $far);
	}
}


#################################
#################################
# PUBLIC METHODS
#################################
#################################

##
# Log::message(message, [domain], [level])
# Requires: $message must be encoded in UTF-8.
#
# Prints a normal message. See the description for Log.pm for more details
# about the parameters.
sub message {
	my ($message, $domain, $level) = @_;

	lock ($log);
	lock (%config);

	$level = 5 if existsInList($config{squelchDomains}, $domain);
	$level = 0 if existsInList($config{verboseDomains}, $domain);
	return $log->processMsg("message",	# type
		$message,
		$domain,
		$level,
		$config{'verbose'},			# currentVerbosity
		%{$log->{messageConsole}},
		%{$log->{messageFiles}});
}


##
# Log::warning(message, [domain], [level])
#
# Prints a warning message. It warns the user that a possible non-fatal error has occured or will occur.
# See the description for Log.pm for more details about the parameters.
sub warning {
	lock ($log);
	return $log->processMsg("warning",
		$_[0],
		$_[1],
		$_[2],
		$log->{warningVerbosity},
		%{$log->{warningConsole}},
		%{$log->{warningFiles}});
}


##
# Log::error(message, [domain], [level])
# Requires: $message must be encoded in UTF-8.
#
# Prints an error message. It tells the user that a non-recoverable error has
# occured.  A "non-recoverable error" could either be a fatal error, or an
# error that prevents the program from performing an action the user requested.
#
# Examples of non-recoverable errors:
# `l
# - Kore receives the "You haven't paid for this account"-packet. The error is
#   fatal, so the entire program must exit.
# - The user typed in an invalid/unrecognized command. Kore cannot perform the
#   command the user requested, but will not exit because this error is not
#   fatal.
# `l`
# See the description for Log.pm for more details about the parameters.
sub error {
	lock ($log);
	return $log->processMsg("error",
		$_[0],
		$_[1],
		$_[2],
		$log->{errorVerbosity},
		%{$log->{errorConsole}},
		%{$log->{errorFiles}});
}


##
# Log::debug(message, [domain], [level])
# Requires: $message must be encoded in UTF-8.
#
# Prints a debugging message. See the description for Log.pm for more details about the parameters.
sub debug {
	my $level = $_[2];
	lock ($log);
	lock (%config);

	$level = 1 if (!defined $level);
	$level = 0 if (existsInList($config{debugDomains}, $_[1]));
	$level = 5 if (existsInList($config{squelchDomains}, $_[1]));
	return $log->processMsg("debug",
		$_[0],
		$_[1],
		$level,
		(defined $config{'debug'}) ? $config{'debug'} : 0,
		%{$log->{debugConsole}},
		%{$log->{debugFiles}});
}


##
# Log::addHook(r_func, [user_data])
# r_func: A reference to the function to call.
# user_data: Additional data to pass to r_func.
# Returns: An ID which you can use to remove this hook.
#
# Adds a hook. Every time Log::message(), Log::warning(), Log::error() or Log::debug() is called,
# r_func is also called, in the following way:
# <pre>
# r_func->($type, $domain, $level, $globalVerbosity, $message, $user_data);
# $type : One of the following: "message", "warning", "error", "debug".
# $domain : The message's domain.
# $level : The message's own verbosity level.
# $globalVerbosity : The global verbosity level.
# $message : The message itself.
# $user_data : The value of user_data, as passed to addHook.
# $near : The function that called "message", "warning", "error" or "debug"
# $far : The function that called $near
# </pre>
#
# See also: Log::delHook()
#
# Example:
# sub hook {
# 	my $type = shift;		# "message"
# 	my $domain = shift;		# "MyDomain"
# 	my $level = shift;		# 2
#	my $globalVerbosity = shift;	# 1 (equal to $config{'verbose'})
#	my $message = shift;		# "Hello World"
#	my $user_data = shift;		# "my_user_data"
#	my $near = shift;		# "Commands::cmdWhere"
#	my $far = shift;		# "Commands::run"
# 	# Do whatever you want here
# }
# Log::addHook(\&hook, "my_user_data");
#
# $config{'verbose'} = 1;
# # Note that the following function will not print anything to screen,
# # because it's verbosity level is higher than the global verbosity
# # level ($config{'verbose'}).
# Log::message("Hello World", "MyDomain", 2);  # hook() will now be called
sub addHook {
	my ($r_func, $user_data) = @_;
	my %hook;
	lock ($log);
	$hook{func} = $r_func;
	$hook{user_data} = $user_data;
	my $ret = binAdd(@{$log->{hooks}}, \%hook);
	return $ret;
}

##
# Log::delHook(ID)
# ID: A hook ID, as returned by addHook().
#
# Removes a hook. r_func will not be called anymore.
#
# Example:
# my $ID = Log::addHook(\&hook);
# Log::message("Hello World", "MyDomain");	# hook() is called
# Log::delHook($ID);
# Log::message("Hello World", "MyDomain");	# hook() is NOT called
sub delHook {
	my $ID = shift;
	lock ($log);
	delete $log->{hooks}[$ID];
}

##
# Log::parseLogToFile(args,hash)
#
# args has to look like domain=file
# but can look like domain1=file1.txt;domain2=file2.txt,file3.txt
#
# The hash has to be a reference for the output hash.
sub parseLogToFile {
	my $args = shift;
	my $list = shift;
	$args =~ s/\s//g;
	my @domains = split (';', $args);
	my $files;
	foreach my $domain (@domains) {
		($domain,$files) = split ('=', $domain);
		my @filesArray = split (',', $files);
		$list->{$domain} = &share([]);
		foreach my $file (@filesArray) {
			push(@{$list->{$domain}}, $file);
		}
	}
}

##
# initLogFiles()
#
# This function should be called everytime config.txt is (re)loaded.
sub initLogFiles {
	lock ($log);
	lock (%config);
	parseLogToFile($config{logToFile_Messages}, %{$log->{messageFiles}}) if $config{logToFile_Messages};
	parseLogToFile($config{logToFile_Warnings}, %{$log->{warningFiles}}) if $config{logToFile_Warnings};
	parseLogToFile($config{logToFile_Errors}, %{$log->{errorFiles}}) if $config{logToFile_Errors};
	parseLogToFile($config{logToFile_Debug}, %{$log->{debugFiles}}) if $config{logToFile_Debug};
}


return 1;
