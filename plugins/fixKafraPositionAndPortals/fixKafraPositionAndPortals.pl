# fixKafraPositionAndPortals
# Author: Henrybk
#
# Merges fixKafraPosition and fixKafraPortals.
# - Keeps the storage Kafra guessing behavior.
# - Keeps the teleport Kafra guessing behavior.
# - Updates outdated Kafra/Zonda portal entries in portals.txt.
# - When a teleport retry had to guess the real NPC position, it rewrites the
#   old stale portal block using the guessed live NPC position.
# - Uses TalkNPC_reset and npc_teleport_error to restart the live route with
#   refreshed portal data, and asks MapRoute to recalculate after a wrong NPC
#   step instead of retrying the stale live step.
#
package fixKafraPositionAndPortals;

use strict;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

use AI;
use Plugins;
use Settings;
use Globals;
use Utils;
use Misc;
use Log qw(message warning);
use Translation;

use constant {
	PLUGIN_NAME => 'fixKafraPositionAndPortals',
	GUESS_TTL   => 180,
};

Plugins::register(PLUGIN_NAME, 'fixes Kafra positions and portal data', \&Unload, \&Unload);

my $hooks = Plugins::addHooks(
	['npc_teleport_missing', \&onmissTele, undef],
	['npc_teleport_error', \&onTeleportError, undef],
	['TalkNPC_npc_missing', \&onmissStorage, undef],
	['npc_talk_responses', \&npc_responses, undef],
);

my %teleport_guess_by_actual_portal;
my %teleport_refresh_by_portal;

my $mapTable = {
	'Al De Baran' => 'aldebaran',
	#'Alberta' => '',
	'Alberta Marina' => 'alberta',
	'Byalan Island' => 'izlu2dun',
	#'Comodo' => '',
	'Dead Pit' => 'mjolnir_02',
	#'Einbroch' => '',
	#'Geffen' => '',
	#'Izlude' => '',
	'Izlude Marina' => 'izlude',
	'Juno' => 'yuno',
	#'Lighthalzen' => '',
	#'Manuk' => '',
	'Midgard Allied Forces Post' => 'mid_camp',
	'Mjolnir\'s Dead Pit' => 'mjolnir_02',
	'Morroc' => 'morocc',
	'Orc Dungeon' => 'gef_fild10',
	'Orc Village' => 'gef_fild10',
	#'Payon' => '',
	'Pharos' => 'cmd_fild07',
	'Pharos Lighthouse' => 'cmd_fild07',
	'Comodo Pharos Beacon' => 'cmd_fild07',
	#'Prontera' => '',
	#'Rachel' => '',
	#'Splendide' => '',
	'Sunken Ship' => 'alb2trea',
	'Turtle island' => 'tur_dun01',
	#'Umbala' => '',
	#'Veins' => '',
};

sub Unload {
	Plugins::delHooks($hooks);
	%teleport_guess_by_actual_portal = ();
	%teleport_refresh_by_portal = ();
	message sprintf("[%s] Plugin unloading or reloading.\n", PLUGIN_NAME), PLUGIN_NAME;
}

sub cleanup_old_state {
	my $now = time;
	foreach my $portalID (keys %teleport_guess_by_actual_portal) {
		delete $teleport_guess_by_actual_portal{$portalID}
			if !$teleport_guess_by_actual_portal{$portalID}{time}
			|| $now - $teleport_guess_by_actual_portal{$portalID}{time} > GUESS_TTL;
	}
	foreach my $portalID (keys %teleport_refresh_by_portal) {
		delete $teleport_refresh_by_portal{$portalID}
			if !$teleport_refresh_by_portal{$portalID}{time}
			|| $now - $teleport_refresh_by_portal{$portalID}{time} > GUESS_TTL;
	}
}

sub find_closest_kafra_employee {
	my $closest;
	my $closest_dist;
	my $closest_x;
	my $closest_y;

	foreach my $actor (@{$npcsList->getItems()}) {
		my $pos = ($actor->isa('Actor::NPC')) ? $actor->{pos} : $actor->{pos_to};
		next if ($actor->{statuses}->{EFFECTSTATE_BURROW});
		next if ($config{avoidHiddenActors} && ($actor->{type} == 111 || $actor->{type} == 139 || $actor->{type} == 2337));
		next unless defined $actor->{name};
		next unless $actor->{name} =~ /^Kafra Employee$/;
		my $dist = blockDistance($char->{pos_to}, $pos);
		next if defined $closest && $closest_dist < $dist;
		$closest = $actor;
		$closest_dist = $dist;
		$closest_x = $pos->{x};
		$closest_y = $pos->{y};
	}

	return ($closest, $closest_x, $closest_y);
}

sub store_teleport_guess {
	my ($args, $closest_x, $closest_y) = @_;

	return unless $field;

	my $map = $field->baseName;
	my $original_portalID = "$map $args->{x} $args->{y}";
	my $actual_portalID = "$map $closest_x $closest_y";

	$teleport_guess_by_actual_portal{$actual_portalID} = {
		time => time,
		portal => $args->{portal},
		replace_portalID => $original_portalID,
		actual_portalID => $actual_portalID,
	};
}

sub onmissStorage {
	my ($self, $args) = @_;

	return if ($args->{plugin_retry} > 0);
	return unless (AI::action() eq 'NPC' && AI::inQueue('storageAuto') && AI::args()->{'is_storageAuto'} == 1);

	my ($closest, $closest_x, $closest_y) = find_closest_kafra_employee();

	if (defined $closest) {
		warning TF("[%s] [storage] Guessing our desired kafra to be %s (%s,%s).\n", PLUGIN_NAME, $closest, $closest_x, $closest_y), 'system';
		$args->{x} = $closest_x;
		$args->{y} = $closest_y;
		$args->{return} = 1;
	}
}

sub onmissTele {
	my ($self, $args) = @_;

	return if ($args->{plugin_retry} > 0);

	my ($from, $to) = split(/=/, $args->{portal});
	return unless ($portals_lut{$from}{dest}{$to}{allow_ticket});

	my ($closest, $closest_x, $closest_y) = find_closest_kafra_employee();

	if (defined $closest) {
		store_teleport_guess($args, $closest_x, $closest_y);
		warning TF("[%s] [teleport] Guessing our desired kafra to be %s (%s,%s).\n", PLUGIN_NAME, $closest, $closest_x, $closest_y), 'system';
		$args->{x} = $closest_x;
		$args->{y} = $closest_y;
		$args->{return} = 1;
	}
}

sub normalize_menu_destination_name {
	my ($name) = @_;
	return '' unless defined $name;

	my $normalized = lc($name);
	$normalized =~ s/([a-z0-9])(?:`|'|\x{2019})s\b/$1/g;
	$normalized =~ s/[`'".]//g;
	$normalized =~ s/[^a-z0-9]+/ /g;
	$normalized =~ s/\s+/ /g;
	$normalized =~ s/^\s+|\s+$//g;
	return $normalized;
}

sub getFixedName {
	my ($name) = @_;

	my $lcName = lc($name);

	if (exists $maps_lut{$lcName . '.rsw'}) {
		return $lcName;
	} elsif (exists $mapTable->{$name}) {
		return $mapTable->{$name};
	}

	my $normalized_name = normalize_menu_destination_name($name);
	foreach my $alias (keys %{$mapTable}) {
		next unless normalize_menu_destination_name($alias) eq $normalized_name;
		return $mapTable->{$alias};
	}

	return undef;
}

sub build_expected_response {
	my ($destination) = @_;
	my $destination_pattern = quotemeta($destination);
	return "r~/(Warp|Teleport)/i r~/$destination_pattern/i";
}

sub parse_active_portal_line {
	my ($line) = @_;
	return if (!defined $line || $line =~ /^\s*#/);

	my $work = $line;
	$work =~ s/\cM|\cJ//g;
	$work =~ s/(.*?)(?:[\s\t]+#.*)?$/$1/;
	$work =~ s/\s+/ /g;
	$work =~ s/^\s+|\s+$//g;

	return if ($work eq '');

	if ($work =~ /^([\w|@|-]+)\s(\d{1,3})\s(\d{1,3})\s([\w|@|-]+)\s(\d{1,3})\s(\d{1,3})(?:\s+(.*))?$/) {
		return {
			normalized => $work,
			portalID   => "$1 $2 $3",
			destID     => "$4 $5 $6",
			destMap    => $4,
			misc       => defined $7 ? $7 : '',
		};
	}

	return;
}

sub find_dest_id_for_map {
	my ($portalIDs, $map) = @_;

	my %seen_portal;
	my @portalIDs = grep { defined $_ && !$seen_portal{$_}++ } @{ $portalIDs || [] };

	foreach my $portalID (@portalIDs) {
		if (exists $portals_lut{$portalID} && exists $portals_lut{$portalID}{dest}) {
			my @existing = sort grep { $portals_lut{$portalID}{dest}{$_}{map} eq $map } keys %{$portals_lut{$portalID}{dest}};
			return $existing[0] if @existing;
		}
	}

	my %dest_counts;
	foreach my $source_portal (keys %portals_lut) {
		next unless exists $portals_lut{$source_portal}{dest};
		foreach my $destID (keys %{$portals_lut{$source_portal}{dest}}) {
			my $dest = $portals_lut{$source_portal}{dest}{$destID};
			next unless $dest->{map} eq $map;
			$dest_counts{$destID}++;
		}
	}

	if (%dest_counts) {
		return (sort { $dest_counts{$b} <=> $dest_counts{$a} || $a cmp $b } keys %dest_counts)[0];
	}

	foreach my $location (sort keys %npcs_lut) {
		my ($npc_map, $x, $y, $name) = split /\s+/, $location . ' ' . $npcs_lut{$location}, 4;
		next unless defined $npc_map && $npc_map eq $map;
		next unless defined $name && $name =~ /(Kafra|Zonda)/i;
		return "$map $x $y";
	}

	return;
}

sub find_portal_dest_id_for_target_map {
	my ($portalID, $target_map, $preferred_destID) = @_;

	return unless $portalID;
	return unless exists $portals_lut{$portalID};
	return unless exists $portals_lut{$portalID}{dest};

	if (defined $preferred_destID && exists $portals_lut{$portalID}{dest}{$preferred_destID}) {
		return $preferred_destID;
	}

	return unless defined $target_map;

	my @matches = sort grep {
		$portals_lut{$portalID}{dest}{$_}{map} eq $target_map
	} keys %{$portals_lut{$portalID}{dest}};

	return $matches[0] if @matches;
	return;
}

sub store_portal_refresh {
	my ($replace_portalID, $actual_portalID, $old_dest_map_by_id, $desired_dest_by_map) = @_;

	return unless $replace_portalID;
	return unless $actual_portalID;

	$teleport_refresh_by_portal{$replace_portalID} = {
		time                => time,
		actual_portalID     => $actual_portalID,
		old_dest_map_by_id  => $old_dest_map_by_id || {},
		desired_dest_by_map => $desired_dest_by_map || {},
	};
}

sub onTeleportError {
	my ($hook, $args) = @_;

	cleanup_old_state();

	return unless $args->{portal};

	my ($replace_portalID, $preferred_destID) = split(/=/, $args->{portal}, 2);
	return unless $replace_portalID;

	my $refresh = $teleport_refresh_by_portal{$replace_portalID};
	return unless $refresh;

	my $actual_portalID = $refresh->{actual_portalID};
	return unless $actual_portalID;

	my $target_map = $refresh->{old_dest_map_by_id}{$preferred_destID};
	if (!defined $target_map && defined $preferred_destID && exists $portals_lut{$actual_portalID}{dest}{$preferred_destID}) {
		$target_map = $portals_lut{$actual_portalID}{dest}{$preferred_destID}{map};
	}

	my $updated_dest;
	if (defined $target_map && exists $portals_lut{$actual_portalID} && exists $portals_lut{$actual_portalID}{dest}) {
		$updated_dest = $refresh->{desired_dest_by_map}{$target_map};
		if (!defined $updated_dest) {
			my $new_destID = find_portal_dest_id_for_target_map($actual_portalID, $target_map, $preferred_destID);
			if (defined $new_destID && exists $portals_lut{$actual_portalID}{dest}{$new_destID}) {
				$updated_dest = {
					destID       => $new_destID,
					steps        => $portals_lut{$actual_portalID}{dest}{$new_destID}{steps},
					allow_ticket => $portals_lut{$actual_portalID}{dest}{$new_destID}{allow_ticket},
				};
			}
		}
	}

	$args->{recalculate} = 1;
	$args->{return} = 1;
	delete $teleport_refresh_by_portal{$replace_portalID};

	if ($updated_dest) {
		my $new_portal = "$actual_portalID=$updated_dest->{destID}";
		warning TF("[%s] Portal data changed from '%s' to '%s'; asking MapRoute to recalculate.\n", PLUGIN_NAME, $replace_portalID, $new_portal);
	} else {
		warning TF("[%s] Portal data changed for '%s'; refreshed menu may differ from the old target, asking MapRoute to recalculate.\n", PLUGIN_NAME, $replace_portalID);
	}
}

sub npc_responses {
	my ($hook, $args) = @_;

	cleanup_old_state();

	my $ID = $args->{ID};
	my $npc = $npcsList->getByID($ID);
	return unless $npc;

	my $name = $args->{name};
	return unless $name =~ /(Kafra|Zonda)/i;

	my $pos = $npc->{pos};
	my $x = $pos->{x};
	my $y = $pos->{y};
	my $map = $field->baseName;

	my $actual_portalID = "$map $x $y";
	my $replace_portalID = $actual_portalID;
	my @lookup_portalIDs = ($actual_portalID);

	if (my $guess = $teleport_guess_by_actual_portal{$actual_portalID}) {
		$replace_portalID = $guess->{replace_portalID} if $guess->{replace_portalID};
		push @lookup_portalIDs, $guess->{replace_portalID} if $guess->{replace_portalID};
	}

	my $responses = $args->{responses};
	return unless ref($responses) eq 'ARRAY';
	return unless scalar @{$responses} > 0;

	my @desired_lines;
	my %desired_seen;
	my %desired_dest_by_map;
	my $parsed_responses = 0;

	foreach my $resp (@{$responses}) {
		if ($resp =~ /^(.+)\s+\S+\s+(\d+)\s*([zZ]|zeny)\.?/i) {
			$parsed_responses++;
			my $destination = $1;
			my $cost = $2;

			my $fixedName = getFixedName($destination);
			if (!defined $fixedName) {
				warning '[' . PLUGIN_NAME . "] Could not resolve destination '$destination' for NPC '$actual_portalID'.\n";
				next;
			}

			my $destID = find_dest_id_for_map(\@lookup_portalIDs, $fixedName);
			if (!defined $destID) {
				warning '[' . PLUGIN_NAME . "] Could not find destination coordinates for '$destination' ($fixedName), skipping add/update.\n";
				next;
			}

			my $expected_resp = build_expected_response($destination);
			my $new_line = "$actual_portalID $destID $cost 1 $expected_resp";
			$desired_dest_by_map{$fixedName} = {
				destID       => $destID,
				steps        => $expected_resp,
				allow_ticket => 1,
			};

			next if $desired_seen{$destID};
			$desired_seen{$destID} = 1;
			push @desired_lines, $new_line;
		}
	}

	return unless $parsed_responses > 0;
	delete $teleport_guess_by_actual_portal{$actual_portalID};

	if (!@desired_lines) {
		warning '[' . PLUGIN_NAME . "] No valid destination lines were built for '$actual_portalID', skipping file changes.\n";
		return;
	}

	my $file = Settings::getTableFilename('portals.txt');

	open my $fh, '<:encoding(UTF-8)', $file or do {
		warning '[' . PLUGIN_NAME . "] Could not open $file for reading.\n";
		return;
	};
	my @lines = <$fh>;
	close $fh;
	chomp @lines;

	my @new_lines;
	my @current_active_lines;
	my $insert_at;
	my %old_dest_map_by_id;

	foreach my $line (@lines) {
		my $parsed = parse_active_portal_line($line);
		if ($parsed && ($parsed->{portalID} eq $replace_portalID || $parsed->{portalID} eq $actual_portalID)) {
			$insert_at = scalar @new_lines if !defined $insert_at;
			push @current_active_lines, $parsed->{normalized};
			$old_dest_map_by_id{$parsed->{destID}} = $parsed->{destMap} if $parsed->{destMap};
			next;
		}
		push @new_lines, $line;
	}

	$insert_at = scalar @new_lines if !defined $insert_at;

	my $current_serialized = join("\n", @current_active_lines);
	my $desired_serialized = join("\n", @desired_lines);
	return if $current_serialized eq $desired_serialized;

	warning '[' . PLUGIN_NAME . "] ##################\n";
	warning '[' . PLUGIN_NAME . "] Rebuilding portal list for '$replace_portalID' using live NPC '$actual_portalID'\n";
	warning '[' . PLUGIN_NAME . "] Active old entries: " . scalar(@current_active_lines) . ' | New entries: ' . scalar(@desired_lines) . "\n";
	warning '[' . PLUGIN_NAME . "] ##################\n";

	splice(@new_lines, $insert_at, 0, @desired_lines);

	open my $wh, '>:utf8', $file or do {
		warning '[' . PLUGIN_NAME . "] Could not open $file for writing.\n";
		return;
	};
	print $wh join("\n", @new_lines) . "\n";
	close $wh;

	warning '[' . PLUGIN_NAME . "] Reloading portals\n";
	Settings::loadByRegexp(qr/portals/);

	warning '[' . PLUGIN_NAME . "] Recompiling portals\n";
	Misc::compilePortals();

	warning '[' . PLUGIN_NAME . "] Reloading again\n";
	Settings::loadByRegexp(qr/portals/);

	store_portal_refresh($replace_portalID, $actual_portalID, \%old_dest_map_by_id, \%desired_dest_by_map);

	Plugins::callHook('TalkNPC_reset', {
		x => $x,
		y => $y,
		message => TF("[%s] Portal data changed for this Kafra. Resetting conversation to retry with refreshed steps.", PLUGIN_NAME),
	});
}

1;





