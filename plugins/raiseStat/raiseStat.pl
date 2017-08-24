package raiseStat;

use strict;
use Plugins;
use Utils;
use Globals qw(%config $net $char $messageSender);
use Log qw(message debug error);
use Network::PacketParser qw(STATUS_STR STATUS_AGI STATUS_VIT STATUS_INT STATUS_DEX STATUS_LUK);


Plugins::register('raiseStat', 'automatically raise character stats', \&on_unload);

################################################################
#  Hooks used to activate the plugin during initialization
#  and on config change events.
my $base_hooks = Plugins::addHooks(
	['start3',        \&checkConfig],
	['postloadfiles', \&checkConfig],
    ['configModify',  \&on_configModify]
   );

my @stats_to_add;
my $waiting_hooks;
my $adding_hook;
my $next_stat;
my $status;
my $timeout = { time => 0, timeout => 1 };

use constant {
	INACTIVE => 0,
	AWAITING_CHANCE_OR_ANSWER => 1,
	ADDING => 2
};

sub on_unload {
   Plugins::delHook($base_hooks);
   changeStatus(INACTIVE);
   message "[raiseStat] Plugin unloading or reloading\n", 'success';
}

################################################################
#  changeStatus() is the function responsible for adding
#  and deleting hooks when changing plugin status.
#  During status == 0 the plugin will be inactive and won't
#  look for opportunities to raise stats.
#  During status == 1 the plugin will be active and will
#  have 'speculative' hooks added to try to look for
#  opportunities to raise stats, during this phase plugin
#  will also be awaiting for an answer after we sent a
#  raise request to server.
#  During status == 2 the plugin will be active and will
#  have 'AI_pre' hook active, on each AI call the plugin
#  will try to raise stats if possible.
sub changeStatus {
	my $new_status = shift;
	Plugins::delHook($waiting_hooks) if ($status == AWAITING_CHANCE_OR_ANSWER);
	Plugins::delHook($adding_hook) if ($status == ADDING);
	if ($new_status == INACTIVE) {
		undef $next_stat;
		undef @stats_to_add;
		debug "[raiseStat] Plugin stage changed to 'INACTIVE'\n";
	} elsif ($new_status == AWAITING_CHANCE_OR_ANSWER) {
		$waiting_hooks = Plugins::addHooks(
			['packet/stats_added', \&on_possible_raise_chance_or_answer],
			['packet/stats_info', \&on_possible_raise_chance_or_answer],
			['packet/stat_info', \&on_possible_raise_chance_or_answer] # 9 is points_free
		);
		debug "[raiseStat] Plugin stage changed to 'AWAITING_CHANCE_OR_ANSWER'\n";
	} elsif ($new_status == ADDING) {
		$adding_hook = Plugins::addHooks(
			['AI_pre',            \&on_ai_pre]
		);
		debug "[raiseStat] Plugin stage changed to 'ADDING'\n";
	}
	$status = $new_status;
}

################################################################
#  on_possible_raise_chance_or_answer() is the function called by
#  our 'speculative' hooks to try to look for
#  opportunities to raise stats or server answers to our raise
#  requests. It changes the plugin status to 'ADDING' (2).
sub on_possible_raise_chance_or_answer {
	my $hookName = shift;
	my $args = shift;
	return if ($hookName eq 'packet/stat_info' && $args && $args->{type} != 9);
	debug "[raiseStat] Received a raise chance or answer\n";
	changeStatus(ADDING);
}

################################################################
#  getNextStat() is the function responsible for deciding
#  which stat we need to raise next, according to
#  '@stats_to_add', if we still have stats to raise, set it
#  to '$next_stat' and return 1, if we have no stats to raise
#  return 0.
sub getNextStat {
	my $amount;
	foreach my $step (@stats_to_add) {
		$amount = $char->{$step->{'stat'}};
		$amount += $char->{"$step->{'stat'}_bonus"} unless $config{statsAddAuto_dontUseBonus};	
		if ($amount < $step->{'value'}) {
			$next_stat = $step->{'stat'};
			debug "[raiseStat] Decided next stat to raise: '".$next_stat."'\n";
			return 1;
		}
	}
	message "[raiseStat] No more stats to raise; disabling statsAddAuto\n", 'success';
	return 0;
}

################################################################
#  canRaise() is the function responsible for checking if
#  we have enough free points to raise '$next_stat'.
sub canRaise {
    $char->{points_free} and
    $char->{"points_".$next_stat} and
    $char->{points_free} >= $char->{"points_".$next_stat};
}

################################################################
#  on_ai_pre() is called by 'AI_pre' (duh) when status is
#  'ADDING' (2), it checks if we can raise our stats, and
#  if we can't, change plugin status, otherwise calls raiseStat()
sub on_ai_pre {
	return if !$char;
	return if $net->getState != Network::IN_GAME;
	return if !timeOut( $timeout );
	$timeout->{time} = time;
	return changeStatus(INACTIVE) unless (getNextStat());
	unless (canRaise()) {
		debug "[raiseStat] Not enough free points to raise '".$next_stat."'\n";
		return changeStatus(AWAITING_CHANCE_OR_ANSWER);
	}
	debug "[raiseStat] We have enough free points to raise '".$next_stat."'\n";
	raiseStat();
	changeStatus(AWAITING_CHANCE_OR_ANSWER);
}

################################################################
#  raiseStat() sends to the server our stat raise request and
#  prints it on console.
sub raiseStat {
	message "[raiseStat] Auto-adding stat ".$next_stat." to ".($char->{$next_stat}+1)."\n";
	$messageSender->sendAddStatusPoint({
		str => STATUS_STR,
		agi => STATUS_AGI,
		vit => STATUS_VIT,
		int => STATUS_INT,
		dex => STATUS_DEX,
		luk => STATUS_LUK,
	}->{$next_stat});
}

################################################################
#  on_configModify() is called whenever config is changed, it
#  checks if something important to us was changed, and can 
#  change plugin status.
sub on_configModify {
	my (undef, $args) = @_;
	return changeStatus(ADDING) if ($args->{key} eq 'statsAddAuto' && $args->{val} && $config{statsAddAuto_list} && validateSteps($config{statsAddAuto_list}));
	return changeStatus(ADDING) if ($args->{key} eq 'statsAddAuto_list' && $args->{val} && $config{statsAddAuto} && validateSteps($args->{val}));
	return changeStatus(INACTIVE) if ($args->{key} eq 'statsAddAuto_list' || $args->{key} eq 'statsAddAuto');
}

################################################################
#  checkConfig() is called after config is re(loaded), it
#  checks our configuration on config.txt and changes plugin
#  status.
sub checkConfig {
	return changeStatus(ADDING) if ($config{statsAddAuto} && $config{statsAddAuto_list} && validateSteps($config{statsAddAuto_list}));
	return changeStatus(INACTIVE);
}

################################################################
#  validateSteps() is the function responsible for validating 
#  '$config{statsAddAuto_list}', return 0 if errors are found
#  and 1 if everything is okay.
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
	debug "[raiseStat] Configuration set in config.txt is valid\n";
	return 1;
}


return 1;
