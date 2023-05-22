#########################################################################
# This software is open source, licensed under the GNU General Public
# License, version 2.
# Basically, this means that you're allowed to modify and distribute
# this software. However, if you distribute modified versions, you MUST
# also distribute the source code.
# See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Processing of incoming chat commands
#
# Kore has a feature called 'chat commands': you command your bot to
# do certain things by using PM or public chat. This module processes
# chat input and executes chat commands when necessary.

package ChatQueue;

#TODO: Review and test the whole document before adding them back
#use strict;
#use warnings;

use Time::HiRes qw(time);

use AI;
use Commands;
use Globals qw($accountID %ai_v $char @chatResponses
		%config $field %itemChange @monsters_Killed %maps_lut $net %overallAuth
		%players %responseVars $startTime_EXP %timeout
		$totalBaseExp $totalJobExp $messageSender
		);
use Log qw(message error);
use Misc qw(auth avoidGM_talk avoidList_talk configModify getIDFromChat
		getResponse quit relog sendMessage setTimeout look parseReload);
use Plugins;
use Translation;
use Utils qw(formatNumber getFormattedDate parseArgs swrite timeConvert timeOut);

our @queue;
our $wordSplitters = qr/(\b| |,|\.|\!)/;
our %lastInput;


# use SelfLoader; 1;
# __DATA__


##
# void ChatQueue::add(String type, Bytes userID, String user, String msg)
# type: 'c' (public chat), 'pm' (private message), 'p' (party chat) or 'g' (guild chat)
# userID: the account ID of the user who sent this message.
# user: the name of the user who sent this message.
# msg: the message.
#
# Add a chat message to the chat queue. The messages in the queue will be processed later.
sub add {
	my %item = (
		type => shift,
		userID => shift,
		user => shift,
		msg => shift,
		time => time
	);
	push @queue, \%item;
	Plugins::callHook('ChatQueue::add', \%item);
}

##
# void ChatQueue::clear()
#
# Clear the chat queue, if there are any unprocessed messages.
sub clear {
	@queue = ();
	%lastInput = ();
}

##
# void ChatQueue::processFirst()
#
# Process the first message in the queue, if any.
# That message will be removed from the queue.
sub processFirst {
	return unless @queue;
	my $cmd = shift @queue;
	my $user = $cmd->{user} || '';
	return if ($user eq $char->{name});

	my $type = $cmd->{type};
	my $msg = $cmd->{msg};
	my $userID = $cmd->{userID};

	return if ( $user ne ""
		&& (avoidGM_talk($user, unpack("V1", $userID)) || avoidList_talk($user, unpack("V1", $userID))) );


	# If the user is not authorized to use chat commands,
	# check whether he's trying to authenticate
	if (( $type eq "pm" || $type eq "p" || $type eq "g" ) && !$overallAuth{$user} && $config{adminPassword}) {
		if ($msg eq $config{adminPassword} && $config{inGameAuth}) {
			auth($user, 1);
			sendMessage($messageSender, "pm", getResponse("authS"), $user);
		}
		# We don't notify the user if login failed; people use it
		# to check whether you're a bot.
	}

	# If the user is authorized to use chat commands,
	# check whether his message is a chat command, and execute it.
	my $callSign = '';
	$callSign = quotemeta $config{"callSign"} if ($config{"callSign"});
	if ($overallAuth{$user} && ( $type eq "pm" || $msg =~ /^\b$callSign\b/i )) {
		my $msg2 = $msg;
		$msg2 =~ s/^\b$callSign\b *//i;
		$msg2 =~ s/ *$//;
		return if processChatCommand($type, $user, $msg2);
	}

	# Not a chat command; attempt to reply with a message
	processChatResponse($cmd) if ($config{autoResponse});
}

sub processChatCommand {
	my ($type, $user, $msg) = @_;
	my ($switch, $after) = split / +/, $msg, 2;
	$after =~ s/ *$//;
	my @args = parseArgs($after);
	my $vars = \%responseVars;

	$vars->{cmd_user} = $user;

	if ($switch eq "conf") {
		if ($args[0] eq "") {
			sendMessage($messageSender, $type, getResponse("confF1"), $user) if $config{verbose};

		} elsif (!exists $config{$args[0]}) {
			sendMessage($messageSender, $type, getResponse("confF2"), $user) if $config{verbose};

		} elsif ($args[1] eq "") {
			if (lc($args[0]) eq "username" || lc($args[0] eq "password")) {
				sendMessage($messageSender, $type, getResponse("confF3"), $user) if $config{verbose};
			} else {
				$vars->{key} = $args[0];
				$vars->{value} = $config{$args[0]};
				sendMessage($messageSender, $type, getResponse("confS1"), $user) if $config{verbose};
				$timeout{ai_thanks_set}{time} = time;
			}

		} else {
			$args[1] = "" if ($args[1] eq "none");
			configModify($args[0], $args[1]);
			sendMessage($messageSender, $type, getResponse("confS2"), $user) if $config{verbose};
			$timeout{ai_thanks_set}{time} = time;
		}

	} elsif ($switch eq "date") {
		$vars->{date} = getFormattedDate(int(time));
		sendMessage($messageSender, $type, getResponse("dateS"), $user) if $config{verbose};
		$timeout{ai_thanks_set}{time} = time;

	} elsif ($switch eq "exp") {

		if ($args[0] eq "") {
			my ($endTime_EXP, $w_sec);
			$endTime_EXP = time;
			$w_sec = int($endTime_EXP - $startTime_EXP);

			if ($w_sec > 0) {
				$vars->{bExpPerHour} = int($totalBaseExp / $w_sec * 3600);
				$vars->{jExpPerHour} = int($totalJobExp / $w_sec * 3600);
				if ($char->{exp_max} && $vars->{bExpPerHour}){
					$vars->{percentBExp} = "(".sprintf("%.2f",$totalBaseExp * 100 / $char->{exp_max})."%)";
					$vars->{percentBExpPerHour} = "(".sprintf("%.2f",$vars->{bExpPerHour} * 100 / $char->{exp_max})."%)";
					$vars->{bLvlUp} = timeConvert(int(($char->{exp_max} - $char->{exp})/($vars->{bExpPerHour}/3600)));
				}
				if ($char->{exp_job_max} && $vars->{jExpPerHour}){
					$vars->{percentJExp}  = "(".sprintf("%.2f",$totalJobExp * 100 / $char->{exp_job_max})."%)";
					$vars->{percentJExpPerHour} = "(".sprintf("%.2f",$vars->{jExpPerHour} * 100 / $char->{exp_job_max})."%)";
					$vars->{jLvlUp} = timeConvert(int(($char->{'exp_job_max'} - $char->{exp_job})/($vars->{jExpPerHour}/3600)));
				}
			}

			$vars->{time} = timeConvert($w_sec);
			$vars->{bExp} = formatNumber($totalBaseExp);
			$vars->{jExp} = formatNumber($totalJobExp);
			$vars->{bExpPerHour} = formatNumber($vars->{bExpPerHour});
			$vars->{jExpPerHour} = formatNumber($vars->{jExpPerHour});
			$vars->{numDeaths} = (defined $char->{deathCount})? $char->{deathCount} : 0;
			sendMessage($messageSender, $type, getResponse("expS"), $user) if $config{verbose};

		} elsif ($args[0] eq "monster") {
			$vars->{numKilledMonsters} = 0;

			sendMessage($messageSender, $type, getResponse("expMonsterS1"), $user) if $config{verbose};

			for (my $i = 0; $i < @monsters_Killed; $i++) {
				next if ($monsters_Killed[$i] eq "");
				$vars->{killedMonsters} = swrite(
					"@<< @<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<",
					[$i, $monsters_Killed[$i]{name}, $monsters_Killed[$i]{count}]);
				$vars->{killedMonsters} = substr($vars->{killedMonsters}, 0, length($vars->{killedMonsters}) - 1);
				$vars->{numKilledMonsters} += $monsters_Killed[$i]{count};
				sendMessage($messageSender, $type, getResponse("expMonsterS2"), $user) if $config{verbose};
			}

			sendMessage($messageSender, $type, getResponse("expMonsterS3"), $user) if $config{verbose};

		} elsif ($args[0] eq "item") {
			sendMessage($messageSender, $type, getResponse("expItemS1"), $user) if $config{verbose};
			for my $item (sort keys %itemChange) {
				next unless $itemChange{$item};
				$vars->{gotItems} = sprintf("%-40s %5d", $item, $itemChange{$item});
				sendMessage($messageSender, $type, getResponse("expItemS2"), $user) if $config{verbose};
			}

		} else {
			sendMessage($messageSender, $type, getResponse("expF"), $user) if $config{verbose};
		}

	} elsif ($switch eq "follow") {
		if ($args[0] eq "stop") {
			if ($config{follow}) {
				AI::clear("follow");
				configModify("follow", 0);
				sendMessage($messageSender, $type, getResponse("followStopS"), $user) if $config{verbose};
				$timeout{ai_thanks_set}{time} = time;
			} else {
				sendMessage($messageSender, $type, getResponse("followStopF"), $user) if $config{verbose};
			}

		} else {
			my $targetID = getIDFromChat(\%players, $user, $after);
			if (defined $targetID) {
				AI::clear("follow");
				main::ai_follow($players{$targetID}{name});
				configModify("follow", 1);
				configModify("followTarget", $players{$targetID}{name});
				sendMessage($messageSender, $type, getResponse("followS"), $user) if $config{verbose};
				$timeout{ai_thanks_set}{time} = time;
			} else {
				sendMessage($messageSender, $type, getResponse("followF"), $user) if $config{verbose};
			}
		}

	} elsif ($switch eq "logout") {
		sendMessage($messageSender, $type, getResponse("quitS"), $user) if $config{verbose};
		quit();
		$timeout{ai_thanks_set}{time} = time;

	} elsif ($switch eq "look") {
		my ($body, $head) = @args;
		if ($body ne "") {
			look($body, $head);
			sendMessage($messageSender, $type, getResponse("lookS"), $user) if $config{verbose};
			$timeout{ai_thanks_set}{time} = time;
		} else {
			sendMessage($messageSender, $type, getResponse("lookF"), $user) if $config{verbose};
		}

	} elsif (($switch eq "move" && $args[0] eq "stop") || $switch eq "stop") {
		AI::clear("move", "route", "mapRoute");
		sendMessage($messageSender, $type, getResponse("moveS"), $user) if $config{verbose};
		$timeout{ai_thanks_set}{time} = time;

	} elsif ($switch eq "move") {
		my ($map, $x, $y);

		if ($args[0] =~ /^\d+$/) {
	 		# x y map
	 		($x, $y, $map) = @args;
		} else {
	 		# map x y
	 		($map, $x, $y) = @args;
		}

		if ($map ne "" || ($x ne "" && $y ne "")) {
			$map = $field->baseName if ($map eq "");
			my $rsw = "${map}.rsw";
			if ($maps_lut{$rsw}) {
				if ($x ne "" && $y ne "") {
					message TF("Calculating route to: %s(%s): %d, %d\n", $maps_lut{$rsw}, $map, $x, $y), "route";
				} else {
					message TF("Calculating route to: %s(%s)\n", $maps_lut{$rsw}, $map), "route";
				}
				sendMessage($messageSender, $type, getResponse("moveS"), $user) if $config{verbose};
				main::ai_route($map, $x, $y, attackOnRoute => 1);
				$timeout{ai_thanks_set}{time} = time;

			} else {
				error TF("Map %s does not exist\n", $map);
				sendMessage($messageSender, $type, getResponse("moveF"), $user) if $config{verbose};
			}

		} else {
			sendMessage($messageSender, $type, getResponse("moveF"), $user) if $config{verbose};
		}

	} elsif ($switch eq "reload") {
		parseReload($after);
		sendMessage($messageSender, $type, getResponse("reloadS"), $user) if $config{verbose};
		$timeout{ai_thanks_set}{time} = time;

	} elsif ($switch eq "relog") {
		sendMessage($messageSender, $type, getResponse("relogS"), $user) if $config{verbose};
		relog($args[0]);
		$timeout{ai_thanks_set}{time} = time;

	} elsif ($msg =~ /\bshut[\s\S]*up\b/) {
		if ($config{verbose}) {
			configModify("verbose", 0);
			sendMessage($messageSender, $type, getResponse("verboseOffS"), $user);
			$timeout{ai_thanks_set}{time} = time;
		} else {
			sendMessage($messageSender, $type, getResponse("verboseOffF"), $user);
		}

	} elsif ($switch eq "speak") {
		if (!$config{verbose}) {
			configModify("verbose", 1);
			sendMessage($messageSender, $type, getResponse("verboseOnS"), $user);
			$timeout{ai_thanks_set}{time} = time;
		} else {
			sendMessage($messageSender, $type, getResponse("verboseOnF"), $user);
		}

	} elsif ($switch eq "sit") {
		Commands::run("sit");
		sendMessage($messageSender, $type, getResponse("sitS"), $user) if $config{verbose};
		$timeout{ai_thanks_set}{time} = time;

	} elsif ($switch eq "stand") {
		Commands::run("stand");
		sendMessage($messageSender, $type, getResponse("standS"), $user) if $config{verbose};
		$timeout{ai_thanks_set}{time} = time;

	} elsif ($switch eq "status") {
		$vars->{char_sp} = $char->{sp};
		$vars->{char_hp} = $char->{hp};
		$vars->{char_sp_max} = $char->{sp_max};
		$vars->{char_hp_max} = $char->{hp_max};
		$vars->{char_lv} = $char->{lv};
		$vars->{char_lv_job} = $char->{lv_job};
		$vars->{char_exp} = formatNumber($char->{exp});
		$vars->{char_exp_max} = formatNumber($char->{exp_max});
		$vars->{char_exp_job} = formatNumber($char->{exp_job});
		$vars->{char_exp_job_max} = formatNumber($char->{exp_job_max});
		$vars->{char_weight} = $char->{weight};
		$vars->{char_weight_max} = $char->{weight_max};
		$vars->{zeny} = formatNumber($char->{zeny});
		sendMessage($messageSender, $type, getResponse("statusS"), $user) if $config{verbose};

	} elsif ($switch eq "tank") {
		if ($args[0] eq "stop") {
			if (!$config{tankMode}) {
				sendMessage($messageSender, $type, getResponse("tankStopF"), $user) if $config{verbose};
			} else {
				sendMessage($messageSender, $type, getResponse("tankStopS"), $user) if $config{verbose};
				configModify("tankMode", 0);
				$timeout{ai_thanks_set}{time} = time;
			}

		} else {
			my $targetID = getIDFromChat(\%players, $user, $after);
			if ($targetID ne "") {
				sendMessage($messageSender, $type, getResponse("tankS"), $user) if $config{verbose};
				configModify("tankMode", 1);
				configModify("tankModeTarget", $players{$targetID}{name});
				$timeout{ai_thanks_set}{time} = time;
			} else {
				sendMessage($messageSender, $type, getResponse("tankF"), $user) if $config{verbose};
			}
		}

	} elsif ($switch eq "thank" || $switch eq "thn" || $switch eq "thx") {
		if (!timeOut($timeout{ai_thanks_set})) {
			$timeout{ai_thanks_set}{time} -= $timeout{ai_thanks_set}{timeout};
			sendMessage($messageSender, $type, getResponse("thankS"), $user) if $config{verbose};
		}

	} elsif ($switch eq "timeout") {
		if ($args[0] eq "") {
			sendMessage($messageSender, $type, getResponse("timeoutF1"), $user) if $config{verbose};

		} elsif (!exists $timeout{$args[0]}{timeout}) {
			sendMessage($messageSender, $type, getResponse("timeoutF2"), $user) if $config{verbose};

		} elsif ($args[1] eq "") {
			$vars->{key} = $args[0];
			$vars->{value} = $timeout{$args[0]}{timeout};
			sendMessage($messageSender, $type, getResponse("timeoutS1"), $user) if $config{verbose};
			$timeout{ai_thanks_set}{time} = time;

		} else {
			$args[1] = "" if ($args[1] eq "none");
			setTimeout($args[0], $args[1]);
			sendMessage($messageSender, $type, getResponse("timeoutS2"), $user) if $config{verbose};
			$timeout{ai_thanks_set}{time} = time;
		}

	} elsif ($switch eq "town") {
		sendMessage($messageSender, $type, getResponse("moveS"), $user);
		ai_useTeleport(2);

	} elsif ($switch eq "version") {
		$vars->{ver} = $Settings::VERSION;
		sendMessage($messageSender, $type, getResponse("versionS"), $user) if $config{verbose};

	} elsif ($switch eq "where") {
		$vars->{x} = $char->{pos_to}{x};
		$vars->{y} = $char->{pos_to}{y};
		$vars->{map} = sprintf "%s (%s)", $field->baseName, $field->name;
		$timeout{ai_thanks_set}{time} = time;
		sendMessage($messageSender, $type, getResponse("whereS"), $user) if $config{verbose};


	# Support Skills

	} elsif ($switch eq "agi"){
		my $targetID = getIDFromChat(\%players, $user, $after);
		my $skill = Skill->new(handle => 'AL_INCAGI');
		if ($targetID eq "") {
			sendMessage($messageSender, $type, getResponse("healF1"), $user) if $config{verbose};

		} elsif (my $lv = $char->getSkillLevel($skill)) {
			my $failed = 1;
			for (my $i = $lv; $i >=1; $i--) {
				if ($char->{sp} >= $skill->getSP($i)) {
					main::ai_skillUse('AL_INCAGI', $i, 0, 0, $targetID);
					$failed = 0;
					last;
				}
			}
			if (!$failed) {
				sendMessage($messageSender, $type, getResponse("healS"), $user) if $config{verbose};
			}else{
				sendMessage($messageSender, $type, getResponse("healF2"), $user) if $config{verbose};
			}

		} else {
			sendMessage($messageSender, $type, getResponse("healF3"), $user) if $config{verbose};
		}
		$timeout{ai_thanks_set}{time} = time;

	} elsif ($switch eq "bless" || $switch eq "blessing"){
		my $targetID = getIDFromChat(\%players, $user, $after);
		my $skill = Skill->new(handle => 'AL_BLESSING');
		if ($targetID eq "") {
			sendMessage($messageSender, $type, getResponse("healF1"), $user) if $config{verbose};

		} elsif (my $lv = $char->getSkillLevel($skill)) {
			my $failed = 1;
			for (my $i = $lv; $i >=1; $i--) {
				if ($char->{sp} >= $skill->getSP($i)) {
					main::ai_skillUse('AL_BLESSING', $i, 0, 0, $targetID);
					$failed = 0;
					last;
				}
			}
			if (!$failed) {
				sendMessage($messageSender, $type, getResponse("healS"), $user) if $config{verbose};
			}else{
				sendMessage($messageSender, $type, getResponse("healF2"), $user) if $config{verbose};
			}

		} else {
			sendMessage($messageSender, $type, getResponse("healF3"), $user) if $config{verbose};
		}
		$timeout{ai_thanks_set}{time} = time;

	} elsif ($switch eq "heal") {
		my $amount;
		my $targetID;
		if ($args[0] =~ /^\d+$/) {
			$amount = $args[0];
			$targetID = getIDFromChat(\%players, $user, $args[1]);
		} else {
			$amount = $args[1];
			$targetID = getIDFromChat(\%players, $user, $args[0]);
		}

		if ($targetID eq "") {
			sendMessage($messageSender, $type, getResponse("healF1"), $user) if $config{verbose};

		} elsif ($char->{skills}{AL_HEAL}{lv} > 0) {
			my $amount_healed;
			my $sp_needed;
			my $sp_used;
			my $failed;
			my @skillCasts;

			# Calculate what skill level is needed to heal $amount HP
			while ($amount_healed < $amount) {
				my ($sp, $amount_this);
				for (my $i = 1; $i <= $char->{skills}{AL_HEAL}{lv}; $i++) {
					$sp = 10 + ($i * 3);
					$amount_this = int(($char->{lv} + $char->{int}) / 8)
							* (4 + $i * 8);
					last if ($amount_healed + $amount_this >= $amount);
				}
				$sp_needed += $sp;
				$amount_healed += $amount_this;
			}

			while ($sp_used < $sp_needed && !$failed) {
				my ($lv, $sp);
				for (my $i = 1; $i <= $char->{skills}{AL_HEAL}{lv}; $i++) {
					$lv = $i;
					$sp = 10 + ($i * 3);
					if ($sp_used + $sp > $char->{sp}) {
						$lv--;
						$sp = 10 + ($lv * 3);
						last;
					}
					last if ($sp_used + $sp >= $sp_needed);
				}

				if ($lv > 0) {
					my %skill;
					$sp_used += $sp;
					$skill{skill} = 'AL_HEAL';
					$skill{lv} = $lv;
					$skill{maxCastTime} = 0;
					$skill{minCastTime} = 0;
					$skill{ID} = $targetID;
					unshift @skillCasts, \%skill;
				} else {
					$vars->{char_sp} = $char->{sp} - $sp_used;
					sendMessage($messageSender, $type, getResponse("healF2"), $user) if $config{verbose};
					$failed = 1;
				}
			}

			if (!$failed) {
				sendMessage($messageSender, $type, getResponse("healS"), $user) if $config{verbose};
			}
			foreach (@skillCasts) {
				main::ai_skillUse($_->{skill}, $_->{lv}, $_->{maxCastTime}, $_->{minCastTime}, $_->{ID});
			}

		} else {
			sendMessage($messageSender, $type, getResponse("healF3"), $user) if $config{verbose};
		}

	} elsif ($switch eq "kyrie"){
		my $targetID = getIDFromChat(\%players, $user, $after);
		my $skill = Skill->new(handle => 'PR_KYRIE');
		if ($targetID eq "") {
			sendMessage($messageSender, $type, getResponse("healF1"), $user) if $config{verbose};

		} elsif (my $lv = $char->getSkillLevel($skill)) {
			my $failed = 1;
			for (my $i = $lv; $i >= 1; $i--) {
				if ($char->{sp} >= $skill->getSP($i)) {
					main::ai_skillUse('PR_KYRIE', $i, 0, 0, $targetID);
					$failed = 0;
					last;
				}
			}

			if (!$failed) {
				sendMessage($messageSender, $type, getResponse("healS"), $user) if $config{verbose};
			}else{
				sendMessage($messageSender, $type, getResponse("healF2"), $user) if $config{verbose};
			}

		} else {
			sendMessage($messageSender, $type, getResponse("healF3"), $user) if $config{verbose};
		}
		$timeout{ai_thanks_set}{time} = time;

	} elsif ($switch eq "mag"){
		my $targetID = $accountID;
		my $skill = Skill->new(handle => 'PR_MAGNIFICAT');
		if (my $lv = $char->getSkillLevel($skill)) {
			my $failed = 1;
			for (my $i = $lv; $i >= 1; $i--) {
				if ($char->{sp} >= $skill->getSP($i)) {
					main::ai_skillUse('PR_MAGNIFICAT', $i, 0, 0, $targetID);
					$failed = 0;
					last;
				}
			}

			if (!$failed) {
				sendMessage($messageSender, $type, getResponse("healS"), $user) if $config{verbose};
			}else{
				sendMessage($messageSender, $type, getResponse("healF2"), $user) if $config{verbose};
			}

		} else {
			sendMessage($messageSender, $type, getResponse("healF3"), $user) if $config{verbose};
		}
		$timeout{ai_thanks_set}{time} = time;

	} else {
		return 0;
	}
	return 1;
}


# Automatically reply to a chat message
sub processChatResponse {
	return unless (AI::state == AI::AUTO);
	my $cmd = shift;
	my $msg = lc $cmd->{msg};
	my $reply;
	my $repeating;

	# Check whether the user is repeating itself
	$msg =~ s/^ +//;
	$msg =~ s/ +$//;
	if (defined $lastInput{msg} && $lastInput{user} eq $cmd->{user} && $lastInput{msg} eq $msg) {
		$repeating = $cmd->{repeating} = 1;
	}

	# Determine a reply
	Plugins::callHook('ChatQueue::processChatResponse', $cmd);
	if (defined $cmd->{reply}) {
		$reply = $cmd->{reply};

	} elsif (!$repeating && ($cmd->{type} eq "c" || $cmd->{type} eq "pm") && !$field->isCity) {
		foreach my $item (@chatResponses) {
			my $word = quotemeta $item->{word};
			if ($msg =~ /${wordSplitters}${word}${wordSplitters}/) {
				my $max = @{$item->{responses}};
				$reply = $item->{responses}[rand($max)];
				last;
			}
		}
	}

	return unless (defined $reply);

	# Calculate a small delay (to simulate typing)
	# The average typing speed is 65 words per minute.
	# The average length of a word used by RO players is 4.25 characters (yes I measured it).
	# So the average user types 65 * 4.25 = 276.25 charcters per minute, or
	# 276.25 / 60 = 4.6042 characters per second
	# We also add a random delay of 0.5-1.5 seconds.
	my $timeout = 0.5 + rand(1) + length($reply) / 4.6042;
	my %args = (
		time => time,
		timeout => $timeout,
		type => $cmd->{type},
		from => $cmd->{user},
		reply => $reply
	);
	AI::queue("autoResponse", \%args);

	$lastInput{msg} = $msg;
	$lastInput{user} = $cmd->{user};
}

1;
