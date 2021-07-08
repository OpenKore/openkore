#############################################################################
	# busParty plugin by Revok
	# revok@openkore.com.br
	# @2013
#############################################################################
package busParty;
	
	use strict;
	use Plugins;
	use Log qw( message error );
	use Globals;
	use Utils;
	use AI;
	
	# Plugin
	Plugins::register('busParty', "send and receive info of followTarget coordinates via BUS", \&unload);
	
	my $networkHook = Plugins::addHooks(['Network::stateChanged',\&init],
	['AI_pre', \&send_my_info]
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
			die("\n\n[busFollow] You MUST start BUS server and configure each bot to use it in order to use this plugin. Open and edit line \"bus 0\" to bus 1 inside control/sys.txt \n\n");
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
		);
		$my_info{location_field} = $field->baseName.".gat"; $my_info{location_x} = $char->{pos}{x}; $my_info{location_y} = $char->{pos}{y}; $my_info{statuses} = join(',', keys %{$char->{statuses}});
		$bus->send('busParty', \%my_info);
	}
	
	sub bus_message_received {
		my (undef, undef, $msg) = @_;
		if (($msg->{messageID} eq 'busParty') && ($msg->{args}{server} eq $servers[$config{'server'}]{'name'}) && $char && $field) {
			error "Received party data \n";
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
			$char->{party}{users}{$ID}{hp} = $msg->{args}{hp_current};
			$char->{party}{users}{$ID}{hp_max} = $msg->{args}{hp_max};
			$char->{party}{users}{$ID}->{ID} = $msg->{args}{accountID};
			undef $char->{party}{users}{$ID}{statuses};
			my $player = Actor::get($ID);
			undef $player->{statuses};
			foreach my $name (split(",", $msg->{args}{statuses})) { $player->setStatus($name, 1); $char->{party}{users}{$ID}->setStatus($name, 1); }
		}
	}
	
	# Plugin unload
	sub unload {
		message("\n[busParty] unloading.\n\n");
		Plugins::delHooks($networkHook);
		$bus->onMessageReceived->remove($bus_message_received) if $bus_message_received;
	}
	
1;