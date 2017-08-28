package OpenKore::Plugins::BusCommand;
###############################################################################
# Plugin to allow console commands to be sent via bus.
# Depends on the bus_hook plugin.

use strict;

use Globals qw( $char %config $field $net );
use Utils qw( &existsInList );

our $name = 'bus_command';

Plugins::register( $name, "$name plugin", \&Unload, \&Unload );

my $hooks = Plugins::addHooks(    #
	[ 'bus/recv/RUN_COMMAND' => \&onBusRecvRunCommand ],
);

sub Unload {
	Plugins::delHooks( $hooks );
}

sub onBusRecvRunCommand {
	my ( undef, $args ) = @_;

    my $allow = 1;
	$allow = 0 if $args->{group} && !check_group( $args->{group} );
	$allow = 0 if $args->{party} && !( $char && $char->{party} && $char->{party}->{name} eq $args->{party} );
	if ( !$allow ) {
		Log::debug( "[$name] Received and ignored command: $args->{command}\n", $name );
		return;
	}

	Log::debug( "[$name] Received command: $args->{command}\n", $name );
	Commands::run( $args->{command} );
}

sub check_group {
	my ( $to ) = @_;

	# Support comma-separated groups, like ONLINE,LEADERS. All checks must match.
	return !grep { !check_group( $_ ) } split /\s*,\s*/, $to if index( $to, ',' ) > -1;

	return 1 if $to eq 'ALL';
	return 1 if $to eq 'AI=auto' && AI::state == AI::AUTO;
	return 1 if $to eq 'AI=manual' && AI::state == AI::MANUAL;
	return 1 if $to eq 'AI=off' && AI::state == AI::OFF;
	return 1 if $to eq 'ONLINE' && $net->getState == Network::IN_GAME;
	return 1 if $to eq 'OFFLINE' && $net->getState != Network::IN_GAME;
	return 1 if $to eq 'LEADERS' && !$config{follow};
	return 1 if $to eq 'FOLLOWERS' && $config{follow} && $config{followTarget};
	return 1 if existsInList( $config{bus_command_groups}, $to );
	return 1 if $to =~ /^MAP=(.*)$/o && $field && $1 eq $field->baseName;
	return 1 if $to =~ /^(\w+)=(.*)$/o && $config{$1} eq $2;

	return;
}

1;
