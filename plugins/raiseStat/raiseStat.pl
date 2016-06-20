package raiseStat;

use strict;
use Plugins;
use Utils;
use Globals qw(%config $net $char $messageSender);
use Log qw(message debug error);
use Network::PacketParser qw(STATUS_STR STATUS_AGI STATUS_VIT STATUS_INT STATUS_DEX STATUS_LUK);


Plugins::register('raiseStat', 'automatically raise character stats', \&on_unload);

my $base_hooks = Plugins::addHooks(
	['start3',        \&checkConfig],
	['postloadfiles', \&checkConfig],
    ['configModify',  \&on_configModify]
   );

my @stats_to_add;
my $active_hooks;
my $adding_hook;
my $next_stat;
my $status;
my $timeout = { time => 0, timeout => 1 };

use constant {
	INACTIVE => 0,
	ACTIVE => 1,
	ADDING => 2
};

sub on_unload {
   Plugins::delHook($base_hooks);
   changeStatus(INACTIVE);
   message "raiseStat plugin unloading or reloading\n", 'success';
}

sub changeStatus {
	my $new_status = shift;
	Plugins::delHook($active_hooks) if ($status == ACTIVE);
	Plugins::delHook($adding_hook) if ($status == ADDING);
	if ($new_status == INACTIVE) {
		undef $next_stat;
		undef @stats_to_add;
	} elsif ($new_status == ACTIVE) {
		$active_hooks = Plugins::addHooks(
			['map_loaded',           \&on_possible_raise_chance],
			['packet/sendMapLoaded', \&on_possible_raise_chance],
			['base_level_changed', \&on_possible_raise_chance]
		);
	} else {
		$adding_hook = Plugins::addHooks(
			['AI_pre',            \&on_ai_pre]
		);
	}
	$status = $new_status;
}

sub getNextStat {
	my $amount;
	foreach my $step (@stats_to_add) {
		$amount = $char->{$step->{'stat'}};
		$amount += $char->{"$step->{'stat'}_bonus"} unless $config{statsAddAuto_dontUseBonus};	
		if ($amount < $step->{'value'}) {
			$next_stat = $step->{'stat'};
			return 1;
		}
	}
	message "raiseStat has no more stats to raise; disabling statsAddAuto\n", 'success';
	return 0;
}

sub canRaise {
	return 1 if ($status != INACTIVE && $char->{points_free} && $char->{"points_".$next_stat} && $char->{points_free} >= $char->{"points_".$next_stat});
	return 0;
}

sub on_possible_raise_chance {
	changeStatus(ADDING) if ($status == ACTIVE);
}

sub on_ai_pre {
	return if !$char;
	return if $net->getState != Network::IN_GAME;
	return if !timeOut( $timeout );
	$timeout->{time} = time;
	return changeStatus(INACTIVE) unless (getNextStat());
	return changeStatus(ACTIVE) unless (canRaise());
	raiseStat();
}

sub raiseStat {
	message "Auto-adding stat ".$next_stat." to ".($char->{$next_stat}+1)."\n";
	$messageSender->sendAddStatusPoint({
		str => STATUS_STR,
		agi => STATUS_AGI,
		vit => STATUS_VIT,
		int => STATUS_INT,
		dex => STATUS_DEX,
		luk => STATUS_LUK,
	}->{$next_stat});
}

sub on_configModify {
	my (undef, $args) = @_;
	if ($args->{key} eq 'statsAddAuto') {
		return changeStatus(ACTIVE) if ($args->{val} && $config{statsAddAuto_list} && validateSteps($config{statsAddAuto_list}));
	} elsif ($args->{key} eq 'statsAddAuto_list') {
		return changeStatus(ACTIVE) if ($args->{val} && $config{statsAddAuto} && validateSteps($args->{val}));
	}
	return changeStatus(INACTIVE);
}

sub checkConfig {
	return changeStatus(ACTIVE) if ($config{statsAddAuto} && $config{statsAddAuto_list} && validateSteps($config{statsAddAuto_list}));
	return changeStatus(INACTIVE);
}

sub validateSteps {
	my $list = shift;
	my @steps = split(/\s*,+\s*/, $list);
	undef @stats_to_add;
	foreach my $step (@steps) {
		if ($step =~ /^(\d+)\s+(str|vit|dex|int|luk|agi)$/) {
			my $value = $1;
			my $stat = $2;
			if ($value > 99 && !$config{statsAdd_over_99}) {
				error "Stat '".$step."' is more then 99 and 'statsAdd_over_99' is disabled; disabling statsAddAuto\n";
				return 0;
			}
			push(@stats_to_add, {'value' => $value, 'stat' => $stat});
		} else {
			error "Unknown stat ".$step."; disabling statsAddAuto\n";
			return 0;
		}
	}
	return 1;
}


return 1;
