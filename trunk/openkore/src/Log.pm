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
# party			Party/follow related
# plugins		Messages about plugin handling
# pm			Private chat message
# publicchat		Public chat message
# route			Routing/pathfinding messages
# sold			Item sold while vending.
# skill			Skill use unrelated to attack
# startup		Messages that are printed during startup.
# storage		Storage item added/removed
# success		An operation succeeded
# syntax		Syntax check files
# system		System messages
# xkore			X-Kore system messages

# Debug domains:
# parseInput
# parseMsg
# sendPacket
# ai
# npc
# route

package Log;

use strict;
use Carp;
use Utils;
use Exporter;
use IO::Socket;
use Globals;
use Interface;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
	$warningVerbosity $errorVerbosity
	%messageConsole %warningConsole %errorConsole %debugConsole
	message warning error debug
	$fileTampstamp $chatTimestamp);


#################################
#################################
# VARIABLES
#################################
#################################


# The verbosity level for messages. Messages that have a higher verbosity than this will not be printed.
# Low level = important messages. High level = less important messages.
# If you set the current verbosity higher, you will see more messages.
our $warningVerbosity;
our $errorVerbosity;

# Enable/disable printing certain domains to console.
# Usage: $messageConsole{$domain} = $enabled
our %messageConsole;
our %warningConsole;
our %errorConsole;
our %debugConsole;

# Messages can also printed to files. These variables
# contain filenames of the files to print to.
# Usage: @{$messageFiles{$domain}} = (list of filenames)
our %messageFiles;
our %warningFiles;
our %errorFiles;
our %debugFiles;

# Message hooks are stored here
our @hooks;

# Enable/disable adding a timestamp to log files.
our $logTimestamp;
# Enable/disable adding a timestamp to chat logs.
our $chatTimestamp;


#################################
#################################
# PRIVATE FUNCTIONS
#################################
#################################


sub MODINIT {
	$warningVerbosity = 1;
	$errorVerbosity = 1;

	%messageConsole = ();
	%warningConsole = ();
	%errorConsole = ();
	%debugConsole = ();

	@hooks = ();
	$logTimestamp = 0;
	$chatTimestamp = 1;
}

sub processMsg {
	my $type = shift;
	my $message = shift;
	my $domain = (shift or "console");
	my $level = (shift or 0);
	my $currentVerbosity = shift;
	my $consoleVar = shift;
	my $files = shift;

	# Print to console if the current verbosity is high enough
	if ($level <= $currentVerbosity) {
		$consoleVar->{$domain} = 1 if (!defined($consoleVar->{$domain}));
		$interface->writeOutput($type, $message, $domain) if (defined $interface && $consoleVar->{$domain});
	}

	# Print to files
	foreach my $file (@{$files->{$domain}}) {
		if (open(F, ">> $file")) {
			print F '['. getFormattedDate(int(time)) .'] ' if ($logTimestamp);
			print F $message;
			close(F);
		}
	}

	# Call hooks
	foreach (@hooks) {
		next if (!defined($_));
		$_->{'func'}->($type, $domain, $level, $currentVerbosity, $message, $_->{'user_data'});
	}
}

sub setColor {
	return if (!$consoleColors{''}{'useColors'});
	my ($type, $domain) = @_;
	my $color = $consoleColors{$type}{$domain};
	$color = $consoleColors{$type}{'default'} if (!defined $color);
	color($color) if (defined $color);
}

#################################
#################################
# PUBLIC METHODS
#################################
#################################


##
# Log::message(message, [domain], [level])
#
# Prints a normal message. See the description for Log.pm for more details about the parameters.
sub message {
	return processMsg("message",	# type
		$_[0],						# message
		$_[1],						# domain
		$_[2],						# level
		$config{'verbose'},			# currentVerbosity
		\%messageConsole,
		\%messageFiles);
}


##
# Log::warning(message, [domain], [level])
#
# Prints a warning message. It warns the user that a possible non-fatal error has occured or will occur.
# See the description for Log.pm for more details about the parameters.
sub warning {
	return processMsg("warning",
		$_[0],
		$_[1],
		$_[2],
		$warningVerbosity,
		\%warningConsole,
		\%warningFiles);
}


##
# Log::error(message, [domain], [level])
#
# Prints an error message. It tells the user that a non-recoverable error has occured.
# A "non-recoverable error" could either be a fatal error, or an error that prevents
# the program from performing an action the user requested.
#
# Examples of non-recoverable errors:
# `l
# - Kore receives the "You haven't paid for this account"-packet. The error is fatal, so the entire program must exit.
# - The user typed in an invalid/unrecognized command. Kore cannot perform the command the user requested,
#   but will not exit because this error is not fatal.
# `l`
#
# See the description for Log.pm for more details about the parameters.
sub error {
	return processMsg("error",
		$_[0],
		$_[1],
		$_[2],
		$errorVerbosity,
		\%errorConsole,
		\%errorFiles);
}


##
# Log::debug(message, [domain], [level])
#
# Prints a debugging message. See the description for Log.pm for more details about the parameters.
sub debug {
	my $level = $_[2];
	$level = 1 if (!defined $level);
	return processMsg("debug",
		$_[0],
		$_[1],
		$level,
		$config{'debug'},
		\%debugConsole,
		\%debugFiles);
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
	my %hook = ();
	$hook{'func'} = $r_func;
	$hook{'user_data'} = $user_data;
	return binAdd(\@hooks, \%hook);
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
	undef $hooks[$ID];
	delete $hooks[$ID] if (@hooks - 1 == $ID);
}


return 1;
