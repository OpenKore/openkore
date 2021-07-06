package OpenKore::Plugins::BusHook;
###############################################################################
# Plugin to connect to a Bus server and proxy Bus messages through hooks.

use strict;

use Bus::Client;
use Log qw( &debug );

our $name = 'bus_hook';
our $bus;

Plugins::register( $name, "$name plugin", \&Unload, \&Unload );

my $hooks = Plugins::addHooks(    #
	[ 'start3'       => \&onStart ],
	[ 'mainLoop_pre' => \&onMainLoopPre ],
	[ 'bus/send'     => \&onBusSend ],
);

sub Unload {
	$bus = undef;
	Plugins::delHooks( $hooks );
}

sub onStart {
	return if $bus;

	$bus = $Globals::bus || Bus::Client->new( userAgent => "$name plugin" );
	$bus->onConnected->add( undef, \&onConnected );
	$bus->onMessageReceived->add( undef, \&onMessageReceived );
}

sub onMainLoopPre {
	onStart() if !$bus;
	$bus->iterate;
}

sub onBusSend {
	my ( undef, $msg ) = @_;
	Plugins::callHook( 'bus/sent' => $msg );
	debug "[$name] >> sent $msg->{messageID}\n", $name;
	$bus->send( $msg->{messageID}, $msg->{args} );
}

# Ask for a list of other clients.
sub onConnected {
	debug "[$name] >> connected\n", $name;
	onBusSend( undef, { messageID => 'LIST_CLIENTS2' } );
	Plugins::callHook( 'bus/connect' );
}

sub onMessageReceived {
	my ( undef, undef, $msg ) = @_;

	my $mid  = $msg->{messageID};
	my $args = $msg->{args};
	debug "[$name] << received $mid\n", $name;
	Plugins::callHook( 'bus/recv'      => $msg );
	Plugins::callHook( "bus/recv/$mid" => $args );
}

1;
