package doramLopeEscape;

use strict;
use warnings;
use utf8;

use Plugins;
use Globals qw($accountID $char $field $messageSender %config);
use Actor;
use Skill;
use AI;
use Log qw(message);
use Time::HiRes qw(time);

Plugins::register(
	'doramLopeEscape',
	'Jump away from configured monsters after taking damage.',
	\&on_unload,
	\&on_unload
);

my $hooks = Plugins::addHooks(
	['packet_attack',   \&on_packet_attack,   undef],
	['packet_skilluse', \&on_packet_skilluse, undef],
	['AI_start',        \&on_ai_start,        undef],
);

my $last_jump = 0;
my $pending_jump;

message "[DoramLopeEscape] Loaded. Set doramLopeEscape 1 to enable.\n", 'info';

sub on_unload {
	Plugins::delHooks($hooks) if $hooks;
}

sub on_packet_attack {
	my (undef, $args) = @_;
	process_damage('attack', $args, $args->{dmg});
}

sub on_packet_skilluse {
	my (undef, $args) = @_;
	process_damage('skill', $args, $args->{damage});
}

# 在每轮 AI 的最早阶段处理待跳跃任务，防止 attackSkillSlot 再次抢占动作。
sub on_ai_start {
	return unless $pending_jump;

	if (!$char || !$messageSender) {
		undef $pending_jump;
		return;
	}

	my $now = time;

	if ($now >= $pending_jump->{expires_at}) {
		dbg('pending jump expired before the character became ready');
		undef $pending_jump;
		return;
	}

	AI::clear(qw(attack move route skill_use));
	$char->sendAttackStop();

	return if $now < $pending_jump->{ready_at};
	return unless cast_and_delay_finished();

	# 直接发送“指定地板坐标”的跳跃包，不再排入 AI 的 skill_use 队列。
	$messageSender->sendSkillUseLoc(
		$pending_jump->{skill}->getIDN,
		$pending_jump->{level},
		$pending_jump->{x},
		$pending_jump->{y}
	);

	$last_jump = $now;

	message sprintf(
		"[DoramLopeEscape] sent SU_LOPE to (%d, %d)\n",
		$pending_jump->{x}, $pending_jump->{y}
	), 'info';

	undef $pending_jump;
}

sub process_damage {
	my ($kind, $args, $damage) = @_;

	return unless $char && $field;
	return unless defined $args->{targetID} && $args->{targetID} eq $accountID;

	$damage = 0 unless defined $damage;
	dbg("$kind hit: damage=$damage");

	return unless $config{doramLopeEscape};
	return unless $damage > 0;

	if ($pending_jump) {
		dbg('ignored: jump already pending');
		return;
	}

	my $cooldown = $config{doramLopeEscape_timeout} || 2;
	my $now = time;

	if ($now - $last_jump < $cooldown) {
		dbg('ignored: cooldown');
		return;
	}

	my $source = Actor::get($args->{sourceID});
	return unless $source && $source->isa('Actor::Monster');

	my $mob_name = $source->nameString || '';
	return unless is_trigger_mob($mob_name);

	my $me  = $char->{pos_to};
	my $mob = $source->{pos_to};

	return unless defined $me->{x}  && defined $me->{y};
	return unless defined $mob->{x} && defined $mob->{y};

	my $dir_x = ($me->{x} <=> $mob->{x});
	my $dir_y = ($me->{y} <=> $mob->{y});
	return unless $dir_x || $dir_y;

	my $step = int($config{doramLopeEscape_step} || 5);
	$step = 1 if $step < 1;

	my $target = find_away_tile($me, $dir_x, $dir_y, $step);
	return unless $target;

	dbg(sprintf(
		'coords: self=(%d,%d) mob=(%d,%d) target=(%d,%d)',
		$me->{x}, $me->{y}, $mob->{x}, $mob->{y},
		$target->{x}, $target->{y}
	));

	my $min_sp = $config{doramLopeEscape_minSP} || 0;
	return if ($char->{sp} || 0) < $min_sp;

	my $skill = Skill->new(
		handle => ($config{doramLopeEscape_skill} || 'SU_LOPE')
	);

	my $known_level = $char->getSkillLevel($skill);
	return unless $known_level > 0;

	my $level = int($config{doramLopeEscape_lvl} || $known_level);
	$level = $known_level if $level > $known_level;
	$level = 1 if $level < 1;

	my $wait = defined $config{doramLopeEscape_wait}
		? $config{doramLopeEscape_wait}
		: 1.3;
	$wait = 0 if $wait < 0;

	$pending_jump = {
		skill      => $skill,
		level      => $level,
		x          => $target->{x},
		y          => $target->{y},
		ready_at   => $now + $wait,
		expires_at => $now + ($config{doramLopeEscape_pending_timeout} || 4),
	};

	AI::clear(qw(attack move route skill_use));
	$char->sendAttackStop();

	message sprintf(
		"[DoramLopeEscape] %s damage from %s: waiting %.1fs, SU_LOPE -> (%d, %d)\n",
		$kind, $mob_name, $wait, $target->{x}, $target->{y}
	), 'info';
}

sub cast_and_delay_finished {
	return 1 unless $char->{time_cast};

	my $cast_wait = $char->{time_cast_wait} || 0;
	return time >= $char->{time_cast} + $cast_wait + 0.15;
}

sub is_trigger_mob {
	my ($name) = @_;

	# nameString 形如：Monster 茅膏菜 (0)
	$name ||= '';
	$name =~ s/^\s*Monster\s+//i;
	$name =~ s/\s+\(\d+\)\s*$//;
	$name =~ s/^\s+|\s+$//g;

	my %wanted = map {
		my $entry = $_;
		$entry =~ s/^\s+|\s+$//g;
		lc($entry) => 1;
	} grep { length $_ } split /\s*,\s*/,
		($config{doramLopeEscape_monsters} || '茅膏菜,邪恶噬人花');

	return $wanted{lc($name)};
}

sub find_away_tile {
	my ($me, $dir_x, $dir_y, $step) = @_;

	my $perp_x = -$dir_y;
	my $perp_y =  $dir_x;

	for (my $distance = $step; $distance >= 1; $distance--) {
		for my $side (0, 1, -1) {
			my $x = $me->{x} + $dir_x * $distance + $perp_x * $side;
			my $y = $me->{y} + $dir_y * $distance + $perp_y * $side;

			return {x => $x, y => $y}
				if $field->isWalkable($x, $y);
		}
	}

	return;
}

sub dbg {
	return unless $config{doramLopeEscape_debug};
	message "[DoramLopeEscape] $_[0]\n", 'info';
}

1;
