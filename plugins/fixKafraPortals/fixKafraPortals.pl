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
# - The destination must already exist in portals.txt for that NPC location.
# - The plugin only updates known entries; it does not create brand new portal
#   records for completely unknown Kafra destinations.
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
	Plugins::delHook( $hooks );
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

	#warning "[fixKafraPortals] Got Kafra npc responses\n";

	my %changedPortals;
	
	foreach my $resp (@{$responses}) {
		#warning "[fixKafraPortals] Testing response '$resp'\n";
		if ($resp =~ /^(.+)\s+\S+\s+(\d+)\s*([zZ]|zeny)\.?/i) {
			#warning "[fixKafraPortals] Passed response check\n";
			my $destination = $1;
			my $cost = $2;

			my $fixedName = getFixedName($destination);
			if (!defined $fixedName) {
				#warning "[fixKafraPortals] [getFixedName] Failed on string '$destination'\n";
				next;
			}

			# TODO ADD FILE TO SAVE INFO ABOUT NON EXISTANT KAFRA
			next unless (exists $portals_lut{$portalID});
			#warning "[fixKafraPortals] Passed portals_lut check\n";

			foreach my $destID (keys %{$portals_lut{$portalID}{dest}}) {
				my $dest = $portals_lut{$portalID}{dest}{$destID};
				#warning "[fixKafraPortals] Found dest check '$destID'\n";

				return unless (exists $dest->{cost} && exists $dest->{allow_ticket});
				#warning "[fixKafraPortals] Passed exists cost allow_ticket - next check '$dest->{map}' x '$fixedName'\n";

				if ($dest->{map} eq $fixedName) {
					my $expected_resp = "r~/(Warp|Teleport)/i r~/$destination/i";
					if ($dest->{cost} != $cost || !$dest->{allow_ticket} || $dest->{steps} ne $expected_resp) {
						$changedPortals{"$portalID $destID"}{portalID} = $portalID;
						$changedPortals{"$portalID $destID"}{destID} = $destID;
						$changedPortals{"$portalID $destID"}{cost} = $cost;
						$changedPortals{"$portalID $destID"}{allow_ticket} = 1;
						$changedPortals{"$portalID $destID"}{steps} = $expected_resp;
						warning "[fixKafraPortals] Found wrong portal '$portalID $destID', new cost $cost (old $dest->{cost}), new steps $expected_resp (old $dest->{steps})\n";
					}
				}
			}
		}
	}

	return unless (scalar keys %changedPortals > 0);

	warning "[fixKafraPortals] ##################\n";
	warning "[fixKafraPortals] We need to fix ".(scalar keys %changedPortals)." portals\n";
	warning "[fixKafraPortals] ##################\n";

	my @changeLines;

	foreach my $changedValue (values %changedPortals) {
		my $portal = $portals_lut{$changedValue->{portalID}}{dest}{$changedValue->{destID}};

		my $change = {
			oldLine => "$changedValue->{portalID} $changedValue->{destID}",
			newLine => "$changedValue->{portalID} $changedValue->{destID} $changedValue->{cost} $changedValue->{allow_ticket} $changedValue->{steps}",
		};
		push(@changeLines, $change);

		$portal->{cost} = $changedValue->{cost};
		$portal->{allow_ticket} = $changedValue->{allow_ticket};
		$portal->{steps} = $changedValue->{steps};

	}

	my $file = Settings::getTableFilename("portals.txt");

	open my $fh, "<:encoding(UTF-8)", $file;
    my @lines = <$fh>;
    close $fh;
    chomp @lines;

    my @new_lines;

    foreach my $line (@lines) {
		my $original_line = $line;
		$line =~ s/\cM|\cJ//g;
		$line =~ s/\s+/ /g;
		$line =~ s/^\s+|\s+$//g;
		$line =~ s/(.*)[\s\t]+#.*$/$1/;

		my $found = 0;
		foreach my $change (@changeLines) {
			next if ($found);
			next unless ($line =~ /$change->{oldLine}/);
			$found = 1;
			warning "[fixKafraPortals] Updating line from '$line' to '$change->{newLine}'\n";
			push (@new_lines, $change->{newLine});
		}
		push (@new_lines, $original_line) unless ($found);
    }

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
