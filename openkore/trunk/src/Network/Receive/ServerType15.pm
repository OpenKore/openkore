# pRO Thor
# Servertype overview: http://www.openkore.com/wiki/index.php/ServerType
package Network::Receive::ServerType15;

use strict;
use Network::Receive::ServerType0 ();
use base qw(Network::Receive::ServerType0);
use Time::HiRes qw(time usleep);

use AI;
use Globals qw($char %timeout $net %config @chars $conState $conState_tries $messageSender $syncMapSync);
use Log qw(message warning error debug);
use Translation;
use Network;
use Utils qw(makeCoordsDir makeCoordsXY makeCoordsFromTo);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new;
	return $self;
}

sub map_loaded {
	my ($self, $args) = @_;
	$net->setState(Network::IN_GAME);
	undef $conState_tries;
	$char = $chars[$config{char}];
	$syncMapSync = pack('V1',$args->{syncMapSync});

	if ($net->version == 1) {
		$net->setState(4);
		message T("Waiting for map to load...\n"), "connection";
		ai_clientSuspend(0, 10);
		main::initMapChangeVars();
	} else {
		$messageSender->sendMapLoaded();
		$messageSender->sendSync(1);
		debug "Sent initial sync\n", "connection";
		$messageSender->sendGuildMasterMemberCheck();

		# Replies 01B6 (Guild Info) and 014C (Guild Ally/Enemy List)
		$messageSender->sendGuildRequestInfo(0);

		# Replies 0166 (Guild Member Titles List) and 0154 (Guild Members List)
		$messageSender->sendGuildRequestInfo(1);
		message(T("You are now in the game\n"), "connection");
		Plugins::callHook('in_game');
		$timeout{'ai'}{'time'} = time;
	}

	$char->{pos} = {};
	makeCoordsDir($char->{pos}, $args->{coords});
	$char->{pos_to} = {%{$char->{pos}}};
	message(TF("Your Coordinates: %s, %s\n", $char->{pos}{x}, $char->{pos}{y}), undef, 1);

	$messageSender->sendIgnoreAll("all") if ($config{ignoreAll});
}

1;
