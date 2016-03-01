#############################################################################
# busCommands plugin by imikelance/Revok
# r3
#																			
# Openkore: http://openkore.com/											
# Openkore Brazil: http://openkore.com.br/
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
	BUS_MESSAGE_ID_MESS		=> 	"busCM",
	# you can change some of this plugin settings below !
	BUS_COMMAND 			=> 	"bus",
	BUS_COMMAND_MESS 			=> 	"busmsg",
	DEBUG					=>	0,		# set to 1 to show debug messages
	SILENT					=>	0,		# disable almost every message. error messages will still be shown
	MESSENGER_MODE			=>	0,		# use this to receive/send messages and not commands.
};

# Plugin
Plugins::register(PLUGINNAME, "receive and send commands (and messages too) via BUS system", \&unload);	
	my $myCmds = Commands::register([BUS_COMMAND, 		"use ".BUS_COMMAND." <all|player name> <command>.",\&comm_Send],
									[BUS_COMMAND_MESS,	"sends a message via BUS",\&msg_Send]);
	
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
		return if (MESSENGER_MODE || $config{'busCommands_messengerMode'});
		msg("Running command \"$2\"");
		Commands::run($2);
	} elsif ($field) {
		if ($1 eq $field->name) {
			return if (MESSENGER_MODE || $config{'busCommands_messengerMode'});
			
			msg("Running command $2 received via BUS");
			Commands::run($2);
		}
	}
}

sub msg_Send {
	my (undef, $cmm) = @_;
	$cmm =~ m/^"(.*)" (.*)$/;
	$cmm =~ m/^(\w+) (.*)$/ unless ($1);
	
	my $from = "anon";
	if ($char) {
		$from = $char->name;
	}
	
	my %args;
	$args{player} = $1;
	$args{comm} = $2;
	$args{sender} = $from;
	$bus->send(BUS_MESSAGE_ID_MESS, \%args);
	
	Plugins::callHook('bus_received', {message => $args{comm}, sender => $args{sender}}) if (($char && $1 eq $char->name) || $1 eq "all");

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
	if ($msg->{messageID} eq BUS_MESSAGE_ID) {
		if ($msg->{args}{player} eq $char->name || $msg->{args}{player} eq "all") {
				Plugins::callHook('bus_received', {message => $msg->{args}{comm},});				
				msg("Running command $msg->{args}{comm} received via BUS");
				Commands::run($msg->{args}{comm});
		} elsif ($field) {
			if ($msg->{args}{player} eq $field->name) {
				Plugins::callHook('bus_received', {message => $msg->{args}{comm},});				
				msg("Running command $msg->{args}{comm} received via BUS");
				Commands::run($msg->{args}{comm});
			}
		}
	} elsif ($msg->{messageID} eq BUS_MESSAGE_ID_MESS) {
	
		Plugins::callHook('bus_received', {message => $msg->{args}{comm}, sender => $msg->{args}{sender}}) 
												if ($msg->{args}{player} eq $char->name || $msg->{args}{player} eq "all");
		
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