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
my $time_sent;
my $status;

use constant {
	INACTIVE => 0,
	ACTIVE => 1,
	ADDING => 2
};

sub on_unload {
   Plugins::delHook($base_hooks);
   deactivate();
   message "raiseStat plugin unloading or reloading\n", 'success';
}

sub deactivate {
	Plugins::delHook($active_hooks) if ($status == ACTIVE);
	Plugins::delHook($adding_hook) if ($status == ADDING);
	$status = INACTIVE;
	undef $time_sent;
	undef $next_stat;
	undef @stats_to_add;
}

sub activate {
	$active_hooks = Plugins::addHooks(
		['map_loaded',           \&endMapChange],
		['packet/sendMapLoaded', \&endMapChange]
	);
	$status = ACTIVE;
	if ($char) {
		getNextStat();
	}
}

sub getNextStat {
	my $amount;
	foreach my $step (@stats_to_add) {
		$amount = $char->{$step->{'stat'}};
		$amount += $char->{"$step->{'stat'}_bonus"} unless $config{statsAddAuto_dontUseBonus};	
		if ($amount < $step->{'value'}) {
			$next_stat = $step->{'stat'};
			return;
		}
	}
	message "raiseStat has no more stats to raise; disabling statsAddAuto\n", 'success';
	deactivate();
}

sub stat_changed {
	getNextStat();
	if (!canRaise() && $status == ADDING) {
		Plugins::delHook($adding_hook);
		$active_hooks = Plugins::addHooks(
			['map_loaded',           \&endMapChange],
			['packet/sendMapLoaded', \&endMapChange]
		);
		$status = ACTIVE;
	}
}

sub canRaise {
	return 0 if ($status == INACTIVE);
	if ($char->{points_free} && $char->{"points_".$next_stat} && $char->{points_free} >= $char->{"points_".$next_stat}) {
		return 1;
	} else {
		return 0;
	}
}

sub raiseStat {
	if (timeOut($time_sent,1)) {
		$time_sent = time;
		if (!canRaise()) {
			Plugins::delHook($adding_hook);
			$active_hooks = Plugins::addHooks(
				['map_loaded',           \&endMapChange],
				['packet/sendMapLoaded', \&endMapChange]
			);
			$status = ACTIVE;
			return;
		}
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
}

sub endMapChange {
	if (!$next_stat) {
		getNextStat();
	} else {
		if (canRaise() && $status == ACTIVE) {
			message "adding hooks\n","system";
			$adding_hook = Plugins::addHooks(
				['packet_charStats',  \&stat_changed],
				['AI_pre',            \&raiseStat]
			);
			Plugins::delHook($active_hooks);
			$status = ADDING;
		}
	}
}

sub on_configModify {
	my (undef, $args) = @_;
	if ($args->{key} eq 'statsAddAuto') {
		if ($args->{val} == 0) {
			deactivate();
		} elsif ($args->{val} == 1) {
			checkSteps();
		} else {
			error "Unknown value set to 'statsAddAuto'; disabling statsAddAuto\n";
			deactivate();
		}
	} elsif ($args->{key} eq 'statsAddAuto_list') {
		checkSteps($args->{val});
	}
}

sub checkConfig {
	if ($config{statsAddAuto}) {
		if ($config{statsAddAuto_list}) {
			checkSteps($config{statsAddAuto_list});
		} else {
			deactivate();
		}
	} else {
		deactivate();
	}
}

sub checkSteps {
	my $list = shift;
	if (!$list) {
		$list = $config{statsAddAuto_list};
	}
	my @steps = split(/\s*,+\s*/, $list);
	undef @stats_to_add;
	foreach my $step (@steps) {
		if ($step =~ /^(\d+)\s+(str|vit|dex|int|luk|agi)$/) {
			my $value = $1;
			my $stat = $2;
			if ($value > 99 && !$config{statsAdd_over_99}) {
				error "Stat '".$step."' is more then 99 and 'statsAdd_over_99' is disabled; disabling statsAddAuto\n";
				deactivate();
				return;
			}
			push(@stats_to_add, {'value' => $value, 'stat' => $stat});
		} else {
			error "Unknown stat ".$step."; disabling statsAddAuto\n";
			deactivate();
			return;
		}
	}
	getNextStat();
	if ($status == INACTIVE) {
		activate();
	}
}


return 1;
