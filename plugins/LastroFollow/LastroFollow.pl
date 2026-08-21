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
my $pending_target;
my $pending_followup;
my $hooks = Plugins::addHooks(
	['lastro_autofollow_state', \&onAutoFollowState, undef],
);

sub onUnload {
	Commands::unregister($commands);
	Plugins::delHooks($hooks);
	$pending_target = undef;
	$pending_followup = undef;
}

sub onAutoFollowState {
	my (undef, $args) = @_;
	return unless $args && exists $args->{enabled};

	$enabled = $args->{enabled} ? 1 : 0;
	return unless defined $pending_target;

	if ($enabled == $pending_target) {
		$pending_target = undef;
		$pending_followup = undef;
		return;
	}

	return unless $pending_followup;
	$pending_followup = 0;
	$pending_target = undef;
	$messageSender->sendLastroAutoFollow();
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

	$pending_target = $enabled{$args};
	$pending_followup = 1;
	$messageSender->sendLastroAutoFollow();
	message "Requested Lastro follow battle " . ($enabled{$args} ? 'enable' : 'disable') . ".\n", 'success';
}

1;
