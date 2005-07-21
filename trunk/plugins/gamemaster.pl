package GameMasterPlugin;

use strict;
use Globals;
use Plugins;
use Commands;
use Log qw(error);
use Network::Send qw(sendMsgToServer);
use Utils;


Plugins::register('Game Master', 'Enables usage of GM commands', \&on_unload);
my $commands = Commands::register(
	['gmb',       'Broadcast a global message.', \&gmb],
	['gmmapmove', 'Move to the specified map.',  \&gmmapmove],
	['gmcreate',  'Create items or monsters.',   \&gmcreate],
	['gmhide',    'Toggle perfect GM hide.',     \&gmhide],
	['gmwarpto',  'Warp to a player.',           \&gmwarpto],
	['gmsummon',  'Summon a player to you.',     \&gmsummon],
	['gmdc',      'Disconnect a player AID.',    \&gmdc],
	['gmkillall', 'Disconnect all users.',       \&gmkillall]
);

sub on_unload {
	Commands::unregister($commands);
}

sub gmb {
	my (undef, $args) = @_;
	return unless ($char);

	if ($args eq '') {
		error "Usage: gmb <MESSAGE>\n";
		return;
	}

	my $msg = "$char->{name}: $args" . chr(0);
	my $packet = pack("C*", 0x99, 0x00) . pack("v", length($msg) + 4) . $msg;
	sendMsgToServer(\$remote_socket, $packet);
}

sub gmmapmove {
	my (undef, $args) = @_;
	return unless ($conState == 5);

	my ($map_name) = $args =~ /(\S+)/;
	# this will pack as 0 if it fails to match
	my ($x, $y) = $args =~ /\w+ (\d+) (\d+)/;

	if ($map_name eq '') {
		error "Usage: gmmapmove <FIELD>\n";
		error "FIELD is a field name including .gat extension, like: gef_fild01.gat\n";
		return;
	}

	my $packet = pack("C*", 0x40, 0x01) . pack("a16", $map_name) . pack("v1 v1", $x, $y);
	sendMsgToServer(\$remote_socket, $packet);
}

sub gmsummon {
	my (undef, $args) = @_;
	return unless ($conState == 5);

	if ($args eq '') {
		error "Usage: gmsummon <player_name>\n";
		return;
	}

	my $packet = pack("C*", 0xBD, 0x01).pack("a24", $args);
	sendMsgToServer(\$remote_socket, $packet);
}

sub gmdc {
	my (undef, $args) = @_;
	return unless ($conState == 5);

	if ($args !~ /^\d+$/) {
		error "Usage: gmdc <player_AID>\n";
		return;
	}

	my $packet = pack("C*", 0xCC, 0x00).pack("V1", $args);
	sendMsgToServer(\$remote_socket, $packet);
}

sub gmkillall {
	return unless ($conState == 5);
	my $packet = pack("C*", 0xCE, 0x00);
	sendMsgToServer(\$remote_socket, $packet);
}

sub gmcreate {
	my (undef, $args) = @_;
	return unless ($conState == 5);

	if ($args eq '') {
		error "Usage: gmcreate (<MONSTER_NAME> || <Item_Name>) \n";
		return;
	}

	my $packet = pack("C*", 0x3F, 0x01).pack("a24", $args);
	sendMsgToServer(\$remote_socket, $packet);
}

sub gmhide {
	return unless ($conState == 5);
	my $packet = pack("C*", 0x9D, 0x01, 0x40, 0x00, 0x00, 0x00);
	sendMsgToServer(\$remote_socket, $packet);
}

sub gmwarpto {
	my (undef, $args) = @_;
	return unless ($conState == 5);

	if ($args eq '') {
		error "Usage: gmwarpto <Player Name>\n";
		return;
	}

	my $packet = pack("C*", 0xBB, 0x01).pack("a24", $args);
	sendMsgToServer(\$remote_socket, $packet);
}

1;
