#########################################################################
#  OpenKore - Network subsystem
#  Copyright (c) 2006 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# Servertype overvie: http://www.openkore.com/wiki/index.php/ServerType
package Network::Receive::ServerType0;

use strict;
use Network::Receive ();
use base qw(Network::Receive);
use Time::HiRes qw(time usleep);

use AI;
use Globals qw($char %timeout $net %config @chars $conState $conState_tries $messageSender);
use Log qw(message warning error debug);
use Translation;
use Network;
use Utils qw(makeCoords);

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

	if ($net->version == 1) {
		$net->setState(4);
		message(T("Waiting for map to load...\n"), "connection");
		ai_clientSuspend(0, 10);
		main::initMapChangeVars();
	} else {
		$messageSender->sendGuildInfoRequest();

		# Replies 01B6 (Guild Info) and 014C (Guild Ally/Enemy List)
		$messageSender->sendGuildRequest(0);

		# Replies 0166 (Guild Member Titles List) and 0154 (Guild Members List)
		$messageSender->sendGuildRequest(1);
		message(T("You are now in the game\n"), "connection");
		$messageSender->sendMapLoaded();
		$timeout{'ai'}{'time'} = time;
	}

	$char->{pos} = {};
	makeCoords($char->{pos}, $args->{coords});
	$char->{pos_to} = {%{$char->{pos}}};
	message(TF("Your Coordinates: %s, %s\n", $char->{pos}{x}, $char->{pos}{y}), undef, 1);

	$messageSender->sendIgnoreAll("all") if ($config{ignoreAll});
}

1;
