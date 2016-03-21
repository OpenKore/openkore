# $Id: Automacro.pm r6760 2009-07-06 02:23:00Z ezza $
package Macro::Automacro;

use strict;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(releaseAM lockAM recheckAM automacroCheck consoleCheckWrapper);
our @EXPORT = qw(checkLocalTime checkVar checkVarVar checkLoc checkPersonGuild checkLevel checkLevel checkClass
	checkPercent checkStatus checkItem checkCond checkCast checkGround checkSpellsID
	checkEquip checkAggressives checkConsole checkMapChange checkMessage checkActor);
	
use Misc qw(whenGroundStatus getSpellName getActorName);
use Utils;
use Globals;
use Skill;
use AI;
use Log qw(message error warning);
use Macro::Data;
use Macro::Utilities qw(between cmpr match getArgs refreshGlobal
	getPlayerID getSoldOut getInventoryAmount getCartAmount getShopAmount
	getStorageAmount callMacro sameParty);

our ($rev) = q$Revision: 6760 $ =~ /(\d+)/;

# check for variable #######################################
sub checkVar {
	my ($var, $cond, $val) = getArgs($_[0]);

	$var = "#$var" if $_[1] eq 'varvar';

	if ($cond eq "unset") {return exists $varStack{$var}?0:1}

	# TODO: seems like this is not needed, because automacroCheck does it
	# and refreshGlobal ignores args
	refreshGlobal($var);

	if (exists $varStack{$var}) {return cmpr($varStack{$var}, $cond, $val)}
	else {return $cond eq "!="}
}

# check for ground statuses
sub checkGround {
	my $arg = $_[0];
	my $not = ($arg =~ s/^not +//)?1:0;
	
	if (whenGroundStatus(calcPosition($char), $arg)) {return $not?0:1}
	return $not?1:0
}

# checks for location ######################################
# parameter: map [x1 y1 [x2 y2]]
# note: when looking in the default direction (north)
# x1 < x2 and y1 > y2 where (x1|y1)=(upper left) and
#                           (x2|y2)=(lower right)
# uses: calcPosition (Utils?)
sub checkLoc {
	my $arg = $_[0];
	if ($arg =~ /,/) {
		my @locs = split(/\s*,\s*/, $arg);
		foreach my $l (@locs) {return 1 if checkLoc($l)}
		return 0
	}
	my $not = ($arg =~ s/^not +//)?1:0;
	my ($map, $x1, $y1, $x2, $y2) = split(/ /, $arg);
	if ($map =~ /^\s*\$/) {
		my ($var) = $map =~ /^\$([a-zA-Z][a-zA-Z\d]*)\s*$/;
		return 0 unless defined $var;
		return 0 unless exists $varStack{$var};
		$map = $varStack{$var}
	}
	if ($map eq $field->baseName || $map eq $field->name) {
		if ($x1 && $y1) {
			my $pos = calcPosition($char);
			return 0 unless defined $pos->{x} && defined $pos->{y};
			if ($x2 && $y2) {
				if (between($x1, $pos->{x}, $x2) && between($y2, $pos->{y}, $y1)) {
					return $not?0:1
				}
				return $not?1:0
			}
			if ($x1 == $pos->{x} && $y1 == $pos->{y}) {
				return $not?0:1
			}
			return $not?1:0
		}
		return $not?0:1
	}
	return $not?1:0
}

# check for pc local time
sub checkLocalTime {
	my ($cond, $val) = $_[0] =~ /^\s*([<>=!]+)\s+(\$[a-zA-Z][a-zA-Z\d]*|\d{2}:\d{2}(?::\d{2})?)\s*$/;
	return 0 if !defined $cond || !defined $val;
	my ($time, $hr, $min, $sec);
	if ($val =~ /^\$/) {
		my ($var) = $val =~ /^\$([a-zA-Z][a-zA-Z\d]*)\s*$/;
		if (exists $varStack{$var}) {$val = $varStack{$var}}
		else {return 0}
	}
	if ($val =~ /^\d{2}:\d{2}(?::\d{2})?\s*$/) {
		($hr, $min, $sec) = split(/:/, $val, 3);
		$sec = 0 if !defined $sec;
	}
	else {message "Wrong time format: hh:mm:ss\n", "menu"; return 0}
	$time = $hr * 3600 + $min * 60 + $sec;
	my ($lc_sec, $lc_min, $lc_hr) = localtime;
	my $lc_time = $lc_hr * 3600 + $lc_min * 60 + $lc_sec;

	return cmpr($lc_time, $cond, $time)?1:0;
}

# check for ($playersList guild) vs (guild.txt or guild list)
sub checkPersonGuild {
	my ($guild, $trigger, $arg) = @_;
	return 0 if !defined $guild || !defined $trigger || !defined $arg;
	
	my $actor = $arg->{player};
	
	return 0 unless defined $actor->{guild};
	my $guildName = $actor->{guild}{name};
	my $dist = $config{clientSight};

	my $not = 0;
	if ($guild =~ /^not\s+/) {$not = 1; $guild =~ s/^not +//g}
	if ($guild =~ /(^.*),\s*(\d+)\s*$/) {$guild = $1; $dist = $2}
	
	return 0 unless (distance(calcPosition($char), calcPosition($actor)) <= $dist);
	
	$varStack{".lastPlayerID"} = undef;
	$varStack{".lastGuildName"} = undef;
	$varStack{".lastGuildNameBinID"} = undef;
	$varStack{".lastGuildNameBinIDDist"} = undef;
	$varStack{".lastGuildNameBinIDName"} = undef;
	$varStack{".lastGuildNameBinIDJobName"} = undef;

	if ($guild eq 'guild.txt') {
		my @gld;
		if (open(FILE, "<", Settings::getControlFilename("guild.txt"))) {
			while (<FILE>) {
				$_ =~ s/\x{FEFF}//g;
				chomp($_);
				next if ($_ =~ /^[\n\r#]/);
				$_ =~ s/  +$/ /; $_ =~ s/^  +/ /;
				push @gld, $_;
			}
			close FILE;
        	}
        	if (@gld) {$guild = join(' , ', @gld)}
        	else {$guild = ''}
        }
        
	if (defined $guild && existsInList($guild, $guildName)) {
		return 0 if $not;
		$varStack{".lastPlayerID"} = unpack("V1", $actor->{ID});
		$varStack{".lastGuildName"} = $guildName;
		$varStack{".lastGuildNameBinID"} = $actor->{binID};
		$varStack{".lastGuildNameBinIDDist"} = sprintf("%.1f", distance(calcPosition($char), calcPosition($actor)));
		$varStack{".lastGuildNameBinIDName"} = $actor->{name};
		$varStack{".lastGuildNameBinIDJobName"} = $jobs_lut{$actor->{jobID}};
		return 1
	}
	elsif (defined $guild && $not) {
		$varStack{".lastPlayerID"} = unpack("V1", $actor->{ID});
		$varStack{".lastGuildName"} = $guildName;
		$varStack{".lastGuildNameBinID"} = $actor->{binID};
		$varStack{".lastGuildNameBinIDDist"} = sprintf("%.1f", distance(calcPosition($char), calcPosition($actor)));
		$varStack{".lastGuildNameBinIDName"} = $actor->{name};
		$varStack{".lastGuildNameBinIDJobName"} = $jobs_lut{$actor->{jobID}};
		return 1;
	}

	return 0
}

# checks for base/job level ################################
# uses cmpr (Macro::Utils)
sub checkLevel {
	my ($cond, $level) = $_[0] =~ /([<>=!]+)\s+(\$[a-zA-Z][a-zA-Z\d]*|\d+|\d+\s*\.{2}\s*\d+)\s*$/;
	if ($level =~ /^\s*\$/) {
		my ($var) = $level =~ /^\$([a-zA-Z][a-zA-Z\d]*)\s*$/;
		return 0 unless defined $var;
		if (exists $varStack{$var}) {$level = $varStack{$var}}
		else {return 0}
	}
	return cmpr($char->{$_[1]}, $cond, $level)
}

# checks for player's jobclass #############################
sub checkClass {
	return 0 unless defined $char;
	my $class = $_[0];
	if ($class =~ /^\s*\$/) {
		my ($var) = $class =~ /^\$([a-zA-Z][a-zA-Z\d]*)\s*$/;
		return 0 unless defined $var;
		if (exists $varStack{$var}) {$class = $varStack{$var}}
		else {return 0}
	}
	if ($class =~ /^\d+$/) {
		return $class == $char->{jobID}?1:0
	} else {
		return lc($class) eq lc($::jobs_lut{$char->{jobID}})?1:0
	}
}

# checks for HP/SP/Weight ##################################
# uses cmpr (Macro::Utils)
sub checkPercent {
	my ($arg, $what) = @_;
	my ($cond, $amount) = $arg =~ /([<>=!]+)\s+(\$[a-zA-Z][a-zA-Z\d]*%?|\d+%?|\d+\s*\.{2}\s*\d+%?)\s*$/;
	if ($what =~ /^(?:hp|sp|weight)$/) {
		return 0 unless (defined $char && defined $char->{$what} && defined $char->{$what."_max"});
		if ($amount =~ /^\s*(?:\d+|\d+\s*\.{2}\s*\d+)%$/ && $char->{$what."_max"}) {
			$amount =~ s/%$//;
			return cmpr(($char->{$what} / $char->{$what."_max"} * 100), $cond, $amount)
		} 
		elsif ($amount =~ /^\s*\$/) {
			my ($var, $percent) = $amount =~ /^\$([a-zA-Z][a-zA-Z\d]*)(%)?\s*/;
			return 0 unless defined $var;
			if ((defined $percent || $percent eq "%") && defined $char->{$what."_max"}) {
				if (exists $varStack{$var}) {
					$amount = $varStack{$var};
					return cmpr(($char->{$what} / $char->{$what."_max"} * 100), $cond, $amount)
				}
			} else {
				if (exists $varStack{$var}) {
					$amount = $varStack{$var};
					return cmpr($char->{$what}, $cond, $amount)
				}
			}
		}
		else {return cmpr($char->{$what}, $cond, $amount)}
	}
	elsif ($what eq 'cweight') {
		return 0 unless (defined $cart{weight} && defined $cart{weight_max});
		if ($amount =~ /^\s*(?:\d+|\d+\s*\.{2}\s*\d+)%$/ && $cart{weight_max}) {
			$amount =~ s/%$//;
			return cmpr(($cart{weight} / $cart{weight_max} * 100), $cond, $amount)
		}
		elsif ($amount =~ /^\s*\$/) {
			my ($var, $percent) = $amount =~ /^\$([a-zA-Z][a-zA-Z\d]*)(%)?\s*/;
			return 0 unless defined $var;
			if ((defined $percent || $percent eq "%") && defined $cart{weight_max}) {
				if (exists $varStack{$var}) {
					$amount = $varStack{$var};
					return cmpr(($cart{weight} / $cart{weight_max} * 100), $cond, $amount)
				}
			} else {
				if (exists $varStack{$var}) {
					$amount = $varStack{$var};
					return cmpr($cart{weight}, $cond, $amount)
				}
			}
		}
		else {return cmpr($cart{weight}, $cond, $amount)}
	}
	return 0
}

# checks for status #######################################
sub checkStatus {
	if ($_[0] =~ /,/) {
		my @statuses = split(/\s*,\s*/, $_[0]);
		foreach my $s (@statuses) {return 1 if checkStatus($s)}
		return 0
	}

	my $status = $_[0];
	return ($status =~ s/^not +//i xor $char->statusActive($status)) if defined $char;
}

# checks for item conditions ##############################
# uses: getInventoryAmount, getCartAmount, getShopAmount,
#       getStorageAmount (Macro::Utils?)
sub checkItem {
	my ($where, $check) = @_;
	$varStack{".lastItem"} = undef;
	$varStack{".lastInvItem"} = undef;
	$varStack{".lastCartItem"} = undef;
	$varStack{".lastShopItem"} = undef;
	$varStack{".lastStorItem"} = undef;
	if ($check =~ /,/) {
		my @checks = split(/\s*,\s*/, $check);
		foreach my $c (@checks) {return 1 if checkItem($where, $c)}
		return 0
	}
	my ($item, $cond, $amount) = getArgs($check);
	if ($item =~ /^\$/) {
		my ($var) = $item =~ /^\$([a-zA-Z][a-zA-Z\d]*)\s*/;
		return 0 unless defined $var;
		if (exists $varStack{$var}) {$item = $varStack{$var}}
		else {return 0}
	}
	if ($item =~ /^(\d+)$/) {
		if (exists $items_lut{$item}) {
			if ($itemSlotCount_lut{$item}) {
				$item = $items_lut{$item}." [".$itemSlotCount_lut{$item}."]";
			} else {
				$item = $items_lut{$item};
			}
		}
	}
	if ($amount =~ /^\$/) {
		my ($var1) = $amount =~ /^\$([a-zA-Z][a-zA-Z\d]*)\s*/;
		return 0 unless defined $var1;
		if (exists $varStack{$var1}) {$amount = $varStack{$var1}}
		else {return 0}
	}
	my $what;
	if ($where eq 'inv')  {$what = getInventoryAmount($item)} # TODO: why is this double checked?
	if ($where eq 'cart') {$what = getCartAmount($item)} # TODO: why is this double checked?
	if ($where eq 'inv')  {return 0 unless (time > $ai_v{'inventory_time'}); $what = getInventoryAmount($item);};
	if ($where eq 'cart') {return 0 unless (time > $ai_v{'cart_time'}); $what = getCartAmount($item)};
	if ($where eq 'shop') {return 0 unless (time > $ai_v{'cart_time'} && $shopstarted); $what = getShopAmount($item)}
	if ($where eq 'stor') {return 0 unless $::storage{openedThisSession}; $what = getStorageAmount($item)}
	my $return = cmpr($what, $cond, $amount)?1:0;
	if ($return) {
		$varStack{".last".ucfirst($where)."Item"} = $item;
		$varStack{".lastItem"} = $item;
	}
	
	return $return;
}

# checks arg1 for condition in arg3 #######################
# uses: cmpr (Macro::Utils)
sub checkCond {
	my ($cond, $amount) = $_[1] =~ /([<>=!]+)\s+(\$[a-zA-Z][a-zA-Z\d]*|\d+|\d+\s*\.{2}\s*\d+)\s*$/;
	if ($amount =~ /^\s*\$/) {
		my ($var) = $amount =~ /^\$([a-zA-Z][a-zA-Z\d]*)\s*$/;
		return 0 unless defined $var;
		if (exists $varStack{$var}) {$amount = $varStack{$var}}
		else {return 0}
	}
	return cmpr($_[0], $cond, $amount)?1:0
}

# checks for equipment ####################################
# equipped <item>, <item2>, ... # equipped item or item2 or ..
# equipped rightHand <item>, rightAccessory <item2>, ... # equipped <item> on righthand etc.
# equipped leftHand none, .. # equipped nothing on lefthand etc.
# see @Item::slots
sub checkEquip {
	if ($_[0] =~ /,/) {
		my @equip = split(/\s*,\s*/, $_[0]);
		foreach my $e (@equip) {return 1 if checkEquip($e)}
		return 0
	}
	my $not;
	my $arg = $_[0];
	if ($arg =~ m/^((?:top|mid|low)Head|(?:left|right)Hand|robe|armor|shoes|(?:left|right)Accessory|arrow)\s+((not)\s+)?(.*)/i) {
		my $match = $4;
		$not = $3?1:0;
		if (my $item = $char->{equipment}{$1}) {
			if ($match =~ /^\d+$/) {
				return ($match == $item->{nameID} xor $not)?1:0
			} else {
				return (lc($match) eq lc($item->name) xor $not)?1:0
			}
		}
		return (lc($match) eq 'none' xor $not)?1:0
	}
	if ($arg =~ /^(not)\s+(.*)$/) { $not = $1; $arg = $2; }
	if ($arg =~ /^\d+$/) {
		foreach my $s (keys %{$char->{equipment}}) {
			next unless $char->{equipment}{$s}->nameID == $arg;
			return 0 if ($not);
			return 1
		}
	} else {
		$arg = lc($arg);
		foreach my $s (keys %{$char->{equipment}}) {
			next unless lc($char->{equipment}{$s}->name) eq $arg;
			return 0 if ($not);
			return 1
		}
	}
	return 1 if ($not);
	return 0
}

# checks for a spell casted on us/party members #########################
# uses: distance, judgeSkillArea (Utils?)
sub checkCast {
	my ($cast, $args) = @_;
	return 0 if $args->{sourceID} eq $accountID;
	
	$cast = lc($cast);
	my $party = ($cast =~ s/^party +//)?1:0;
	my $pos = calcPosition($char);
	my $target = (defined $args->{targetID})?$args->{targetID}:0;
	my $source = $args->{sourceID};
	return 0 if $target eq $source;

	if (($target eq $accountID || ($pos->{x} == $args->{x} && $pos->{y} == $args->{y}) || distance($pos, $args) <= judgeSkillArea($args->{skillID})) && existsInList($cast, lc(Skill->new(idn => $args->{skillID})->getName()))) {
		if (my $actor = $monstersList->getByID($source)) {
			$varStack{".caster"} = "monster";
			$varStack{".casterName"} = $actor->{name};
			$varStack{".casterID"} = $actor->{binID};
			$varStack{".casterPos"} = $actor->{pos_to}{x} ." ". $actor->{pos_to}{y};
			$varStack{".casterDist"} = sprintf("%.1f", distance($pos, calcPosition($actor)))

		}
		elsif (my $actor = $playersList->getByID($source)) {
			$varStack{".caster"} = "player";
			$varStack{".casterName"} = (defined $actor->{name})?$actor->{name}:"Unknown";
			$varStack{".casterID"} = $actor->{binID};
			$varStack{".casterPos"} = $actor->{pos_to}{x} ." ". $actor->{pos_to}{y};
			$varStack{".casterDist"} = sprintf("%.1f", distance($pos, calcPosition($actor)));

		}
		else {return 0}
		$varStack{".casterSkill"} = Skill->new(idn => $args->{skillID})->getName();
		$varStack{".casterTarget"} = $args->{x} ." ". $args->{y};
		$varStack{".casterTargetName"} = $char->{name};
		return 1
	}
	elsif ($party && existsInList($cast, lc(Skill->new(idn => $args->{skillID})->getName()))) {
		return 0 if !$char->{'party'} || !%{$char->{'party'}};
		if (my $actor = $monstersList->getByID($source)) {
			foreach my Actor::Player $player (@{$playersList->getItems()}) {
				next unless sameParty($player->{name});
				if ($target eq $player->{ID} || ($player->{pos_to}{x} == $args->{x} && $player->{pos_to}{y} == $args->{y}) || distance($player->{pos}, $args) <= judgeSkillArea($args->{skillID})) {
					$varStack{".caster"} = "monster";
					$varStack{".casterName"} = $actor->{name};
					$varStack{".casterID"} = $actor->{binID};
					$varStack{".casterPos"} = $actor->{pos_to}{x} ." ". $actor->{pos_to}{y};
					$varStack{".casterSkill"} = Skill->new(idn => $args->{skillID})->getName();
					$varStack{".casterTarget"} = $args->{x} ." ". $args->{y};
					$varStack{".casterTargetName"} = $player->{name};
					$varStack{".casterDist"} = sprintf("%.1f", distance($pos, calcPosition($actor)));
					return 1
				}
			}

		}
		elsif (my $actor = $playersList->getByID($source)) {
			return 0 if sameParty($actor->{name});
			foreach my Actor::Player $player (@{$playersList->getItems()}) {
				next unless sameParty($player->{name});
				if ($target eq $player->{ID} || ($player->{pos_to}{x} == $args->{x} && $player->{pos_to}{y} == $args->{y}) || distance($player->{pos}, $args) <= judgeSkillArea($args->{skillID})) {
					$varStack{".caster"} = "player";
					$varStack{".casterName"} = (defined $actor->{name})?$actor->{name}:"Unknown";
					$varStack{".casterID"} = $actor->{binID};
					$varStack{".casterPos"} = $actor->{pos_to}{x} ." ". $actor->{pos_to}{y};
					$varStack{".casterSkill"} = Skill->new(idn => $args->{skillID})->getName();
					$varStack{".casterTarget"} = $args->{x} ." ". $args->{y};
					$varStack{".casterTargetName"} = $player->{name};
					$varStack{".casterDist"} = sprintf("%.1f", distance($pos, calcPosition($actor)));
					return 1
				}
			}
		}
		else {return 0}
	} 
	else {return 0}
}

# checks for area spell
sub checkSpellsID {
	my ($line, $args) = @_;
	my $dist = $config{clientSight} || 20;
	my ($list, $cond);
	if ($line =~ /^\s*(.*),?\s+([<>=!~]+)\s+(\d+|\d+\s*.{2}\s*\d+)\s*$/) {
		($list, $cond, $dist) = ($1, $2, $3)
	}
	else {$list = $line; $cond = "<="}
	
	foreach (@spellsID) {
		my $spell = $spells{$_};
		my $type = getSpellName($spell->{type});
		my $dist1 = sprintf("%.1f",distance(calcPosition($char), calcPosition($spell)));
		my ($actor, $owner, $ID) = getActorName($spell->{sourceID}) =~ /^(\w+?)\s(.*?)\s\((\d+)\)\s*$/;
		if (existsInList($list, $type) &&
			$args->{x} eq $spell->{'pos'}{'x'} &&
			$args->{y} eq $spell->{'pos'}{'y'} &&
			$args->{sourceID} eq $spell->{sourceID}
		) {
			$varStack{".areaName"} = $type;
			$varStack{".areaActor"} = $actor;
			$varStack{".areaSourceName"} = $owner;
			$varStack{".areaSourceID"} = $ID;
			$varStack{".areaPos"} = sprintf("%d %d %s", $spell->{'pos'}{'x'}, $spell->{'pos'}{'y'}, $field->baseName);
			$varStack{".areaDist"} = $dist1;
			return cmpr($dist1, $cond, $dist)
		}
	}
	return 0
}

# checks for aggressives
sub checkAggressives {
	my ($cond, $amount) = $_[0] =~ /([<>=!]+)\s+(\$[a-zA-Z][a-zA-Z\d]*|\d+|\d+\s*\.{2}\s*\d+)\s*$/;
	if ($amount =~ /^\s*\$/) {
		my ($var) = $amount =~ /^\$([a-zA-Z][a-zA-Z\d]*)\s*$/;
		return 0 unless defined $var;
		if (exists $varStack{$var}) {$amount = $varStack{$var}}
		else {return 0}
	}
	return cmpr(scalar ai_getAggressives, $cond, $amount)
}
# checks for console message
sub checkConsole {
	my ($msg, $arg) = @_;
	$$arg[4] =~ s/[\r\n]*$//;
	if (match($$arg[4],$msg)){
		$varStack{".lastLogMsg"} = $$arg[4];
		return 1
	}
	return 0
}

sub consoleCheckWrapper {
	return unless defined $conState;
	# skip "macro" and "cvsdebug" domains to avoid loops
	return if $_[1] =~ /^(?:macro|cvsdebug)$/;
	# skip debug messages unless macro_allowDebug is set
	return if ($_[0] eq 'debug' && !$::config{macro_allowDebug});
	my @args = @_;
	automacroCheck("log", \@args)
}

# checks for map change
sub checkMapChange {
	return ($_[0] eq 'any' || $_[0] eq '*' || existsInList($_[0], $field->baseName))?1:0
}

sub checkAction  {
	my ($args) = @_;
	return 0 if !$questList;
	if ($_[0] =~ /,/) {
		my @action = split(/\s*,\s*/, $_[0]);
		foreach my $e (@action) {return 1 if checkAction($e)}
		return 0
	}

	my $modifier = ($args =~ s/^not\s//)?1:0;
	my $result = existsInList($args, AI::action());
	return $result xor $modifier;
}

# checks for eval
sub checkEval {
	return if $Settings::lockdown;
	
	#if ($_[0] =~ /;/) {
	#	my @eval = split(/\s*;\s*/, $_[0]);
	#	foreach my $e (@eval) {return 1 if checkEval($e)}
	#	return 0
	#}
	return eval $_[0];
}

sub checkConfigKey {
	my ($args) = @_;
	if ($_[0] =~ /,/) {
		my @key = split(/\s*,\s*/, $_[0]);
		foreach my $e (@key) {return 1 if checkConfigKey($e)}
		return 0
	}
	
	if ($args =~ /^(\S+)\s+((not)\s+)?(.*)$/) {
		my $key = $1;
		my $not = $3;
		my $value = $4;
		if ($value =~ /^\$/) {
			my ($var) = $value =~ /^\$([a-zA-Z][a-zA-Z\d]*)\s*$/;
			return 0 unless defined $var;
			return 0 unless exists $varStack{$var};
			$value = $varStack{$var};
		}
		return 1 if (($config{$key} eq $value || (!$config{$key} && $value eq 'none')) xor $not);
	}
	return 0;
}


sub checkQuest {
    my ($args) = @_;
    if ($_[0] =~ /,/) {
        my @key = split(/\s*,\s*/, $_[0]);
        foreach my $e (@key) {return 1 if checkQuest($e)}
        return 0
    }
    my $questID;
    if ($args =~ /^(\d+)/) { $questID = $1; } else { return 0; }
    $args =~ s/^\d+\s+//;
    if ($args eq "active" || $args eq "inactive") {
        my $WantedStatus = ($args eq "active")?1:0;
        return 1 if (($::questList->{$questID}->{'active'} == 1 && $WantedStatus == 1) || ($::questList->{$questID}->{'active'} == 0 && $WantedStatus == 0) || (!$::questList->{$questID}->{'active'} && $WantedStatus == 0));
    } elsif ($args eq "killed") {
        my @MobIds = keys %{($questList->{$questID})->{missions}};
        return 0 if ($::questList->{$questID}->{'active'} != 1);
        foreach my $MobId (@MobIds) {
			return 0 if (!$::questList->{$questID}->{missions}->{$MobId}->{goal});#On some servers we do not receive the packet that tells us the goal until we kill at least one mob
            return 0 unless ($::questList->{$questID}->{missions}->{$MobId}->{count} == $::questList->{$questID}->{missions}->{$MobId}->{goal});
        }
        return 1;
    } elsif ($args eq "time over" || $args eq "time inside") {
        my $WantedTime = ($args eq "time inside")?1:0;
        return 1 if ($::questList->{$questID}->{'active'} == 1 && (($::questList->{$questID}->{'time'} > time && $WantedTime == 1) || ($::questList->{$questID}->{'time'} < time && $WantedTime == 0)));
    }
    return 0;
}

# releases a locked automacro ##################
sub releaseAM {
	if ($_[0] eq 'all') {
		foreach (keys %automacro) {
			undef $automacro{$_}->{disabled}
		}
		return 1
	}
	if (defined $automacro{$_[0]}) {
		undef $automacro{$_[0]}->{disabled};
		return 1
	}
	return 0
}

# locks an automacro ##################
sub lockAM {
	if ($_[0] eq 'all') {
		foreach (keys %automacro) {
			$automacro{$_}->{disabled} = 1
		}
		return 1
	}
	if (defined $automacro{$_[0]}) {
		$automacro{$_[0]}->{disabled} = 1;
		return 1
	}
	return 0
}

# releases a locked automacro ##################
sub recheckAM {
	if ($_[0] eq 'all') {
		foreach (keys %automacro) {
			undef $automacro{$_}->{rtime}
		}
		return 1
	}
	if (defined $automacro{$_[0]}) {
		undef $automacro{$_[0]}->{rtime};
		return 1
	}
	return 0
}

# checks for near actor ##################################
sub checkActor {
	my ($actorType, $not, $who, $distCond, $dist) = $_[0] =~ /^(\w+)\s+(not|none|except)?\s*(["\/].*?["\/]\w*)?\s*,?\s*([<>=!~]+)?\s*(\d*)/;
	$distCond = "<=" if (!$distCond && $dist > 0);
	my %actorTypes = (
			npc => $npcsList->getItems(),
			player => $playersList->getItems(),
			monster => $monstersList->getItems(),
			pet => $petsList->getItems()
		);
	return 0 if (!exists($actorTypes{$actorType}) || ($not ne 'none' && !$who));
	if ($who =~ /(?<!\\)\$\w+/) {
		my $valu;
		my @val = $who =~ /(?<!\\)(\$\w+)/g;
		foreach (@val) {
			$_ =~ s/^\$//;
			return 0 if (!$varStack{$_});
			$who =~ s/\$$_/$varStack{$_}/;
		}
	}
	foreach my $actor (@{$actorTypes{$actorType}}) {
		next if ($dist && !cmpr(distance($char->{pos_to}, $actor->{pos_to}), $distCond, $dist));
		if ((!$who) || (!match($actor->name, $who) && $not eq 'except') || (match($actor->name, $who) && $not eq 'none')) {
			return 0;
		} elsif ((!match($actor->name, $who) && !$not) || (match($actor->name, $who) && $not eq 'not')) {
			next;
		}
		next if ($not eq 'except' || $not eq 'none');
		next if ($actorType eq 'npc' && $actor->{statuses}->{EFFECTSTATE_BURROW});#Won't trigger on perfect invisible npcs
		my $val = sprintf("%d %d %s", $actor->{pos_to}{x}, $actor->{pos_to}{y}, $field->baseName);
		if ($actorType eq 'npc') {
			$varStack{".lastNpcName"} = $actor->name;
			$varStack{".lastNpcPos"} = $val;
			$varStack{".lastNpcIndex"} = $actor->{binID};
			$varStack{".lastNPcID"} = $actor->{nameID};
		} elsif ($actorType eq 'player') {
			$varStack{".lastPlayerName"} = $actor->name;
			$varStack{".lastPlayerPos"} = $val;
			$varStack{".lastPlayerLevel"} = $actor->{lv};
			$varStack{".lastPlayerJob"} = $actor->job;
			$varStack{".lastPlayerAccountId"} = $actor->{nameID};
			$varStack{".lastPlayerBinId"} = $actor->{binID};
		} elsif ($actorType eq 'monster') {
			$varStack{".lastMonster"} = $actor->{name};
			$varStack{".lastMonsterPos"} = $val;
			$varStack{".lastMonsterDist"} = $dist;
			$varStack{".lastMonsterID"} = $actor->{binID};
			$varStack{".lastMonsterBinID"} = $actor->{binType};
		} elsif ($actorType eq 'pet') {
			$varStack{".lastPetName"} = $actor->name;
			$varStack{".lastPetPos"} = $val;
			$varStack{".lastPetIndex"} = $actor->{binID};
			$varStack{".lastPetType"} = $actor->{type};
		}
		return 1
	}
	return 1 if ($not eq 'none' || $not eq 'except');
	return 0
}

#cheks messages
sub checkMessage {
	my ($condition, $args) = @_;
	my ($sourceType, $notMsg, $MsgCondition, $notActor, $actorCondition, $distCond, $dist) = $condition =~ /^(\w+)\s+(not)?\s*([\/"].*?[\/"]\w*)\s*,?\s*(not)?\s*([\/"].*?[\/"]\w*)?\s*,?\s*([<>=!~]+)?\s*(\d*)/;
	my ($message, $actor);
	if ($sourceType eq 'npc' || $sourceType eq 'self') { $message = $args->{msg}; } else { $message = $args->{Msg}; }
	if ($sourceType eq 'pm' || $sourceType eq 'pub' || $sourceType eq 'party' || $sourceType eq 'guild') { $actor = $args->{MsgUser}; } elsif ($sourceType eq 'npc') { $actor = $args->{name}; } elsif ($sourceType eq 'self') { $actor = $args->{user}; }
	########
	my @val;
	if ($MsgCondition =~ /(?<!\\)\$\w+/) {
		@val = $MsgCondition =~ /(?<!\\)(\$\w+)/g;
		foreach (@val) {
			$_ =~ s/^\$//;
			return 0 if (!$varStack{$_});
			$MsgCondition =~ s/\$$_/$varStack{$_}/;
		}
		undef @val;
	}
	if ($actorCondition && $actorCondition =~ /(?<!\\)\$\w+/) {
		@val = $actorCondition =~ /(?<!\\)(\$\w+)/g;
		foreach (@val) {
			$_ =~ s/^\$//;
			return 0 if (!$varStack{$_});
			$actorCondition =~ s/\$$_/$varStack{$_}/;
		}
		undef @val;
	}
	########
	return 0 if ((!match($message, $MsgCondition) xor $notMsg) || ($actorCondition && (!match($actor, $actorCondition) xor $notActor)));
	if ($dist) {
		my %lol;
		my $counter;
		foreach (@{$playersList->getItems()}) {
			$lol{$_->{name}} = $counter;
		} continue {
			$counter++;
		}
		if (exists($lol{$actor})) {
			$distCond = "<=" if (!$distCond);
			return 0 if (!cmpr(distance($char->{pos_to}, @{$playersList->getItems()}[$lol{$actor}]->{pos_to}), $distCond, $dist));
		} else {
			return 0;
		}
	}
	$varStack{".last".$sourceType."Msg"} = $message;
	$varStack{".last".$sourceType} = $actor if ($actor);
	return 1;
}

#cheks dead targets
sub checkTargetDied {
	my ($cond, $monster) = @_;
	my ($key, $value) = $cond =~ /(.+)\s+(.+)/;
	if ($key eq 'name') {
		return 0 if ($monster->{monster}->{name} ne $value);
	} elsif ($key eq 'name_given') {
		return 0 if ($monster->{monster}->{name_given} ne $value);
	} elsif ($key eq 'nameID') {
		return 0 if ($monster->{monster}->{nameID} != $value);
	} elsif ($key eq 'dmgFromYou') {
		return 0 if (!inRange($monster->{monster}->{dmgFromYou}, $value));
	} elsif ($key eq 'numAtkFromYou') {
		return 0 if (!inRange($monster->{monster}->{numAtkFromYou}, $value));
	} elsif ($key eq 'moblv') {
		return 0 if ($monster->{monster}->{lv} != $value);
	} else {
		return 0;
	}
	$varStack{".lastTargetName"} = $monster->{monster}->{name};
	$varStack{".lastTargetGivenName"} = $monster->{monster}->{name_given};
	$varStack{".lastTargetID"} = $monster->{monster}->{nameID};
	return 1;
}

sub checkCity {
	if (($_[0] && $field->isCity) || (!$_[0] && !$field->isCity)) {
		return 1;
	} else {
		return 0;
	}
}

sub checkProgressBar {
	my ($ourStatus, $wantedStatus) = @_;
	if ($ourStatus == $wantedStatus) {
		return 1;
	} else {
		return 0;
	}
}

sub checkSkillLevel {
	my ($handle, $cond, $amount) = getArgs($_[0]);
	my $skillLevel = $char->getSkillLevel(new Skill(handle => $handle));
	my $return = cmpr($skillLevel, $cond, $amount)?1:0;
	if ($return) {
		$varStack{".lastSkillLevel"} = $skillLevel;
		return 1;
	} else {
		$varStack{".lastSkillLevel"} = undef;
		return 0;
	}
}

sub checkPlugin {
	my ($args) = @_;
	my ($wantedStatus, $pluginName);
	if ($args =~ /(on|off)\s+(.+)/) {
		$wantedStatus = ($1 eq 'on') ? 1 : 0;
		$pluginName = $2;
	} else {
		return 0;
	}
	
	foreach my $plugin (@Plugins::plugins) {
		next unless $plugin;
		if ($plugin->{name} =~ /$pluginName/i) {
			return 1 if ($wantedStatus);
		}
	}
	
	return 0 if ($wantedStatus);
	
	return 1;
}

sub checkLoggedChar {
	my ($slot) = @_;
	return 0 if ($slot !~ /\d+/);
	
	my $charCounter = 0;
	foreach (@chars) {
		next unless (defined $_);
		if ($_->{name} eq $char->{name}) {
			return 1 if ($charCounter == $slot);
			return 0;
		}
	} continue {
		$charCounter++;
	}
	return 0;
}

# parses automacros and checks conditions #################
sub automacroCheck {
	my ($trigger, $args) = @_;
	return unless ($conState == 5 && $char) || $trigger =~ /^(?:charSelectScreen|Network|packet)/;

	# do not run an automacro if there's already a macro running and the running
	# macro is non-interruptible
	return if (defined $queue && !$queue->interruptible);

	refreshGlobal();
	CHKAM:
	foreach my $am (sort {
		($automacro{$a}->{priority} or 0) <=> ($automacro{$b}->{priority} or 0)
	} keys %automacro) {
		next CHKAM if $automacro{$am}->{disabled};

		if (defined $automacro{$am}->{call} && !defined $macro{$automacro{$am}->{call}}) {
			if ($automacro{$am}->{call} =~ /^\$/) {
				my ($varMacroName) = $automacro{$am}->{call} =~ /^\$([a-zA-Z][a-zA-Z\d]*)\s*$/;
				next CHKAM unless defined $varMacroName;
				next CHKAM unless exists $varStack{$varMacroName};
				next CHKAM unless defined $macro{$varStack{$varMacroName}};
			} else {
				error "automacro $am: macro ".$automacro{$am}->{call}." not found.\n";
				$automacro{$am}->{disabled} = 1; return
			}
		}
		
		if (defined $automacro{$am}->{recheck}) {
			$automacro{$am}->{rtime} = 0 unless $automacro{$am}->{rtime};
			my %tmptimer = (timeout => $automacro{$am}->{recheck}, time => $automacro{$am}->{rtime});
			next CHKAM unless timeOut(\%tmptimer)
		}
		
		if (defined $automacro{$am}->{timeout}) {
			$automacro{$am}->{time} = 0 unless $automacro{$am}->{time};
			my %tmptimer = (timeout => $automacro{$am}->{timeout}, time => $automacro{$am}->{time});
			next CHKAM unless timeOut(\%tmptimer)
		}
		
		$automacro{$am}->{rtime} = time if $automacro{$am}->{recheck};

		if (defined $automacro{$am}->{hook}) {
			next CHKAM unless $trigger eq $automacro{$am}->{hook};
			# save arguments
			my $s = 0;
			foreach my $save (@{$automacro{$am}->{save}}) {
				if (defined $args->{$save}) {
					if (ref($args->{$save}) eq 'SCALAR') {
						$varStack{".hooksave$s"} = ${$args->{$save}}
					} else {
						if (!$::config{macro_nowarn} && ref($args->{$save}) ne '') {
							warning "[macro] \$.hooksave$s is of type ".ref($args->{$save}).". Take care!\n"
						}
						$varStack{".hooksave$s"} = $args->{$save}
					}
				} else {
					error "[macro] \$args->{$save} does not exist\n"
				}
				$s++
			}
		} elsif (defined $automacro{$am}->{console}) {
			if ($trigger eq 'log') {
				next CHKAM unless checkConsole($automacro{$am}->{console}, $args)
			} else {next CHKAM}
		} elsif (defined $automacro{$am}->{spell}) {
			if ($trigger =~ /^(?:is_casting|packet_skilluse)$/) {
			next CHKAM unless checkCast($automacro{$am}->{spell}, $args)
			} else {next CHKAM}
		} elsif (defined $automacro{$am}->{message}) {
			if (($trigger eq 'npc_talk' && $automacro{$am}->{message} =~ /^npc/) ||
				($trigger eq 'packet_privMsg' && $automacro{$am}->{message} =~ /^pm/) ||
				($trigger eq 'packet_pubMsg' && $automacro{$am}->{message} =~ /^pub/) ||
				($trigger eq 'packet_sysMsg' && $automacro{$am}->{message} =~ /^sys/) ||
				($trigger eq 'packet_partyMsg' && $automacro{$am}->{message} =~ /^party/) ||
				($trigger eq 'packet_selfChat' && $automacro{$am}->{message} =~ /^self/) ||
				($trigger eq 'packet_localBroadcast' && $automacro{$am}->{message} =~ /^local/) ||
				($trigger eq 'packet_guildMsg' && $automacro{$am}->{message} =~ /^guild/)
				){
					next CHKAM unless checkMessage($automacro{$am}->{message}, $args)
			} else {next CHKAM}
		} elsif (defined $automacro{$am}->{mapchange}) {
			if ($trigger eq 'packet_mapChange') {
			next CHKAM unless checkMapChange($automacro{$am}->{mapchange})
			} else {next CHKAM}
		} elsif (defined $automacro{$am}->{playerguild}) {
 			if (($trigger eq 'player') || ($trigger eq 'charNameUpdate')) {
			next CHKAM unless checkPersonGuild($automacro{$am}->{playerguild},$trigger,$args)
			} else {next CHKAM}
		} elsif (defined $automacro{$am}->{areaSpell}) {
			if ($trigger eq 'packet_areaSpell') {
			next CHKAM unless checkSpellsID($automacro{$am}->{areaSpell}, $args)
			} else {next CHKAM}
		} elsif (defined $automacro{$am}->{targetdied}) {
			if ($trigger eq 'target_died') {
			next CHKAM unless checkTargetDied($automacro{$am}->{targetdied}, $args)
			} else {next CHKAM}
		}

		next CHKAM if (defined $automacro{$am}->{map}    && $automacro{$am}->{map} ne $field->baseName);
		next CHKAM if (defined $automacro{$am}->{class}  && !checkClass($automacro{$am}->{class}));
		next CHKAM if (defined $automacro{$am}->{whenGround} && !checkGround($automacro{$am}->{whenGround}));
		next CHKAM if (defined $automacro{$am}->{incity} && !checkCity($automacro{$am}->{incity}));
		next CHKAM if (defined $automacro{$am}->{progress_bar} && !checkProgressBar($char->{progress_bar} || 0, $automacro{$am}->{progress_bar}));
		
		foreach my $i (@{$automacro{$am}->{eval}})		 {next CHKAM unless checkEval($i)}
		foreach my $i (@{$automacro{$am}->{action}})	 {next CHKAM unless checkAction($i)}
		foreach my $i (@{$automacro{$am}->{aggressives}}){next CHKAM unless checkAggressives($i)}
		foreach my $i (@{$automacro{$am}->{location}})   {next CHKAM unless checkLoc($i)}
		foreach my $i (@{$automacro{$am}->{localtime}})  {next CHKAM unless checkLocalTime($i, "")}
		foreach my $i (@{$automacro{$am}->{config}}) 	 {next CHKAM unless checkConfigKey($i)}
		foreach my $i (@{$automacro{$am}->{quest}}) 	 {next CHKAM unless checkQuest($i)}
		foreach my $i (@{$automacro{$am}->{var}})        {next CHKAM unless checkVar($i, "")}
		foreach my $i (@{$automacro{$am}->{varvar}})     {next CHKAM unless checkVar($i, "varvar")}
		foreach my $i (@{$automacro{$am}->{base}})       {next CHKAM unless checkLevel($i, "lv")}
		foreach my $i (@{$automacro{$am}->{job}})        {next CHKAM unless checkLevel($i, "lv_job")}
		foreach my $i (@{$automacro{$am}->{hp}})         {next CHKAM unless checkPercent($i, "hp")}
		foreach my $i (@{$automacro{$am}->{sp}})         {next CHKAM unless checkPercent($i, "sp")}
		foreach my $i (@{$automacro{$am}->{spirit}})     {next CHKAM unless checkCond($char->{spirits} || 0, $i)}
		foreach my $i (@{$automacro{$am}->{weight}})     {next CHKAM unless checkPercent($i, "weight")}
		foreach my $i (@{$automacro{$am}->{cartweight}}) {next CHKAM unless checkPercent($i, "cweight")}
		foreach my $i (@{$automacro{$am}->{soldout}})    {next CHKAM unless checkCond(getSoldOut(), $i)}
		foreach my $i (@{$automacro{$am}->{zeny}})       {next CHKAM unless checkCond($char->{zeny}, $i)}
		foreach my $i (@{$automacro{$am}->{cash}})       {next CHKAM unless checkCond($cashShop{points}->{cash}?$cashShop{points}->{cash}:0, $i)}
		foreach my $i (@{$automacro{$am}->{equipped}})   {next CHKAM unless checkEquip($i)}
		foreach my $i (@{$automacro{$am}->{status}})     {next CHKAM unless checkStatus($i)}
		foreach my $i (@{$automacro{$am}->{actor}})      {next CHKAM unless checkActor($i)}
		foreach my $i (@{$automacro{$am}->{inventory}})  {next CHKAM unless checkItem("inv", $i)}
		foreach my $i (@{$automacro{$am}->{storage}})    {next CHKAM unless checkItem("stor", $i)}
		foreach my $i (@{$automacro{$am}->{shop}})       {next CHKAM unless checkItem("shop", $i)}
		foreach my $i (@{$automacro{$am}->{cart}})       {next CHKAM unless checkItem("cart", $i)}
		foreach my $i (@{$automacro{$am}->{skilllvl}})   {next CHKAM unless checkSkillLevel($i)}
		foreach my $i (@{$automacro{$am}->{plugin}})     {next CHKAM unless checkPlugin($i)}
		foreach my $i (@{$automacro{$am}->{loggedchar}}) {next CHKAM unless checkLoggedChar($i)}

		message "[macro] automacro $am triggered.\n", "macro";

		unless (defined $automacro{$am}->{call} || $::config{macro_nowarn}) {
			warning "[macro] automacro $am: call not defined.\n", "macro"
		}

		$automacro{$am}->{time} = time  if $automacro{$am}->{timeout};
		$automacro{$am}->{disabled} = 1 if $automacro{$am}->{'run-once'};

		foreach my $i (@{$automacro{$am}->{set}}) {
			my ($var, $val) = $i =~ /^(.*?)\s+(.*)/;
			$varStack{$var} = $val
		}

		if (defined $automacro{$am}->{call}) {
			undef $queue if defined $queue;
			if ($automacro{$am}->{call} =~ /^\$/) {
				my ($callVar) = $automacro{$am}->{call} =~ /^\$([a-zA-Z][a-zA-Z\d]*)\s*$/;
				$queue = new Macro::Script($varStack{$callVar});
			} else {
				$queue = new Macro::Script($automacro{$am}->{call});
			}
			if (defined $queue) {
				$queue->overrideAI(1) if $automacro{$am}->{overrideAI};
				$queue->interruptible(0) if $automacro{$am}->{exclusive};
				$queue->orphan($automacro{$am}->{orphan}) if defined $automacro{$am}->{orphan};
				$queue->timeout($automacro{$am}->{delay}) if $automacro{$am}->{delay};
				$queue->setMacro_delay($automacro{$am}->{macro_delay}) if $automacro{$am}->{macro_delay};
				$varStack{".caller"} = $am;
				$onHold = 0;
				callMacro
			} else {
				error "unable to create macro queue.\n"
			}
		}

		return # don't execute multiple macros at once
	}
}

1;
