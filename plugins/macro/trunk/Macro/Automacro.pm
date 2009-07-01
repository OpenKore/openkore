# $Id: Automacro.pm r6752 2009-07-01 11:42:00Z ezza $
package Macro::Automacro;

use strict;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(releaseAM lockAM automacroCheck consoleCheckWrapper);
our @EXPORT = qw(checkLocalTime checkVar checkVarVar checkLoc checkPersonGuild checkLevel checkLevel checkClass
	checkPercent checkStatus checkItem checkPerson checkCond checkCast checkGround checkSpellsID
	checkEquip checkMsg checkMonster checkAggressives checkConsole checkMapChange checkNotMonster);
	
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

our ($rev) = q$Revision: 6752 $ =~ /(\d+)/;

# check for variable #######################################
sub checkVar {
	my ($var, $cond, $val) = getArgs($_[0]);

	$var = "#$var" if $_[1] eq 'varvar';

	if ($cond eq "unset") {return exists $varStack{$var}?0:1}

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
	if ($map eq $field->name) {
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
	
	my $actor;
	
	if ($trigger eq 'charNameUpdate') {$actor = $arg}
	else {$actor = $arg->{player}}
	
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
				#chomp($_);
				next if ($_ =~ /^[\n\r#]/);
				#$_ =~ /^(.*)$/;
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
	return 0 unless defined $char->{jobID};
	my $class = $_[0];
	if ($class =~ /^\s*\$/) {
		my ($var) = $class =~ /^\$([a-zA-Z][a-zA-Z\d]*)\s*$/;
		return 0 unless defined $var;
		if (exists $varStack{$var}) {$class = $varStack{$var}}
		else {return 0}
	}
	return lc($class) eq lc($::jobs_lut{$char->{jobID}})?1:0
}

# checks for HP/SP/Weight ##################################
# uses cmpr (Macro::Utils)
sub checkPercent {
	my ($arg, $what) = @_;
	my ($cond, $amount) = $arg =~ /([<>=!]+)\s+(\$[a-zA-Z][a-zA-Z\d]*%?|\d+%?|\d+\s*\.{2}\s*\d+%?)\s*$/;
	if ($what =~ /^(?:hp|sp|weight)$/) {
		return 0 unless (defined $char->{$what} && defined $char->{$what."_max"});
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

	my $status = lc($_[0]);
	my $not = ($status =~ s/^not +//)?1:0;

	foreach (split(',', $varStack{".status"})) {
		if (lc($_) eq $status) {return $not?0:1}
	}
	return $not?1:0
}

# checks for item conditions ##############################
# uses: getInventoryAmount, getCartAmount, getShopAmount,
#       getStorageAmount (Macro::Utils?)
sub checkItem {
	my ($where, $check) = @_;
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
	if ($amount =~ /^\$/) {
		my ($var1) = $amount =~ /^\$([a-zA-Z][a-zA-Z\d]*)\s*/;
		return 0 unless defined $var1;
		if (exists $varStack{$var1}) {$amount = $varStack{$var1}}
		else {return 0}
	}
	my $what;
	if ($where eq 'inv')  {$what = getInventoryAmount($item)}
	if ($where eq 'cart') {$what = getCartAmount($item)}
	if ($where eq 'shop') {return 0 unless $shopstarted; $what = getShopAmount($item)}
	if ($where eq 'stor') {return 0 unless $::storage{opened}; $what = getStorageAmount($item)}

	return cmpr($what, $cond, $amount)?1:0
}

# checks for near person ##################################
sub checkPerson {
	my ($who, $dist) = $_[0] =~ /^(["\/].*?["\/]\w*)\s*,?\s*(.*)/;

	foreach my $player (@{$playersList->getItems()}) {
		next unless match($player->name, $who);
		if ($dist > 0) {
			return (distance($char->{pos_to}, $player->{pos_to}) <= $dist)?1:0
		}
		return 1
	}
	return 0
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

	my $arg = $_[0];

	if ($arg =~ m/^((?:top|mid|low)Head|(?:left|right)Hand|robe|armor|shoes|(?:left|right)Accessory|arrow)\s+(.*)/i) {
		if (my $item = $char->{equipment}{$1}) {
			return lc($2) eq lc($item->name)?1:0
		}
		return lc($2) eq 'none'?1:0
	}

	$arg = lc($arg);
	foreach my $s (keys %{$char->{equipment}}) {
		next unless lc($char->{equipment}{$s}->name) eq $arg;
		return 1
	}
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

# checks for public, private, party or guild message ######
# uses calcPosition, distance (Utils?)
sub checkMsg {
	my ($var, $tmp, $arg) = @_;
	my $msg;
	if ($var eq '.lastpub') {
		($msg, my $distance) = $tmp =~ /^([\/"].*?[\/"]\w*)\s*,?\s*(\d*)/;
		if ($distance ne '') {
			my $mypos = calcPosition($char);
			my $pos = calcPosition($::players{$arg->{pubID}});
			return 0 unless distance($mypos, $pos) <= $distance
		}
	} elsif ($var eq '.lastpm') {
		($msg, my $allowed) = $tmp =~ /^([\/"].*?[\/"]\w*)\s*,?\s*(.*)/;
		my $auth;
		if (!$allowed) {
			$auth = 1
		} else {
			my @tfld = split(/,/, $allowed);
			for (my $i = 0; $i < @tfld; $i++) {
				next unless defined $tfld[$i];
				$tfld[$i] =~ s/(?:^ +| +$)//g;
				if ($arg->{privMsgUser} eq $tfld[$i]) {$auth = 1; last}
			}
		}
		return 0 unless $auth
	} else {
		$msg = $tmp
	}

	$arg->{Msg} =~ s/[\r\n]*$//g;
	if (match($arg->{Msg},$msg)){
		$varStack{$var} = $arg->{MsgUser};
		$varStack{$var."Msg"} = $arg->{Msg};
		return 1
	}
	return 0
}

# checks for area spell
sub checkSpellsID {
	my ($line, $args) = @_;
	my $dist = $config{clientSight} || 20;
	my ($list, $cond);
	if ($line =~ /^\s*(.*),?\s+([<>=!~]+)\s+(\d+|\d+\s+.{2}\s+\d+)\s*$/) {
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
			$varStack{".areaPos"} = sprintf("%d %d %s", $spell->{'pos'}{'x'}, $spell->{'pos'}{'y'}, $field->{name});
			$varStack{".areaDist"} = $dist1;
			return cmpr($dist1, $cond, $dist)
		}
	}
	return 0
}

# checks for monster ...
sub checkMonster {
	my $line = $_[0];
	my ($not, $mercenary, $use, $monsterList, $cond);
	my $mondist = $config{clientSight} || 20;

	if ($line =~ /^\s*(.*),?\s+([<>=!~]+)\s+(\d+|\d+\s+.{2}\s+\d+)\s*$/) {
		($monsterList, $cond, $mondist) = ($1, $2, $3)
	} else {
		$monsterList = $line;
		$cond = "<="
	}

	if ($monsterList =~ /^(not|mercenary)\s+(.*)\s*$/) {
		if ($1 eq "not") {$not = 1; $monsterList = $2}
		else {$mercenary = 1; $use = 1; $monsterList = $2}
	}

	foreach (@monstersID) {
		next unless defined $_;
		if ($mercenary) {
			#Whose the mercenary's master,
			#update later ;p
			my $mypos = calcPosition($char);
			my $pos = calcPosition($monsters{$_});
			my $dist = sprintf("%.1f",distance($pos, $mypos));
			if (existsInList($monsterList, $monsters{$_}->{name}) && $dist < 3) {$use = 0; last}
		}
		elsif ($not) {
			next if existsInList($monsterList, $monsters{$_}->{name});
			my $mypos = calcPosition($char);
			my $pos = calcPosition($monsters{$_});
			my $dist = sprintf("%.1f",distance($pos, $mypos));
			my $val = sprintf("%d %d %s", $pos->{x}, $pos->{y}, $field->{name});
			$varStack{".lastMonster"} = $monsters{$_}->{name};
			$varStack{".lastMonsterPos"} = $val;
			$varStack{".lastMonsterDist"} = $dist;
			$varStack{".lastMonsterID"} = $monsters{$_}->{binID};
			return cmpr($dist, $cond, $mondist)
		} else {
			if (existsInList($monsterList, $monsters{$_}->{name})) {
				my $counter;
				my $mypos = calcPosition($char);
				my $pos = calcPosition($monsters{$_});
				my $dist = sprintf("%.1f", distance($mypos, $pos));
				my $val = sprintf("%d %d %s", $pos->{x}, $pos->{y}, $field->{name});
				$varStack{".lastMonster"} = $monsters{$_}->{name};
				$varStack{".lastMonsterPos"} = $val;
				$varStack{".lastMonsterDist"} = $dist;
				$varStack{".lastMonsterID"} = $monsters{$_}->{binID};
				for (my $i = 0; $i < @::monstersID; $i++) {
					next if $::monstersID[$i] eq "";
					my $monster = Actor::get($::monstersID[$i]);
					if ($monster->name eq $monsters{$_}->{name}) {
						if ($monster->{binID} eq $monsters{$_}->{binID}) {
							$counter++;
							next
						} else {
							my $monsToMonDist = sprintf("%.1f",distance($pos, $monster->{pos_to}));
							$counter++ if $monsToMonDist < 12;
							next
						}
					}
					next
				}
				$varStack{".lastMonsterCount"} = $counter;
				return cmpr($dist, $cond, $mondist)
			}
		}
	}
	return 1 if ($use);
	return 0
}

# checks for forbidden monster
# quick hack, maybe combine it with checkMonster later
sub checkNotMonster {
	my $mondist = $config{clientSight};
	my $monsterList = $_[0];
	if ($monsterList =~ /,\s+\d+\s*$/) {
		$mondist = $monsterList =~ /,\s+(\d+)\s*$/;
		$monsterList = s/, +\d+\s*$//g;
	}
	foreach (@monstersID) {
		next unless defined $_;
		next if existsInList($monsterList, $monsters{$_}->{name});
		my $mypos = calcPosition($char);
		my $pos = calcPosition($monsters{$_});
		my $dist = sprintf("%.1f",distance($pos, $mypos));
		return $dist <= $mondist ?1:0
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
	return ($_[0] eq 'any' || $_[0] eq '*' || existsInList($_[0], $field->name))?1:0
}

# checks for eval
sub checkEval {
	if ($_[0] =~ /;/) {
		my @eval = split(/\s*;\s*/, $_[0]);
		foreach my $e (@eval) {return 1 if checkEval($e)}
		return 0
	}
	return eval $_[0];
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

# parses automacros and checks conditions #################
sub automacroCheck {
	my ($trigger, $args) = @_;
	return unless $conState == 5 || $trigger =~ /^(?:charSelectScreen|Network)/;

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
			error "automacro $am: macro ".$automacro{$am}->{call}." not found.\n";
			$automacro{$am}->{disabled} = 1; return
		}

		if (defined $automacro{$am}->{timeout}) {
			$automacro{$am}->{time} = 0 unless $automacro{$am}->{time};
			my %tmptimer = (timeout => $automacro{$am}->{timeout}, time => $automacro{$am}->{time});
			next CHKAM unless timeOut(\%tmptimer)
		}

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
		} elsif (defined $automacro{$am}->{pm}) {
			if ($trigger eq 'packet_privMsg') {
			next CHKAM unless checkMsg(".lastpm", $automacro{$am}->{pm}, $args)
			} else {next CHKAM}
		} elsif (defined $automacro{$am}->{pubm}) {
			if ($trigger eq 'packet_pubMsg') {
			next CHKAM unless checkMsg(".lastpub", $automacro{$am}->{pubm}, $args)
			} else {next CHKAM}
		} elsif (defined $automacro{$am}->{party}) {
			if ($trigger eq 'packet_partyMsg') {
			next CHKAM unless checkMsg(".lastparty", $automacro{$am}->{party}, $args)
			} else {next CHKAM}
		} elsif (defined $automacro{$am}->{guild}) {
			if ($trigger eq 'packet_guildMsg') {
			next CHKAM unless checkMsg(".lastguild", $automacro{$am}->{guild}, $args)
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
		}

		next CHKAM if (defined $automacro{$am}->{map}    && $automacro{$am}->{map} ne $field->name);
		next CHKAM if (defined $automacro{$am}->{class}  && !checkClass($automacro{$am}->{class}));
		next CHKAM if (defined $automacro{$am}->{notMonster} && !checkNotMonster($automacro{$am}->{notMonster}));
		next CHKAM if (defined $automacro{$am}->{eval} && !checkEval($automacro{$am}->{eval}));
		next CHKAM if (defined $automacro{$am}->{whenGround} && !checkGround($automacro{$am}->{whenGround}));
		
		foreach my $i (@{$automacro{$am}->{monster}})    {next CHKAM unless checkMonster($i)}
		foreach my $i (@{$automacro{$am}->{aggressives}}){next CHKAM unless checkAggressives($i)}
		foreach my $i (@{$automacro{$am}->{location}})   {next CHKAM unless checkLoc($i)}
		foreach my $i (@{$automacro{$am}->{localtime}})  {next CHKAM unless checkLocalTime($i, "")}
		foreach my $i (@{$automacro{$am}->{var}})        {next CHKAM unless checkVar($i, "")}
		foreach my $i (@{$automacro{$am}->{varvar}})     {next CHKAM unless checkVar($i, "varvar")}
		foreach my $i (@{$automacro{$am}->{base}})       {next CHKAM unless checkLevel($i, "lv")}
		foreach my $i (@{$automacro{$am}->{job}})        {next CHKAM unless checkLevel($i, "lv_job")}
		foreach my $i (@{$automacro{$am}->{hp}})         {next CHKAM unless checkPercent($i, "hp")}
		foreach my $i (@{$automacro{$am}->{sp}})         {next CHKAM unless checkPercent($i, "sp")}
		foreach my $i (@{$automacro{$am}->{spirit}})     {next CHKAM unless checkCond($char->{spirits} or 0, $i)}
		foreach my $i (@{$automacro{$am}->{weight}})     {next CHKAM unless checkPercent($i, "weight")}
		foreach my $i (@{$automacro{$am}->{cartweight}}) {next CHKAM unless checkPercent($i, "cweight")}
		foreach my $i (@{$automacro{$am}->{soldout}})    {next CHKAM unless checkCond(getSoldOut(), $i)}
		foreach my $i (@{$automacro{$am}->{zeny}})       {next CHKAM unless checkCond($char->{zenny}, $i)}
		foreach my $i (@{$automacro{$am}->{player}})     {next CHKAM unless checkPerson($i)}
		foreach my $i (@{$automacro{$am}->{equipped}})   {next CHKAM unless checkEquip($i)}
		foreach my $i (@{$automacro{$am}->{status}})     {next CHKAM unless checkStatus($i)}
		foreach my $i (@{$automacro{$am}->{inventory}})  {next CHKAM unless checkItem("inv", $i)}
		foreach my $i (@{$automacro{$am}->{storage}})    {next CHKAM unless checkItem("stor", $i)}
		foreach my $i (@{$automacro{$am}->{shop}})       {next CHKAM unless checkItem("shop", $i)}
		foreach my $i (@{$automacro{$am}->{cart}})       {next CHKAM unless checkItem("cart", $i)}

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
			$queue = new Macro::Script($automacro{$am}->{call});
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
