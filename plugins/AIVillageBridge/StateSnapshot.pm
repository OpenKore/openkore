package AIVillageBridge::StateSnapshot;

use strict;
use warnings;

use Globals qw($char $field %players %monsters %npcs %items @ai_seq @ai_seq_args);
use Log qw(debug warning);
use Time::HiRes qw(time);

# Item type IDs for equippable gear (weapon/armor categories).
# From Actor/Item.pm: equippable => types 4,5,8,9,10,11,13,14,15,16,17,19,20
my %EQUIPPABLE_TYPES = map { $_ => 1 } (4, 5, 8, 9, 10, 11, 13, 14, 15, 16, 17, 19, 20);

# Maximum counts for nearby entities and notable items
use constant MAX_NEARBY_PLAYERS   => 20;
use constant MAX_NEARBY_MONSTERS  => 20;
use constant MAX_NOTABLE_ITEMS    => 10;
use constant MAX_AI_SEQ_ENTRIES   => 5;

# Minimum sell value for an item to be considered notable
use constant NOTABLE_VALUE_THRESHOLD => 100;

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

# take() -> hashref (always returns a hashref, empty on fatal error)
sub take {
    my ($self) = @_;

    my $state;
    eval {
        $state = $self->_collect();
    };
    if ($@) {
        warning("[AIVillageBridge::StateSnapshot] take() caught exception: $@\n");
        return {};
    }

    return $state // {};
}

sub _collect {
    my ($self) = @_;

    # Guard: if $char is not yet initialised, return empty state gracefully
    unless (defined $char) {
        debug("[AIVillageBridge::StateSnapshot] \$char is undef, returning empty state\n", 'aivillage');
        return {};
    }

    my $state = {
        hp         => $char->{hp}     || 0,
        hp_max     => $char->{hp_max} || 0,
        sp         => $char->{sp}     || 0,
        sp_max     => $char->{sp_max} || 0,
        map        => $self->_map_name(),
        pos        => $self->_char_pos(),
        base_level => $char->{lv}     || 0,
        job_level  => $char->{lv_job} || 0,
        job        => $self->_job_name(),
        zeny       => $char->{zeny}   || 0,
        ai_seq     => $self->_ai_seq_snapshot(),

        nearby_players   => $self->_nearby_players(),
        nearby_monsters  => $self->_nearby_monsters(),
        inventory_summary => $self->_inventory_summary(),
    };

    return $state;
}

# Returns the map name string
sub _map_name {
    my ($self) = @_;
    if (defined $field) {
        my $name;
        eval { $name = $field->name() };
        return $name if defined $name && !$@;
    }
    return 'unknown';
}

# Returns {x, y} for the character's position
sub _char_pos {
    my ($self) = @_;
    my $pos = $char->{pos_to} // $char->{pos};
    if (defined $pos && ref($pos) eq 'HASH') {
        return { x => ($pos->{x} || 0), y => ($pos->{y} || 0) };
    }
    return { x => 0, y => 0 };
}

# Returns the job name string
sub _job_name {
    my ($self) = @_;
    if (defined $char->{jobID}) {
        return $::jobs_lut{$char->{jobID}} || "Job $char->{jobID}";
    }
    return 'unknown';
}

# Returns first MAX_AI_SEQ_ENTRIES entries from @ai_seq
sub _ai_seq_snapshot {
    my ($self) = @_;
    my $end = $#ai_seq < (MAX_AI_SEQ_ENTRIES - 1) ? $#ai_seq : (MAX_AI_SEQ_ENTRIES - 1);
    return $end >= 0 ? [@ai_seq[0..$end]] : [];
}

# Returns array of {name, job, pos} for nearby players (max MAX_NEARBY_PLAYERS)
sub _nearby_players {
    my ($self) = @_;
    my @result;

    for my $id (keys %players) {
        last if @result >= MAX_NEARBY_PLAYERS;
        my $player = $players{$id};
        next unless defined $player;

        my $pos = $player->{pos_to} // $player->{pos};
        my $pos_entry = (defined $pos && ref($pos) eq 'HASH')
            ? { x => ($pos->{x} || 0), y => ($pos->{y} || 0) }
            : { x => 0, y => 0 };

        my $job_id  = $player->{jobID};
        my $job_str = (defined $job_id)
            ? ($::jobs_lut{$job_id} || "Job $job_id")
            : 'unknown';

        push @result, {
            name => ($player->{name} || 'unknown'),
            job  => $job_str,
            pos  => $pos_entry,
        };
    }

    return \@result;
}

# Returns array of {name, id, pos} for nearby monsters (max MAX_NEARBY_MONSTERS)
sub _nearby_monsters {
    my ($self) = @_;
    my @result;

    for my $id (keys %monsters) {
        last if @result >= MAX_NEARBY_MONSTERS;
        my $monster = $monsters{$id};
        next unless defined $monster;

        my $pos = $monster->{pos} // $monster->{pos_to};
        my $pos_entry = (defined $pos && ref($pos) eq 'HASH')
            ? { x => ($pos->{x} || 0), y => ($pos->{y} || 0) }
            : { x => 0, y => 0 };

        # Represent the binary ID as a hex string (matches OpenKore convention)
        my $hex_id = defined($monster->{ID}) ? unpack('H*', $monster->{ID}) : 'unknown';

        push @result, {
            name => ($monster->{name} || 'unknown'),
            id   => $hex_id,
            pos  => $pos_entry,
        };
    }

    return \@result;
}

# Returns inventory summary hash
sub _inventory_summary {
    my ($self) = @_;

    my $summary = {
        weight      => $char->{weight}     || 0,
        weight_max  => $char->{weight_max} || 0,
        item_count  => 0,
        notable_items => [],
    };

    # $char->inventory() returns an InventoryList object that supports @{} dereferencing
    my $inventory;
    eval { $inventory = $char->inventory() };
    return $summary if $@ || !defined $inventory;

    my @items;
    eval { @items = @{$inventory} };
    return $summary if $@;

    $summary->{item_count} = scalar @items;

    my @notable;
    for my $item (@items) {
        last if @notable >= MAX_NOTABLE_ITEMS;
        next unless defined $item;

        my $is_notable = 0;

        # Notable if it's equippable (weapon/armor type)
        if (defined $item->{type} && $EQUIPPABLE_TYPES{$item->{type}}) {
            $is_notable = 1;
        }

        # Notable if sell value exceeds threshold
        if (!$is_notable && defined $item->{sellValue} && $item->{sellValue} > NOTABLE_VALUE_THRESHOLD) {
            $is_notable = 1;
        }

        # Fallback: check buyValue if sellValue not set
        if (!$is_notable && defined $item->{buyValue} && $item->{buyValue} > NOTABLE_VALUE_THRESHOLD) {
            $is_notable = 1;
        }

        next unless $is_notable;

        my $item_name = $item->{name} || 'Unknown Item';
        my $amount    = $item->{amount} || 1;
        push @notable, "$item_name [$amount]";
    }

    $summary->{notable_items} = \@notable;
    return $summary;
}

1;
