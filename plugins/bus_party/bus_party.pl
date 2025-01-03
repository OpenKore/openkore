package OpenKore::Plugins::BusParty;
###############################################################################
# Plugin to update party information via bus.
#
# This plugin is always loaded, but only sends data if the "bus_party" config
# option is enabled.

use strict;

use Globals qw( $accountID $char %config $field $net @partyUsersID );
use Log qw( &debug &message );
use Utils qw( &binAdd &binFind &binRemove &calcPosition &timeOut );
use Time::HiRes qw( &time );

our $name = 'bus_party';
our $timeout = { time => 0, timeout => 0.2 };
our $bus_party ||= {};

Plugins::register( $name, "$name plugin", \&Unload, \&Unload );

my $hooks = Plugins::addHooks(    #
	[ 'mainLoop_pre'           => \&onMainLoopPre ],
	[ 'bus/connect'            => \&onBusConnect ],
	[ 'bus/recv/PARTY_REQUEST' => \&onBusRecvPartyRequest ],
	[ 'bus/recv/PARTY_UPDATE'  => \&onBusRecvPartyUpdate ],
	[ 'bus/recv/LEAVE'         => \&onBusRecvLeave ],
);

sub Unload {
	Plugins::delHooks( $hooks );
}

sub onMainLoopPre {
    return if !$config{bus_party};

    return if !timeOut($timeout);
    $timeout->{time} = time;

	my $party_update = partial_party_update();
	return if !%$party_update;
	Plugins::callHook( 'bus/send', { messageID => 'PARTY_UPDATE', args => $party_update } );
}

sub onBusConnect{
	Plugins::callHook( 'bus/send', { messageID => 'PARTY_REQUEST' } );
	Plugins::callHook( 'bus/send', { messageID => 'PARTY_UPDATE', args => full_party_update() } );
}

sub onBusRecvPartyRequest {
	my ( undef, $args ) = @_;
	Plugins::callHook( 'bus/send', { messageID => 'PARTY_UPDATE', TO => $args->{FROM}, args => full_party_update() } );
}

sub onBusRecvPartyUpdate {
	my ( undef, $args ) = @_;
	my $actor = $bus_party->{ $args->{FROM} } ||= {};
	$actor->{$_} = $args->{$_} foreach keys %$args;

	# Update the party.
	my $id = pack 'V', $actor->{id};
	return if !$actor->{id} || $id eq $accountID;
	return if !$actor->{name};
	return if !$char;
	return if !$char->{party};

	my $party_user = $char->{party}{users}{$id};
	if ( binFind( \@partyUsersID, $id ) eq '' ) {
		binAdd( \@partyUsersID, $id );
	}
	if ( !$party_user ) {
		$party_user = $char->{party}{users}{$id} = Actor::Party->new;
		$party_user->{ID} = $id;
		message "[bot_party] Party Member: $args->{name}\n";
	}

	foreach ( qw( name online hp hp_max ) ) {
		$party_user->{$_} = $actor->{$_};
	}
	$party_user->{bus_party} = $actor->{party};
	$party_user->{map}       = "$actor->{map}.gat";
	$party_user->{pos}->{x}  = $actor->{x};
	$party_user->{pos}->{y}  = $actor->{y};
}

sub onBusRecvLeave {
	my ( undef, $args ) = @_;

    my $actor = $bus_party->{ $args->{clientID} };
    return if !$actor;

	# Remove the character from $char->{party} if they're not in our actual party.
	my $id = pack 'V', $actor->{id};
	if ( $char && $char->{party} && ( !$char->{party}->{name} || $actor->{party} ne $char->{party}->{name} ) && binFind( \@partyUsersID, $id ) ne '' ) {
		delete $char->{party}->{users}->{$id};
		binRemove( \@partyUsersID, $id );
	}

	delete $bus_party->{ $args->{clientID} };
}

sub full_party_update {
	my $update = {};
	$update->{followTarget} = $config{follow} && $config{followTarget} || '';
	if ( $char ) {
		my $pos = calcPosition( $char );
		$update->{id}         = unpack 'V', $accountID;
		$update->{name}       = $char->{name};
		$update->{hp}         = $char->{hp};
		$update->{hp_max}     = $char->{hp_max};
		$update->{sp}         = $char->{sp};
		$update->{sp_max}     = $char->{sp_max};
		$update->{lv}         = $char->{lv};
		$update->{xp}         = $char->{exp};
		$update->{xp_max}     = $char->{exp_max};
		$update->{jl}         = $char->{lv_job};
		$update->{jp}         = $char->{exp_job};
		$update->{jp_max}     = $char->{exp_job_max};
		$update->{zeny}       = $char->{zeny};
		$update->{status}     = $char->{statuses} && %{ $char->{statuses} } ? join ', ', keys %{ $char->{statuses} } : '';
		$update->{x}          = $pos->{x};
		$update->{y}          = $pos->{y};
		$update->{weight}     = $char->{weight};
		$update->{weight_max} = $char->{weight_max};
		if ( $char->{party} ) {
			$update->{party} = $char->{party}->{name} || '';
			$update->{admin} = $char->{party}->{users}->{$accountID}->{admin} ? 1 : 0;
		}
	}
	if ( $field ) {
		$update->{map} = $field->baseName;
	}
	if ( $net ) {
		$update->{online} = $net->getState == Network::IN_GAME ? 1 : 0;
	}
	$update;
}

sub partial_party_update {
	our $last_update ||= {};
	my $update  = full_party_update();
	my $partial = {};
	foreach ( keys %$update ) {
		next if $last_update->{$_} eq $update->{$_};
		$partial->{$_} = $update->{$_};
	}
	$last_update = $update;
	$partial;
}

1;
