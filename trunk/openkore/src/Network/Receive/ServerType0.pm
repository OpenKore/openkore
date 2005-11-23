package Network::Receive::ServerType0;

use strict;
use base qw(Network::Receive);

use Globals;
use Actor;
use Actor::You;
use Time::HiRes qw(time usleep);
use Settings;
use Log qw(message warning error debug);
use FileParsers;
use Interface;
use Network::Send;
use Misc;
use Plugins;
use Utils;
use Skills;
use AI;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new;
	return $self;
}

sub map_loaded {
	my ($self,$args) = @_;
	$conState = 5;
	undef $conState_tries;
	$char = $chars[$config{'char'}];

	if ($net->version == 1) {
		$conState = 4;
		message("Waiting for map to load...\n", "connection");
		ai_clientSuspend(0, 10);
		main::initMapChangeVars();
	} else {
		message("You are now in the game\n", "connection");
		$net->sendMapLoaded();
		$timeout{'ai'}{'time'} = time;
	}

	$char->{pos} = {};
	makeCoords($char->{pos}, $args->{coords});
	$char->{pos_to} = {%{$char->{pos}}};
	message("Your Coordinates: $char->{pos}{x}, $char->{pos}{y}\n", undef, 1);

	$net->sendIgnoreAll("all") if ($config{'ignoreAll'});
}

1;
