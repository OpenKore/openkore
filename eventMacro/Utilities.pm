# $Id: Utilities.pm r6812 2009-07-29 14:00:00Z ezza $
package eventMacro::Utilities;

use strict;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(ai_isIdle q4rx q4rx2 between cmpr match getArgs refreshGlobal getnpcID getPlayerID
	getMonsterID getVenderID getItemIDs getItemPrice getInventoryIDs getStorageIDs getSoldOut getInventoryAmount
	getCartAmount getShopAmount getStorageAmount getVendAmount getRandom getRandomRange getConfig
	getWord call_macro getArgFromList getListLenght sameParty processCmd parse_syntax_condition_operator_plus_number_or_variable validate_code_number_operator_compare_number_or_variable);

use Utils;
use Globals;
use AI;
use Log qw(message error warning debug);

use eventMacro::Core;
use eventMacro::Data;
use eventMacro::Lists;
use eventMacro::Automacro;
use eventMacro::FileParser;

our ($rev) = q$Revision: 6812 $ =~ /(\d+)/;

# own ai_Isidle check that excludes deal
sub ai_isIdle {
	return 1 if $eventMacro->{Macro_Runner}->overrideAI;

	# now check for orphaned script object
	# may happen when messing around with "ai clear" and stuff.
	if (defined $eventMacro->{Macro_Runner} && !AI::inQueue('macro')) {
		my $method = $eventMacro->{Macro_Runner}->orphan;

		# 'terminate' undefs the macro object and returns "ai is not idle"
		if ($method eq 'terminate') {
			if ( !$eventMacro->{Macro_Runner}->interruptible && $eventMacro->get_automacro_checking_status() == 1 ) {
				message "[eventMacro] Uninterruptible macro '".$eventMacro->{Macro_Runner}->get_name()."' ended. Automacros will return to being checked.\n";
				$eventMacro->set_automacro_checking_status(0);
			}
			undef $eventMacro->{Macro_Runner};
			return 0
		# 'reregister' re-inserts "macro" in ai_queue at the first position
		} elsif ($method eq 'reregister') {
			$eventMacro->{Macro_Runner}->register;
			return 1
		# 'reregister_safe' waits until AI is idle then re-inserts "macro"
		} elsif ($method eq 'reregister_safe') {
			if (AI::isIdle || AI::is('deal')) {
				$eventMacro->{Macro_Runner}->register;
				return 1
			}
			return 0
		} else {
			error "unknown 'orphan' method. terminating macro\n", "macro";
			if ( !$eventMacro->{Macro_Runner}->interruptible && $eventMacro->get_automacro_checking_status() == 1 ) {
				message "[eventMacro] Uninterruptible macro '".$eventMacro->{Macro_Runner}->get_name()."' ended. Automacros will return to being checked.\n";
				$eventMacro->set_automacro_checking_status(0);
			}
			undef $eventMacro->{Macro_Runner};
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
	my ($a, $cond, $b) = @_;
	unless (defined $a && defined $cond && defined $b) {
		# this produces a warning but that's what we want
		error "cmpr: wrong # of arguments ($a) ($cond) ($b)\n", "macro";
		return 0
	}

	if ($a =~ /^\s*(-?[\d.]+)\s*\.{2}\s*(-?[\d.]+)\s*$/) {
		my ($a1, $a2) = ($1, $2);
		if ($b =~ /^-?[\d.]+$/) {
			if ($cond eq "!=") {return (between($a1, $b, $a2))?0:1}
			if ($cond eq "=" || $cond eq "==" || $cond eq "=~" || $cond eq "~") {
				return between($a1, $b, $a2)
			}
		}
		error "cmpr: wrong # of arguments ($a) ($cond) ($b)\n--> ($b) <-- maybe should be numeric?\n", "macro";
		return 0
	}

	if ($b =~ /^\s*(-?[\d.]+)\s*\.{2}\s*(-?[\d.]+)\s*$/) {
		my ($b1, $b2) = ($1, $2);
		if ($a =~ /^-?[\d.]+$/) {
			if ($cond eq "!=") {return (between($b1, $a, $b2))?0:1}
			if ($cond eq "=" || $cond eq "==" || $cond eq "=~" || $cond eq "~") {
				return between($b1, $a, $b2)
			}
		}
		error "cmpr: wrong # of arguments ($a) ($cond) ($b)\n--> ($a) <-- maybe should be numeric?\n", "macro";
		return 0
	}

	if ($a =~ /^-?[\d.]+$/ && $b =~ /^-?[\d.]+$/) {
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
	if ($cond eq "=~" && $b =~ /^\/.*?\/\w?\s*$/) {
		return match($a, $b, 1)
	}

	return 0
}

sub q4rx {
	my $s = $_[0];
	$s =~ s/([\/*+(){}\[\]\\\$\^?])/\\$1/g;
	return $s
}

sub q4rx2 {
	# We let alone the original q4rx sub routine... 
	# instead, we use this for our new @nick ;p
	my $s = $_[0];
	$s =~ s/([\/*+(){}\[\]\\\$\^?"'\. ])/\\$1/g;
	return $s
}

sub match {
	my ($text, $kw, $cmpr) = @_;

	unless (defined $text && defined $kw) {
		# this produces a warning but that's what we want
		error "match: wrong # of arguments ($text) ($kw)\n", "macro";
		return 0
	}

	if ($kw =~ /^"(.*?)"$/) {
		return $text eq $1
	}

	if ($kw =~ /^\/(.*?)\/(\w?)$/) {
		if ($text =~ /$1/ || ($2 eq 'i' && $text =~ /$1/i)) {
			if (!defined $cmpr) {
				no strict;
				foreach my $idx (1..$#-) {$eventMacro->set_var(".lastMatch$idx",${$idx})}
				use strict;
			}
			return 1
		}
	}

	return 0
}

sub getArgs {
	my $arg = $_[0];
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
	my ($message, $wordno) = $_[0] =~ /^"(.*?)"\s*,\s?(\d+|\$[a-zA-Z][a-zA-Z\d]*)$/s;
	my @words = split(/[ ,.:;\"\'!?\r\n]/, $message);
	my $no = 1;
	if ($wordno =~ /^\$/) {
		my ($val) = $wordno =~ /^\$([a-zA-Z][a-zA-Z\d]*)\s*$/;
		return "" unless defined $val;
		if ($eventMacro->exists_var($val) && $eventMacro->get_var($val) =~ /^[1-9][0-9]*$/) {$wordno = $eventMacro->get_var($val)}
		else {return ""}
	
	}
	foreach (@words) {
		next if /^$/;
		return $_ if $no == $wordno;
		$no++
	}
	return ""
}

# gets openkore setting
sub getConfig {
	my ($arg1) = $_[0] =~ /^\s*(\w*\.*\w+)\s*$/;
	# Basic Support for "label" in blocks. Thanks to "piroJOKE" (from Commands.pm, sub cmdConf)
	if ($arg1 =~ /\./) {
		$arg1 =~ s/\.+/\./; # Filter Out Unnececary dot's
		my ($label, $param) = split /\./, $arg1, 2; # Split the label form parameter
		foreach (%::config) {
			if ($_ =~ /_\d+_label/){ # we only need those blocks witch have labels
				if ($::config{$_} eq $label) {
					my ($real_key, undef) = split /_label/, $_, 2;
					# "<label>.block" param support. Thanks to "vit"
					if ($param ne "block") {
						$real_key .= "_";
						$real_key .= $param;
					}
					$arg1 = $real_key;
					last;
				};
			};
		};
	};
	return (defined $::config{$arg1})?$::config{$arg1}:"";
}

# sets and/or refreshes global variables
sub refreshGlobal {
	my $var = $_[0];

	$eventMacro->set_var(".time", time);
	$eventMacro->set_var(".datetime", scalar localtime);
	my ($sec, $min, $hour) = localtime;
	$eventMacro->set_var(".second", $sec);
	$eventMacro->set_var(".minute", $min);
	$eventMacro->set_var(".hour", $hour);
	
	return unless $net && $net->getState == Network::IN_GAME;
	
	$eventMacro->set_var(".map", (defined $field)?$field->baseName:"undef");
	my $pos = calcPosition($char); 
	$eventMacro->set_var(".pos", sprintf("%d %d", $pos->{x}, $pos->{y}));
	
	$eventMacro->set_var(".hp", $char->{hp});
	$eventMacro->set_var(".sp", $char->{sp});
	$eventMacro->set_var(".lvl", $char->{lv});
	$eventMacro->set_var(".joblvl", $char->{lv_job});
	$eventMacro->set_var(".spirits", ($char->{spirits} or 0));
	$eventMacro->set_var(".zeny", $char->{zeny});
	$eventMacro->set_var(".weight", $char->{weight});
	$eventMacro->set_var(".maxweight", $char->{weight_max});
	$eventMacro->set_var('.status', (join ',',
		('muted')x!!$char->{muted},
		('dead')x!!$char->{dead},
		map { $statusName{$_} || $_ } keys %{$char->{statuses}}
	) || 'none');
}

# get NPC array index
sub getnpcID {
	my $arg = $_[0];
	my ($what, $a, $b);

	if (($a, $b) = $arg =~ /^\s*(\d+) (\d+)\s*$/) {$what = 1}
	elsif (($a, $b) = $arg =~ /^\s*\/(.+?)\/(\w?)\s*$/) {$what = 2}
	elsif (($a) = $arg =~ /^\s*"(.*?)"\s*$/) {$what = 3}
	else {return -1}
	
	my @ids;	
	foreach my $npc (@{$npcsList->getItems()}) {
		if ($what == 1) {return $npc->{binID} if ($npc->{pos}{x} == $a && $npc->{pos}{y} == $b)}
		elsif ($what == 2) {
			if ($npc->{name} =~ /$a/ || ($b eq "i" && $npc->{name} =~ /$a/i)) {push @ids, $npc->{binID}}
		}
		else {return $npc->{binID} if $npc->{name} eq $a}
	}
	if (@ids) {return join ',', @ids}
	return -1
}

# get player array index
sub getPlayerID {
	foreach my $pl (@{$playersList->getItems()}) {
		return $pl->{binID} if $pl->name eq $_[0]
	}
	return -1
}

# get monster array index
sub getMonsterID {
	foreach my $ml (@{$monstersList->getItems()}) {
		return $ml->{binID} if ($ml->name eq $_[0] || $ml->{binType} eq $_[0]);
	}
	return -1
}

# get vender array index
sub getVenderID {
	for (my $i = 0; $i < @::venderListsID; $i++) {
		next if $::venderListsID[$i] eq "";
		my $player = Actor::get($::venderListsID[$i]);
		return $i if $player->name eq $_[0]
	}
	return -1
}

# get inventory item ids
# checked and ok
sub getInventoryIDs {
	return unless $char->inventory->size();
	my $find = lc($_[0]);
	my @ids;
	foreach my $item (@{$char->inventory->getItems}) {
		if (lc($item->name) eq $find) {push @ids, $item->{invIndex}}
	}
	unless (@ids) {push @ids, -1}
	return @ids
}

# get item array index
# works for $cart{'inventory'}, @articles
sub getItemIDs {
	my ($item, $pool) = (lc($_[0]), $_[1]);
	my @ids;
	for (my $id = 0; $id < @{$pool}; $id++) {
		next unless $$pool[$id];
		if (lc($$pool[$id]{name}) eq $item) {push @ids, $id}
	}
	unless (@ids) {push @ids, -1}
	return @ids
}

# get item price from its index
# works with @venderprice
# returns -1 if no shop is being visited
sub getItemPrice {
	my ($itemIndex, $pool) = ($_[0], $_[1]);
	my $price = -1;
	if ($$pool[$itemIndex]) {$price = $$pool[$itemIndex]{price}}
	return $price
}

# get storage array index
# returns -1 if no matching items in storage
sub getStorageIDs {
	my $item = lc($_[0]);
	my @ids;
	for (my $id = 0; $id < @storageID; $id++) {
		next unless $storageID[$id];
		if (lc($storage{$storageID[$id]}{name}) eq $item) {push @ids, $id}
	}
	unless (@ids) {push @ids, -1}
	return @ids
}

# get amount of sold out slots
sub getSoldOut {
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
	my $arg = lc($_[0]);
	my $amount = 0;
	foreach my $item (@{$char->inventory->getItems}) {
		if (lc($item->name) eq $arg) {$amount += $item->{amount}}
	}
	return $amount
}

# get amount of an item in cart
sub getCartAmount {
	my $arg = lc($_[0]);
	return 0 unless $cart{'inventory'};
	my $amount = 0;
	for (my $id = 0; $id < @{$cart{'inventory'}}; $id++) {
		next unless $cart{'inventory'}[$id];
		if (lc($cart{'inventory'}[$id]{'name'}) eq $arg) {$amount += $cart{'inventory'}[$id]{amount}}
	}
	return $amount
}

# get amount of an item in your shop
sub getShopAmount {
	my $arg = lc($_[0]);
	my $amount = 0;
	foreach my $aitem (@::articles) {
		next unless $aitem;
		if (lc($aitem->{name}) eq $arg) {$amount += $aitem->{quantity}}
	}
	return $amount
}

# get amount of an item in storage
# returns -1 if the storage is closed
sub getStorageAmount {
	my $arg = lc($_[0]);
	return -1 unless $::storage{opened};
	my $amount = 0;
	for (my $id = 0; $id < @storageID; $id++) {
		next unless $storageID[$id];
		if (lc($storage{$storageID[$id]}{name}) eq $arg) {$amount += $storage{$storageID[$id]}{amount}}
	}
	return $amount
}

# get amount of items for the specifical index in another venders shop
# returns -1 if no shop is being visited
sub getVendAmount {
	my ($itemIndex, $pool) = ($_[0], $_[1]);
	my $amount = -1;
	if ($$pool[$itemIndex]) {$amount = $$pool[$itemIndex]{amount}}
	return $amount
}

# returns random item from argument list
sub getRandom {
	my $arg = $_[0];
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

# returns given argument from a comma separated list
# returns -1 if no such listID exists or when the list is empty or wrong
sub getArgFromList {
	my ($listID, $list) = split(/, \s*/, $_[0]);
	my @items = split(/,\s*/, $list);
	unless (@items) {
		warning "[macro] wrong syntax in \@listItem\n", "macro";
		return -1
	}
	if ($items[$listID]) {
	return $items[$listID]
		} else {
		warning "[macro] the $listID number item does not exist in the list\n", "macro";
		return -1
	}
}

# returns the lenght of a comma separated list
sub getListLenght {
	my $list = $_[0];
	my @items = split(/,\s*/, $list);
	return scalar(@items)
}

# check if player is in party
sub sameParty {
	my $player = shift;
	for (my $i = 0; $i < @partyUsersID; $i++) {
		next if $partyUsersID[$i] eq "";
		next if $partyUsersID[$i] eq $accountID;
		return 1 if $char->{'party'}{'users'}{$partyUsersID[$i]}{'name'} eq $player
	}
	return 0
}

# returns random number within the given range  ###########
sub getRandomRange {
	my ($low, $high) = split(/,\s*/, $_[0]);
	return int(rand($high-$low+1))+$low if (defined $high && defined $low)
}

sub processCmd {
	my $command = $_[0];
	if (defined $_[0]) {
		if ($_[0] ne '') {
			unless (Commands::run($command)) {
				my $errorMsg = sprintf("[macro] %s failed with %s\n", $eventMacro->{Macro_Runner}->name, $command);
				
				my $hookArgs = {
					'message' => $errorMsg,
					'name' => $eventMacro->{Macro_Runner}->name,
					'error' => 'Commands::run failed',
				};
				Plugins::callHook ('macro/error', $hookArgs);
				return $hookArgs->{continue} if $hookArgs->{return};
				
				error $errorMsg, "macro";
				if ( !$eventMacro->{Macro_Runner}->interruptible && $eventMacro->get_automacro_checking_status() == 1 ) {
					message "[eventMacro] Uninterruptible macro '".$eventMacro->{Macro_Runner}->get_name()."' ended. Automacros will return to being checked.\n";
					$eventMacro->set_automacro_checking_status(0);
				}
				undef $eventMacro->{Macro_Runner};
				return
			}
		}
		$eventMacro->{Macro_Runner}->ok;
		if (defined $eventMacro->{Macro_Runner} && $eventMacro->{Macro_Runner}->finished) {undef $eventMacro->{Macro_Runner}}
	} else {
		my $name = (defined $eventMacro->{Macro_Runner}->{subcall}) ? $eventMacro->{Macro_Runner}->{subcall}->name : $eventMacro->{Macro_Runner}->name;
		my $error = $eventMacro->{Macro_Runner}->error;
		my $errorMsg = sprintf(
			"[macro] %s error: %s\n",
			$name =~ /^tempMacro\d+$/ && $eventMacro->is_var_defined('.caller') ? $eventMacro->get_var('.caller').'.call' : $name,
			$error
		);
		
		my $hookArgs = {
			'message' => $errorMsg,
			'name' => $name,
			'error' => $error,
		};
		Plugins::callHook ('macro/error', $hookArgs);
		return $hookArgs->{continue} if $hookArgs->{return};
		
		error $errorMsg, "macro";
		if ( !$eventMacro->{Macro_Runner}->interruptible && $eventMacro->get_automacro_checking_status() == 1 ) {
			message "[eventMacro] Uninterruptible macro '".$eventMacro->{Macro_Runner}->get_name()."' ended. Automacros will return to being checked.\n";
			$eventMacro->set_automacro_checking_status(0);
		}
		undef $eventMacro->{Macro_Runner};
		return
	}
	
	return 1;
}

sub parse_syntax_condition_operator_plus_number_or_variable {
	my ($condition_code, $code_operator_ref, $code_number_ref, $variables_ref) = @_;
	if ($condition_code =~ /([<>=!]+)\s+(\$[a-zA-Z][a-zA-Z\d]*|\d+|\d+\s*\.{2}\s*\d+)\s*$/) {
		$$code_operator_ref = $1;
		my $code_level = $2;
		if ($code_level =~ /^\s*\$/) {
			my ($var) = $code_level =~ /^\$([a-zA-Z][a-zA-Z\d]*)\s*$/;
			return 0 unless (defined $var);
			$$code_number_ref = $var;
			push (@{$variables_ref}, $var);
		} else {
			$$code_number_ref = $code_level;
		}
		return 1;
	}
	return 0;
}

sub validate_code_number_operator_compare_number_or_variable {
	my ($compare_number, $code_operator, $code_number, $is_variable) = @_;
	
	if ($is_variable) {
		my $variable_value = $eventMacro->get_var($code_number);
		if (defined $variable_value) {
			return cmpr($compare_number, $code_operator, $variable_value);
		} else {
			return 0;
		}
	} else {
		return cmpr($compare_number, $code_operator, $code_number);
	}
}

1;
