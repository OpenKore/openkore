package LastroFollow;

use strict;
use warnings;

use Commands;
use Globals qw($masterServer $messageSender $net);
use Log qw(error message);
use Network;
use Plugins;

Plugins::register(
	'LastroFollow',
	'Toggles Lastro server-side follow battle',
	\&onUnload,
);

my $commands = Commands::register(
	['autofollow', 'autofollow <on|off> - toggle Lastro follow battle', \&commandAutoFollow],
);
my $enabled;
my $hooks = Plugins::addHooks(
	['lastro_autofollow_state', \&onAutoFollowState, undef],
);

sub onUnload {
	Commands::unregister($commands);
	Plugins::delHooks($hooks);
}

sub onAutoFollowState {
	my (undef, $args) = @_;
	return unless $args && exists $args->{enabled};

	$enabled = $args->{enabled} ? 1 : 0;
}

sub commandAutoFollow {
	my (undef, $args) = @_;
	$args = '' unless defined $args;
	$args =~ s/^\s+|\s+$//g;
	$args = lc $args;

	my %enabled = (on => 1, off => 0);
	unless (exists $enabled{$args}) {
		error "Usage: autofollow <on|off>\n";
		return;
	}

	unless ($masterServer && $masterServer->{lastroAutoFollow}) {
		error "autofollow is available only for the configured Lastro server.\n";
		return;
	}

	unless ($net && $net->getState == Network::IN_GAME) {
		error "autofollow can only be changed while connected to the map server.\n";
		return;
	}

	unless ($messageSender && $messageSender->can('sendLastroAutoFollow')) {
		error "autofollow is unavailable for the active server type.\n";
		return;
	}

	unless (defined $enabled) {
		error "Lastro follow state has not been received yet; wait for map initialization.\n";
		return;
	}

	if ($enabled == $enabled{$args}) {
		message "Lastro follow battle is already " . ($enabled ? 'enabled' : 'disabled') . ".\n", 'info';
		return;
	}

	$messageSender->sendLastroAutoFollow();
	message "Requested Lastro follow battle " . ($enabled{$args} ? 'enable' : 'disable') . ".\n", 'success';
}

1;
