# This package depends on two entries in control/timeouts.txt.
#   * reconnect_backoff 30,60,180
#   * reconnect_random 20
# reconnect_backoff is a comma-separated list of timeouts which will be used in order when we get repeatedly disconnected from the server.
# reconnect_random is the maximum random amount of time to be added to all reconnect times. This only applies if reconnect_backoff is defined. Default is zero.
#
package OpenKore::Plugins::reconnect;

use strict;

use Globals qw( %config %masterServers %timeout );
use Log qw( &message );
use Plugins;
use Utils qw( &min );
use Translation qw( &TF );

our $default;
our $counter = 0;

Plugins::register( 'reconnect', 'v1.0', \&unload );

my $hooks = Plugins::addHooks(    #
	[ 'Network::connectTo' => \&trying_to_connect ],
	[ 'in_game'            => \&connected ],
);

sub unload {
	Plugins::delHooks( $hooks );
}

sub trying_to_connect {
	my ( undef, $params ) = @_;
	return if($config{XKore} eq 1 || $config{XKore} eq 3);
	# Only trigger if we're connecting to the login server.
	next if $masterServers{ $config{master} }->{ip} ne $params->{host};
	next if $masterServers{ $config{master} }->{port} ne $params->{port};

    my $timeout = timeout();

	$timeout{reconnect} = { timeout => timeout() };
	$counter++;

	if ( $counter > 1 ) {
		message TF( "[reconnect] Login retry number %d, setting reconnect timeout to %d seconds.\n", $counter, $timeout{reconnect}->{timeout} ), 'success';
	}
}

sub connected {
	return if($config{XKore} eq 1 || $config{XKore} eq 3);
	$counter = 0;
	$timeout{reconnect} = { timeout => timeout() };
}

# Return the current timeout if there is one.
sub timeout {
	my @timeouts = split /\s*,\s*/, $timeout{reconnect_backoff}->{timeout} || '';
	return $timeout{reconnect}->{timeout} if !@timeouts;
	$timeouts[ min( $counter, $#timeouts ) ] + int rand( $timeout{reconnect_random}->{timeout} || 0 );
}

1;
