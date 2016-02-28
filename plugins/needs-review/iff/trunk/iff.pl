##
# IFF (Identify Friend or Foe) Plugin
#
# This plugin is meant as a helper for GVG AIs to determine which players are
# enemies. It currently cannot handle monsters.
#
# A foe is anyone who is not a friend.
# A friend is anyone who is:
# * a member of your party
# * a member of your guild
# * a member of an allied guild
# * a member of a guild in $config{iff_friendlyGuilds}
# * a player listed in $config{iff_friendlyPlayers}
#
# This plugin provides:
# * an 'iff' command to list friendliness of all players on screen
# * an 'iff <name>' command to list the friendliness of a specific player
# * the function IFF::foe($player) which returns 1 iff $player is a foe

package IFF;

use strict;
use Globals;
use Match;
use Plugins;
use Utils;
use Log qw(message error);
use Network::Send;

Plugins::register('iff', 'Identify Friend or Foe', \&Unload, \&Reload);

my $hooks = Plugins::addHooks(
	["packet/map_loaded", \&map_loaded],
	["Command_post", \&Command_post]
);

sub Reload { Unload(); }
sub Unload { Plugins::delHooks($hooks); }

our $reason;

sub map_loaded {
	message "IFF: Requesting guild ally information...\n";
	sendGuildRequest(\$remote_socket, 0);
}

##
# IFF::foe($player)
#
# Returns 1 if $player is a foe, 0 otherwise.
# Sets $IFF::reason to indicate why.
sub foe {
	my ($player) = @_;

	if (existsInList($config{iff_hostilePlayers}, $player->{name})) {
		$reason = 'manual hostile player';
		return 1;
	}

	if ($config{iff_hostilePlayers}) {
		# Only players in that list are hostile
		$reason = 'not hostile';
		return 0;
	}

	if ($char->{party} && $char->{party}{users}{$player->{ID}}) {
		$reason = 'party member';
		return 0;
	}

	if ($pvp == 2 && $char->{guildID} && $char->{guildID} eq $player->{guildID}) {
		$reason = 'guild member';
		return 0;
	}

	if ($pvp == 2 && $player->{guildID} && $guild{ally}{$player->{guildID}}) {
		$reason = 'allied guild member';
		return 0;
	}

	# Since names are not immediately available, IFF may identify a manual
	# friendly as a foe at first...?
	if (existsInList($config{iff_friendlyGuilds}, $player->{guild}{name})) {
		$reason = 'manual friendly guild member';
		return 0;
	}

	if (existsInList($config{iff_friendlyAID}, unpack("L1", $player->{ID}))) {
		$reason = 'manual friendly AID';
		return 0;
	}

	if (existsInList($config{iff_friendlyPlayers}, $player->{name})) {
		$reason = 'manual friendly player';
		return 0;
	}

	$reason = 'not friendly';
	return 1;
}

sub Command_post {
	my (undef, $data) = @_;
	return unless $data->{switch} eq 'iff';
	$data->{return} = 1;

	my (undef, $args) = split(' ', $data->{input}, 2);
	if (defined $args) {
		iff_player($args);
	} else {
		iff();
	}
}

##
# iff()
#
# Lists all players and their IFF status.
sub iff {
	for my $ID (@playersID) {
		next unless $ID;
		my $player = $players{$ID};
		_iff_player($player);
	}
	message "End of IFF list.\n", "list";
}

##
# iff_player($name)
#
# Matches $name to a player and prints whether it is friendly and why.
sub iff_player {
	my ($name) = @_;

	my $player = Match::player($name, 1);
	if (!$player) {
		error "Player $name does not exist.\n";
		return;
	}

	_iff_player($player);
}

##
# _iff_player($player)
#
# Prints whether $player is friendly and why.
sub _iff_player {
	my ($player) = @_;

	my $status = foe($player) ? 'foe' : 'friend';
	message "Player $player->{name} ($player->{binID}) is $status ($reason).\n", "list";
}

1;
