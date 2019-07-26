# alertsound plugin by joseph
# Modified by 4epT (29.06.2019)
#
# Alert Plugin Version 5
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
#	death, emotion, teleport, map change, monster <monster name>, player <player name>, player *, GM near,
#	private GM chat, private chat, public GM chat, npc chat, public chat, system message, disconnected,
#   item <item name>, item <item ID>, item cards
#
# example:
#	alertSound {
#		eventList monster Poring
#		notInTown 1
#		inLockOnly 0
#		play sounds\birds.wav
#	}
######################
package alertsound;

use strict;
use Plugins;
use Globals qw($accountID %config %cities_lut $field %items_lut %players);
use Log qw(message);
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
	['packet/item_appeared', \&item_appeared, undef],
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
# eventList item <item name>
# eventlist item <item ID>
# eventList item cards
	my (undef, $args) = @_;
	my $nameID = $args->{nameID};
	my $type = $args->{type};
	my $name = $items_lut{$nameID};
	if ($type == 6) {
		alertSound("item cards");
	}
	alertSound("item $nameID");
	alertSound("item $name");
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

	for (my $i = 0; exists $config{"alertSound_".$i."_eventList"}; $i++) {
		next if (!$config{"alertSound_".$i."_eventList"});
		if (Utils::existsInList($config{"alertSound_".$i."_eventList"}, "player *")) {
			alertSound("player *");
			return;
		}
	}

	if ($name =~ /^([a-z]?ro)?-?(Sub)?-?\[?GM\]?/i) {
		alertSound("GM near");
	} else {
		alertSound("player $name");
	}
}
sub private {
# eventList private GM chat
# eventList private chat
	my (undef, $args) = @_;
	if ($args->{privMsgUser} =~ /^([a-z]?ro)?-?(Sub)?-?\[?GM\]?/i) {
		alertSound("private GM chat");
	} else {
		alertSound("private chat");
	}
}
sub public {
# eventList public GM chat
# eventList npc chat
# eventList public chat
	my (undef, $args) = @_;
	if ($args->{pubMsgUser} =~ /^([a-z]?ro)?-?(Sub)?-?\[?GM\]?/i) {
		alertSound("public GM chat");
	} elsif (unpack("V", $args->{pubID}) == 0) {
		alertSound("npc chat");
	} else {
		alertSound("public chat");
	}
}
sub system_message {
# eventList system message
	alertSound("system message");
}

sub alertSound {
	my $event = shift;
	for (my $i = 0; exists $config{"alertSound_".$i."_eventList"}; $i++) {
		next if (!$config{"alertSound_".$i."_eventList"});
		if (Utils::existsInList($config{"alertSound_".$i."_eventList"}, $event)
			&& (!$config{"alertSound_".$i."_notInTown"} || !$cities_lut{$field->baseName().'.rsw'})
			&& (!$config{"alertSound_".$i."_inLockOnly"} || $field->baseName() eq $config{'lockMap'})) {
				message "Sound alert: $event\n", "alertSound";
				Utils::Win32::playSound($config{"alertSound_".$i."_play"});
		}
	}
}

1;
