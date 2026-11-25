##
# MODULE DESCRIPTION: Outgoing client messages handling
#
# This class contains only handler functions
# which are used to handle messages
# that are sent by the RO client, if it's present.

package Network::ClientReceive;

use strict;
use Modules 'register';
use Time::HiRes qw(time);

use Globals qw($packetParser $incomingMessages %config $char $field %ai_v %timeout $shopstarted $firstLoginMap $sentWelcomeMessage @lastpm %lastpm);
use Misc qw(configModify visualDump);
use Log qw(message debug warning);
use Translation;
use Utils qw(existsInList);
use WarpPortal qw(
	noteMemoRequest noteWarpCast noteWarpSelection
	normalizeWarpMap availableWarpMaps warpMapIndex
);

use base qw(Network::PacketParser);

sub new {
	my ( $class ) = @_;
	my $self = $class->SUPER::new( @_ );
	
	$self->{hook_prefix} = 'Network::ClientReceive';
	
	return $self;
}

sub handleChat {
	my ($self, $args, $chat) = @_;
	
	my $prefix = quotemeta $config{commandPrefix};
	if ($chat =~ /^$prefix/) {
		$chat =~ s/^$prefix//;
		$chat =~ s/^\s*//;
		$chat =~ s/\s*$//;
		main::parseInput($chat, 1);
		$args->{mangle} = 2;
		return 1;
	}
}

sub game_login {
	$incomingMessages->nextMessageMightBeAccountID;
}

sub char_login {
	my ($self, $args) = @_;
	
	configModify('char', $args->{slot});
}

sub map_login {
	my ($self, $args) = @_;
	
	$incomingMessages->nextMessageMightBeAccountID;
	
	if ($config{sex} ne '') {
		$args->{sex} = $config{sex};
		$args->{mangle} = 1;
	}
}

sub map_loaded {
	$packetParser->changeToInGameState;
	AI::clear('clientSuspend');
	$timeout{ai}{time} = time;
	if ($firstLoginMap) {
		undef $sentWelcomeMessage;
		undef $firstLoginMap;
	}
	$timeout{welcomeText}{time} = time;
	$ai_v{portalTrace_mapChanged} = time;
	message T("Map loaded\n"), 'connection';
	
	Plugins::callHook('map_loaded');
}

# These are outgoing client packets parsed by ClientReceive in XKore mode.
# Capture only the observed request facts; the server acknowledgement remains
# the authority for whether /memo actually succeeded.
sub memo_request {
	return unless $char && $field && $char->{pos};
	noteMemoRequest($field->baseName, $char->{pos}{x}, $char->{pos}{y});
}

sub skill_use_location {
	my ($self, $args) = @_;
	noteWarpCast($args->{skillID}, $args->{lv}, $args->{x}, $args->{y});
}

# XKore sees the official client's destination choice as an outgoing packet.
# Correlate it only with a fresh AL_WARP menu and the cast observed for that menu.
sub warp_select {
	my ($self, $args) = @_;
	return unless $char && $field && $char->{pos} && ($args->{skillID} || 0) == 27;
	my $state = $char->{warpPortalState} or return;
	my $cast = $state->{last_portal_cast} or return;
	my $now = time;
	return unless $cast->{session} == $state->{session}
		&& $cast->{level} && $cast->{level} >= 1 && $cast->{level} <= 4
		&& defined($cast->{time}) && $cast->{time} <= $now && $now - $cast->{time} <= 20
		&& defined($state->{verified_at}) && $state->{verified_at} >= $cast->{time}
		&& $state->{verified_at} <= $now && $now - $state->{verified_at} <= 20
		&& ($state->{cast_level} || 0) == $cast->{level};
	return unless availableWarpMaps();
	my $map = normalizeWarpMap($args->{mapName});
	return unless $map;
	my $index = warpMapIndex($map);
	return unless defined($index) && $index + 1 <= $cast->{level};
	my $source_map = $field->baseName;
	my $attempt_id = join('-', 'xkore', $state->{session}, sprintf('%.6f', $cast->{time}));
	my $pending = $char->{warpPortalPendingTraversal};
	# Packet observation can be repeated by instrumentation; preserve evidence
	# already attached to this cast instead of restarting its attempt clock.
	return if $pending && ($pending->{attempt_id} || '') eq $attempt_id;
	noteWarpSelection($map, $source_map, $char->{pos}{x}, $char->{pos}{y},
		$cast->{level}, $attempt_id, $cast->{portal_pos});
}

sub actor_action {
	my ($self, $args) = @_;
	
	unless ($config{tankMode} || AI::inQueue('attack')) {
		AI::clear('clientSuspend');
		$char->clientSuspend($args->{switch}, 2, $args->{type}, $args->{targetID});
	} else {
		$args->{mangle} = 2;
	}
}

sub public_chat {
	my ($self, $args) = @_;
	
	$self->handleChat($args, $args->{message});
}

sub private_message {
	my ($self, $args) = @_;
	
	unless ($self->handleChat($args, $args->{privMsg})) {
		undef %lastpm;
		@lastpm{qw(msg user)} = @{$args}{qw(privMsg privMsgUser)};
		push @lastpm, {%lastpm};
	}
}

sub actor_look_at {
	my ($self, $args) = @_;
	
	@{$char->{look}}{qw(head body)} = @{$args}{qw(head body)};
}

sub item_take {
	my ($self, $args) = @_;
	
	AI::clear('clientSuspend');
	$char->clientSuspend($args->{switch}, 2, $args->{ID});
}

sub restart {
	my ($self, $args) = @_;
	
	AI::clear('clientSuspend');
	$char->clientSuspend($args->{switch}, $timeout{'ai_clientSuspend'}{'timeout'}) if $char;
}

sub party_chat {
	my ($self, $args) = @_;
	
	$self->handleChat($args, $args->{message});
}

sub alignment {
	my ($self, $args) = @_;
	
	# Chat/skill mute
	$args->{mangle} = 2;
}

sub guild_chat {
	my ($self, $args) = @_;
	
	$self->handleChat($args, $args->{message});
}

sub quit_request {
	my ($self, $args) = @_;
	
	AI::clear('clientSuspend');
	$char->clientSuspend($args->{switch}, 10);
}

sub shop_open {
	# client started a shop manually
	$shopstarted = 1;
}

sub shop_close {
	# client stopped shop manually
	$shopstarted = 0;
}

=pod
# sendSync
	if ($masterServer->{syncID} && $switch eq sprintf('%04X', hex($masterServer->{syncID}))) {
		#syncSync support for XKore 1 mode
		$syncSync = substr($msg, $masterServer->{syncTickOffset}, 4);

# sendSync
	} elsif ($switch eq "00A7") {
		if($masterServer && $masterServer->{paddedPackets}) {
			$syncSync = substr($msg, 8, 4);
		}

# sendSync
	} elsif ($switch eq "007E") {
		if ($masterServer && $masterServer->{paddedPackets}) {
			$syncSync = substr($msg, 4, 4);
		}

# sendMapLoaded
	} elsif ($switch eq "007D") {
		# syncSync support for XKore 1 mode
		if($masterServer->{serverType} == 11) {
			$syncSync = substr($msg, 8, 4);
		} else {
			# formula: MapLoaded_len + Sync_len - 4 - Sync_packet_last_junk
			$syncSync = substr($msg, $masterServer->{mapLoadedTickOffset}, 4);
		}

# sendMove
	} elsif ($switch eq "0085") {
		#if ($masterServer->{serverType} == 0 || $masterServer->{serverType} == 1 || $masterServer->{serverType} == 2) {
		#	#Move
		#	AI::clear("clientSuspend");
		#	makeCoordsDir(\%coords, substr($msg, 2, 3));
		#	ai_clientSuspend($switch, (distance($char->{'pos'}, \%coords) * $char->{walk_speed}) + 4);
		#}
=cut

sub unhandledMessage {}

sub unknownMessage {
	my ($self, $args) = @_;
	
	# Unknown message - ignore it
	unless (existsInList($config{debugPacket_exclude}, $args->{switch})) {
		debug TF("Packet Tokenizer: Unknown outgoing switch: %s\n", $args->{switch}), 'outgoing';
		visualDump($args->{RAW_MSG}, "<< Outgoing unknown packet") if $config{debugPacket_unparsed};
	}
	
	# Pass it along to the server, whatever it is
}

1;
