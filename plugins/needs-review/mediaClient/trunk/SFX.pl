package SFX;
 
use strict;
use Time::HiRes qw(time usleep);
use encoding 'utf8';

use Globals;
use Actor;
use Actor::You;
use Actor::Player;
use Actor::Monster;
use Actor::Party;
use Actor::Unknown;
use Item;
use Settings;
use Log qw(message warning error debug);
use FileParsers;
use Misc;
use Plugins;
use Utils;
use Skills;
use Utils::Crypton;
use I18N qw(bytesToString);
my $dataDir = $Plugins::current_plugin_folder;
use FindBin qw($RealBin);
use lib "$RealBin/plugins/mediaClient";
use client;

use constant MAX_VOLUME => 128;

my %ALERT;
my $pathTo = 'sounds/SFX/';
my $ext = '.ogg';

Plugins::register('SFX', 'plays sound effects', \&Unload);

my $hooks = Plugins::addHooks(
	['packet_attack', \&onAttack, undef],
	['packet/unit_levelup', \&onLevelup, undef],
);

sub Unload {
	Plugins::delHooks($hooks);
	client->getInstance()->quit;
}

sub onLevelup {
	my ($packet, $args) = @_;
	
	my $type = $args->{type};
	if ($type == 0) {
		client->getInstance->play($pathTo . 'levelup' . $ext, 'SFX', 1);
	} elsif ($type == 1) {
		client->getInstance->play($pathTo . 'levelup' . $ext, 'SFX', 1);
	} elsif ($type == 2) {
		client->getInstance->play($pathTo . 'bs_refinefailed' . $ext, 'SFX', 1);
	} elsif ($type == 3) {
		client->getInstance->play($pathTo . 'bs_refinesuccess' . $ext, 'SFX', 1);
	}
}

sub onAttack {
	my ($packet, $args) = @_;
	my $weapon;
	my $dmg = $args->{dmg};
	
	if ($args->{sourceID} eq $accountID) {
		$weapon = lc($char->{equipment}{rightHand}{name}) || 'fist1';
		$weapon =~ s/\ \[\d\]//g;
	}
	
	#weapon classifications
	if ($weapon eq 'knife' ||
		$weapon eq 'dagger' ||
		$weapon eq 'stiletto' ||
		$weapon eq 'main gauche') {
		$weapon = 'dagger';
	}
	
	if ($args->{sourceID} eq $accountID) {
		my $hit = $dmg > 0 ? "hit" : "attack";
		my $file = $pathTo . '_' . $hit . '_' . $weapon . $ext;
		client->getInstance->play($file, 'SFX', 1);

	} else {
		my $hit = "attack";
		my $source = Actor::get($args->{sourceID});
		my $monster = lc($source->name);

		#monster classifications
		if ($monster eq 'drops') {
			$monster = 'poring';
		}
		if ($monster eq 'super picky') {
			$monster = 'picky';
		}

		$monster =~ s/\ /\_/g;
		my $file = $pathTo . 'monsters/' . $monster . '_' . $hit . $ext;
		client->getInstance->play($file, 'SFX', 1);
	}	
}

sub unused {
	my $job = lc($jobs_lut{$char->{jobID}});
	$job = 'swordman' if ($job eq 'swordsman');
	$job = 'magician' if ($job eq 'mage');
}

1;
