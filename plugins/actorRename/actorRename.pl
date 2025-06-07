# ====================
# actorRename v4.0
# ====================
# TÁ LISO
# ====================

package actorRename;

use strict;
use Plugins;
use Globals;
use Settings;
use Utils;
use Log qw(message debug error);
use JSON::Tiny qw(from_json to_json);

our %actor_name_cache;

Plugins::register('actorRename', 'Replaces monster and NPC names using actor_name.json', \&onUnload);

my $hooks = Plugins::addHooks(
    ['packet/actor_display', \&onActorDisplay, undef],
    ['packet/actor_exists', \&onActorDisplay, undef],
    ['packet/actor_spawned', \&onActorDisplay, undef],
    ['packet/actor_moved',      \&onActorDisplay, undef],
    ['packet/actor_status_active', \&onActorDisplay, undef],
    ['packet/actor_action',     \&onActorDisplay, undef],
    ['packet/actor_info',       \&onActorDisplay, undef],
    ['packet/actor_name_request', \&onActorDisplay, undef],
);

# Plugin cleanup
sub onUnload {
    Plugins::delHooks($hooks);
    %actor_name_cache = ();
}

# Load actor_name.json
sub loadactorRenameJSON {
    message "Loading actor_name.json...\n", "actorRename";
    %actor_name_cache = ();

    my $file = "$Plugins::current_plugin_folder/actor_name.json";
    unless (-r $file) {
        error("[actorRename] Can't read $file\n");
        return;
    }

    open my $fh, '<', $file or do {
        error("[actorRename] Failed to open $file: $!\n");
        return;
    };

    local $/; # Enable slurp mode
    my $json_text = <$fh>;
    close $fh;

    my $data = eval { from_json($json_text) };  # ← FIXED
    if ($@ || ref($data) ne 'HASH') {
        error("[actorRename] Failed to parse JSON: $@\n");
        return;
    }

    %actor_name_cache = %{$data};
    my $count = scalar(keys %actor_name_cache);
    message "[actorRename] Loaded $count actor names from actor_name.json\n", "actorRename";
}


loadactorRenameJSON();    # Load actor_name.json into Memory

# Main renaming logic
sub onActorDisplay {
    my ($self, $args) = @_;

    my $ID = unpack("V1", $args->{ID});
    my $useActorList = (substr($Settings::VERSION, 4) >= 1);

    my $actor;
    my $type;

    if ($args->{type} >= 1000) {
        # Monster or pet/homunculus
        return if ($args->{hair_style} == 0x64 || $args->{pet});  # Skip pets/homunculi
        $type = 'monster';
        $actor = $useActorList ? $Globals::monstersList->getByID($args->{ID}) : $Globals::monsters{$args->{ID}};

    } elsif ($args->{type} < 1000 && $args->{type} != 45 && !$jobs_lut{$args->{type}}) {
        # NPC
        $type = 'npc';
        $actor = $useActorList ? $Globals::npcsList->getByID($args->{ID}) : $Globals::npcs{$args->{ID}};
    } else {
        return;  # Not monster or NPC
    }

    return unless $actor;

    # Lets process the actor, but lets print the name of the actor before we change it
    debug "[actorRename] Processing actor of type: $type with ID: $ID\n", "actorRename";
    
    my $original_name = $actor->{name} || '(no name)';

    # Only rename if the name starts with \x1C
    if (substr($original_name, 0, 1) eq "\x1C") {
        debug "[actorRename] Should rename: \"$original_name\"\n", "actorRename";
        my $clean_name = $original_name;
        $clean_name =~ s/\x1C//g;

        if (exists $actor_name_cache{$clean_name}) {
            # lets rename
            $actor->{name} = $actor_name_cache{$clean_name};
            $actor->{name_given} = $actor_name_cache{$clean_name};
            $actor->setName($actor_name_cache{$clean_name});  # Update the actor's name in the list
            debug "[actorRename] Renamed actor [$ID] from \"$original_name\" to \"$actor->{name}\"\n", "actorRename";
        } else {
            debug "[actorRename] No match found for \"$clean_name\" in actor_name_cache\n", "actorRename";
        }
    } else {
        debug "[actorRename] Skipped \"$original_name\" — doesn't start with \\x1C\n", "actorRename";
    }


}



1;
