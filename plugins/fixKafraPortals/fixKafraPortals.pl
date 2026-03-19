#
# fixKafraPortals
# Author: Henrybk
#
# What this plugin does:
# This plugin listens to Kafra and Zonda teleport destination dialogs and uses
# the shown options to automatically update outdated entries in portals.txt.
# It is useful when a server changes Kafra warp prices, destination names, or
# response steps and you want OpenKore to keep using the correct portal data.
#
# How it works:
# - When you talk to a Kafra or Zonda NPC and the destination list appears,
#   the plugin reads the available warp responses.
# - It matches each destination against the current portals database.
# - If the stored portal data has the wrong cost, missing ticket support, or
#   outdated dialog step matching, the plugin rewrites that portal entry in
#   portals.txt and reloads the portals data.
#
# How to configure it:
# This plugin does not require custom config.txt entries.
# Just place it in the plugins folder, enable it, and talk to Kafra/Zonda warp
# NPCs normally so the plugin can inspect their destination menu.
#
# Requirements and notes:
# - The NPC name must match "Kafra" or "Zonda".
# - Commented lines in portals.txt are ignored and left untouched.
# - The plugin can update existing entries, remove duplicates, add missing
#   entries, and delete stale active entries no longer offered by the NPC.
# - It updates portal cost, enables ticket support, and refreshes the expected
#   dialog step pattern used for the destination.
#
# Examples:
# 1. A Kafra in Prontera now charges 1200 zeny to warp to Aldebaran instead of
#    the old value in portals.txt. Open the warp menu once and the plugin will
#    detect the new price and update that line automatically.
#
# 2. A server changes the exact destination text shown in the teleport menu.
#    If the destination can still be matched to a known map, the plugin updates
#    the stored response step pattern to match the current dialog.
#
# 3. A portal entry was missing ticket support. After reading the NPC responses,
#    the plugin rewrites the matching portals.txt entry with allow_ticket = 1.
#
# 4. A Kafra menu no longer offers one of the old destinations in portals.txt.
#    The plugin removes that stale active entry for that NPC.
#
# Result:
# After updating the affected entries, the plugin reloads and recompiles portal
# data so route and NPC warp behavior can use the corrected values immediately.
#
package fixKafraPortals;

use strict;
use File::Spec;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

use Plugins;
use Globals;
use Utils;
use Log qw(message warning error debug);
use Translation;

use constant { PLUGIN_NAME => 'fixKafraPortals' };

Plugins::register( 'fixKafraPortals', 'updates Kafra Portals', \&Unload );

my $hooks = Plugins::addHooks(
	[ 'npc_talk_responses', \&npc_responses, undef ],
);

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
	#'Prontera' => '',
	#'Rachel' => '',
	#'Splendide' => '',
	'Sunken Ship' => 'alb2trea',
	'Turtle island' => 'tur_dun01',
	#'Umbala' => '',
	#'Veins' => '',
};

my $debug  = 0;

sub Unload {
	Plugins::delHooks( $hooks );
	message sprintf( "[%s] Plugin unloading or reloading.\n", PLUGIN_NAME ), PLUGIN_NAME;
}

sub getFixedName {
	my ( $name ) = @_;

	my $lcName = lc($name);

	if (exists $maps_lut{$lcName.'.rsw'}) {
		return $lcName;

	} elsif (exists $mapTable->{$name}) {
		return $mapTable->{$name};

	} else {
		return undef;
	}
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
			portalID => "$1 $2 $3",
			destID => "$4 $5 $6",
			destMap => $4,
			misc => defined $7 ? $7 : '',
		};
	}

	return;
}

sub find_dest_id_for_map {
	my ($portalID, $map) = @_;

	if (exists $portals_lut{$portalID} && exists $portals_lut{$portalID}{dest}) {
		my @existing = sort grep { $portals_lut{$portalID}{dest}{$_}{map} eq $map } keys %{$portals_lut{$portalID}{dest}};
		return $existing[0] if (@existing);
	}

	my %dest_counts;
	foreach my $source_portal (keys %portals_lut) {
		next unless (exists $portals_lut{$source_portal}{dest});
		foreach my $destID (keys %{$portals_lut{$source_portal}{dest}}) {
			my $dest = $portals_lut{$source_portal}{dest}{$destID};
			next unless ($dest->{map} eq $map);
			$dest_counts{$destID}++;
		}
	}

	if (%dest_counts) {
		return (sort { $dest_counts{$b} <=> $dest_counts{$a} || $a cmp $b } keys %dest_counts)[0];
	}

	foreach my $location (sort keys %npcs_lut) {
		my ($npc_map, $x, $y, $name) = split /\s+/, $location . ' ' . $npcs_lut{$location}, 4;
		next unless (defined $npc_map && $npc_map eq $map);
		next unless (defined $name && $name =~ /(Kafra|Zonda)/i);
		return "$map $x $y";
	}

	return;
}

sub npc_responses {
	my ( $hook, $args ) = @_;

	my $ID = $args->{'ID'};
	my $npc = $npcsList->getByID($ID);
	return unless ($npc);

	my $name = $args->{'name'};
	return unless ($name =~ /(Kafra|Zonda)/i);

	my $pos = $npc->{pos};
	my $x = $pos->{x};
	my $y = $pos->{y};

	my $map = $field->baseName;

	my $portalID = "$map $x $y";

	my $responses = $args->{'responses'};

	return unless (ref($responses) eq 'ARRAY');
	return unless (scalar @{$responses} > 0);

	my @desired_lines;
	my %desired_seen;
	my $parsed_responses = 0;
	
	foreach my $resp (@{$responses}) {
		if ($resp =~ /^(.+)\s+\S+\s+(\d+)\s*([zZ]|zeny)\.?/i) {
			$parsed_responses++;
			my $destination = $1;
			my $cost = $2;

			my $fixedName = getFixedName($destination);
			if (!defined $fixedName) {
				warning "[fixKafraPortals] Could not resolve destination '$destination' for NPC '$portalID'.\n";
				next;
			}

			my $destID = find_dest_id_for_map($portalID, $fixedName);
			if (!defined $destID) {
				warning "[fixKafraPortals] Could not find destination coordinates for '$destination' ($fixedName), skipping add/update.\n";
				next;
			}

			my $expected_resp = build_expected_response($destination);
			my $new_line = "$portalID $destID $cost 1 $expected_resp";

			next if ($desired_seen{$destID});
			$desired_seen{$destID} = 1;
			push @desired_lines, $new_line;
		}
	}

	return unless ($parsed_responses > 0);
	if (!@desired_lines) {
		warning "[fixKafraPortals] No valid destination lines were built for '$portalID', skipping file changes.\n";
		return;
	}

	my $file = Settings::getTableFilename("portals.txt");

	open my $fh, "<:encoding(UTF-8)", $file;
    my @lines = <$fh>;
    close $fh;
    chomp @lines;

	my @new_lines;
	my @current_active_lines;
	my $insert_at;

	foreach my $line (@lines) {
		my $parsed = parse_active_portal_line($line);
		if ($parsed && $parsed->{portalID} eq $portalID) {
			$insert_at = scalar @new_lines if (!defined $insert_at);
			push @current_active_lines, $parsed->{normalized};
			next;
		}
		push @new_lines, $line;
	}

	$insert_at = scalar @new_lines if (!defined $insert_at);

	my $current_serialized = join("\n", @current_active_lines);
	my $desired_serialized = join("\n", @desired_lines);
	return if ($current_serialized eq $desired_serialized);

	warning "[fixKafraPortals] ##################\n";
	warning "[fixKafraPortals] Rebuilding portal list for '$portalID'\n";
	warning "[fixKafraPortals] Active old entries: " . scalar(@current_active_lines) . " | New entries: " . scalar(@desired_lines) . "\n";
	warning "[fixKafraPortals] ##################\n";

	splice(@new_lines, $insert_at, 0, @desired_lines);

	open my $wh, ">:utf8", $file;
    print $wh join("\n", @new_lines) . "\n";
    close $wh;

	warning "[fixKafraPortals] Reloading portals\n";
	Settings::loadByRegexp(qr/portals/);

	warning "[fixKafraPortals] Recompiling portals\n";
	Misc::compilePortals();

	warning "[fixKafraPortals] Reloading again\n";
	Settings::loadByRegexp(qr/portals/);
}

1;
