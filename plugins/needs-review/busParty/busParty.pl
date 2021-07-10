#############################################################################
# busParty plugin by Revok
# revok@openkore.com.br
# 2021-07-09
#############################################################################
package busParty;

use strict;
use AI;
use Globals;
use Log qw( message error debug );
use Misc qw(center);
use Plugins;
use Utils;

# Plugin
Plugins::register('busParty', "send and receive info of followTarget coordinates via BUS", \&unload);

my $networkHook = Plugins::addHooks(
	['Network::stateChanged',\&init],
	['AI_pre', \&send_my_info]
);

my $chooks = Commands::register(
	['busParty', 'show busParty info', \&cmdParty],
);

my $bus_message_received;
my %bus_sendinfo_timeout = (timeout => 6);

# handle plugin loaded manually
if ($::net) {
	if ($::net->getState() > 1) {
		$bus_message_received = $bus->onMessageReceived->add(undef, \&bus_message_received);
	}
}

sub init {
	return if ($::net->getState() == 1);
	if (!$bus) {
		die("\n\n[busParty] You MUST start BUS server and configure each bot to use it in order to use this plugin. Open and edit line \"bus 0\" to bus 1 inside control/sys.txt \n\n");
		} elsif (!$bus_message_received) {
		$bus_message_received = $bus->onMessageReceived->add(undef, \&bus_message_received);
	}
}

sub send_my_info {
	if (timeOut(\%bus_sendinfo_timeout)) {
		if ($char && $field && ($bus->getState == 4)) {
			sendInfo();
		}
		$bus_sendinfo_timeout{time} = time;
	}
}

sub sendInfo {
	my %my_info = (
		server => $servers[$config{'server'}]{'name'},
		name => $char->{name},
		online => 1,
		hp_current => $char->{hp},
		hp_max => $char->{hp_max},
		accountID => $accountID,
		location_field => $field->baseName.".gat",
		location_x => $char->{pos}{x},
		location_y => $char->{pos}{y},
		statuses => join(',', keys %{$char->{statuses}})
	);
	$bus->send('busParty', \%my_info);
}

sub bus_message_received {
	my (undef, undef, $msg) = @_;
	if (($msg->{messageID} eq 'busParty') && ($msg->{args}{server} eq $servers[$config{'server'}]{'name'}) && $char && $field) {
		debug "Received party data \n", "busparty";
		my $ID = $msg->{args}{accountID};
		if (binFind(\@partyUsersID, $ID) eq "" || ref($char->{party}{users}{$ID}) ne "Actor::Party") {
			binAdd(\@partyUsersID, $ID);
			$char->{party}{users}{$ID} = new Actor::Party();
			message "[busParty] Adding fake party data \n";
		}
		$char->{party}{users}{$ID}{name} = $msg->{args}{name};
		$char->{party}{users}{$ID}{admin} = 0;
		$char->{party}{users}{$ID}{online} = $msg->{args}{online};
		$char->{party}{users}{$ID}{map} = $msg->{args}{location_field};
		$char->{party}{users}{$ID}{pos}{x} = $msg->{args}{location_x};
		$char->{party}{users}{$ID}{pos}{y} = $msg->{args}{location_y};
		$char->{party}{users}{$ID}{hp} = $msg->{args}{hp_current};
		$char->{party}{users}{$ID}{hp_max} = $msg->{args}{hp_max};
		$char->{party}{users}{$ID}->{ID} = $msg->{args}{accountID};
		undef $char->{party}{users}{$ID}{statuses};
		my $player = Actor::get($ID);
		undef $player->{statuses};
		foreach my $name (split(",", $msg->{args}{statuses})) { $player->setStatus($name, 1); $char->{party}{users}{$ID}->setStatus($name, 1); }
	}
}

sub cmdParty {
	my $msg = center(" busParty Information ", 82, '-') ."\n".
	"#  Name                   Map           Coord     Online  HP\n";
	for (my $i = 0; $i < @partyUsersID; $i++) {
		next if ($partyUsersID[$i] eq "");
		my $coord_string = "";
		my $hp_string = "";
		my $name_string = $char->{'party'}{'users'}{$partyUsersID[$i]}{'name'};
		my $online_string;
		my $map_string;

		if ($partyUsersID[$i] eq $accountID) {
			$online_string = "Yes";
			($map_string) = $field->name;
			$coord_string = $char->{'pos'}{'x'}. ", ".$char->{'pos'}{'y'};
			$hp_string = $char->{'hp'}."/".$char->{'hp_max'}
					." (".int($char->{'hp'}/$char->{'hp_max'} * 100)
					."%)";
		} else {
			$online_string = ($char->{'party'}{'users'}{$partyUsersID[$i]}{'online'}) ? "Yes" : "No";
			($map_string) = $char->{'party'}{'users'}{$partyUsersID[$i]}{'map'} =~ /([\s\S]*)\.gat/;
			$coord_string = $char->{'party'}{'users'}{$partyUsersID[$i]}{'pos'}{'x'}
				. ", ".$char->{'party'}{'users'}{$partyUsersID[$i]}{'pos'}{'y'}
				if ($char->{'party'}{'users'}{$partyUsersID[$i]}{'pos'}{'x'} ne ""
					&& $char->{'party'}{'users'}{$partyUsersID[$i]}{'online'});
			$hp_string = $char->{'party'}{'users'}{$partyUsersID[$i]}{'hp'}."/".$char->{'party'}{'users'}{$partyUsersID[$i]}{'hp_max'}
				." (".int($char->{'party'}{'users'}{$partyUsersID[$i]}{'hp'}/$char->{'party'}{'users'}{$partyUsersID[$i]}{'hp_max'} * 100)
				."%)" if ($char->{'party'}{'users'}{$partyUsersID[$i]}{'hp_max'} && $char->{'party'}{'users'}{$partyUsersID[$i]}{'online'});
		}
		$msg .= swrite(
			"@< @<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<< @<<<<<<<  @<<     @<<<<<<<<<<<<<<<<<<<<<<<",
			[$i, $name_string, $map_string, $coord_string, $online_string, $hp_string]);
	}
	$msg .= ('-'x82) . "\n";
	message $msg, "list";
}
# Plugin unload
sub unload {
	message "busParty plugin unloading, ", "system";
	Plugins::delHooks($networkHook);
	Commands::unregister($chooks);
	$bus->onMessageReceived->remove($bus_message_received) if $bus_message_received;
	undef $bus_message_received;
	undef %bus_sendinfo_timeout;
}

1;
