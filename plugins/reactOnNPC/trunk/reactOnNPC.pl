# =======================
# reactOnNPC v.2.0.2
# =======================
# This plugin is licensed under the GNU GPL
# Copyright 2006 by hakore [mod by windows98SE and ya4ept]
#
# http://forums.openkore.com/viewtopic.php?f=34&t=198
# http://sourceforge.net/p/openkore/code/HEAD/tree/plugins/reactOnNPC/trunk/
#
# Example (put in config.txt):
#
# reactOnNPC_debug 1
# reactOnNPC talk text @eval(my $color1 = '#1~1';my $color2 = '#3~1';if ($color1 eq $color2@) {return '#3~2'}) {
#	type text
#	useColors 1
#	respIgnoreColor 1
#	delay 2
#	msg_0 /Bot Checking.../
#	msg_1 /Enter the \^([0-9a-fA-F]{6})RED COLOR\^000000 Code./
#	msg_2 /^\s$/
#	msg_3 /\s+\^([0-9a-fA-F]{6})(\S+)\^[0-9a-fA-F]{6}\s+/
# Shared SelfCondition (see http://openkore.com/index.php/Category:Self_Condition):
#	disabled 0
#	whenStatusActive 
#	whenStatusInactive
#	onAction
#	notOnAction
#	inMap
#	notInMap
#	inLockOnly
#	notInTown
#	timeout
#	notWhileSitting
#	manualAI
#	whenIdle
#	hp
#	sp
#	weight
#	zeny
#	spirit
#	amuletType
#	homunculus
#	homunculus_hp
#	homunculus_sp
#	homunculus_dead
#	homunculus_resting
#	mercenary
#	mercenary_hp
#	mercenary_sp
#	mercenary_whenStatusActive
#	mercenary_whenStatusInactive
#	aggressives
#	partyAggressives
#	stopWhenHit
#	whenFollowing
#	monstersCount
#	monsters
#	notMonsters
#	defendMonsters
#	inInventory
#	inCart
#	whenGround
#	whenNotGround
#	whenPermitSkill
#	whenNotPermitSkill
#	onlyWhenSafe
#	whenEquipped
#	whenNotEquipped
#	whenWater
#	equip_leftAccessory
#	equip_rightAccessory
#	equip_leftHand
#	equip_rightHand
#	equip_robe
#	whenFlag
#	whenNotFlag
# }

package reactOnNPC;

use strict;
use Plugins;
use Globals qw(%config);
use Log qw(message);
use Utils qw (timeOut);

Plugins::register('reactOnNPC', "react on NPC messages", \&Unload, \&Unload);

my $hooks = (
	Plugins::addHooks(
		['packet/npc_talk', \&onNPCTalk, undef],
		['packet/npc_talk_close', \&onNPCAction, undef],
		['packet/npc_talk_continue', \&onNPCAction, undef],
		['packet/npc_talk_number', \&onNPCAction, undef],
		['packet/npc_talk_responses', \&onNPCAction, undef],
		['packet/npc_talk_text', \&onNPCAction, undef],
		['mainLoop_pre', \&onCheckCmd, undef]
	)
);

my %reactOnNPC;
my @reactOnNPC;

sub Unload {
	Plugins::delHooks($hooks);
	undef %reactOnNPC;
	undef @reactOnNPC;
	message "reactOnNPC plugin unloading or reloading\n", 'success';
};

sub onNPCTalk {
	return if !$config{"reactOnNPC_0"};
	my (undef, $args) = @_;
	my $ID = unpack("V", substr($args->{RAW_MSG}, 4, 4));
	my $msg = unpack("Z*", substr($args->{RAW_MSG}, 8));

	$msg = I18N::bytesToString($msg);

	if (!%reactOnNPC || $reactOnNPC{action}) {
		undef %reactOnNPC if %reactOnNPC;
		$reactOnNPC{index} = 0;
		$reactOnNPC{ID} = $ID;
		$reactOnNPC{msg}[$reactOnNPC{index}] = $msg;
	} else {
		$reactOnNPC{index}++;
		$reactOnNPC{msg}[$reactOnNPC{index}] = $msg;
	}
	message "[reactOnNPC] NPC message saved ($reactOnNPC{index}): \"$msg\".\n", "plugin" if $config{"reactOnNPC_debug"};
}

sub onNPCAction {
	return if !$config{"reactOnNPC_0"};
	my $type = substr(shift, 16);
	$reactOnNPC{action} = $type;
	message "[reactOnNPC] onNPCAction type is: $type.\n", "plugin" if $config{"reactOnNPC_debug"};

	if ($type eq 'responses') {
		my $args = shift;
		my $msg = unpack("Z*", substr($args->{RAW_MSG}, 8));
		$msg = I18N::bytesToString($msg);
		undef @{$reactOnNPC{responses}};
		my @responses = split /:/, $msg;
		foreach (@responses) {
			push @{$reactOnNPC{responses}}, $_ if $_ ne "";
		}
	}

	my $i = 0;
	while (exists $config{"reactOnNPC_$i"}) {
		if ($config{"reactOnNPC_${i}_type"} && $config{"reactOnNPC_${i}_type"} ne $type) {
			# Report if type not met
			message "[reactOnNPC] Conditions for reactOnNPC_$i (npc:${type}, rect:".$config{"reactOnNPC_${i}_type"}.") 'type' not met.\n", "plugin" if $config{"reactOnNPC_debug"};
			$i++;
			next;
		} elsif (!main::checkSelfCondition("reactOnNPC_$i")) {
			# Report if checkSelfCondition not met
			message "[reactOnNPC] Conditions for reactOnNPC_$i 'checkSelfCondition' not met.\n", "plugin" if $config{"reactOnNPC_debug"};
			$i++;
			next;
		}
		# Report if  checkSelfCondition and type met <Yee ha!!>
		message "[reactOnNPC] Conditions for reactOnNPC_$i (npc:${type} , rect:".$config{"reactOnNPC_${i}_type"}.") is met.\n", "plugin" if $config{"reactOnNPC_debug"};
		my $j = 0;
		my $ok = 1;
		while (exists $config{"reactOnNPC_${i}_msg_$j"}) {
			my $msg;
			if (exists $reactOnNPC{msg}[$j]) {
				$msg = $reactOnNPC{msg}[$j];
				# Remove RO color codes
				$msg =~ s/\^[a-fA-F0-9]{6}//g unless ($config{"reactOnNPC_${i}_useColors"});
			}
			if (!defined $msg || !match("msg", $j, $msg, $config{"reactOnNPC_${i}_msg_$j"})) {
				message "[reactOnNPC] One or more lines doesn't match for \"reactOnNPC_$i\" ($j).\n", "plugin" if $config{"reactOnNPC_debug"};
				$ok = 0;
				last;
			}
			$j++;
		}

		if ($ok) {
			my $cmd = $config{"reactOnNPC_$i"};
			$cmd =~ s/#(\d+)~(\d+)/$reactOnNPC{match}[$1][$2]/g;
			my $kws = 'eval|resp';
			while (my ($kw, $expr) = $cmd =~ /\@($kws)\(((?:(?!(?<!\@)\@$kws\().)+?)(?<!\@)\)/) {
				my $eval;
				my $eval_expr = $expr;
				$eval_expr =~ s/\@(?=[\@)])//g;
				if ($kw eq 'eval') {
					$eval = eval $eval_expr;
				} elsif ($kw eq 'resp') {
					my $k = 0;
					foreach my $rIC (@{$reactOnNPC{responses}}){
						# Remove RO color codes <npc response>
						$rIC =~ s/\^[a-fA-F0-9]{6}//g if($config{"reactOnNPC_${i}_respIgnoreColor"});
						if (match("response", $k, $rIC, $eval_expr)) {
							last;
						}
						$k++;
					}
				$eval = $k;
				}
				$expr = quotemeta $expr;
				$cmd =~ s/\@$kw\($expr\)/$eval/g;
			}
			if (my $delay = $config{"reactOnNPC_${i}_delay"}) {
				my $params = {
					cmd => $cmd,
					time => time,
					timeout => $delay
				};
				message "[reactOnNPC] React to NPC with delay. Execute command \"$cmd\" after $delay seconds.\n", "plugin" if $config{"reactOnNPC_debug"};
				push @reactOnNPC, $params;
				undef %reactOnNPC;
			} else {
				message "[reactOnNPC] Reacting to NPC. Executing command \"$cmd\".\n", "success";
				undef %reactOnNPC;
				Commands::run($cmd);
			}
			last;
		}
		$i++;
	}
	undef %reactOnNPC if $type eq 'close';
}

sub onCheckCmd {
	for (my $i = 0; $i < @reactOnNPC; $i++) {
		my $args = $reactOnNPC[$i];
		if (timeOut($args->{time}, $args->{timeout})) {
			message "[reactOnNPC] Reacting to NPC. Executing command \"".$args->{cmd}."\".\n", "success";
			Commands::run($args->{cmd});
			undef @reactOnNPC;
		}
	}
}

sub match {
	my ($type, $line, $subject, $pattern) = @_;
	# $head for report matching in one line ^^"
	my $head = "[reactOnNPC] Matching [$type ($line)] \"$subject\" to \"$pattern\" ...";
	if (my ($re, $ci) = $pattern =~ /^\/(.+?)\/(i?)$/) {
		if (($ci && $subject =~ /$re/i) || (!$ci && $subject =~ /$re/)) {
			if (defined $line) {
				no strict;
				foreach my $index (1..$#-) {
					$reactOnNPC{match}[$line][$index] = ${$index};
				}
			}
			message "$head regexp ok.\n", "plugin" if $config{"reactOnNPC_debug"};
			return 1;
		}
	} elsif ($subject eq $pattern) {
		message "$head ok.\n", "plugin" if $config{"reactOnNPC_debug"};
		return 1;
	}
	message "$head doesn't match.\n", "plugin" if $config{"reactOnNPC_debug"};

}

1;