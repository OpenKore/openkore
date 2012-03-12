#############################################################################
# busCommands revision 02 plugin by imikelance/marcelofoxes									
#																			
# Openkore: http://openkore.com/											
# Openkore Brazil: http://openkore.com.br/		
#
# 17:03 segunda-feira, 20 de fevereiro de 2012 (rev 02)
#	- now you can use "bus <map name> <command>" to command your bots inside that map
#
# 01:01 domingo, 12 de fevereiro de 2012 (rev 01)
#	- fixed "bus command", where only commands without arguments (like sit, stand, st) would work									
#	- fixed self name checking													
#	- added	hook to allow usage with macros												
#	- added MESSENGER_MODE to allow this plugin to act as a messenger (receive/send messages only)												
#												
# 05:52 quarta-feira, 8 de fevereiro de 2012
# 	- released !
#
#	my special thanks goes to openkore team for developing BUS System !
#																			
# This source code is licensed under the									
# GNU General Public License, Version 3.									
# See http://www.gnu.org/licenses/gpl.html									
#############################################################################
package busCommands;

use strict;
use Plugins;
use Log qw( warning message error );
use Globals;

use constant {
	PLUGINNAME				=>	"busCommands",
	BUS_MESSAGE_ID 			=> 	"busComm",
	# you can change some of this plugin settings below !
	BUS_COMMAND 			=> 	"bus",
	DEBUG					=>	0,		# set to 1 to show debug messages
	SILENT					=>	0,		# disable almost every message. error messages will still be shown
	MESSENGER_MODE			=>	0,		# use this to receive/send messages and not commands.
};

# Plugin
Plugins::register(PLUGINNAME, "receive and send commands (and messages too) via BUS system", \&unload);	
	my $myCmds = Commands::register([BUS_COMMAND, 		"use ".BUS_COMMAND." <all|player name> <command>.",\&comm_Send]);
	
	my $networkHook = Plugins::addHook('Network::stateChanged',\&init);
	
my $bus_message_received;

sub comm_Send {
	my (undef, $cmm) = @_;
	$cmm =~ m/^"(.*)" (.*)$/;
	$cmm =~ m/^(\w+) (.*)$/ unless ($1);
	unless ($1 && $2) {
		msg("Command \"".BUS_COMMAND."\" failed, please use ".BUS_COMMAND." <all|player name> <command>.", 3);
		return;
	}
	if ($char && $bus->getState == 4) {
		my %args;
		$args{player} = $1;
		$args{comm} = $2;
		$bus->send(BUS_MESSAGE_ID, \%args);
	}
	
	if ($1 eq $char->name || $1 eq "all") {
		Plugins::callHook('bus_received', {message => $2});
		return if (MESSENGER_MODE || $config{'busCommands_messengerMode'});
		msg("Running command \"$2\"");
		Commands::run($2);
	} elsif ($field) {
		if ($1 eq $field->name) {
			Plugins::callHook('bus_received', {message => $2});
			return if (MESSENGER_MODE || $config{'busCommands_messengerMode'});
			
			msg("Running command $2 received via BUS");
			Commands::run($2);
		}
	}
}
			
# handle plugin loaded manually
if ($::net) {
	if ($::net->getState() > 1) {
		$bus_message_received = $bus->onMessageReceived->add(undef, \&bus_message_received);
		Plugins::delHook($networkHook);
		undef $networkHook;
	}
}

sub init {
	return if ($::net->getState() == 1);
	if (!$bus) {
		die("\n\n[".PLUGINNAME."] You MUST start BUS server and configure each bot to use it in order to use this plugin. Open and edit line bus 0 to bus 1 inside control/sys.txt \n\n", 3, 0);
	} elsif (!$bus_message_received) {
		$bus_message_received = $bus->onMessageReceived->add(undef, \&bus_message_received);
		Plugins::delHook($networkHook);
		undef $networkHook;
	}
}

sub bus_message_received {
	my (undef, undef, $msg) = @_;
	return if (!$char);
	return unless ($msg->{messageID} eq BUS_MESSAGE_ID);
	if ($msg->{args}{player} eq $char->name || $msg->{args}{player} eq "all") {
			Plugins::callHook('bus_received', {message => $msg->{args}{comm},});
			return if (MESSENGER_MODE || $config{'busCommands_messengerMode'});
			
			msg("Running command $msg->{args}{comm} received via BUS");
			Commands::run($msg->{args}{comm});
	} elsif ($field) {
		if ($msg->{args}{player} eq $field->name) {
			Plugins::callHook('bus_received', {message => $msg->{args}{comm},});
			return if (MESSENGER_MODE || $config{'busCommands_messengerMode'});
			
			msg("Running command $msg->{args}{comm} received via BUS");
			Commands::run($msg->{args}{comm});
		}
	}
}

sub msg {
	# SILENT constant support and sprintf.
	my ($msg, $msglevel, $debug) = @_;
	
	unless ($debug eq 1 && DEBUG ne 1) {
	$msg = "[".PLUGINNAME."] ".$msg."\n";
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

# Plugin unload
sub unload {
	message("\n[".PLUGINNAME."] unloading.\n\n");
	#Plugins::delHooks($myHooks);
	Plugins::delHook($networkHook) if $networkHook;
	Commands::unregister($myCmds);
	undef $myCmds;
	undef $networkHook;
	$bus->onMessageReceived->remove($bus_message_received) if $bus_message_received;
	undef $bus_message_received if $bus_message_received;
}

1;