package ChatQueue;

use strict;
use Time::HiRes qw(time);

use Globals qw($remote_socket %config %players $char %ai_v %timeout
		%responseVars %field %overallAuth %maps_lut %skillsSP_lut);
use AI;
use Commands;
use Log qw(message error);
use Utils qw(parseArgs);
use Misc qw(auth configModify sendMessage getIDFromChat avoidGM_talk avoidList_talk getResponse);


our @queue;

##
# ChatQueue::add(type, userID, user, msg)
sub add {
	my %item = (
		type => shift,
		userID => shift,
		user => shift,
		msg => shift,
		time => time
	);
	push @queue, \%item;
}

##
# ChatQueue::clear()
sub clear {
	@queue = ();
}

##
# ChatQueue::processFirst()
sub processFirst {
	return unless @queue;
	my $cmd = shift @queue;
	return if ($cmd->{user} eq $char->{name});

	my $type = $cmd->{type};
	my $user = $cmd->{user};
	my $msg = $cmd->{msg};

	return if ( $user ne ""
		&& (avoidGM_talk($user, $msg) || avoidList_talk($user, $msg, unpack("L1", $cmd->{userID}))) );


	# If the user is not authorized to use chat commands,
	# check whether he's trying to authenticate
	if (( $type eq "pm" || $type eq "p" || $type eq "g" ) && !$overallAuth{$user}) {
		if ($msg eq $config{adminPassword}) {
			auth($user, 1);
			sendMessage(\$remote_socket, "pm", getResponse("authS"), $user);
		}
	}

	# If the user is authorized to use chat commands,
	# check whether his message is a chat command, and execute it.
	my $callSign = quotemeta $config{callSign};
	if ($overallAuth{$user} && ( $type eq "pm" || $msg =~ /^\b*$callSign\b*/i )) {
		my $msg2 = lc $msg;
		$msg2 =~ s/^\b*$callSign\b*//;
		$msg2 =~ s/ *$//;
		return if _processChatCommand($type, $user, $msg2);
	}
}

sub _processChatCommand {
	my ($type, $user, $msg) = @_;
	my ($switch, $after) = split / +/, $msg, 2;
	$after =~ s/ *$//;
	my @args = parseArgs($after);
	my $vars = \%responseVars;

	$vars->{cmd_user} = $user;

	if ($switch eq "sit") {
		Commands::run("sit");
		sendMessage(\$remote_socket, $type, getResponse("sitS"), $user) if $config{verbose};
		$timeout{ai_thanks_set}{time} = time;

	} elsif ($switch eq "stand") {
		Commands::run("stand");
		sendMessage(\$remote_socket, $type, getResponse("standS"), $user) if $config{verbose};
		$timeout{ai_thanks_set}{time} = time;

	} elsif ($switch eq "relog") {
		main::relog();
		sendMessage(\$remote_socket, $type, getResponse("relogS"), $user) if $config{verbose};
		$timeout{ai_thanks_set}{time} = time;

	} elsif ($switch eq "logout") {
		quit();
		sendMessage(\$remote_socket, $type, getResponse("quitS"), $user) if $config{verbose};
		$timeout{ai_thanks_set}{time} = time;

	} elsif ($switch eq "reload") {
		Settings::parseReload($after);
		sendMessage(\$remote_socket, $type, getResponse("reloadS"), $user) if $config{verbose};
		$timeout{ai_thanks_set}{time} = time;

	} elsif ($switch eq "status") {
		$vars->{char_sp} = $char->{sp};
		$vars->{char_hp} = $char->{hp};
		$vars->{char_sp_max} = $char->{sp_max};
		$vars->{char_hp_max} = $char->{hp_max};
		$vars->{char_lv} = $char->{lv};
		$vars->{char_lv_job} = $char->{lv_job};
		$vars->{char_exp} = $char->{exp};
		$vars->{char_exp_max} = $char->{exp_max};
		$vars->{char_exp_job} = $char->{exp_job};
		$vars->{char_exp_job_max} = $char->{exp_job_max};
		$vars->{char_weight} = $char->{weight};
		$vars->{char_weight_max} = $char->{weight_max};
		$vars->{zenny} = $char->{zenny};
		sendMessage(\$remote_socket, $type, getResponse("statusS"), $user) if $config{verbose};

	} elsif ($switch eq "conf") {
		if ($args[0] eq "") {
			sendMessage(\$remote_socket, $type, getResponse("confF1"), $user) if $config{verbose};

		} elsif (!exists $config{$args[0]}) {
			sendMessage(\$remote_socket, $type, getResponse("confF2"), $user) if $config{verbose};

		} elsif ($args[1] eq "") {
			if (lc($args[0]) eq "username" || lc($args[0] eq "password")) {
				sendMessage(\$remote_socket, $type, getResponse("confF3"), $user) if $config{verbosr};
			} else {
				$vars->{key} = $args[0];
				$vars->{value} = $config{$args[0]};
				sendMessage(\$remote_socket, $type, getResponse("confS1"), $user) if $config{verbose};
				$timeout{ai_thanks_set}{time} = time;
			}

		} else {
			$args[1] = "" if ($args[1] eq "none");
			configModify($args[0], $args[1]);
			sendMessage(\$remote_socket, $type, getResponse("confS2"), $user) if $config{verbose};
			$timeout{ai_thanks_set}{time} = time;
		}

	} elsif ($msg =~ /\bshut[\s\S]*up\b/) {
		if ($config{verbose}) {
			configModify("verbose", 0);
			sendMessage(\$remote_socket, $type, getResponse("verboseOffS"), $user);
			$timeout{ai_thanks_set}{time} = time;
		} else {
			sendMessage(\$remote_socket, $type, getResponse("verboseOffF"), $user);
		}

	} elsif ($switch eq "speak") {
		if (!$config{verbose}) {
			configModify("verbose", 1);
			sendMessage(\$remote_socket, $type, getResponse("verboseOnS"), $user);
			$timeout{ai_thanks_set}{time} = time;
		} else {
			sendMessage(\$remote_socket, $type, getResponse("verboseOnF"), $user);
		}

	} elsif ($switch eq "date") {
		$vars->{date} = getFormattedDate(int(time));
		sendMessage(\$remote_socket, $type, getResponse("dateS"), $user) if $config{verbose};
		$timeout{ai_thanks_set}{time} = time;

	} elsif (($switch eq "move" && $args[0] eq "stop") || $switch eq "stop") {
		AI::clear("move", "route", "mapRoute");
		sendMessage(\$remote_socket, $type, getResponse("moveS"), $user) if $config{verbose};
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

		if ($map eq "") {
	 		$x eq "" || $y eq ""
		} else {
	 		$x ne "" && $y ne ""
		}

		if ($map ne "" || ($x ne "" && $y ne "")) {
			$map = $field{name} if ($map eq "");
			my $rsw = "${map}.rsw";
			if ($maps_lut{$rsw}) {
				if ($x ne "" && $y ne "") {
					message "Calculating route to: $maps_lut{$rsw}($map): $x, $y\n", "route";
				} else {
					message "Calculating route to: $maps_lut{$rsw}($map)\n", "route";
				}
				sendMessage(\$remote_socket, $type, getResponse("moveS"), $user) if $config{verbose};
				ai_route($map, $x, $y, attackOnRoute => 1);
				$timeout{ai_thanks_set}{time} = time;

			} else {
				error "Map $map does not exist\n";
				sendMessage(\$remote_socket, $type, getResponse("moveF"), $user) if $config{verbose};
			}

		} else {
			sendMessage(\$remote_socket, $type, getResponse("moveF"), $user) if $config{verbose};
		}

	} elsif ($switch eq "look") {
		my ($body, $head) = @args;
		if ($body ne "") {
			look($body, $head);
			sendMessage(\$remote_socket, $type, getResponse("lookS"), $user) if $config{verbose};
			$timeout{ai_thanks_set}{time} = time;
		} else {
			sendMessage(\$remote_socket, $type, getResponse("lookF"), $user) if $config{verbose};
		}	

	} elsif ($switch eq "follow") {
		if ($args[0] eq "stop") {
			if ($config{follow}) {
				AI::clear("follow");
				configModify("follow", 0);
				sendMessage(\$remote_socket, $type, getResponse("followStopS"), $user) if $config{verbose};
				$timeout{ai_thanks_set}{time} = time;
			} else {
				sendMessage(\$remote_socket, $type, getResponse("followStopF"), $user) if $config{verbose};
			}

		} else {
			my $targetID = getIDFromChat(\%players, $user, $after);
			if (defined $targetID) {
				AI::clear("follow");
				main::ai_follow($players{$targetID}{name});
				configModify("follow", 1);
				configModify("followTarget", $players{$targetID}{name});
				sendMessage(\$remote_socket, $type, getResponse("followS"), $user) if $config{verbose};
				$timeout{ai_thanks_set}{time} = time;
			} else {
				sendMessage(\$remote_socket, $type, getResponse("followF"), $user) if $config{verbose};
			}
		}

	} elsif ($switch eq "tank") {
		if ($args[0] eq "stop") {
			if (!$config{tankMode}) {
				sendMessage(\$remote_socket, $type, getResponse("tankStopF"), $user) if $config{verbose};
			} else {
				sendMessage(\$remote_socket, $type, getResponse("tankStopS"), $user) if $config{verbose};
				configModify("tankMode", 0);
				$timeout{ai_thanks_set}{time} = time;
			}

		} else {
			my $targetID = getIDFromChat(\%players, $user, $after);
			if ($targetID ne "") {
				sendMessage(\$remote_socket, $type, getResponse("tankS"), $user) if $config{verbose};
				configModify("tankMode", 1);
				configModify("tankModeTarget", $players{$targetID}{name});
				$timeout{ai_thanks_set}{time} = time;
			} else {
				sendMessage(\$remote_socket, $type, getResponse("tankF"), $user) if $config{verbose};
			}
		}

	} elsif ($switch eq "town") {
		sendMessage(\$remote_socket, $type, getResponse("moveS"), $user);
		main::useTeleport(2);
		
	} elsif ($switch eq "where") {
		my $rsw = "$field{name}.rsw";
		$vars->{x} = $char->{pos_to}{x};
		$vars->{y} = $char->{pos_to}{y};
		$vars->{map} = "$maps_lut{$rsw} ($field{name})";
		$timeout{ai_thanks_set}{time} = time;
		sendMessage(\$remote_socket, $type, getResponse("whereS"), $user) if $config{verbose};

	# Heal
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
			sendMessage(\$remote_socket, $type, getResponse("healF1"), $user) if $config{verbose};

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
					sendMessage(\$remote_socket, $type, getResponse("healF2"), $user) if $config{verbose};
					$failed = 1;
				}
			}

			if (!$failed) {
				sendMessage(\$remote_socket, $type, getResponse("healS"), $user) if $config{verbose};
			}
			foreach (@skillCasts) {
				main::ai_skillUse($_->{skill}, $_->{lv}, $_->{maxCastTime}, $_->{minCastTime}, $_->{ID});
			}

		} else {
			sendMessage(\$remote_socket, $type, getResponse("healF3"), $user) if $config{verbose};
		}

	# Inc Agi
	} elsif ($switch eq "agi"){
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
			sendMessage(\$remote_socket, $type, getResponse("healF1"), $user) if $config{verbose};

		} elsif ($char->{skills}{AL_INCAGI}{lv} > 0) {
			my $failed = 1;
			for (my $i = $char->{skills}{AL_INCAGI}{lv}; $i >=1; $i--) {
				if ($char->{sp} >= $skillsSP_lut{AL_INCAGI}{$i}) {
					main::ai_skillUse('AL_INCAGI', $i, 0, 0, $targetID);
					$failed = 0;
					last;
				}
			}
			if (!$failed) {
				sendMessage(\$remote_socket, $type, getResponse("healS"), $user) if $config{verbose};
			}else{
				sendMessage(\$remote_socket, $type, getResponse("healF2"), $user) if $config{verbose};
			}

		} else {
			sendMessage(\$remote_socket, $type, getResponse("healF3"), $user) if $config{'verbose'};
		}
		$timeout{ai_thanks_set}{time} = time;

	# Blessing
	} elsif ($switch eq "bless" || $switch eq "blessing"){
		my $targetID = getIDFromChat(\%players, $user, $after);
		if ($targetID eq "") {
			sendMessage(\$remote_socket, $type, getResponse("healF1"), $user) if $config{verbose};

		} elsif ($char->{skills}{AL_BLESSING}{lv} > 0) {
			my $failed = 1;
			for (my $i = $char->{skills}{AL_BLESSING}{lv}; $i >=1; $i--) {
				if ($char->{sp} >= $skillsSP_lut{AL_BLESSING}{$i}) {
					main::ai_skillUse('AL_BLESSING', $i, 0, 0, $targetID);
					$failed = 0;
					last;
				}
			}
			if (!$failed) {
				sendMessage(\$remote_socket, $type, getResponse("healS"), $user) if $config{verbose};
			}else{
				sendMessage(\$remote_socket, $type, getResponse("healF2"), $user) if $config{verbose};
			}

		} else {
			sendMessage(\$remote_socket, $type, getResponse("healF3"), $user) if $config{verbose};
		}
		$timeout{ai_thanks_set}{time} = time;

	# Kyrie
	} elsif ($switch eq "kyrie"){
		my $targetID = getIDFromChat(\%players, $user, $after);
		if ($targetID eq "") {
			sendMessage(\$remote_socket, $type, getResponse("healF1"), $user) if $config{verbose};

		} elsif ($char->{skills}{PR_KYRIE}{lv} > 0) {
			my $failed = 1;
			for (my $i = $char->{skills}{PR_KYRIE}{lv}; $i >= 1; $i--) {
				if ($char->{sp} >= $skillsSP_lut{PR_KYRIE}{$i}) {
					main::ai_skillUse('PR_KYRIE', $i, 0, 0, $targetID);
					$failed = 0;
					last;
				}
			}

			if (!$failed) {
				sendMessage(\$remote_socket, $type, getResponse("healS"), $user) if $config{verbose};
			}else{
				sendMessage(\$remote_socket, $type, getResponse("healF2"), $user) if $config{verbose};
			}

		} else {
			sendMessage(\$remote_socket, $type, getResponse("healF3"), $user) if $config{verbose};
		}
		$timeout{ai_thanks_set}{time} = time;

	} elsif ($switch eq "thank" || $switch eq "thn" || $switch eq "thx") {
		if (!timeOut($timeout{ai_thanks_set})) {
			$timeout{ai_thanks_set}{time} -= $timeout{ai_thanks_set}{timeout};
			sendMessage(\$remote_socket, $type, getResponse("thankS"), $user) if $config{verbose};
		}

	} else {
		return 0;
	}
	return 1;
}

1;
