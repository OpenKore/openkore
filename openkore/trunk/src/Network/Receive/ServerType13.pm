package Network::Receive::ServerType13;

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
use Translation;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new;
	return $self;
}

sub map_loaded {
	my ($self, $args) = @_;
	$conState = 5;
	undef $conState_tries;
	$char = $chars[$config{'char'}];
	
	#Reading MapSync
	$syncMapSync = substr($args->{RAW_MSG}, 2, 4);
	
	if ($net->version == 1) {
		$conState = 4;
		message T("Waiting for map to load...\n"), "connection";
		ai_clientSuspend(0, 10);
		main::initMapChangeVars();
	} else {
		message	T("Requesting guild information...\n"), "info";
		sendGuildInfoRequest($net);

		# Replies 01B6 (Guild Info) and 014C (Guild Ally/Enemy List)
		sendGuildRequest($net, 0);

		# Replies 0166 (Guild Member Titles List) and 0154 (Guild Members List)
		sendGuildRequest($net, 1);
		message T("You are now in the game\n"), "connection";
		sendMapLoaded($net);
		#for rRO server initial sync is not sending
		sendSync($net, 1);
		debug "Sent initial sync\n", "connection";
		$timeout{'ai'}{'time'} = time;
	}

	$char->{pos} = {};
	makeCoords($char->{pos}, $args->{coords});
	$char->{pos_to} = {%{$char->{pos}}};
	message TF("Your Coordinates: %s, %s\n", $char->{pos}{x}, $char->{pos}{y}), undef, 1;

	sendIgnoreAll($net, "all") if ($config{'ignoreAll'});
}

1;
