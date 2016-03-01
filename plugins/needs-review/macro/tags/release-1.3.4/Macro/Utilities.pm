package Macro::Utilities;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(ai_isIdle between cmpr match getArgs setVar getVar refreshGlobal getnpcID getPlayerID
	getItemIDs getStorageIDs getSoldOut getInventoryAmount getCartAmount getShopAmount getStorageAmount
	getRandom getRandomRange getConfig getWord callMacro);

use Utils;
use Globals;
use AI;
use Log qw(warning error);
use Macro::Data;

our $Changed = sprintf("%s %s %s",
	q$Date: 2006-08-29 12:26:56 +0200 (di, 29 aug 2006) $
	=~ /(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}) ([+-]\d{4})/);
      
my $orphanWarn = 1;

# own ai_Isidle check that excludes deal
sub ai_isIdle {
	return 1 if $queue->overrideAI;

	# now check for orphaned script object
	# may happen when messing around with "ai clear" and stuff.
	if (defined $queue && !AI::inQueue('macro')) {
		my $method = $queue->orphan;
		if ($orphanWarn) {
			error "[macro] orphaned macro!\n", "macro";
			warning "found an active macro '".$queue->name."' but no 'macro' record in ai queue\n", "macro";
			warning "using method '$method' to solve this problem\n", "macro";
			$orphanWarn = 0
		}

		# 'terminate' undefs the macro object and returns "ai is not idle"
		if ($method eq 'terminate') {
			undef $queue;
			$orphanWarn = 1;
			return 0
		# 'reregister' re-inserts "macro" in ai_queue at the first position
		} elsif ($method eq 'reregister') {
			$queue->register;
			$orphanWarn = 1;
			return 1
		# 'reregister_safe' waits until AI is idle then re-inserts "macro"
		} elsif ($method eq 'reregister_safe') {
			if (AI::isIdle || AI::is('deal')) {
				$queue->register;
				$orphanWarn = 1;
				return 1
			}
			return 0
		# everything else terminates the macro (default behaviour)
		} else {
			warning "unknown method. terminating macro\n", "macro";
			undef $queue;
			$orphanWarn = 1;
			return 0
		}
	}
	return AI::is('macro', 'deal')
}

sub between {
	if ($_[0] <= $_[1] && $_[1] <= $_[2]) {return 1}
	return 0
}

sub cmpr {
	$cvs->debug("cmpr (@_)", $logfac{function_call_auto});
	my ($a, $cond, $b) = @_;
	unless (defined $a && defined $cond && defined $b) {
		error "cmpr: wrong # of arguments\n", "macro";
		return 0
	}

	if ($a =~ /^[\d.]+$/ && $b =~ /^[\d.]+$/) {
		if (($cond eq "=" || $cond eq "==") && $a == $b) {return 1}
		if ($cond eq ">=" && $a >= $b) {return 1}
		if ($cond eq "<=" && $a <= $b) {return 1}
		if ($cond eq ">"  && $a > $b)  {return 1}
		if ($cond eq "<"  && $a < $b)  {return 1}
		if ($cond eq "!=" && $a != $b) {return 1}
		return 0
	}
	if (($cond eq "=" || $cond eq "==") && $a eq $b) {return 1}
	if ($cond eq "!=" && $a ne $b) {return 1}
	if ($cond eq "~") {
		$a = lc($a);
		foreach my $e (split(/,/, $b)) {return 1 if $a eq lc($e)}
	}
	return 0
}

sub match {
	$cvs->debug("match (@_)", $logfac{function_call_auto});
	my ($text, $kw) = @_;

	unless (defined $text && defined $kw) {
		error "match: wrong # of args\n", "macro";
		return 0
	}

	my $match;
	my $flag;
  
	if ($kw =~ /^".*"$/) {$match = 0}
	elsif ($kw =~ /^\/.*\/\w?$/) {$match = 1}
	else {return 0}
	($kw, $flag) = $kw =~ /^[\/"](.*?)[\/"](\w?)/;
  
	if ($match == 0 && $text eq $kw) {return 1}
	if ($match == 1 && ($text =~ /$kw/ || ($flag eq 'i' && $text =~ /$kw/i))) {
		no strict;
		foreach my $idx (1..$#-) {setVar(".lastMatch".$idx, ${$idx})}
		use strict;
		return 1
	}

	return 0
}

sub getArgs {
	my $arg = shift;
	if ($arg =~ /".*"/) {
		my @ret = $arg =~ /^"(.*?)"\s+(.*?)( .*)?$/;
		$ret[2] =~ s/^\s+//g if defined $ret[2];
		return @ret
	} else {
		return split(/\s/, $arg, 3)
	}
}

# gets word from message
sub getWord {
	$cvs->debug("getWord(@_)", $logfac{function_call_macro});
	my $arg = shift;
	my ($message, $wordno) = $arg =~ /^"(.*?)",\s?(\d+)$/s;
	my @words = split(/[ ,.:;"'!?\r\n]/, $message);
	my $no = 1;
	foreach (@words) {
		next if /^$/;
		return $_ if ($no == $wordno);
		$no++
	}
	return ""
}

# gets openkore setting
sub getConfig {
	$cvs->debug("getConfig(@_)", $logfac{function_call_macro});
	my $setting = shift;
	return (defined $::config{$setting})?$::config{$setting}:""
}

# adds variable and value to stack
sub setVar {
	my ($var, $val) = @_;
	$cvs->debug("'$var' = '$val'", $logfac{variable_trace});
	$varStack{$var} = $val;
	return 1
}

# gets variable's value from stack
sub getVar {
	my $var = shift;
	refreshGlobal($var);
	return unless defined $varStack{$var};
	return $varStack{$var}
}

# sets and/or refreshes global variables
sub refreshGlobal {
	my $var = shift;

	if (!defined $var || $var eq '.map') {
		setVar(".map", $field{name})
	}

	if (!defined $var || $var eq '.pos') {
		my $pos = calcPosition($char);
		my $val = sprintf("%d %d", $pos->{x}, $pos->{y});
		setVar(".pos", $val)
	}

	if (!defined $var || $var eq '.time') {
		setVar(".time", time)
	}

	if (!defined $var || $var eq '.datetime') {
		setVar(".datetime", scalar localtime)
	}
	
	if (!defined $var || $var eq '.hp') {
		setVar(".hp", $char->{hp})
	}
	
	if (!defined $var || $var eq '.sp') {
		setVar(".sp", $char->{sp})
	}
	
	if (!defined $var || $var eq '.lvl') {
		setVar(".lvl", $char->{lv})
	}

	if (!defined $var || $var eq '.joblvl') {
		setVar(".joblvl", $char->{lv_job})
	}

	if (!defined $var || $var eq '.spirits') {
		setVar(".spirits", ($char->{spirits} or 0))
	}

	if (!defined $var || $var eq '.zeny') {
		setVar(".zeny", $char->{zenny})
	}

	if (!defined $var || $var eq '.status') {
		my @statuses;
		if ($char->{muted}) {push @statuses, "muted"}
		if ($char->{dead}) {push @statuses, "dead"}
		foreach (keys %{$char->{statuses}}) {push @statuses, $_}
		setVar(".status", join ',', @statuses)
	}
}

# get NPC array index
sub getnpcID {
	$cvs->debug("getnpcID(@_)", $logfac{function_call_macro});
	my ($tmpx, $tmpy) = split(/ /,$_[0]);
	for (my $id = 0; $id < @npcsID; $id++) {
		next unless $npcsID[$id];
		if ($npcs{$npcsID[$id]}{pos}{x} == $tmpx &&
			$npcs{$npcsID[$id]}{pos}{y} == $tmpy) {return $id}
	}
	return -1
}

## getPlayerID(name, r_array)
# get player array index
sub getPlayerID {
	$cvs->debug("getPlayerID(@_)", $logfac{function_call_macro} | $logfac{function_call_auto});
	my ($name, $pool) = @_;
	for (my $id = 0; $id < @{$pool}; $id++) {
		next unless $$pool[$id];
		next unless $players{$$pool[$id]}->{name};
		if ($players{$$pool[$id]}->{name} eq $name) {return $id}
	}
	return -1
}

# get item array index
sub getItemIDs {
	$cvs->debug("getItemIDs(@_)", $logfac{function_call_macro} | $logfac{function_call_auto});
	my ($item, $pool) = @_;
	my @ids;
	for (my $id = 0; $id < @{$pool}; $id++) {
		next unless $$pool[$id];
		if (lc($$pool[$id]{name}) eq lc($item)) {push @ids, $id}
	}
	unless (@ids) {push @ids, -1}
	return @ids
}

# get storage array index
sub getStorageIDs {
	$cvs->debug("getStorageIDs(@_)", $logfac{function_call_macro} | $logfac{function_call_auto});
	my $item = shift;
	my @ids;
	for (my $id = 0; $id < @storageID; $id++) {
		next unless $storageID[$id];
		if (lc($storage{$storageID[$id]}{name}) eq lc($item)) {push @ids, $id}
	}
	unless (@ids) {push @ids, -1}
	return @ids
}

# get amount of sold out slots
sub getSoldOut {
	$cvs->debug("getSoldOut(@_)", $logfac{function_call_auto});
	return 0 unless $shopstarted;
	my $soldout = 0;
	foreach my $aitem (@::articles) {
		next unless $aitem;
		if ($aitem->{quantity} == 0) {$soldout++}
	}
	return $soldout
}

# get amount of an item in inventory
sub getInventoryAmount {
	$cvs->debug("getInventoryAmount(@_)", $logfac{function_call_macro} | $logfac{function_call_auto});
	my $item = shift;
	return 0 unless $char->{inventory};
	my @ids = getItemIDs($item, \@{$char->{inventory}});
	my $amount = 0;
	foreach my $id (@ids) {
		next unless $id >= 0;
		$amount += $char->{inventory}[$id]{amount}
	}
	return $amount
}

# get amount of an item in cart
sub getCartAmount {
	$cvs->debug("getCartAmount(@_)", $logfac{function_call_macro} | $logfac{function_call_auto});
	my $item = shift;
	return 0 unless $cart{inventory};
	my @ids = getItemIDs($item, \@{$cart{inventory}});
	my $amount = 0;
	foreach my $id (@ids) {
		next unless $id >= 0;
		$amount += $cart{inventory}[$id]{amount}
	}
	return $amount
}

# get amount of an item in shop
sub getShopAmount {
	$cvs->debug("getShopAmount(@_)", $logfac{function_call_macro} | $logfac{function_call_auto});
	my $item = shift;
	my $amount = 0;
	foreach my $aitem (@::articles) {
		next unless $aitem;
		if (lc($aitem->{name}) eq lc($item)) {$amount += $aitem->{quantity}}
	}
	return $amount
}

# get amount of an item in storage
sub getStorageAmount {
	$cvs->debug("getStorageAmount(@_)", $logfac{function_call_macro} | $logfac{function_call_auto});
	my $item = shift;
	return 0 unless $::storage{opened};
	my @ids = getStorageIDs($item);
	my $amount = 0;
	foreach my $id (@ids) {
		next unless $id >= 0;
		$amount += $storage{$storageID[$id]}{amount}
	}
	return $amount
}

# returns random item from argument list ##################
sub getRandom {
	$cvs->debug("getRandom(@_)", $logfac{function_call_macro});
	my $arg = shift;
	my @items;
	my $id = 0;
	while (($items[$id++]) = $arg =~ /^[, ]*"(.*?)"/) {
		$arg =~ s/^[, ]*".*?"//g;
	}
	pop @items;
	unless (@items) {
		warning "[macro] wrong syntax in \@random\n", "macro";
		return
	}
	return $items[rand $id-1]
}

# returns random number within the given range  ###########
sub getRandomRange {
	$cvs->debug("getRandomRange(@_)", $logfac{function_call_macro});
	my ($low, $high) = split(/,\s*/, $_[0]);
	return int(rand($high-$low+1))+$low if (defined $high && defined $low)
}

sub processCmd {
	$cvs->debug("processCmd (@_)", $logfac{developers});
	my $command = shift;
	if (defined $command) {
		if ($command ne '') {
			unless (Commands::run($command)) {
				error(sprintf("[macro] %s failed with %s\n", $queue->name, $command), "macro");
				undef $queue;
				return
			}
		}
		$queue->ok;
		if (defined $queue && $queue->finished) {undef $queue}
	} else {
		error(sprintf("[macro] %s error: %s\n", $queue->name, $queue->error), "macro");
		warning "the line number may be incorrect if you called a sub-macro.\n", "macro";
		undef $queue
	}
}

# macro/script
sub callMacro {
	return unless defined $queue;
	return if $onHold;
	my %tmptime = $queue->timeout;
	unless ($queue->registered || $queue->overrideAI) {
		if (timeOut(\%tmptime)) {$queue->register}
		else {return}
	}
	if (timeOut(\%tmptime) && ai_isIdle()) {
		my $command = $queue->next;
		if ($queue->macro_block) {
			while ($queue->macro_block) {
				$command = $queue->next;
				processCmd($command)
			}
		} else {
			processCmd($command)
		}
	}
}

1;
