# alertsound plugin by joseph
# Modified by 4epT (08.10.2019)
#
# Alert Plugin Version 7
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
#	public npc chat, public chat, system message, disconnected, item <item name>, item <item ID>, item cards, item *<part item name>*
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
#	}
######################
package alertsound;

use strict;
use Plugins;
use Globals qw($accountID %ai_v %avoid %config %cities_lut $field %items_lut $itemsList %players);
use Log qw(message);
use Misc qw(checkSelfCondition itemName);
use Utils::Win32;

Plugins::register('alertsound', 'plays sounds on certain events', \&Unload, \&Reload);
my $packetHook = Plugins::addHooks (
	['self_died', \&death, undef],
	['packet_pre/actor_display', \&monster, undef],
	['charNameUpdate', \&player, undef],
	['player', \&player, undef],
	['packet_privMsg', \&private, undef],
	['packet_pubMsg', \&public, undef],
	['packet_sysMsg', \&system_message, undef],
	['packet_emotion', \&emotion, undef],
	['Network::Receive::map_changed', \&map_change, undef],
	['disconnected', \&disconnected, undef],
	['item_appeared', \&item_appeared, undef],
	['avoidGM_near', \&avoidGM_near, undef],
	['avoidList_near', \&avoidList_near, undef]
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
			my ($part_itemName) = $eventList =~ /item (\*\w+\*)$/;
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
	my (undef, $args) = @_;
	my $name = $args->{player}{name};

	if (exist_eventList("player *")) {
		alertSound("player *");
		return;
	} elsif (exist_eventList("GM near") and $name =~ /^([a-z]?ro)?-?(Sub)?-?\[?GM\]?/i) {
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
	my $event = "chat";
	if (exist_eventList("private GM chat") and $args->{privMsgUser} =~ /^([a-z]?ro)?-?(Sub)?-?\[?GM\]?/i) {
		$event = "GM chat";
	} elsif (exist_eventList("private avoidList chat") and $avoid{Players}{lc($args->{privMsgUser})}) {
		$event = "avoidList chat";
	}
	alertSound("private $event");
}

sub public {
# eventList public GM chat
# eventList public npc chat
# eventList public chat
	my (undef, $args) = @_;
	my $event = "chat";
	if (exist_eventList("public GM chat") and $args->{pubMsgUser} =~ /^([a-z]?ro)?-?(Sub)?-?\[?GM\]?/i) {
		$event = "GM chat";
	} elsif (exist_eventList("public avoidList chat") and $avoid{Players}{lc($args->{pubMsgUser})}) {
		$event = "avoidList chat";
	} elsif (unpack("V", $args->{pubID}) == 0) {
		$event = "npc chat";
	}
	alertSound("public $event");
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

sub exist_eventList {
	my $event = shift;
	for (my $i = 0; exists $config{"alertSound_".$i."_eventList"}; $i++) {
		next if (!$config{"alertSound_".$i."_eventList"});
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