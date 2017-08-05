package OpenKore::Plugin::Map;
###############################################################################
# Plugin to display a map of the current location.
#
# control/config.txt
# map_showWater 1              - show water tiles with blue background
# map_showBlockedShopTiles 1   - show tiles within 3 tiles of an NPC with green background
# map_showGroundEffects 1      - show ground effects with red background

use strict;

use Plugins;
use Globals;
use Utils;
use Misc;
use Log qw(message warning error);
use AI;
use Time::HiRes;
use Task::UseSkill;
use Skill;

Plugins::register( 'map', 'map', \&Unload, \&Unload );

our $mode = 'auto';
our $fw;
our $fh;
our $x1;
our $x2;
our $y1;
our $y2;
our $grid;
our $color_grid;

my $hooks = Plugins::addHooks(
    [ 'curses/updateObjects' => \&onUpdateObjects ],
);

my $chooks = Commands::register(
	[ 'map', "Map plugin", \&onMapCommand ],
);

sub Unload {
    Plugins::delHooks($hooks);
    message "map unloaded.\n";
}

sub onUpdateObjects {
    onMapCommand( 'map', int( ( $interface->{winObjectsWidth} - 1 ) / 2 ) );
}

sub onMapCommand {
    my ( @params ) = split /\s+/, $_[1];

    if ( !@params ) {
        Log::message("map: Usage\n");
        Log::message("  map [width] [height]   - display map (default size: 30 15)\n");
        Log::message("  map set x y            - set a map cell\n");
        return;
    }

    if ( !$char || !$char->{pos} ) {
        Log::message( "map: No character yet!\n" );
        return;
    }

    my $gw = $params[0] || 30;
    my $gh = $params[1] || 15;

    if ( $interface->{winObjects} ) {
        my $map = drawcolormap( $gw, $gh );
        my $line = $interface->{winObjectsHeight} - @$map;
        $interface->printw( $interface->{winObjects}, $line++, 0, $_->{pic}, @{ $_->{mapchars} } ) foreach @$map;
        Curses::noutrefresh( $interface->{winObjects} );
    } else {
        my $lines = drawmap( $gw, $gh );
        Log::message( "$_\n" ) foreach @$lines;
    }
}

sub drawmap {
    return if !$field;
    my $map = drawcolormap( @_ );
    return [ map { join '', @{ $_->{mapchars} } } @$map ];
}

sub drawcolormap {
    my ( $gw, $gh ) = @_;

    my $pos = calcPosition( $char );

    $fw = $field->width;
    $fh = $field->height;
    $x1 = $pos->{x} - $gw;
    $x2 = $pos->{x} + $gw;
    $y1 = $pos->{y} - $gh;
    $y2 = $pos->{y} + $gh;

    our $base_key ||= '';
    our $base_grid;
    our $base_color_grid;

    my $new_key = join ':', $pos->{x}, $pos->{y}, $gw, $gh;

    if ( $base_key ne $new_key ) {

        $grid       = [];
        $color_grid = [];

        # Add walkability.
        foreach my $y ( reverse $y1 .. $y2 ) {
            push @$grid, my $row = [];
            push @$color_grid, [];

            if ( $y < 0 || $y >= $fh ) {
                @$row = ( '~' ) x 2 * $gw + 1;
                next;
            }

            foreach my $x ( $x1 .. $x2 ) {
                if ( $field->isWalkable( $x, $y ) ) {
                    push @$row, ' ';
                    add_pos( 'bg_blue', { x => $x, y => $y } ) if $config{map_showWater} && $field->getBlock( $x, $y ) == Field::WALKABLE_WATER;
                } else {
                    push @$row, '#';
                }
            }
        }

        # Add tiles which are to close to npcs to be able to open a shop.
        if ( $config{map_showBlockedShopTiles} ) {
            foreach my $npc ( @{ $npcsList->getItems } ) {
                foreach my $y ( -3 .. 3 ) {
                    foreach my $x ( -3 .. 3 ) {
                        add_pos( 'bg_green', { x => $npc->{pos}->{x} + $x, y => $npc->{pos}->{y} + $y } );
                    }
                }
            }
        }

        $base_key        = $new_key;
        $base_grid       = $grid;
        $base_color_grid = $color_grid;
    }

    # Clone the grid.
    $grid       = [ map { [ @$_ ] } @$base_grid];
    $color_grid = [ map { [ @$_ ] } @$base_color_grid];

    # Add ground effects. Background-only.
    if ( $config{map_showGroundEffects} ) {
        foreach ( @spellsID ) {
            next if !$_ || !$spells{$_};
            add_pos( 'bg_red', $spells{$_}{pos} );
        }
    }

    # Add follow preference.
    if ( $config{follow} && $config{followTarget} ) {
        my ( $master ) = grep { $_->name eq $config{followTarget} && !$_->{dead} } @{ $playersList->getItems };
        if ( $master ) {
            my $pos = calcPosition( $master );
            my $poss = [];
            my $min = ($config{followDistanceMin} - 0.5) ** 2;
            my $max = ($config{followDistanceMax} + 0.5) ** 2;
            foreach my $dy ( -$config{followDistanceMax} .. $config{followDistanceMax} ) {
                foreach my $dx ( -$config{followDistanceMax} .. $config{followDistanceMax} ) {
                    next if $dx * $dx + $dy * $dy < $min;
                    next if $dx * $dx + $dy * $dy > $max;
                    my $p = { x => $pos->{x} + $dx, y => $pos->{y} + $dy };
                    push @$poss, $p if $field->isWalkable( $p->{x}, $p->{y} );
                }
            }
            add_pos( '.', $_ ) foreach @$poss;
            add_pos( 'T', $master->{pos_to} );

            foreach my $p ( @$poss ) {
                $p->{threat} = ( abs( $char->{pos_to}->{x} - $p->{x} ) + abs( $char->{pos_to}->{y} - $p->{y} ) ) / 10;
                foreach my $monster ( @{ $monstersList->getItems } ) {
                    my $pm = $monster->{pos_to} || $monster->{pos};
                    $p->{threat} += 20 - ( abs( $pm->{x} - $p->{x} ) + abs( $pm->{y} - $p->{y} ) );
                }
            }
            my ( $safest ) = sort { $a->{threat} <=> $b->{threat} } @$poss;
            add_pos( '*', $safest );
        }
    }

    # Add current route (if any).
    my $route_task;
    foreach ( 0 .. 10 ) {
        if ( AI::action( $_ ) eq '' ) {
            last;
        } elsif ( AI::action( $_ ) eq 'route' ) {
            $route_task = AI::args( $_ );
            last;
        }
    }
    $route_task = $route_task->{ST_subtask} if $route_task && $route_task->isa( 'Task::MapRoute' );
    if ( $route_task && $route_task->{solution} ) {
        add_pos( '.', $_ ) foreach @{ $route_task->{solution} };
    }

    # Add player.
    add_pos( 't', $char->{pos_to} );
    add_pos( '@', $pos );

    # Add portals.
    for ( my $i = 0 ; $i < @portalsID ; $i++ ) {
        next if $portalsID[$i] eq "";
        add_pos( 'o', $portals{ $portalsID[$i] }->{pos} );
    }

    # Add NPCs.
	foreach (@{$npcsList->getItems}) {
        add_pos( 'n',  $_->{pos} );
    }

    # Add slaves.
    foreach my $slave ( @{ $slavesList->getItems } ) {
        add_pos( 's', calcPosition( $slave ) );
    }

    # Add players.
    foreach my $player ( @{ $playersList->getItems } ) {
        add_pos( 'p', calcPosition( $player ) );
    }

    # Add vendors.
    foreach my $id ( @venderListsID ) {
        next if !$id;
        my $player = Actor::get( $id );
        next if !$player || !$player->{pos_to};

        # Vendors don't move, so we don't need to calculate their position.
        add_pos( '$', $player->{pos_to} );
    }

    # Add chats.
    foreach my $id ( @chatRoomsID ) {
        next if !$id;
        my $room = $chatRooms{$id};
        next if !$room;
        my $player = Actor::get( $room->{ownerID} );
        next if !$player || !$player->{pos_to};

        # Chat rooms don't move, so we don't need to calculate their position.
        add_pos( 'C', $player->{pos_to} );
    }

    # Add monsters.
    foreach my $monster ( @{ $monstersList->getItems } ) {
        if ( $config{monster_filter} ) {
            next if $monster->{name_given} !~ /$config{monster_filter}/igs;
            add_pos( 'M', calcPosition( $monster ), 'red' );
        } else {
            add_pos( ':', $monster->{pos_to} );
            add_pos( 'm', calcPosition( $monster ) );
        }
    }

    # Render map into a picture (containing color information) and mapchars (containing the ASCII representation).
    my $lines = [];
    foreach my $i ( 0 .. $#$grid ) {
        my $row  = $grid->[$i];
        my $crow = $color_grid->[$i];
        my $line = join '', @$row;
        if ( !@$crow ) {
            push @$lines, { pic => '{normal}@*', mapchars => [$line] };
            next;
        }
        my $color    = $crow->[0] || 'normal';
        my $mapchars = [];
        my $pic      = "{$color}@*";
        my $i0       = 0;
        my $i1       = 0;
        foreach ( @$crow ) {
            $_ ||= 'normal';
            if ( $color ne $_ ) {
                push @$mapchars, substr $line, $i0, $i1 - $i0 if $i1;

                $pic .= "{$_}@*";
                $color = $_;
                $i0    = $i1;
            }
            $i1++;
        }
        push @$mapchars, substr $line, $i0, $i1 - $i0;
        if ( $i1 != length $line ) {
            $pic .= '{normal}@*';
            push @$mapchars, substr $line, $i1, length( $line ) - $i1;
        }
        push @$lines, { pic => $pic, mapchars => $mapchars };
    }

    return $lines;
}

sub add_pos {
    my ( $ch, $pos, $color ) = @_;
    return if $pos->{x} < $x1;
    return if $pos->{x} > $x2;
    return if $pos->{y} < $y1;
    return if $pos->{y} > $y2;

    # Don't touch wall tiles once they're defined.
    return if $grid->[ $y2 - $pos->{y} ]->[ $pos->{x} - $x1 ] eq '#';

    ( $ch, $color ) = ( undef, $ch ) if $ch && $ch =~ /^bg_/o;

    $grid->[ $y2 - $pos->{y} ]->[ $pos->{x} - $x1 ] = $ch if defined $ch && length $ch < 2;
    $color_grid->[ $y2 - $pos->{y} ]->[ $pos->{x} - $x1 ] = $color if $color;
}

1;
