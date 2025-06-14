# ====================
# mobName v1.0
# ====================
# Replaces monster names based on mob_db.txt
# Author: Overman!?
# ====================

package mobName;

use strict;
use Plugins;
use Globals;
use Settings;
use Utils;
use Log qw(message debug error);

our %mob_db_cache;

Plugins::register('mobName', 'Replaces monster names using mob_db.txt', \&onUnload);

my $hooks = Plugins::addHooks(
    ['packet/actor_display', \&onActorDisplay, undef],
    ['packet/actor_exists', \&onActorDisplay, undef],
    ['packet/actor_spawned', \&onActorDisplay, undef],
);

# Plugin cleanup
sub onUnload {
    Plugins::delHooks($hooks);
    %mob_db_cache = ();
}

# Load mob_db.txt
sub loadMonDB2 {
	message "Loading mob_db.txt...\n", "mobName";
    %mob_db_cache = ();

    my $file = Settings::getTableFilename('mob_db.txt');
    unless (-r $file) {
        error("[mobName] Can't read $file\n");
        return;
    }

    open my $fh, "<", $file or do {
        error("[mobName] Failed to open $file: $!\n");
        return;
    };

    my $i = 0;
    while (<$fh>) {
        next unless m/^(\d+),/; 
        my @fields = split /,/;
        my ($ID, $iROName) = ($fields[0], $fields[1]);
        $mob_db_cache{$ID} = $iROName;
        $i++;
    }
    close $fh;

    message "[mobName] Loaded $i monsters from mob_db.txt\n", "mobName";
}

sub loadMonDB {
    message "Loading mob_db.txt...\n", "mobName";
    %mob_db_cache = ();

    my $file = "$Plugins::current_plugin_folder/mob_db.txt";
    unless (-r $file) {
        error("[mobName] Can't read $file\n");
        return;
    }

    open my $fh, "<", $file or do {
        error("[mobName] Failed to open $file: $!\n");
        return;
    };

    my $i = 0;
    while (<$fh>) {
        next unless m/^(\d+),/; 
        my @fields = split /,/;
        my ($ID, $iROName) = ($fields[0], $fields[1]);
        $mob_db_cache{$ID} = $iROName;
        $i++;
    }
    close $fh;

    message "[mobName] Loaded $i monsters from mob_db.txt\n", "mobName";
}

loadMonDB();    # Load MonsterDB into Memory

# Main renaming logic
sub onActorDisplay {
    my (undef, $args) = @_;
    my $useActorList = (substr($Settings::VERSION, 4) >= 1);
    my $actor = ($useActorList)
        ? $Globals::monstersList->getByID($args->{ID})
        : $Globals::monsters{$args->{ID}};

    return unless $actor;

    if (exists $mob_db_cache{$args->{type}}) {
        my $cleanName = $mob_db_cache{$args->{type}};
        $cleanName =~ s/[\r\n]//g;  # Remove quebras de linha
        $cleanName =~ s/^\s+|\s+$//g;  # Remove espaços no início e fim
        $actor->{name} = $cleanName;
        $actor->{name_given} = $cleanName;
        debug "[mobName] Renamed monster [$actor->{ID}] to \"$actor->{name}\"", "mobName";
    } else {
		# change name to id
		my $cleanName = $args->{type};
		$cleanName =~ s/[\r\n]//g;  # Remove quebras de linha
		$cleanName =~ s/^\s+|\s+$//g;  # Remove espaços no início e fim
		$actor->{name} = $cleanName;
		$actor->{name_given} = $cleanName;
		debug "[mobName] Renamed monster [$actor->{ID}] to \"$actor->{name}\"", "mobName";
	}
}

1;
