#########################################################################
#  OpenKore - Packet Receiveing
#  This module contains functions for Receiveing packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
########################################################################
# Korea (kRO) # by alisonrag / sctnightcore
# The majority of private servers use eAthena, this is a clone of kRO
package Network::Receive::Zero;
use strict;
use base qw(Network::Receive::ServerType0);
use Log qw(warning debug error message);
use Globals;
use Translation;
use I18N qw(bytesToString);
use Socket qw(inet_ntoa);
use Utils;
use Utils::DataStructures;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %handlers = qw(
		received_characters 099D
		received_characters 082D
		sync_received_characters 09A0
		account_server_info 0AC4
		received_character_ID_and_Map 0AC5
		map_changed 0AC7
		actor_exists 09FF
		inventory_item_added 0A37
		map_login 0436
		character_status 0229
		actor_status_active 0196
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

# from old ServerType0
sub map_loaded {
	my ($self, $args) = @_;
	$net->setState(Network::IN_GAME);
	undef $conState_tries;
	$char = $chars[$config{char}];
	return unless Network::Receive::changeToInGameState;

	if ($net->version == 1) {
		$net->setState(4);
		message(T("Waiting for map to load...\n"), "connection");
		ai_clientSuspend(0, 10);
		main::initMapChangeVars();
	} else {
		$messageSender->sendReqRemainTime();
		$messageSender->sendMapLoaded();
		$messageSender->sendSync(1);
		$messageSender->sendRequestCashItemsList();
		$messageSender->sendGuildRequestInfo();
		
		message(T("You are now in the game\n"), "connection");
		Plugins::callHook('in_game');
		$timeout{'ai'}{'time'} = time;
		our $quest_generation++;

		$messageSender->sendIgnoreAll("all") if ($config{ignoreAll}); # broking xkore 1 and 3 when use cryptkey
		$messageSender->sendBlockingPlayerCancel(); # request to unfreeze char
	}

	$char->{pos} = {};
	makeCoordsDir($char->{pos}, $args->{coords}, \$char->{look}{body});
	$char->{pos_to} = {%{$char->{pos}}};
	message(TF("Your Coordinates: %s, %s\n", $char->{pos}{x}, $char->{pos}{y}), undef, 1);
}

sub parse_account_server_info {
    my ($self, $args) = @_;

    @{$args->{servers}} = map {
		my %server;
		@server{qw(ip port name users state property unknown)} = unpack 'a4 v Z20 v3 a128', $_;		
		$server{ip} = inet_ntoa($server{ip});
		$server{name} = bytesToString($server{name});
		\%server
	} unpack '(a160)*', $args->{serverInfo};
}

 sub party_users_info {
	my ($self, $args) = @_;
 	return unless Network::Receive::changeToInGameState();
 
 	$char->{party}{name} = bytesToString($args->{party_name});

	for (my $i = 0; $i < length($args->{playerInfo}); $i += 54) {
		my $ID = substr($args->{playerInfo}, $i, 4);
		if (binFind(\@partyUsersID, $ID) eq "") {
			binAdd(\@partyUsersID, $ID);
		}
		$char->{party}{users}{$ID} = new Actor::Party();
		@{$char->{party}{users}{$ID}}{qw(ID GID name map admin online jobID lv)} = unpack('V V Z24 Z16 C2 v2', substr($args->{playerInfo}, $i, 54));
		$char->{party}{users}{$ID}{name} = bytesToString($char->{party}{users}{$ID}{name});
		$char->{party}{users}{$ID}{admin} = !$char->{party}{users}{$ID}{admin};
		$char->{party}{users}{$ID}{online} = !$char->{party}{users}{$ID}{online};

		debug TF("Party Member: %s (%s)\n", $char->{party}{users}{$ID}{name}, $char->{party}{users}{$ID}{map}), "party", 1;
	}
}

1;