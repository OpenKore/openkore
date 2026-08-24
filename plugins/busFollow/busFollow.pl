#############################################################################
	# busFollow plugin by Revok
	# revok@openkore.com.br
	#
	# Openkore Brazil: http://openkorebrasil.org/
#############################################################################

package busFollow;
	
	use strict;
	use Plugins;
	use Log qw( message error );
	use Globals;
	use Utils;
	use Translation;
	use AI;
	
	use constant {
		PLUGINNAME                =>    "busFollow",
	};
	
	# Plugin
	Plugins::register(PLUGINNAME, "send and receive info of followTarget coordinates via BUS", \&unload);    
	
	my $networkHook = Plugins::addHooks(['Network::stateChanged',\&init],
	['ai_follow', \&process_bus_follow],
	['AI_pre', \&send_my_info],    
	);
    
	my $bus_message_received;
	my %bots_info;
	
	# handle plugin loaded manually
	if ($::net) {
		if ($::net->getState() > 1) {
			$bus_message_received = $bus->onMessageReceived->add(undef, \&bus_message_received);
		}
	}
	
	sub init {
		return if ($::net->getState() == 1);
		if (!$bus) {
			die("\n\n[".PLUGINNAME."] You MUST start BUS server and configure each bot to use it in order to use this plugin. Open and edit line \"bus 0\" to bus 1 inside control/sys.txt \n\n");
			} elsif (!$bus_message_received) {
			$bus_message_received = $bus->onMessageReceived->add(undef, \&bus_message_received);
		}
	}
	
	sub send_my_info {
		if (!$timeout{busFollow_sendInfo}{timeout}) {
			$timeout{busFollow_sendInfo}{timeout} = 1;
			error ("[".PLUGINNAME."] busFollow_sendInfo is missing in timeouts.txt ! Defaulting to ".$timeout{busFollow_sendInfo}{timeout}." seconds.\n");
			return;
			} elsif (timeOut($timeout{busFollow_sendInfo})) {
			$timeout{busFollow_sendInfo}{time} = time;
			if (defined($chars[$config{'char'}])) {
				my %args;
				$args{name} = $chars[$config{'char'}]{'name'};
				$args{map} = $field->baseName;
				$args{x} = $chars[$config{'char'}]{'pos_to'}{'x'};
				$args{y} = $chars[$config{'char'}]{'pos_to'}{'y'};
				$bus->send('charInfo', \%args);
			}
		}
	}
	
	
	sub bus_message_received {
		my (undef, undef, $msg) = @_;
		if (($msg->{messageID} eq 'charInfo') && ($msg->{args}{name} =~ /$config{followTarget}/) && $config{follow}) {
			#warning ("Received master info from BUS \n");
			$bots_info{"$msg->{args}{name}"} = $msg->{args}; # get {x}, {y} and {map}
		}
	}
	
	sub process_bus_follow {
		my (undef, $args) = @_;
		# borrow ai_partyfollow algorithm
		return if ($args->{following} && $args->{ai_follow_lost});
		my %master;
		if ($bots_info{$config{followTarget}} && !AI::inQueue("storageAuto","storageGet","sellAuto","buyAuto")) {
			
			$master{x} = $bots_info{$config{followTarget}}{x};
			$master{y} = $bots_info{$config{followTarget}}{y};
			$master{map} = $bots_info{$config{followTarget}}{map};
			
			if ($master{map} ne $field->name || $master{x} == 0 || $master{y} == 0) { # Compare including InstanceID
				delete $master{x};
				delete $master{y};
			}
			
			return unless ($master{map} ne $field->name || exists $master{x}); # Compare including InstanceID
			
			# Compare map names including InstanceID
			if ((exists $ai_v{master} && distance(\%master, $ai_v{master}) > 15)
			|| $master{map} != $ai_v{master}{map}
			|| (timeOut($ai_v{master}{time}, 15) && distance(\%master, $char->{pos_to}) > $config{followDistanceMax})) {
				
				$ai_v{master}{x} = $master{x};
				$ai_v{master}{y} = $master{y};
				$ai_v{master}{map} = $master{map};
				($ai_v{master}{map_name}, undef) = Field::nameToBaseName(undef, $master{map}); # Hack to clean up InstanceID
				$ai_v{master}{time} = time;
				
				if ($ai_v{master}{map} ne $field->name) {
					message TF("Calculating route to find master: %s\n", $ai_v{master}{map_name}), "follow";
					} elsif (distance(\%master, $char->{pos_to}) > $config{followDistanceMax} ) {
					message TF("Calculating route to find master: %s (%s,%s)\n", $ai_v{master}{map_name}, $ai_v{master}{x}, $ai_v{master}{y}), "follow";
					} else {
					return;
				}
				
				AI::clear("move", "route", "mapRoute");
				ai_route($ai_v{master}{map_name}, $ai_v{master}{x}, $ai_v{master}{y}, distFromGoal => $config{followDistanceMin});
				
				my $followIndex = AI::findAction("follow");
				if (defined $followIndex) {
					$ai_seq_args[$followIndex]{ai_follow_lost_end}{timeout} = $timeout{ai_follow_lost_end}{timeout};
				}
			}
		}
	}
	
	# Plugin unload
	sub unload {
		message("\n[".PLUGINNAME."] unloading.\n\n");
		Plugins::delHooks($networkHook);
		$bus->onMessageReceived->remove($bus_message_received) if $bus_message_received;
	}
	
1;										