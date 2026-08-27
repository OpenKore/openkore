package sageFreeCastAttack;

use strict;
use warnings;

use AI;
use Globals qw($accountID $char $monstersList %config);
use Log qw(message);
use Plugins;
use Time::HiRes ();
use Utils qw(blockDistance calcPosition);

Plugins::register(
	'sageFreeCastAttack',
	'Keeps weapon attacks active while a Sage casts supported spells.',
	\&on_unload
);

my $hooks = Plugins::addHooks(
	['is_casting', \&on_is_casting, undef],
	['AI_pre', \&on_ai_pre, undef],
	['packet_attack', \&on_packet_attack, undef],
	['packet_castCancelled', \&on_cast_cancelled, undef],
);

my $pending_attack;
my $initial_delay = 0.10;
my $retry_delay = 0.30;

my %supported_skill_ids = (
	14 => 'MG_COLDBOLT',
	19 => 'MG_FIREBOLT',
	20 => 'MG_LIGHTNINGBOLT',
	21 => 'MG_THUNDERSTORM',
);

sub on_unload {
	_cancel_pending('plugin unloaded');
	Plugins::delHooks($hooks) if $hooks;
}

sub _now {
	return Time::HiRes::time();
}

sub _debug_log {
	return unless $config{sageFreeCastAttack_debug};
	message("[sageFreeCastAttack] $_[0]\n", 'plugin');
}

sub _target_label {
	my ($target) = @_;
	my $label = $target->{name} || 'target';
	$label .= " ($target->{binID})" if defined $target->{binID};
	return $label;
}

sub _cancel_pending {
	my ($reason) = @_;
	return unless $pending_attack;
	_debug_log(
		"cancelled: $reason for $pending_attack->{target_label}"
	);
	undef $pending_attack;
}

sub on_is_casting {
	my (undef, $args) = @_;

	return unless $args;
	return unless defined $accountID
		&& defined $args->{sourceID}
		&& $args->{sourceID} eq $accountID;
	_cancel_pending('a new self cast started');
	return unless $config{sageFreeCastAttack};
	return unless $config{attackUseWeapon};
	return unless $char && $char->getSkillLevelByHandle('SA_FREECAST') > 0;
	return unless defined $args->{skillID}
		&& exists $supported_skill_ids{$args->{skillID}};
	return unless ($args->{castTime} || 0) > 0;

	my $attack_index = AI::findAction('attack');
	return unless defined $attack_index;

	my $attack_args = AI::args($attack_index);
	return unless $attack_args && defined $attack_args->{ID};

	my $target = $monstersList && $monstersList->getByID($attack_args->{ID});
	return unless $target && !$target->{dead};

	my $now = _now();
	$pending_attack = {
		targetID => $attack_args->{ID},
		target_label => _target_label($target),
		skillID => $args->{skillID},
		send_at => $now + $initial_delay,
		expires_at => $now + ($args->{castTime} / 1000),
		attempts => 0,
	};
	_debug_log(
		"scheduled $supported_skill_ids{$args->{skillID}} weapon attack"
		. " for $pending_attack->{target_label}"
	);
}

sub on_ai_pre {
	return unless $pending_attack;
	unless ($config{sageFreeCastAttack}
		&& $config{attackUseWeapon}
		&& $char
		&& $char->getSkillLevelByHandle('SA_FREECAST') > 0) {
		_cancel_pending('plugin or weapon attack disabled');
		return;
	}

	my $casting_skill_id = eval {
		$char->{casting}{skill}->getIDN();
	};
	unless (defined $casting_skill_id
		&& $casting_skill_id == $pending_attack->{skillID}) {
		_cancel_pending('cast ended or changed');
		return;
	}

	my $now = _now();
	if ($now >= $pending_attack->{expires_at}) {
		_cancel_pending('cast-time window ended');
		return;
	}
	return if $now < $pending_attack->{send_at};

	my $attack_index = AI::findAction('attack');
	my $attack_args = defined $attack_index ? AI::args($attack_index) : undef;
	unless ($attack_args
		&& defined $attack_args->{ID}
		&& $attack_args->{ID} eq $pending_attack->{targetID}) {
		_cancel_pending('AI attack target changed');
		return;
	}

	my $target = $monstersList
		&& $monstersList->getByID($pending_attack->{targetID});
	unless ($target && !$target->{dead}) {
		_cancel_pending('target disappeared or died');
		return;
	}

	my $weapon_range = $char->{attack_range}
		|| $config{attackMaxDistance}
		|| $config{attackDistance}
		|| 1;
	unless ($char->{pos} && $char->{pos_to}
		&& $target->{pos} && $target->{pos_to}) {
		unless ($pending_attack->{waiting_reason}
			&& $pending_attack->{waiting_reason} eq 'position') {
			_debug_log("waiting for weapon range: position unavailable");
			$pending_attack->{waiting_reason} = 'position';
		}
		return;
	}

	my $char_position = calcPosition($char);
	my $target_position = calcPosition($target);
	unless ($char_position && $target_position) {
		_debug_log("waiting for weapon range: position prediction failed");
		return;
	}

	my $distance = blockDistance($char_position, $target_position);
	if ($distance > $weapon_range) {
		my $reason = "$distance/$weapon_range";
		unless ($pending_attack->{waiting_reason}
			&& $pending_attack->{waiting_reason} eq $reason) {
			_debug_log(
				"waiting for weapon range: distance $distance, range $weapon_range"
			);
			$pending_attack->{waiting_reason} = $reason;
		}
		return;
	}
	delete $pending_attack->{waiting_reason};

	$char->sendAttack($pending_attack->{targetID});
	$pending_attack->{attempts}++;
	$pending_attack->{send_at} = $now + $retry_delay;
	_debug_log(
		"send attempt $pending_attack->{attempts} for $pending_attack->{target_label}"
		. " at distance $distance/$weapon_range"
	);
}

sub on_packet_attack {
	my (undef, $args) = @_;

	return unless $pending_attack && $pending_attack->{attempts};
	return unless $args
		&& defined $args->{sourceID}
		&& defined $args->{targetID};
	return unless defined $accountID && $args->{sourceID} eq $accountID;
	return unless $args->{targetID} eq $pending_attack->{targetID};

	_debug_log(
		"acknowledged $pending_attack->{target_label}"
		. " after attempt $pending_attack->{attempts}"
	);
	undef $pending_attack;
}

sub on_cast_cancelled {
	my (undef, $args) = @_;

	return unless $pending_attack;
	return unless $args && defined $args->{sourceID};
	return unless defined $accountID && $args->{sourceID} eq $accountID;

	_cancel_pending('cast cancelled by server');
}

1;
