# alertsound plugin by joseph
# Modified by 4epT (27.06.2021)
#
# Alert Plugin Version 12
#
# This software is open source, licensed under the GNU General Public
# License, ver. (2 * (2 + cos(pi)))
######################
# alertSound($event)
# $event: unique event name
#
# Plays a sound if plugin alertSound is enabled (see sys.txt), and if a sound is specified for the event.
#
# The config option "alertSound_#_eventList" should have a comma seperated list of all the desired events.
#
# Supported events:
#	death, emotion, teleport, map change, monster <monster name>, player <player name>, player *, GM near, avoidGM_near,
#	avoidList_near, private GM chat, private avoidList chat (not working for ID), private chat, public GM chat, public avoidList chat,
#	public npc chat, public chat, system message, disconnected, item <item name>, item <item ID>, item cards, item *<part item name>*, friend
#
# example:
#	alertSound {
#		eventList monster Poring
#		play plugins\alertSound\sounds\birds.wav
#		disabled 0
#		notInTown 0
#		inLockOnly 0
#		timeout 0
#		# other Self Conditions
#		notParty 1 << only works with eventList: player ***,  public ***
#		notPlayers 4epT, joseph << only works with eventList: player ***,  private ***, public ***
#	}
######################
package alertsound;

use strict;
use Plugins;
use Globals qw($accountID %ai_v %avoid $char %cities_lut %config $field %items_lut $itemsList %players $playersList);
use Log qw(message);
use Misc qw(checkSelfCondition itemName);
require Utils::Win32 if ($^O eq 'MSWin32'); #this plugin only works on OS windows

if ($^O ne 'MSWin32') {
	# We are not on Windows, Plugin can't work.
	print "alertSound plugin only works on windows OS. Let's skip it.\n\n";
	return 1;
}

Plugins::register('alertsound', 'plays sounds on certain events', \&Unload, \&Reload);
my $packetHook = Plugins::addHooks (
	['self_died', \&death, undef],
	['packet_pre/actor_display', \&monster, undef],
	['charNameUpdate', \&player, undef],
	['player_exist', \&player, undef],
	['player_connected', \&player, undef],
	['player_moved', \&player, undef],
	['packet_privMsg', \&private, undef],
	['packet_pubMsg', \&public, undef],
	['packet_sysMsg', \&system_message, undef],
	['packet_emotion', \&emotion, undef],
	['Network::Receive::map_changed', \&map_change, undef],
	['disconnected', \&disconnected, undef],
	['item_appeared', \&item_appeared, undef],
	['avoidGM_near', \&avoidGM_near, undef],
	['avoidList_near', \&avoidList_near, undef],
	['friend_request', \&friend, undef]
);
sub Reload {
	message "alertsound plugin reloading, ", 'system';
	Plugins::delHooks($packetHook);
}
sub Unload {
	message "alertsound plugin unloading, ", 'system';
	Plugins::delHooks($packetHook);
}

sub death {
#eventList death
	alertSound("death");
}

sub disconnected {
#eventList disconnected
	alertSound("disconnected");
}

sub emotion {
#eventList emotion
	my (undef, $args) = @_;
	if ($players{$args->{ID}} && $args->{ID} ne $accountID) {
		alertSound("emotion");
	}
}

sub item_appeared {
# eventList item cards
# eventlist item <item ID>
# eventList item <item name>
# eventList item *<part item name>*
	my (undef, $args) = @_;
	my $item = $args->{item};
	#only works with the new '084B' package
	if ($args->{type} == 6) {
		alertSound("item cards");
	}
	alertSound("item $item->{nameID}");
	alertSound("item $item->{name}");

	for (my $i = 0; exists $config{"alertSound_".$i."_eventList"}; $i++) {
		my $eventList = $config{"alertSound_".$i."_eventList"};
		next if (!$eventList or $eventList !~ /item /i);
		foreach (split /\,/, $eventList) {
			my ($part_itemName) = $_ =~ /item (\*\w+\*)$/;
			next if (!$part_itemName);
			if ($item->{name} =~ /^$part_itemName/i) {
				alertSound("item $part_itemName");
				return;
			}
		}
	}
}

sub map_change {
# eventList teleport
# eventList map change
	my (undef, $args) = @_;
	if ($args->{oldMap} eq $field->{baseName}) {
		alertSound("teleport");
	} else {
		alertSound("map change");
	}
}

sub monster {
#eventList monster <monster name>
	my (undef, $args) = @_;
	if ($args->{type} >= 1000 and $args->{hair_style} ne 0x64) {
		my $display = ($::monsters_lut{$args->{type}} ne "")
			? $::monsters_lut{$args->{type}}
			: "Unknown ".$args->{type};
		alertSound("monster $display");
	}
}

sub player {
# eventList player <player name>
# eventlist player *
# eventList GM near
	my ($hook, $args) = @_;
	my $name = ($hook eq "player_moved") ? $args->{name} : $args->{player}{name};
	my $ID   = ($hook eq "player_moved") ? $args->{ID} : $args->{player}{ID};
	if (exist_eventList("player *", $name, $ID)) {
		alertSound("player *");
	} elsif (exist_eventList("GM near", $name, $ID) and $name =~ /^([a-z]?ro)?-?(Sub)?-?\[?GM\]?/i) {
		alertSound("GM near");
	} else {
		alertSound("player $name");
	}
}

sub private {
# eventList private GM chat
# eventList private avoidList chat (not working for ID)
# eventList private chat
	my (undef, $args) = @_;
	my $name = $args->{privMsgUser};
	my $event;
	if (exist_eventList("private GM chat", $name) and $name =~ /^([a-z]?ro)?-?(Sub)?-?\[?GM\]?/i) {
		$event = "private GM chat";
	} elsif (exist_eventList("private avoidList chat", $name) and $avoid{Players}{lc($name)}) {
		$event = "private avoidList chat";
	} elsif ( exist_eventList("private chat", $name) ) {
		$event = "private chat";
	}
	alertSound($event) if $event;
}

sub public {
# eventList public GM chat
# eventList public avoidList chat (not working for ID)
# eventList public npc chat
# eventList public chat
	my (undef, $args) = @_;
	my $name = $args->{pubMsgUser};
	my $ID = $args->{pubID};
	my $event;
	if (exist_eventList("public GM chat") and $name =~ /^([a-z]?ro)?-?(Sub)?-?\[?GM\]?/i) {
		$event = "public GM chat";
	} elsif (exist_eventList("public avoidList chat") and $avoid{Players}{lc($name)}) {
		$event = "public avoidList chat";
	} elsif (unpack("V", $ID) == 0) {
		$event = "public npc chat";
	} elsif ( exist_eventList("public chat", $name, $ID) ) {
		$event = "public chat";
	}
	alertSound($event) if $event;
}

sub system_message {
# eventList system message
	alertSound("system message");
}

sub avoidGM_near {
# eventList avoidGM_near
	alertSound("avoidGM_near");
}

sub avoidList_near {
# eventList avoidList_near
	alertSound("avoidList_near");
}

sub friend {
# eventList friend
	my (undef, $args) = @_;
	alertSound("friend");
}

sub exist_eventList {
	my ($event, $name, $ID) = @_;
	for (my $i = 0; exists $config{"alertSound_".$i."_eventList"}; $i++) {
		next if (!$config{"alertSound_".$i."_eventList"});
		next if ( $config{"alertSound_".$i."_notParty"} == 1 && $char->{party}{joined} && $char->{party}{users}{$ID} );
		next if ( $name && Utils::existsInList($config{"alertSound_".$i."_notPlayers"}, $name) );
		if (Utils::existsInList($config{"alertSound_".$i."_eventList"}, $event)
		    && checkSelfCondition("alertSound_$i")) {
			return 1;
		}
	}
	return 0;
}

sub alertSound {
	my $event = shift;
	for (my $i = 0; exists $config{"alertSound_".$i."_eventList"}; $i++) {
		next if (!$config{"alertSound_".$i."_eventList"});
		if (Utils::existsInList($config{"alertSound_".$i."_eventList"}, $event)
			&& checkSelfCondition("alertSound_$i")) {
				$ai_v{"alertSound_$i"."_time"} = time;
				message "Sound alert: $event\n", "alertSound";
				Utils::Win32::playSound($config{"alertSound_".$i."_play"});
		}
	}
}

1;
