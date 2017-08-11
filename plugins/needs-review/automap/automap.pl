package autoMapChange;
###############################################################################
#. Automatic Map Changer
#. By catcity
#. Contributions by allanon
#
#. CONFIGURATION
#. Add These Lines to config.txt:
#
#. autoMapChange [0|1]
#. autoMapChange_time [Number of Seconds]
#. autoMapChange_timeSeed [Number of Seconds]
#. autoMapChange_list [Comma Seperated List]
#
#. autoMapChange is a boolean. Set it to 0 to turn the plugin off. Set it to 1 to turn the plugin on.
#. autoMapChange_time is the number of seconds that you would like the plugin to wait until the next map change.
#. autoMapChange_timeSeed is a random seed. The plugin will take any amount of seconds between 0 and the number you set here and add it to the time.
#. autoMapChange_list is a comma seperated list of lockMaps that you would like the plugin to randomly draw from.
#
#. EXAMPLE CONFIG.TXT
#. autoMapChange 1
#. autoMapChange_time 3600
#. autoMapChange_timeSeed 3600
#. autoMapChange_list prt_fild01, prt_fild02, prt_fild03, prt_fild04
#
#. Between every 60 and 120 minutes this example config will randomly choose a map from the list and set it as your lockMap.
#
#. It is possible that it will select the same map from the list twice in a row.
#. It is possible that it will select the same map from the list three times in a row.
#. It is possible that it will... Well you get the message.
#. You can use this to give preference to certain maps that you want to spend more time on than others.
#. Add multiple instances of the same map to the list and it has a greater chance of being the selected map.
#
#. CONSOLE COMMANDS
#. Automatic Map Changer has two additional console commands.
#
#. Typing 'automap' into the console gives the time since last change and the time until the next change.
#. Typing 'automap change' into the console forces an immediate random change and resets the time.

use strict;

use Commands;
use Globals;
use Log qw( debug message warning error );
use Misc;
use Network;
use Plugins;
use Time::HiRes;
use Utils qw( timeOut parseArgs );

Plugins::register( 'autoMapChange', 'automatically change lockMap periodically', \&on_unload, \&on_unload );
my $hooks = Plugins::addHooks(    #
    [ configModify => \&on_configModify ],
    [ mainLoop_pre => \&on_mainLoop ],
    [ start3       => \&on_start ],
);

my $commands = Commands::register(
    [
        automap => [
            'Check Automap Timings',
            [ ''       => 'display time since last lockMap change and time of next change' ],
            [ change   => 'change lockmap now' ],
            [ validate => 'validate plugin configuration' ]
        ],
        \&on_cmdAutoMap
    ]
);

our $last_change ||= 0;
our $time_seed   ||= reset_time_seed();

sub on_unload {
    Plugins::delHooks( $hooks );
    Commands::unregister( $commands );
}

sub on_start {
    $time_seed ||= reset_time_seed();

    return if !$config{autoMapChange};

    validate();
}

sub on_configModify {
    my ( $undef, $args ) = @_;

    # Reset the time_seed if it is now greater than the maximum.
    reset_time_seed() if $args->{key} eq 'autoMapChange_timeSeed' && $time_seed >= $config{autoMapChange_timeSeed};

    # Validate the configuration if they just turned on the plugin.
    validate( 1 ) if $args->{key} eq 'autoMapChange' && $args->{val};
}

sub on_mainLoop {
    return if $net->getState != Network::IN_GAME;
    return if (AI::state != AI::AUTO);
    return if !$config{autoMapChange};

    my $timeout = $config{autoMapChange_time} + $time_seed;
    return if !timeOut( $last_change, $timeout );

    change_lock( "after $timeout seconds" );
}

sub on_cmdAutoMap {
    my ( undef, $args ) = @_;

    my ( $cmd, @args ) = parseArgs( $args );

    if ( !$cmd ) {
        my $time_since = int time - $last_change;
        my $time_until = int $config{autoMapChange_time} + $time_seed - $time_since;
        $time_until = 0 if $time_until < 0;
        message "[automap] It has been $time_since seconds since your last lockMap change.\n";
        message "[automap] Your next change will occur in $time_until seconds.\n";
        if ( !$config{autoMapChange} ) {
            warning "[automap] No changes will occur while plugin is disabled. To enable, set autoMapChange to 1.\n";
        }
    } elsif ( $cmd eq 'change' ) {
        change_lock( 'user requested change' );
    } elsif ( $cmd eq 'validate' ) {
        validate();
    } else {
        error "[automap] Unknown command.\n";
        Commands::helpIndent( 'automap', $Commands::customCommands{automap}{desc} );
    }
}

sub validate {
    my ( $turning_on ) = @_;

    my $validation = 0;

    message "[automap] Validating plugin configuration.\n";

    if ( !$turning_on && !$config{autoMapChange} ) {
        warning "[automap] Plugin is disabled. To enable, set autoMapChange to 1.\n";
    }

    if ( $config{autoMapChange_time} eq '' ) {
        configModify( autoMapChange_time => 3600, 1 );
        warning "[automap] Your autoMapChange_time config is undefined.\n";
        warning "[automap] Automatically setting autoMapChange_time to 3600 seconds [1 Hour].\n";
    } elsif ( $config{autoMapChange_time} <= 120 && $config{autoMapChange_time} != 0 ) {
        warning "[automap] Detected that your autoMapChange_time is set to a very low value.\n";
        warning "[automap] This can have a negative impact on your bot performance.\n";
    } elsif ( $config{autoMapChange_time} == 0 ) {
        warning "[automap] Detected that your autoMapChange_time has been set to 0.\n";
        warning "[automap] This will spam your bot with lockMap changes.\n";
        if ( $config{autoMapChange} ) {
            error "[automap] Disabling plugin.\n";
            configModify( autoMapChange => 0, 1 );
        }
    } elsif ( $config{autoMapChange_time} ) {
        message "[automap] Time config is set to $config{autoMapChange_time}.\n";
        $validation++;
    }

    if ( $config{autoMapChange_timeSeed} eq '' ) {
        configModify( autoMapChange_timeSeed => 0, 1 );
        warning "[automap] Detected that your autoMapChange_timeSeed is undefined.\n";
        warning "[automap] Automatically setting autoMapChange_timeSeed to 0.\n";
    } elsif ( $config{autoMapChange_timeSeed} ) {
        message "[automap] Seed config is declared.\n";
        $validation++;
    } elsif ( $config{autoMapChange_timeSeed} == 0 ) {
        message "[automap] Seed config is declared as 0.\n";
        message "[automap] This is fine, but please note that it is for precision time changes.\n";
        message "[automap] Your lockMap will change exactly on the time specified with no randomness or variation.\n";
        $validation++;
    }

    my $lock_list = lock_list();
    if ( !@$lock_list ) {
        configModify( autoMapChange => 0, 1 );
        warning "[automap] Detected that your autoMapChange_list is empty.\n";
        if ( $config{autoMapChange} ) {
            error "[automap] Disabling plugin.\n";
            configModify( autoMapChange => 0, 1 );
        }
    } else {
        message "[automap] List config is declared, containing " . @$lock_list . " maps.\n";
        $validation++;
    }

    if ( $validation < 3 ) {
        warning "[automap] Please review your configuration in config.txt.\n";
    } elsif ( $validation == 3 ) {
        message "[automap] Everything okay!\n";
    }
}

sub change_lock {
    my ( $reason ) = @_;

    my $locks    = lock_list();
    my $old_lock = $config{lockMap};
    my $new_lock = $locks->[ int rand @$locks ];
    configModify( lockMap => $new_lock, 1 );
    message "[automap] Changed lockMap from $old_lock to $new_lock [$reason].\n";

    $last_change = int time;

    # Randomize the time seed whenever we change lockMap.
    reset_time_seed();
}

sub reset_time_seed {
    $time_seed = rand $config{autoMapChange_timeSeed};
}

sub lock_list {
    [ split /[,\s]+/, $config{autoMapChange_list} ];
}

1;
