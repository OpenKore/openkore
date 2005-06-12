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
	['gmmapmove', 'Move to the specified map.',  \&gmmapmove]
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

	if ($args eq '') {
		error "Usage: gmmapmove <FIELD>\n";
		error "FIELD is a field name including .gat extension, like: gef_fild01.gat\n";
		return;
	}

	my $packet = pack("C*", 0x40, 0x01) . pack("a20", $args);
	sendMsgToServer(\$remote_socket, $packet);
}

1;
