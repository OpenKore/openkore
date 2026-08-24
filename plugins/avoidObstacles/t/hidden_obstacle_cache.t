use strict;
use warnings;
use FindBin;
use Test::More;

BEGIN {
	package AI;
	sub import {}
	$INC{'AI.pm'} = 1;

	package FileParsers;
	use Exporter 'import';
	our @EXPORT_OK = qw(parseConfigFile);
	sub parseConfigFile {}
	$INC{'FileParsers.pm'} = 1;

	package Globals;
	use Exporter 'import';
	our @EXPORT = qw(
		$field $char $monstersList $playersList
		@spellsID %spells @portalsID %portals %monsters %portals_lut %config
	);
	our ($field, $char, $monstersList, $playersList);
	our (@spellsID, %spells, @portalsID, %portals, %monsters, %portals_lut, %config);
	$INC{'Globals.pm'} = 1;

	package Misc;
	use Exporter 'import';
	our @EXPORT = qw(calcPosFromPathfinding parseReload);
	sub calcPosFromPathfinding {
		my (undef, $actor) = @_;
		return $actor->{pos_to} || $actor->{pos};
	}
	sub parseReload {}
	$INC{'Misc.pm'} = 1;

	package Plugins;
	sub register {}
	sub addHooks { return []; }
	sub delHooks {}
	$INC{'Plugins.pm'} = 1;

	package Skill;
	sub import {}
	sub new { return bless {}, shift; }
	sub getName { return 'Unknown'; }
	$INC{'Skill.pm'} = 1;

	package Settings;
	sub import {}
	sub getControlFilename { return undef; }
	$INC{'Settings.pm'} = 1;

	package Utils;
	use Exporter 'import';
	our @EXPORT = qw(blockDistance getOffset);
	sub blockDistance {
		my ($left, $right) = @_;
		my $x = abs($left->{x} - $right->{x});
		my $y = abs($left->{y} - $right->{y});
		return $x > $y ? $x : $y;
	}
	sub getOffset { return 0; }
	$INC{'Utils.pm'} = 1;

	package Log;
	use Exporter 'import';
	our @EXPORT_OK = qw(error message debug warning);
	our @messages;
	sub error { push @messages, $_[0]; }
	sub message { push @messages, $_[0]; }
	sub debug { push @messages, $_[0]; }
	sub warning { push @messages, $_[0]; }
	$INC{'Log.pm'} = 1;

	package Commands;
	sub register { return []; }
	sub unregister {}

	package Actor;
	sub get { return undef; }

	package Actor::Monster;
	$INC{'Actor.pm'} = 1;
}

{
	package TestField;
	sub getSquareEdgesFromCoord {
		my ($self, $pos, $distance) = @_;
		return (
			$pos->{x} - $distance,
			$pos->{y} - $distance,
			$pos->{x} + $distance,
			$pos->{y} + $distance,
		);
	}
	sub isWalkable { return 1; }
	sub name { return 'test'; }
	sub baseName { return 'test'; }
}

require "$FindBin::Bin/../avoidObstacles.pl";

sub make_actor {
	my ($id, $x, $y) = @_;
	return bless {
		ID => $id,
		name => "test-$id",
		nameID => 9000,
		pos => { x => $x, y => $y },
	}, 'Actor::Monster';
}

sub obstacle_profile {
	return {
		enabled => 1,
		penalty_dist => [100],
		danger_dist => [1],
		prohibited_dist => 0,
		drop_target_when_near_dist => -1,
		drop_destination_when_near_dist => -1,
	};
}

sub reset_plugin {
	my (%settings) = @_;
	my %config = (
		clientSight => 17,
	);
	$config{avoidObstacles_hidden_obstacle_ttl} = $settings{ttl} if exists $settings{ttl};
	$config{avoidObstacles_hidden_obstacle_limit} = $settings{limit} if exists $settings{limit};
	%Globals::config = %config;
	$Globals::field = bless { width => 200, weightMap => '' }, 'TestField';
	$Globals::char = bless { pos => { x => 100, y => 100 } }, 'Actor::Monster';
	$Globals::monstersList = undef;
	$Globals::playersList = undef;
	@Globals::spellsID = ();
	%Globals::spells = ();
	@Globals::portalsID = ();
	%Globals::portals = ();
	avoidObstacles::reset_plugin_configuration();
	avoidObstacles::load_settings_from_config();
	avoidObstacles::rebuild_obstacles_from_world();
}

sub mark_hidden {
	my ($actor) = @_;
	avoidObstacles::add_obstacle($actor, obstacle_profile(), 'monster');
	avoidObstacles::on_actor_avoid_removal(undef, { actor => $actor });
}

sub status_snapshot {
	@Log::messages = ();
	avoidObstacles::command_avoid('avoid', 'status');
	my $status = $Log::messages[-1] || '';
	my ($obstacles, $removed_cache, $weight_cells, $danger_cells, $prohibited_cells) =
		$status =~ /obstacles=(\d+) removed-cache=(\d+) weight-cells=(\d+) danger-cells=(\d+) prohibited-cells=(\d+)/;
	return {} unless defined $obstacles;
	return {
		obstacles => 0 + $obstacles,
		removed_cache => 0 + $removed_cache,
		weight_cells => 0 + $weight_cells,
		danger_cells => 0 + $danger_cells,
		prohibited_cells => 0 + $prohibited_cells,
	};
}

my $test_now = 1_000;
{
	no warnings 'redefine';
	no warnings 'once';
	local *avoidObstacles::current_time = sub { return $test_now; };

	reset_plugin();
	mark_hidden(make_actor('expired', 0, 0));
	avoidObstacles::prune_hidden_obstacles($test_now + 4);
	is_deeply(
		status_snapshot(),
		{
			obstacles => 1,
			removed_cache => 1,
			weight_cells => 1,
			danger_cells => 1,
			prohibited_cells => 1,
		},
		'hidden obstacle remains active throughout the default five-second safety window',
	);

	avoidObstacles::prune_hidden_obstacles($test_now + 5);
	is_deeply(
		status_snapshot(),
		{
			obstacles => 0,
			removed_cache => 0,
			weight_cells => 0,
			danger_cells => 0,
			prohibited_cells => 0,
		},
		'expiry releases hidden obstacle state and every route contribution',
	);

	reset_plugin(ttl => 3600, limit => 1);
	$test_now = 2_000;
	mark_hidden(make_actor('first', 0, 0));
	$test_now = 2_001;
	mark_hidden(make_actor('second', 1, 1));
	is_deeply(
		status_snapshot(),
		{
			obstacles => 1,
			removed_cache => 1,
			weight_cells => 1,
			danger_cells => 1,
			prohibited_cells => 1,
		},
		'cache-cap eviction keeps one obstacle and releases every evicted contribution',
	);
}

done_testing();
