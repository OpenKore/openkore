#########################################################################
#  OpenKore - AI
#  Copyright (c) OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: 4286 $
#  $Id: Commands.pm 4286 2006-04-17 14:02:27Z illusion_kore $
#
#########################################################################
#
# This module contains the core AI logic.

package AI::CoreLogic;
use strict;
use Time::HiRes qw(time);
use Carp::Assert;
use IO::Socket;
use Text::ParseWords;
use encoding 'utf8';

use Globals;
use Log qw(message warning error debug);
use Network::Send ();
use Settings;
use AI;
use AI::SlaveManager;
use ChatQueue;
use Utils;
use Misc;
use Commands;
use Network;
use FileParsers;
use Translation;
use Field;
use Task::TalkNPC;
use Utils::Exceptions;

# This is the main function from which the rest of the AI
# will be invoked.
sub iterate {
	Benchmark::begin("ai_prepare") if DEBUG;
	processWipeOldActors();
	processGetPlayerInfo();
	processMisc();
	processPortalRecording();
	Benchmark::end("ai_prepare") if DEBUG;

	return if (!$AI);
	if ($net->clientAlive() && !$sentWelcomeMessage && timeOut($timeout{welcomeText})) {
		$messageSender->injectAdminMessage($Settings::welcomeText) if ($config{'verbose'} && !$config{'XKore_silent'});
		$sentWelcomeMessage = 1;
	}


	##### MANUAL AI STARTS HERE #####

	Plugins::callHook('AI_pre/manual');
	Benchmark::begin("AI (part 1)") if DEBUG;
	return if processClientSuspend();
	Benchmark::begin("AI (part 1.1)") if DEBUG;
	processLook();
	processTask('NPC');
	processEquip();
	processDrop();
	processEscapeUnknownMaps();
	Benchmark::end("AI (part 1.1)") if DEBUG;
	Benchmark::begin("AI (part 1.2)") if DEBUG;
	processDelayedTeleport();
	processTask("sitting");
	processTask("standing");
	AI::Attack::process();
	Benchmark::end("AI (part 1.2)") if DEBUG;
	Benchmark::begin("AI (part 1.3)") if DEBUG;
	processSkillUse();
	processAutoCommandUse();
	processTask("route", onError => sub {
		my ($task, $error) = @_;
		if (!($task->isa('Task::MapRoute') && $error->{code} == Task::MapRoute::TOO_MUCH_TIME())
		 && !($task->isa('Task::Route') && $error->{code} == Task::Route::TOO_MUCH_TIME())) {
			error("$error->{message}\n");
		}
	});
	processTake();
	processMove();
	Benchmark::end("AI (part 1.3)") if DEBUG;

	Benchmark::begin("AI (part 1.4)") if DEBUG;
	Benchmark::begin("ai_autoItemUse") if DEBUG;
	processAutoItemUse();
	Benchmark::end("ai_autoItemUse") if DEBUG;
	Benchmark::begin("ai_autoSkillUse") if DEBUG;
	processAutoSkillUse();
	Benchmark::end("ai_autoSkillUse") if DEBUG;
	Benchmark::end("AI (part 1.4)") if DEBUG;

	Benchmark::end("AI (part 1)") if DEBUG;



	Misc::checkValidity("AI part 1");
	return if ($AI != 2);


	##### AUTOMATIC AI STARTS HERE #####

	Plugins::callHook('AI_pre');
	Benchmark::begin("AI (part 2)") if DEBUG;

	ChatQueue::processFirst;

	processDcOnPlayer();
	processDeal();
	processDealAuto();
	processPartyAuto();
	processGuildAutoDeny();

	Misc::checkValidity("AI part 1.1");
	#processAutoBreakTime(); moved to a plugin
	processDead();
	processStorageGet();
	processCartAdd();
	processCartGet();
	processAutoMakeArrow();
	Benchmark::end("AI (part 2)") if DEBUG;
	Misc::checkValidity("AI part 2");


	Benchmark::begin("AI (part 3)") if DEBUG;
	Benchmark::begin("AI (part 3.1)") if DEBUG;
	processAutoStorage();
	Misc::checkValidity("AI (autostorage)");
	processAutoSell();
	Misc::checkValidity("AI (autosell)");
	processAutoBuy();
	Misc::checkValidity("AI (autobuy)");
	processAutoCart();
	Misc::checkValidity("AI (autocart)");
	Benchmark::end("AI (part 3.1)") if DEBUG;

	Benchmark::begin("AI (part 3.2)") if DEBUG;
	processLockMap();
	#processAutoStatsRaise(); moved to a task
	#processAutoSkillsRaise(); moved to a task
	#processTask("skill_raise");
	processRandomWalk();
	processFollow();
	Benchmark::end("AI (part 3.2)") if DEBUG;

	Benchmark::begin("AI (part 3.3)") if DEBUG;
	processSitAutoIdle();
	processSitAuto();


	Benchmark::end("AI (part 3.3)") if DEBUG;
	Benchmark::end("AI (part 3)") if DEBUG;

	Benchmark::begin("AI (part 4)") if DEBUG;
	processPartySkillUse();
	processMonsterSkillUse();

	Misc::checkValidity("AI part 3");
	processAutoEquip();
	processAutoAttack();
	processItemsTake();
	processItemsAutoGather();
	processItemsGather();
	processAutoTeleport();
	processAllowedMaps();
	processAutoResponse();
	processAvoid();
	processSendEmotion();
	processAutoShopOpen();
	processRepairAuto();
	Benchmark::end("AI (part 4)") if DEBUG;


	##########

	# DEBUG CODE
	if (timeOut($ai_v{time}, 2) && $config{'debug'} >= 2) {
		my $len = @ai_seq_args;
		debug "AI: @ai_seq | $len\n", "ai", 2;
		$ai_v{time} = time;
	}
	$ai_v{'AI_last_finished'} = time;

	if ($cmdQueue && timeOut($cmdQueueStartTime,$cmdQueueTime)) {
		my $execCommand = '';
		if (@cmdQueueList) {
			$execCommand = join (";;", @cmdQueueList);
		} else {
			$execCommand = $cmdQueueList[0];
		}	
		@cmdQueueList = ();
		$cmdQueue = 0;
		$cmdQueueTime = 0;
		debug "Executing queued command: $execCommand\n", "ai";
		Commands::run($execCommand);
	}


	Plugins::callHook('AI_post');
}


#############################################################


# Wipe old entries in the %actor_old hashes.
sub processWipeOldActors {
	if (timeOut($timeout{ai_wipe_check})) {
		my $timeout = $timeout{ai_wipe_old}{timeout};

		foreach (keys %players_old) {
			if (timeOut($players_old{$_}{'gone_time'}, $timeout)) {
				delete $players_old{$_};
				binRemove(\@playersID_old, $_);
			}
		}
		foreach (keys %monsters_old) {
			if (timeOut($monsters_old{$_}{'gone_time'}, $timeout)) {
				delete $monsters_old{$_};
				binRemove(\@monstersID_old, $_);
			}
		}
		foreach (keys %npcs_old) {
			delete $npcs_old{$_} if (time - $npcs_old{$_}{'gone_time'} >= $timeout{'ai_wipe_old'}{'timeout'});
		}
		foreach (keys %items_old) {
			delete $items_old{$_} if (time - $items_old{$_}{'gone_time'} >= $timeout{'ai_wipe_old'}{'timeout'});
		}
		foreach (keys %portals_old) {
			if (timeOut($portals_old{$_}{gone_time}, $timeout)) {
				delete $portals_old{$_};
				binRemove(\@portalsID_old, $_);
			}
		}

		# Remove players that are too far away; sometimes they don't get
		# removed from the list for some reason
		#foreach (keys %players) {
		#	if (distance($char->{pos_to}, $players{$_}{pos_to}) > 35) {
		#		$playersList->remove($players{$_});
		#		last;
		#	}
		#}

		$timeout{'ai_wipe_check'}{'time'} = time;
		debug "Wiped old\n", "ai", 2;
	}
}

sub processGetPlayerInfo {
	if (timeOut($timeout{ai_getInfo})) {
		processNameRequestQueue(\@unknownPlayers, [$playersList, $slavesList]);
		processNameRequestQueue(\@unknownNPCs, [$npcsList]);

		foreach (keys %monsters) {
			last if (isSafeActorQuery($_) != 1); # Do not Query GM hidden Monster names
			if ($monsters{$_}{'name'} =~ /Unknown/) {
				$messageSender->sendGetPlayerInfo($_);
				last;
			}
			if ($monsters{$_}{'name_given'} =~ /Unknown/) {
				$messageSender->sendGetPlayerInfo($_);
				last;
			}
		}
		foreach (keys %pets) {
			if ($pets{$_}{'name_given'} =~ /Unknown/) {
				last if (isSafeActorQuery($_) != 1); # Do not Query GM hidden Pet names
				$messageSender->sendGetPlayerInfo($_);
				last;
			}
		}
		$timeout{ai_getInfo}{time} = time;
	}
}

sub processMisc {
	if (timeOut($timeout{ai_sync})) {
		$timeout{ai_sync}{time} = time;
		$messageSender->sendSync();
	}

	if (timeOut($char->{muted}, $char->{mute_period})) {
		delete $char->{muted};
		delete $char->{mute_period};
	}
}

##### CLIENT SUSPEND #####
# The clientSuspend AI sequence is used to freeze all other AI activity
# for a certain period of time.
sub processClientSuspend {
	my $result = 0;
	if (AI::action eq 'clientSuspend' && timeOut(AI::args)) {
		debug "AI suspend by clientSuspend dequeued\n";
		AI::dequeue;
	} elsif (AI::action eq "clientSuspend" && $net->clientAlive()) {
		# When XKore mode is turned on, clientSuspend will increase it's timeout
		# every time the user tries to do something manually.
		my $args = AI::args;

		if ($args->{'type'} eq "0089") {
			# Player's manually attacking
			if ($args->{'args'}[0] == 2) {
				if ($chars[$config{'char'}]{'sitting'}) {
					$args->{'time'} = time;
				}
			} elsif ($args->{'args'}[0] == 3) {
				$args->{'timeout'} = 6;
			} else {
				my $ID = $args->{args}[1];
				my $monster = $monstersList->getByID($ID);

				if (!$args->{'forceGiveup'}{'timeout'}) {
					$args->{'forceGiveup'}{'timeout'} = 6;
					$args->{'forceGiveup'}{'time'} = time;
				}
				if ($monster) {
					$args->{time} = time;
					$args->{dmgFromYou_last} = $monster->{dmgFromYou};
					$args->{missedFromYou_last} = $monster->{missedFromYou};
					if ($args->{dmgFromYou_last} != $monster->{dmgFromYou}) {
						$args->{forceGiveup}{time} = time;
					}
				} else {
					$args->{time} -= $args->{'timeout'};
				}
				if (timeOut($args->{forceGiveup})) {
					$args->{time} -= $args->{timeout};
				}
			}

		} elsif ($args->{'type'} eq "009F") {
			# Player's manually picking up an item
			if (!$args->{'forceGiveup'}{'timeout'}) {
				$args->{'forceGiveup'}{'timeout'} = 4;
				$args->{'forceGiveup'}{'time'} = time;
			}
			if ($items{$args->{'args'}[0]}) {
				$args->{'time'} = time;
			} else {
				$args->{'time'} -= $args->{'timeout'};
			}
			if (timeOut($args->{'forceGiveup'})) {
				$args->{'time'} -= $args->{'timeout'};
			}
		}

		# Client suspended, do not continue with AI
		$result = 1;
	}
	return $result;
}

sub processLook {
	if (AI::action eq "look" && timeOut($timeout{'ai_look'})) {
		$timeout{'ai_look'}{'time'} = time;
		$messageSender->sendLook(AI::args->{'look_body'}, AI::args->{'look_head'});
		AI::dequeue;
	}
}

=pod
##### TALK WITH NPC ######
sub processNPCTalk {
	return if (AI::action ne "NPC");
	my $args = AI::args;
	my $task = $args->{task};
	if (!$task) {
		$task = new Task::TalkNPC(x => $args->{pos}{x},
					y => $args->{pos}{y},
					sequence => $args->{sequence});
		$task->activate();
		$args->{task} = $task;
	} else {
		$task->iterate();
		if ($task->getStatus() == Task::DONE) {
			AI::dequeue;
			my $error = $task->getError();
			if ($error) {
				error("$error->{message}\n", "ai_npcTalk");
			} else {
				message TF("Done talking with %s.\n", $task->target()->name), "ai_npcTalk";
			}
		}
	}
}
=cut

##### DROPPING #####
# Drop one or more items from inventory.
sub processDrop {
	if (AI::action eq "drop" && timeOut(AI::args)) {
		my $item = AI::args->{'items'}[0];
		my $amount = AI::args->{max};

		drop($item, $amount);
		shift @{AI::args->{items}};
		AI::args->{time} = time;
		AI::dequeue if (@{AI::args->{'items'}} <= 0);
	}
}

##### PORTALRECORD #####
# Automatically record new unknown portals
sub processPortalRecording {
	return unless $config{portalRecord};
	return unless $ai_v{portalTrace_mapChanged} && timeOut($ai_v{portalTrace_mapChanged}, 0.5);
	delete $ai_v{portalTrace_mapChanged};

	debug "Checking for new portals...\n", "portalRecord";
	my $first = 1;
	my ($foundID, $smallDist, $dist);

	if (!$field{name}) {
		debug "Field name not known - abort\n", "portalRecord";
		return;
	}


	# Find the nearest portal or the only portal on the map
	# you came from (source portal)
	foreach (@portalsID_old) {
		next if (!$_);
		$dist = distance($char->{old_pos_to}, $portals_old{$_}{pos});
		if ($dist <= 7 && ($first || $dist < $smallDist)) {
			$smallDist = $dist;
			$foundID = $_;
			undef $first;
		}
	}

	my ($sourceMap, $sourceID, %sourcePos, $sourceIndex);
	if (defined $foundID) {
		$sourceMap = $portals_old{$foundID}{source}{map};
		$sourceID = $portals_old{$foundID}{nameID};
		%sourcePos = %{$portals_old{$foundID}{pos}};
		$sourceIndex = $foundID;
		debug "Source portal: $sourceMap ($sourcePos{x}, $sourcePos{y})\n", "portalRecord";
	} else {
		debug "No source portal found.\n", "portalRecord";
		return;
	}

	#if (defined portalExists($sourceMap, \%sourcePos)) {
	#	debug "Source portal is already in portals.txt - abort\n", "portalRecord";
	#	return;
	#}


	# Find the nearest portal or only portal on the
	# current map (destination portal)
	$first = 1;
	undef $foundID;
	undef $smallDist;

	foreach (@portalsID) {
		next if (!$_);
		$dist = distance($chars[$config{'char'}]{pos_to}, $portals{$_}{pos});
		if ($first || $dist < $smallDist) {
			$smallDist = $dist;
			$foundID = $_;
			undef $first;
		}
	}

	# Sanity checks
	if (!defined $foundID) {
		debug "No destination portal found.\n", "portalRecord";
		return;
	}
	#if (defined portalExists($field{name}, $portals{$foundID}{pos})) {
	#	debug "Destination portal is already in portals.txt\n", "portalRecord";
	#	last PORTALRECORD;
	#}
	if (defined portalExists2($sourceMap, \%sourcePos, $field{name}, $portals{$foundID}{pos})) {
		debug "This portal is already in portals.txt\n", "portalRecord";
		return;
	}


	# And finally, record the portal information
	my ($destMap, $destID, %destPos);
	$destMap = $field{name};
	$destID = $portals{$foundID}{nameID};
	%destPos = %{$portals{$foundID}{pos}};
	debug "Destination portal: $destMap ($destPos{x}, $destPos{y})\n", "portalRecord";

	$portals{$foundID}{name} = "$field{name} -> $sourceMap";
	$portals_old{$sourceIndex}{name} = "$sourceMap -> $field{name}";


	my ($ID, $destName);

	# Record information about destination portal
	if ($config{portalRecord} > 1 &&
	    !defined portalExists($field{name}, $portals{$foundID}{pos})) {
		$ID = "$field{name} $destPos{x} $destPos{y}";
		$portals_lut{$ID}{source}{map} = $field{name};
		$portals_lut{$ID}{source}{x} = $destPos{x};
		$portals_lut{$ID}{source}{y} = $destPos{y};
		$destName = "$sourceMap $sourcePos{x} $sourcePos{y}";
		$portals_lut{$ID}{dest}{$destName}{map} = $sourceMap;
		$portals_lut{$ID}{dest}{$destName}{x} = $sourcePos{x};
		$portals_lut{$ID}{dest}{$destName}{y} = $sourcePos{y};

		message TF("Recorded new portal (destination): %s (%s, %s) -> %s (%s, %s)\n", $field{name}, $destPos{x}, $destPos{y}, $sourceMap, $sourcePos{x}, $sourcePos{y}), "portalRecord";
		updatePortalLUT(Settings::getTableFilename("portals.txt"),
				$field{name}, $destPos{x}, $destPos{y},
				$sourceMap, $sourcePos{x}, $sourcePos{y});
	}

	# Record information about the source portal
	if (!defined portalExists($sourceMap, \%sourcePos)) {
		$ID = "$sourceMap $sourcePos{x} $sourcePos{y}";
		$portals_lut{$ID}{source}{map} = $sourceMap;
		$portals_lut{$ID}{source}{x} = $sourcePos{x};
		$portals_lut{$ID}{source}{y} = $sourcePos{y};
		$destName = "$field{name} $destPos{x} $destPos{y}";
		$portals_lut{$ID}{dest}{$destName}{map} = $field{name};
		$portals_lut{$ID}{dest}{$destName}{x} = $destPos{x};
		$portals_lut{$ID}{dest}{$destName}{y} = $destPos{y};

		message TF("Recorded new portal (source): %s (%s, %s) -> %s (%s, %s)\n", $sourceMap, $sourcePos{x}, $sourcePos{y}, $field{name}, $char->{pos}{x}, $char->{pos}{y}), "portalRecord";
		updatePortalLUT(Settings::getTableFilename("portals.txt"),
				$sourceMap, $sourcePos{x}, $sourcePos{y},
				$field{name}, $char->{pos}{x}, $char->{pos}{y});
	}
}

##### ESCAPE UNKNOWN MAPS #####
sub processEscapeUnknownMaps {
	# escape from unknown maps. Happens when kore accidentally teleports onto an
	# portal. With this, kore should automaticly go into the portal on the other side
	# Todo: Make kore do a random walk searching for portal if there's no portal arround.

	if (AI::action eq "escape" && $AI == 2) {
		my $skip = 0;                   
		if (timeOut($timeout{ai_route_escape}) && $timeout{ai_route_escape}{time}){
			AI::dequeue;
			if ($portalsID[0]) {
				message T("Escaping to into nearest portal.\n");
				main::ai_route($field{name}, $portals{$portalsID[0]}{'pos'}{'x'},
					$portals{$portalsID[0]}{'pos'}{'y'}, attackOnRoute => 1, noSitAuto => 1);
				$skip = 1;

			} elsif ($spellsID[0]){   #get into the first portal you see
			     my $spell = $spells{$spellsID[0]};
				if (getSpellName($spell->{type}) eq "Warp Portal" ){
					message T("Found warp portal escaping into warp portal.\n");
					main::ai_route($field{name}, $spell->{pos}{x},
						$spell->{pos}{y}, attackOnRoute => 1, noSitAuto => 1);
					$skip = 1;
				}else{
					error T("Escape failed no portal found.\n");;
				}

			} else {
				error T("Escape failed no portal found.\n");
			}
		}
		if ($config{route_escape_randomWalk} && !$skip) { #randomly search for portals...
			my ($randX, $randY);
			my $i = 500;
			my $pos = calcPosition($char);
			do {
				if ((rand(2)+1)%2) {
					$randX = $pos->{x} + int(rand(9) + 1);
				} else {
					$randX = $pos->{x} - int(rand(9) + 1);
				}
				if ((rand(2)+1)%2) {
					$randY = $pos->{y} + int(rand(9) + 1);
				} else {
					$randY = $pos->{y} - int(rand(9) + 1);
				}
			} while (--$i && !$field->isWalkable($randX, $randY));
			if (!$i) {
				error T("Invalid coordinates specified for randomWalk\n Retrying...");
			} else {
				message TF("Calculating random route to: %s(%s): %s, %s\n", $maps_lut{$field{name}.'.rsw'}, $field{name}, $randX, $randY), "route";
				ai_route($field{name}, $randX, $randY,
					 maxRouteTime => $config{route_randomWalk_maxRouteTime},
					 attackOnRoute => 2,
					 noMapRoute => ($config{route_randomWalk} == 2 ? 1 : 0) );
			}
		}
	}
}

##### DELAYED-TELEPORT #####
sub processDelayedTeleport {
	if (AI::action eq 'teleport') {
		if ($timeout{ai_teleport_delay}{time} && timeOut($timeout{ai_teleport_delay})) {
			# We have already successfully used the Teleport skill,
			# and the ai_teleport_delay timeout has elapsed
			$messageSender->sendWarpTele(26, AI::args->{lv} == 2 ? "$config{saveMap}.gat" : "Random");
			AI::dequeue;
		} elsif (!$timeout{ai_teleport_delay}{time} && timeOut($timeout{ai_teleport_retry})) {
			# We are still trying to use the Teleport skill
			$messageSender->sendSkillUse(26, $char->{skills}{AL_TELEPORT}{lv}, $accountID);
			$timeout{ai_teleport_retry}{time} = time;
		}
	}
}

##### SKILL USE #####
sub processSkillUse {
	#FIXME: need to move closer before using skill on player,
	#there might be line of sight problem too
	#or the player disappers from the area

	if (AI::action eq "skill_use" && AI::args->{suspended}) {
		AI::args->{giveup}{time} += time - AI::args->{suspended};
		AI::args->{minCastTime}{time} += time - AI::args->{suspended};
		AI::args->{maxCastTime}{time} += time - AI::args->{suspended};
		delete AI::args->{suspended};
	}

	SKILL_USE: {
		last SKILL_USE if (AI::action ne "skill_use");
		my $args = AI::args;

		if ($args->{monsterID} && $skillsArea{$args->{skillHandle}} == 2) {
			delete $args->{monsterID};
		}

		if (exists $args->{ai_equipAuto_skilluse_giveup} && binFind(\@skillsID, $args->{skillHandle}) eq "" && timeOut($args->{ai_equipAuto_skilluse_giveup})) {
			warning T("Timeout equiping for skill\n");
			AI::dequeue;
			${$args->{ret}} = 'equip timeout' if ($args->{ret});
		} elsif (Actor::Item::scanConfigAndCheck("$args->{prefix}_equip")) {
			#check if item needs to be equipped
			Actor::Item::scanConfigAndEquip("$args->{prefix}_equip");
		} elsif (timeOut($args->{waitBeforeUse})) {
			if (defined $args->{monsterID} && !defined $monsters{$args->{monsterID}}) {
				# This skill is supposed to be used for attacking a monster, but that monster has died
				AI::dequeue;
				${$args->{ret}} = 'target gone' if ($args->{ret});

			} elsif ($char->{sitting}) {
				AI::suspend;
				stand();

			# Use skill if we haven't done so yet
			} elsif (!$args->{skill_used}) {
				my $handle = $args->{skillHandle};
				if (!defined $args->{skillID}) {
					my $skill = new Skill(handle => $handle);
					$args->{skillID} = $skill->getIDN();
				}
				my $skillID = $args->{skillID};

				if ($handle eq 'AL_TELEPORT') {
					${$args->{ret}} = 'ok' if ($args->{ret});
					AI::dequeue;
					useTeleport($args->{lv});
					last SKILL_USE;
				}

				$args->{skill_used} = 1;
				$args->{giveup}{time} = time;

				# Stop attacking, otherwise skill use might fail
				my $attackIndex = AI::findAction("attack");
				if (defined($attackIndex) && AI::args($attackIndex)->{attackMethod}{type} eq "weapon") {
					# 2005-01-24 pmak: Commenting this out since it may
					# be causing bot to attack slowly when a buff runs
					# out.
					#stopAttack();
				}

				# Give an error if we don't actually possess this skill
				my $skill = new Skill(handle => $handle);
				if ($char->{skills}{$handle}{lv} <= 0 && (!$char->{permitSkill} || $char->{permitSkill}->getHandle() ne $handle)) {
					debug "Attempted to use skill (".$skill->getName().") which you do not have.\n";
				}

				$args->{maxCastTime}{time} = time;
				if ($skillsArea{$handle} == 2) {
					$messageSender->sendSkillUse($skillID, $args->{lv}, $accountID);
				} elsif ($args->{x} ne "") {
					$messageSender->sendSkillUseLoc($skillID, $args->{lv}, $args->{x}, $args->{y});
				} else {
					$messageSender->sendSkillUse($skillID, $args->{lv}, $args->{target});
				}
				undef $char->{permitSkill};
				$args->{skill_use_last} = $char->{skills}{$handle}{time_used};

				delete $char->{cast_cancelled};

			} elsif (timeOut($args->{minCastTime})) {
				if ($args->{skill_use_last} != $char->{skills}{$args->{skillHandle}}{time_used}) {
					AI::dequeue;
					${$args->{ret}} = 'ok' if ($args->{ret});

				} elsif ($char->{cast_cancelled} > $char->{time_cast}) {
					AI::dequeue;
					${$args->{ret}} = 'cancelled' if ($args->{ret});

				} elsif (timeOut($char->{time_cast}, $char->{time_cast_wait} + 0.5)
				  && ( (timeOut($args->{giveup}) && (!$char->{time_cast} || !$args->{maxCastTime}{timeout}) )
				      || ( $args->{maxCastTime}{timeout} && timeOut($args->{maxCastTime})) )
				) {
					AI::dequeue;
					${$args->{ret}} = 'timeout' if ($args->{ret});
				}
			}
		}
	}
}

sub processTask {
	my $ai_name = shift;
	if (AI::action eq $ai_name) {
		my $task = AI::args;
		if ($task->getStatus() == Task::INACTIVE) {
			$task->activate();
			should($task->getStatus(), Task::RUNNING) if DEBUG;
		}
		if (DEBUG && $task->getStatus() != Task::RUNNING) {
			require Scalar::Util;
			require Data::Dumper;
			# Make sure redundant information is not included in the error report.
			if ($task->isa('Task::MapRoute')) {
				delete $task->{ST_subtask}{solution};
			} elsif ($task->isa('Task::Route') && $task->{ST_subtask}) {
				delete $task->{solution};
			}
			die "Task '" . $task->getName() . "' (class " . Scalar::Util::blessed($task) . ") has status " .
				Task::_getStatusName($task->getStatus()) .
				", but should be RUNNING. Object details:\n" .
				Data::Dumper::Dumper($task);
		}
		$task->iterate();
		if ($task->getStatus() == Task::DONE) {
			# We can't just dequeue the last AI sequence. Perhaps the task
			# pushed a new AI sequence on the AI stack just before finishing.
			# For example, the Route task does that when it's stuck.
			# So, we must dequeue the correct sequence without affecting the
			# others.
			for (my $i = 0; $i < @AI::ai_seq; $i++) {
				if ($AI::ai_seq[$i] eq $ai_name) {
					splice(@AI::ai_seq, $i, 1);
					splice(@AI::ai_seq_args, $i, 1);
					last;
				}
			}
			my %args = @_;
			my $error = $task->getError();
			if ($error) {
				if ($args{onError}) {
					$args{onError}->($task, $error);
				} else {
					error("$error->{message}\n");
				}
			} elsif ($args{onSuccess}) {
				$args{onSuccess}->($task);
			}
		}
	}
}

sub processTake {
	##### TAKE #####

	if (AI::action eq "take" && AI::args->{suspended}) {
		AI::args->{ai_take_giveup}{time} += time - AI::args->{suspended};
		delete AI::args->{suspended};
	}

	if (AI::action eq "take" && !(my $item = $items{AI::args->{ID}})) {
		AI::dequeue;

	} elsif (AI::action eq "take" && timeOut(AI::args->{ai_take_giveup})) {
		message TF("Failed to take %s (%s) from (%s, %s) to (%s, %s)\n", $item->{name}, $item->{binID}, $char->{pos}{x}, $char->{pos}{y}, $item->{pos}{x}, $item->{pos}{y});
		$item->{take_failed}++;
		AI::dequeue;

	} elsif (AI::action eq "take") {
		my $myPos = $char->{pos_to};
		my $dist = round(distance($item->{pos}, $myPos));
		debug "Planning to take $item->{name} ($item->{binID}), distance $dist\n", "drop";

		if ($char->{sitting}) {
			stand();

		} elsif ($dist > 1) {
			if (!$config{itemsTakeAuto_new}) {
				my (%vec, %pos);
				getVector(\%vec, $item->{pos}, $myPos);
				moveAlongVector(\%pos, $myPos, \%vec, $dist - 1);
				move($pos{x}, $pos{y});
			} else {
				my $pos = $item->{pos};
				message TF("Routing to (%s, %s) to take %s (%s), distance %s\n", $pos->{x}, $pos->{y}, $item->{name}, $item->{binID}, $dist);
				ai_route($field{name}, $pos->{x}, $pos->{y}, maxRouteDistance => $config{'attackMaxRouteDistance'});
			}

		} elsif (timeOut($timeout{ai_take})) {
			my %vec;
			my $direction;
			getVector(\%vec, $item->{pos}, $myPos);
			$direction = int(sprintf("%.0f", (360 - vectorToDegree(\%vec)) / 45)) % 8;
			$messageSender->sendLook($direction, 0) if ($direction != $char->{look}{body});
			$messageSender->sendTake($item->{ID});
			$timeout{ai_take}{time} = time;
		}
	}
}

##### MOVE #####
sub processMove {
	if (AI::action eq "move") {
		AI::args->{ai_move_giveup}{time} = time unless AI::args->{ai_move_giveup}{time};

		# Wait until we've stand up, if we're sitting
		if ($char->{sitting}) {
			AI::args->{ai_move_giveup}{time} = 0;
			stand();

		# Stop if the map changed
		} elsif (AI::args->{mapChanged}) {
			debug "Move - map change detected\n", "ai_move";
			AI::dequeue;

		# Stop if we've moved
		} elsif (AI::args->{time_move} != $char->{time_move}) {
			debug "Move - moving\n", "ai_move";
			AI::dequeue;

		# Stop if we've timed out
		} elsif (timeOut(AI::args->{ai_move_giveup})) {
			debug "Move - timeout\n", "ai_move";
			AI::dequeue;

		} elsif (timeOut($AI::Timeouts::move_retry, 0.5)) {
			# No update yet, send move request again.
			# We do this every 0.5 secs
			$AI::Timeouts::move_retry = time;
			$messageSender->sendMove(AI::args->{move_to}{x}, AI::args->{move_to}{y});
		}
	}
}

sub processEquip {
	if (AI::action eq "equip") {
		# Just wait until everything is equipped or timedOut
		if (!$ai_v{temp}{waitForEquip} || timeOut($timeout{ai_equip_giveup})) {
			AI::dequeue;
			delete $ai_v{temp}{waitForEquip};
		}
	}
}

sub processDeal {
	if (AI::action ne "deal" && %currentDeal) {
		AI::queue('deal');
	} elsif (AI::action eq "deal") {
		if (%currentDeal) {
			if (!$currentDeal{you_finalize} && timeOut($timeout{ai_dealAuto}) &&
				(!$config{dealAuto_names} || existsInList($config{dealAuto_names}, $currentDeal{name})) &&
			    ($config{dealAuto} == 2 ||
				 $config{dealAuto} == 3 && $currentDeal{other_finalize})) {
				$messageSender->sendDealAddItem(0, $currentDeal{'you_zeny'});
				$messageSender->sendDealFinalize();
				$timeout{ai_dealAuto}{time} = time;
			} elsif ($currentDeal{other_finalize} && $currentDeal{you_finalize} &&timeOut($timeout{ai_dealAuto}) && $config{dealAuto} >= 2 &&
				(!$config{dealAuto_names} || existsInList($config{dealAuto_names}, $currentDeal{name}))) {
				$messageSender->sendDealTrade();
				$timeout{ai_dealAuto}{time} = time;
			}
		} else {
			AI::dequeue();
		}
	}
}

sub processDealAuto {
	# dealAuto 1=refuse 2,3=accept
	if ($config{'dealAuto'} && %incomingDeal) {
		if ($config{'dealAuto'} == 1 && timeOut($timeout{ai_dealAutoCancel})) {
			$messageSender->sendDealReply(4);
			$timeout{'ai_dealAutoCancel'}{'time'} = time;
		} elsif ($config{'dealAuto'} >= 2 &&
			(!$config{dealAuto_names} || existsInList($config{dealAuto_names}, $incomingDeal{name})) &&
			timeOut($timeout{ai_dealAuto})) {
			$messageSender->sendDealReply(3);
			$timeout{'ai_dealAuto'}{'time'} = time;
		}
	}
}

sub processPartyAuto {
	# partyAuto 1=refuse 2=accept
	if ($config{'partyAuto'} && %incomingParty && timeOut($timeout{'ai_partyAuto'})) {
		if ($config{partyAuto} == 1) {
			message T("Auto-denying party request\n");
		} else {
			message T("Auto-accepting party request\n");
		}
		$messageSender->sendPartyJoin($incomingParty{'ID'}, $config{'partyAuto'} - 1);
		$timeout{'ai_partyAuto'}{'time'} = time;
		undef %incomingParty;
	}
}

sub processGuildAutoDeny {
	if ($config{'guildAutoDeny'} && %incomingGuild && timeOut($timeout{'ai_guildAutoDeny'})) {
		$messageSender->sendGuildJoin($incomingGuild{'ID'}, 0) if ($incomingGuild{'Type'} == 1);
		$messageSender->sendGuildAlly($incomingGuild{'ID'}, 0) if ($incomingGuild{'Type'} == 2);
		$timeout{'ai_guildAutoDeny'}{'time'} = time;
		undef %incomingGuild;
	}
}

=pod moved to a plugin
##### AUTOBREAKTIME #####
# Break time: automatically disconnect at certain times of the day
sub processAutoBreakTime {
	if (timeOut($AI::Timeouts::autoBreakTime, 30)) {
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
		my $hormin = sprintf("%02d:%02d", $hour, $min);
		my @wdays = ('sun','mon','tue','wed','thu','fri','sat');
		debug "autoBreakTime: hormin = $hormin, weekday = $wdays[$wday]\n", "autoBreakTime", 2;
		for (my $i = 0; exists $config{"autoBreakTime_$i"}; $i++) {
			next if (!$config{"autoBreakTime_$i"});

			if  ( ($wdays[$wday] eq lc($config{"autoBreakTime_$i"})) || (lc($config{"autoBreakTime_$i"}) eq "all") ) {
				if ($config{"autoBreakTime_${i}_startTime"} eq $hormin) {
					my ($hr1, $min1) = split /:/, $config{"autoBreakTime_${i}_startTime"};
					my ($hr2, $min2) = split /:/, $config{"autoBreakTime_${i}_stopTime"};
					my $time1 = $hr1 * 60 * 60 + $min1 * 60;
					my $time2 = $hr2 * 60 * 60 + $min2 * 60;
					my $diff = ($time2 - $time1) % (60 * 60 * 24);

					message TF("\nDisconnecting due to break time: %s to %s\n\n", $config{"autoBreakTime_$i"."_startTime"}, $config{"autoBreakTime_$i"."_stopTime"}), "system";
					chatLog("k", TF("*** Disconnected due to Break Time: %s to %s ***\n", $config{"autoBreakTime_$i"."_startTime"}, $config{"autoBreakTime_$i"."_stopTime"}));

					$timeout_ex{'master'}{'timeout'} = $diff;
					$timeout_ex{'master'}{'time'} = time;
					$KoreStartTime = time;
					$net->serverDisconnect();
					AI::clear();
					undef %ai_v;
					$net->setState(Network::NOT_CONNECTED);
					undef $conState_tries;
					last;
				}
			}
		}
		$AI::Timeouts::autoBreakTime = time;
	}
}
=cut

##### DEAD #####
sub processDead {
	if (AI::action eq "dead" && !$char->{dead}) {
		AI::dequeue;

		if ($char->{resurrected}) {
			# We've been resurrected
			$char->{resurrected} = 0;

		} else {
			# Force storage after death
			if ($config{storageAuto} && !$config{storageAuto_notAfterDeath} && ai_storageAutoCheck()) {
				message T("Auto-storaging due to death\n");
				AI::queue("storageAuto");
			}

			if ($config{autoMoveOnDeath} && $config{autoMoveOnDeath_map}) {
				if ($config{autoMoveOnDeath_x} && $config{autoMoveOnDeath_y}) {
					message TF("Moving to %s - %d,%d\n", $config{autoMoveOnDeath_map}, $config{autoMoveOnDeath_x}, $config{autoMoveOnDeath_y});
				} else {
					message TF("Moving to %s\n", $config{autoMoveOnDeath_map});
				}
				AI::queue("sitAuto");
				ai_route($config{autoMoveOnDeath_map}, $config{autoMoveOnDeath_x}, $config{autoMoveOnDeath_y});
			}
		}

	} elsif (AI::action ne "dead" && AI::action ne "deal" && $char->{'dead'}) {
		AI::clear();
		AI::queue("dead");
	}

	if (AI::action eq "dead" && $config{dcOnDeath} != -1 && time - $char->{dead_time} >= $timeout{ai_dead_respawn}{timeout}) {
		$messageSender->sendRestart(0);
		$char->{'dead_time'} = time;
	}

	if (AI::action eq "dead" && $config{dcOnDeath} && $config{dcOnDeath} != -1) {
		message T("Disconnecting on death!\n");
		chatLog("k", T("*** You died, auto disconnect! ***\n"));
		$quit = 1;
	}
}

##### STORAGE GET #####
# Get one or more items from storage.
sub processStorageGet {
	if (AI::action eq "storageGet" && timeOut(AI::args)) {
		my $item = shift @{AI::args->{items}};
		my $amount = AI::args->{max};

		if (!$amount || $amount > $item->{amount}) {
			$amount = $item->{amount};
		}
		$messageSender->sendStorageGet($item->{index}, $amount) if $storage{opened};
		AI::args->{time} = time;
		AI::dequeue if !@{AI::args->{items}};
	}
}

#### CART ADD ####
# Put one or more items in cart.
# TODO: check for cart weight & number of items
sub processCartAdd {
	if (AI::action eq "cartAdd" && timeOut(AI::args)) {
		my $item = AI::args->{items}[0];
		my $i = $item->{index};
		my $invItem = $char->inventory->get($i);
		if ($invItem) {
			my $amount = $item->{amount};
			if (!$amount || $amount > $invItem->{amount}) {
				$amount = $invItem->{amount};
			}
			$messageSender->sendCartAdd($invItem->{index}, $amount);
		}
		shift @{AI::args->{items}};
		AI::args->{time} = time;
		AI::dequeue if (@{AI::args->{items}} <= 0);
	}
}

#### CART Get ####
# Get one or more items from cart.
sub processCartGet {
	if (AI::action eq "cartGet" && timeOut(AI::args)) {
		my $item = AI::args->{items}[0];
		my $i = $item->{index};

		if ($cart{inventory}[$i]) {
			my $amount = $item->{amount};
			if (!$amount || $amount > $cart{inventory}[$i]{amount}) {
				$amount = $cart{inventory}[$i]{amount};
			}
			$messageSender->sendCartGet($i, $amount);
		}
		shift @{AI::args->{items}};
		AI::args->{time} = time;
		AI::dequeue if (@{AI::args->{items}} <= 0);
	}
}

sub processAutoMakeArrow {
	####### AUTO MAKE ARROW #######
	if ((AI::isIdle || AI::is(qw/route move autoBuy storageAuto follow sitAuto items_take items_gather/))
	 && timeOut($AI::Timeouts::autoArrow, 0.2) && $config{autoMakeArrows} && defined binFind(\@skillsID, 'AC_MAKINGARROW') ) {
		my $max = @arrowCraftID;
		for (my $i = 0; $i < $max; $i++) {
			my $item = $char->inventory->get($arrowCraftID[$i]);
			next if (!$item);
			if ($arrowcraft_items{lc($item->{name})}) {
				$messageSender->sendArrowCraft($item->{nameID});
				debug "Making item\n", "ai_makeItem";
				last;
			}
		}
		$AI::Timeouts::autoArrow = time;
	}

	if ($config{autoMakeArrows} && $useArrowCraft) {
		if (defined binFind(\@skillsID, 'AC_MAKINGARROW')) {
			ai_skillUse('AC_MAKINGARROW', 1, 0, 0, $accountID);
		}
		undef $useArrowCraft;
	}
}

##### AUTO STORAGE #####
sub processAutoStorage {
	# storageAuto - chobit aska 20030128
	if (AI::is("", "route", "sitAuto", "follow")
		  && $config{storageAuto} && ($config{storageAuto_npc} ne "" || $config{storageAuto_useChatCommand})
		  && !$ai_v{sitAuto_forcedBySitCommand}
		  && (($config{'itemsMaxWeight_sellOrStore'} && percent_weight($char) >= $config{'itemsMaxWeight_sellOrStore'})
		      || (!$config{'itemsMaxWeight_sellOrStore'} && percent_weight($char) >= $config{'itemsMaxWeight'}))
		  && !AI::inQueue("storageAuto") && time > $ai_v{'inventory_time'}) {

		# Initiate autostorage when the weight limit has been reached
		my $routeIndex = AI::findAction("route");
		my $attackOnRoute = 2;
		$attackOnRoute = AI::args($routeIndex)->{attackOnRoute} if (defined $routeIndex);
		# Only autostorage when we're on an attack route, or not moving
		if ($attackOnRoute > 1 && ai_storageAutoCheck()) {
			message T("Auto-storaging due to excess weight\n");
			AI::queue("storageAuto");
		}

	} elsif (AI::is("", "route", "attack")
		  && $config{storageAuto}
		  && ($config{storageAuto_npc} ne "" || $config{storageAuto_useChatCommand})
		  && !$ai_v{sitAuto_forcedBySitCommand}
		  && !AI::inQueue("storageAuto")
		  && $char->inventory->size() > 0) {

		# Initiate autostorage when we're low on some item, and getAuto is set
		my $needitem = "";
		my $i;
		Misc::checkValidity("AutoStorage part 1");
		for ($i = 0; exists $config{"getAuto_$i"}; $i++) {
			next unless ($config{"getAuto_$i"});
			if ($storage{opened} && findKeyString(\%storage, "name", $config{"getAuto_$i"}) eq '') {
				foreach (keys %items_lut) {
					if ((lc($items_lut{$_}) eq lc($config{"getAuto_$i"})) && ($items_lut{$_} ne $config{"getAuto_$i"})) {
						configModify("getAuto_$i", $items_lut{$_});
					}
				}
			}

			my $item = $char->inventory->getByName($config{"getAuto_$i"});
			if ($config{"getAuto_${i}_minAmount"} ne "" &&
			    $config{"getAuto_${i}_maxAmount"} ne "" &&
			    !$config{"getAuto_${i}_passive"} &&
			    (!$item ||
				 ($item->{amount} <= $config{"getAuto_${i}_minAmount"} &&
				  $item->{amount} < $config{"getAuto_${i}_maxAmount"})
			    )
			) {
				if ($storage{opened} && findKeyString(\%storage, "name", $config{"getAuto_$i"}) eq '') {
					if ($config{"getAuto_${i}_dcOnEmpty"}) {
 						message TF("Disconnecting on empty %s!\n", $config{"getAuto_$i"});
						chatLog("k", TF("Disconnecting on empty %s!\n", $config{"getAuto_$i"}));
						quit();
					}
				} else {
					if ($storage{openedThisSession} && findKeyString(\%storage, "name", $config{"getAuto_$i"}) eq '') {
					} else {
							my $sti = $config{"getAuto_$i"};
							if ($needitem eq "") {
								$needitem = "$sti";
							} else {$needitem = "$needitem, $sti";}
						}
				}
			}
		}
		Misc::checkValidity("AutoStorage part 2");

		my $routeIndex = AI::findAction("route");
		my $attackOnRoute;
		$attackOnRoute = AI::args($routeIndex)->{attackOnRoute} if (defined $routeIndex);

		# Only autostorage when we're on an attack route, or not moving
		if ((!defined($routeIndex) || $attackOnRoute > 1) && $needitem ne "" &&
			$char->inventory->size() > 0 && ai_storageAutoCheck()) {
	 		message TF("Auto-storaging due to insufficient %s\n", $needitem);
			AI::queue("storageAuto");
		}
		$timeout{'ai_storageAuto'}{'time'} = time;
	}


	if (AI::action eq "storageAuto" && AI::args->{done}) {
		# Autostorage finished; trigger sellAuto unless autostorage was already triggered by it
		my $forcedBySell = AI::args->{forcedBySell};
		my $forcedByBuy = AI::args->{forcedByBuy};
		AI::dequeue;
		if ($forcedByBuy) {
			AI::queue("sellAuto", {forcedByBuy => 1});
		} elsif (!$forcedBySell && ai_sellAutoCheck() && $config{sellAuto}) {
			AI::queue("sellAuto", {forcedByStorage => 1});
		}

	} elsif (AI::action eq "storageAuto" && timeOut($timeout{'ai_storageAuto'})) {
		# Main autostorage block
		my $args = AI::args;

		my $do_route;

		if (!$config{storageAuto_useChatCommand}) {
			# Stop if the specified NPC is invalid
			$args->{npc} = {};
			getNPCInfo($config{'storageAuto_npc'}, $args->{npc});
			if (!defined($args->{npc}{ok})) {
				$args->{done} = 1;
				return;
			}

			# Determine whether we have to move to the NPC
			if ($field{'name'} ne $args->{npc}{map}) {
				$do_route = 1;
			} else {
				my $distance = distance($args->{npc}{pos}, $char->{pos_to});
				if ($distance > $config{'storageAuto_distance'}) {
					$do_route = 1;
				}
			}

			if ($do_route) {
				if ($args->{warpedToSave} && !$args->{mapChanged} && !timeOut($args->{warpStart}, 8)) {
					undef $args->{warpedToSave};
				}

				# If warpToBuyOrSell is set, warp to saveMap if we haven't done so
				if ($config{'saveMap'} ne "" && $config{'saveMap_warpToBuyOrSell'} && !$args->{warpedToSave}
				    && !$cities_lut{$field{'name'}.'.rsw'} && $config{'saveMap'} ne $field{name}) {
					$args->{warpedToSave} = 1;
					# If we still haven't warped after a certain amount of time, fallback to walking
					$args->{warpStart} = time unless $args->{warpStart};
					message T("Teleporting to auto-storage\n"), "teleport";
					useTeleport(2);
					$timeout{'ai_storageAuto'}{'time'} = time;
				} else {
					# warpToBuyOrSell is not set, or we've already warped, or timed out. Walk to the NPC
					message TF("Calculating auto-storage route to: %s(%s): %s, %s\n", $maps_lut{$args->{npc}{map}.'.rsw'}, $args->{npc}{map}, $args->{npc}{pos}{x}, $args->{npc}{pos}{y}), "route";
					ai_route($args->{npc}{map}, $args->{npc}{pos}{x}, $args->{npc}{pos}{y},
						 attackOnRoute => 1,
						 distFromGoal => $config{'storageAuto_distance'});
				}
			}
		}
		if (!$do_route) {
			# Talk to NPC if we haven't done so
			if (!defined($args->{sentStore})) {
				if ($config{storageAuto_useChatCommand}) {
					$messageSender->sendChat($config{storageAuto_useChatCommand});
				} else {
					if ($config{'storageAuto_npc_type'} eq "" || $config{'storageAuto_npc_type'} eq "1") {
						warning T("Warning storageAuto has changed. Please read News.txt\n") if ($config{'storageAuto_npc_type'} eq "");
						$config{'storageAuto_npc_steps'} = "c r1 n";
						debug "Using standard iRO npc storage steps.\n", "npc";
					} elsif ($config{'storageAuto_npc_type'} eq "2") {
						$config{'storageAuto_npc_steps'} = "c c r1 n";
						debug "Using iRO comodo (location) npc storage steps.\n", "npc";
					} elsif ($config{'storageAuto_npc_type'} eq "3") {
						message T("Using storage steps defined in config.\n"), "info";
					} elsif ($config{'storageAuto_npc_type'} ne "" && $config{'storageAuto_npc_type'} ne "1" && $config{'storageAuto_npc_type'} ne "2" && $config{'storageAuto_npc_type'} ne "3") {
						error T("Something is wrong with storageAuto_npc_type in your config.\n");
					}

					ai_talkNPC($args->{npc}{pos}{x}, $args->{npc}{pos}{y}, $config{'storageAuto_npc_steps'});
				}

				delete $ai_v{temp}{storage_opened};
				$args->{sentStore} = 1;

				# NPC talk retry
				$AI::Timeouts::storageOpening = time;
				$timeout{'ai_storageAuto'}{'time'} = time;
				return;
			}

			if (!defined $ai_v{temp}{storage_opened}) {
				# NPC talk retry
				if (timeOut($AI::Timeouts::storageOpening, 40)) {
					undef $args->{sentStore};
					debug "Retry talking to autostorage NPC.\n", "npc";
				}

				# Storage not yet opened; stop and wait until it's open
				return;
			}

			if (!$args->{getStart}) {
				$args->{done} = 1;
				
				# if storage is full disconnect if it says so in conf
				if(defined $storage{items_max} && @storageID >= $storage{items_max} && $config{'dcOnStorageFull'}) {
					error T("Disconnecting because storage is full!\n");
					chatLog("k", T("Disconnecting because storage is full!\n"));
					quit();
				}

				# inventory to storage
				$args->{nextItem} = 0 unless $args->{nextItem};
				for (my $i = $args->{nextItem}; $i < @{$char->inventory->getItems()}; $i++) {
					my $item = $char->inventory->getItems()->[$i];
					next if $item->{equipped};
					next if ($item->{broken} && $item->{type} == 7); # dont store pet egg in use

					my $control = items_control($item->{name});

					debug "AUTOSTORAGE: $item->{name} x $item->{amount} - store = $control->{storage}, keep = $control->{keep}\n", "storage";
					if ($control->{storage} && $item->{amount} > $control->{keep}) {
						if ($args->{lastIndex} == $item->{index} &&
						    timeOut($timeout{'ai_storageAuto_giveup'})) {
							return;
						} elsif ($args->{lastIndex} != $item->{index}) {
							$timeout{ai_storageAuto_giveup}{time} = time;
						}
						undef $args->{done};
						$args->{lastIndex} = $item->{index};
						$messageSender->sendStorageAdd($item->{index}, $item->{amount} - $control->{keep});
						$timeout{ai_storageAuto}{time} = time;
						$args->{nextItem} = $i;
						return;
					}
				}

				# cart to storage
				# we don't really need to check if we have a cart
				# if we don't have one it will not find any items to loop through
				$args->{cartNextItem} = 0 unless $args->{cartNextItem};
				for (my $i = $args->{cartNextItem}; $i < @{$cart{inventory}}; $i++) {
					my $item = $cart{inventory}[$i];
					next unless ($item && %{$item});

					my $control = items_control($item->{name});

					debug "AUTOSTORAGE (cart): $item->{name} x $item->{amount} - store = $control->{storage}, keep = $control->{keep}\n", "storage";
					# store from cart as well as inventory if the flag is equal to 2
					if ($control->{storage} == 2 && $item->{amount} > $control->{keep}) {
						if ($args->{cartLastIndex} == $item->{index} &&
						    timeOut($timeout{'ai_storageAuto_giveup'})) {
							return;
						} elsif ($args->{cartLastIndex} != $item->{index}) {
							$timeout{ai_storageAuto_giveup}{time} = time;
						}
						undef $args->{done};
						$args->{cartLastIndex} = $item->{index};
						$messageSender->sendStorageAddFromCart($item->{index}, $item->{amount} - $control->{keep});
						$timeout{ai_storageAuto}{time} = time;
						$args->{cartNextItem} = $i + 1;
						return;
					}
				}

				if ($args->{done}) {
					# plugins can hook here and decide to keep storage open longer
					my %hookArgs;
					Plugins::callHook("AI_storage_done", \%hookArgs);
					undef $args->{done} if ($hookArgs{return});
				}
			}


			# getAuto begin

			if (!$args->{getStart} && $args->{done} == 1) {
				$args->{getStart} = 1;
				undef $args->{done};
				$args->{index} = 0;
				$args->{retry} = 0;
				return;
			}

			if (defined($args->{getStart}) && $args->{done} != 1) {
				Misc::checkValidity("AutoStorage part 3");
				while (exists $config{"getAuto_$args->{index}"}) {
					if (!$config{"getAuto_$args->{index}"}) {
						$args->{index}++;
						next;
					}

					my %item;
					my $itemName = $config{"getAuto_$args->{index}"};
					if (!$itemName) {
						$args->{index}++;
						next;
					}
					my $invItem = $char->inventory->getByName($itemName);
					$item{name} = $itemName;
					$item{inventory}{index} = $invItem ? $invItem->{invIndex} : undef;
					$item{inventory}{amount} = $invItem ? $invItem->{amount} : 0;
					$item{storage}{index} = findKeyString(\%storage, "name", $item{name});
					$item{storage}{amount} = ($item{storage}{index} ne "")? $storage{$item{storage}{index}}{amount} : 0;
					$item{max_amount} = $config{"getAuto_$args->{index}"."_maxAmount"};
					$item{amount_needed} = $item{max_amount} - $item{inventory}{amount};

					# Calculate the amount to get
					if ($item{amount_needed} > 0) {
						$item{amount_get} = ($item{storage}{amount} >= $item{amount_needed})? $item{amount_needed} : $item{storage}{amount};
					}

					# Try at most 3 times to get the item
					if (($item{amount_get} > 0) && ($args->{retry} < 3)) {
						message TF("Attempt to get %s x %s from storage, retry: %s\n", $item{amount_get}, $item{name}, $ai_seq_args[0]{retry}), "storage", 1;
						$messageSender->sendStorageGet($item{storage}{index}, $item{amount_get});
						$timeout{ai_storageAuto}{time} = time;
						$args->{retry}++;
						return;

						# we don't inc the index when amount_get is more then 0, this will enable a way of retrying
						# on next loop if it fails this time
					}

					if ($item{storage}{amount} < $item{amount_needed}) {
						warning TF("storage: %s out of stock\n", $item{name});
					}

					if (!$config{relogAfterStorage} && $args->{retry} >= 3 && !$args->{warned}) {
						# We tried 3 times to get the item and failed.
						# There is a weird server bug which causes this to happen,
						# but I can't reproduce it. This can be worked around by
						# relogging in after autostorage.
						warning T("Kore tried to get an item from storage 3 times, but failed.\n" .
							  "This problem could be caused by a server bug.\n" .
							  "To work around this problem, set 'relogAfterStorage' to 1, and relogin.\n");
						$args->{warned} = 1;
					}

					# We got the item, or we tried 3 times to get it, but failed.
					# Increment index and process the next item.
					$args->{index}++;
					$args->{retry} = 0;
				}
				Misc::checkValidity("AutoStorage part 4");
			}

			$messageSender->sendStorageClose() unless $config{storageAuto_keepOpen};
			if (percent_weight($char) >= $config{'itemsMaxWeight_sellOrStore'} && ai_storageAutoCheck()) {
				error T("Character is still overweight after storageAuto (storage is full?)\n");
				if ($config{dcOnStorageFull}) {
					error T("Disconnecting on storage full!\n");
					chatLog("k", T("Disconnecting on storage full!\n"));
					quit();
				}
			}
			
			if ($config{'relogAfterStorage'} && $config{'XKore'} ne "1") {
				writeStorageLog(0);
				relog();
			}
			$args->{done} = 1;
		}
	}
}

#####AUTO SELL#####
sub processAutoSell {
	if ((AI::action eq "" || AI::action eq "route" || AI::action eq "sitAuto" || AI::action eq "follow")
		&& (($config{'itemsMaxWeight_sellOrStore'} && percent_weight($char) >= $config{'itemsMaxWeight_sellOrStore'})
			|| ($config{'itemsMaxNum_sellOrStore'} && $char->inventory->size() >= $config{'itemsMaxNum_sellOrStore'})
			|| (!$config{'itemsMaxWeight_sellOrStore'} && percent_weight($char) >= $config{'itemsMaxWeight'})
			)
		&& $config{'sellAuto'}
		&& $config{'sellAuto_npc'} ne ""
		&& !$ai_v{sitAuto_forcedBySitCommand}
	  ) {
		$ai_v{'temp'}{'ai_route_index'} = AI::findAction("route");
		if ($ai_v{'temp'}{'ai_route_index'} ne "") {
			$ai_v{'temp'}{'ai_route_attackOnRoute'} = AI::args($ai_v{'temp'}{'ai_route_index'})->{'attackOnRoute'};
		}
		if (!($ai_v{'temp'}{'ai_route_index'} ne "" && $ai_v{'temp'}{'ai_route_attackOnRoute'} <= 1) && ai_sellAutoCheck()) {
			AI::queue("sellAuto");
		}
	}

	if (AI::action eq "sellAuto" && AI::args->{'done'}) {
		my $var = AI::args->{'forcedByBuy'};
		my $var2 = AI::args->{'forcedByStorage'};
		message T("Auto-sell sequence completed.\n"), "success";
		AI::dequeue;
		if ($var2) {
			AI::queue("buyAuto", {forcedByStorage => 1});
		} elsif (!$var) {
			AI::queue("buyAuto", {forcedBySell => 1});
		}
	} elsif (AI::action eq "sellAuto" && timeOut($timeout{'ai_sellAuto'})) {
		my $args = AI::args;

		$args->{'npc'} = {};
		my $destination = $config{sellAuto_standpoint} || $config{sellAuto_npc};
		getNPCInfo($destination, $args->{'npc'});
		if (!defined($args->{'npc'}{'ok'})) {
			$args->{'done'} = 1;
			return;
		}

		undef $ai_v{'temp'}{'do_route'};
		if ($field{'name'} ne $args->{'npc'}{'map'}) {
			$ai_v{'temp'}{'do_route'} = 1;
		} else {
			$ai_v{'temp'}{'distance'} = distance($args->{'npc'}{'pos'}, $chars[$config{'char'}]{'pos_to'});
			$config{'sellAuto_distance'} = 1 if ($config{sellAuto_standpoint});
			if ($ai_v{'temp'}{'distance'} > $config{'sellAuto_distance'}) {
				$ai_v{'temp'}{'do_route'} = 1;
			}
		}
		if ($ai_v{'temp'}{'do_route'}) {
			if ($args->{'warpedToSave'} && !$args->{'mapChanged'} && !timeOut($args->{warpStart}, 8)) {
				undef $args->{'warpedToSave'};
			}

			if ($config{'saveMap'} ne "" && $config{'saveMap_warpToBuyOrSell'} && !$args->{'warpedToSave'}
			&& !$cities_lut{$field{'name'}.'.rsw'} && $config{'saveMap'} ne $field{name}) {
				$args->{'warpedToSave'} = 1;
				# If we still haven't warped after a certain amount of time, fallback to walking
				$args->{warpStart} = time unless $args->{warpStart};
				message T("Teleporting to auto-sell\n"), "teleport";
				useTeleport(2);
				$timeout{'ai_sellAuto'}{'time'} = time;
			} else {
	 			message TF("Calculating auto-sell route to: %s(%s): %s, %s\n", $maps_lut{$ai_seq_args[0]{'npc'}{'map'}.'.rsw'}, $ai_seq_args[0]{'npc'}{'map'}, $ai_seq_args[0]{'npc'}{'pos'}{'x'}, $ai_seq_args[0]{'npc'}{'pos'}{'y'}), "route";
				ai_route($args->{'npc'}{'map'}, $args->{'npc'}{'pos'}{'x'}, $args->{'npc'}{'pos'}{'y'},
					attackOnRoute => 1,
					distFromGoal => $config{'sellAuto_distance'},
					noSitAuto => 1);
			}
		} else {
			$args->{'npc'} = {};
			getNPCInfo($config{'sellAuto_npc'}, $args->{'npc'});
			if (!defined($args->{'sentSell'})) {
				$args->{'sentSell'} = 1;

				# load the real npc location just in case we used standpoint
				my $realpos = {};
				getNPCInfo($config{"sellAuto_npc"}, $realpos);

				ai_talkNPC($realpos->{pos}{x}, $realpos->{pos}{y}, $config{sellAuto_npc_steps} || 's e');

				return;
			}
			$args->{'done'} = 1;

			# Form list of items to sell
			my @sellItems;
			foreach my $item (@{$char->inventory->getItems()}) {
				next if ($item->{equipped});

				my $control = items_control($item->{name});

				if ($control->{'sell'} && $item->{'amount'} > $control->{keep}) {
					if ($args->{lastIndex} ne "" && $args->{lastIndex} == $item->{index} && timeOut($timeout{'ai_sellAuto_giveup'})) {
						return;
					} elsif ($args->{lastIndex} eq "" || $args->{lastIndex} != $item->{index}) {
						$timeout{ai_sellAuto_giveup}{time} = time;
					}
					undef $args->{done};
					$args->{lastIndex} = $item->{index};

					my %obj;
					$obj{index} = $item->{index};
					$obj{amount} = $item->{amount} - $control->{keep};
					push @sellItems, \%obj;

					$timeout{ai_sellAuto}{time} = time;
				}
			}
			$messageSender->sendSellBulk(\@sellItems) if (@sellItems);

			if ($args->{done}) {
				# plugins can hook here and decide to keep sell going longer
				my %hookArgs;
				Plugins::callHook("AI_sell_done", \%hookArgs);
				undef $args->{done} if ($hookArgs{return});
			}
		}
	}
}

#####AUTO BUY#####
sub processAutoBuy {
		my $needitem;
	if ((AI::action eq "" || AI::action eq "route" || AI::action eq "follow") && timeOut($timeout{'ai_buyAuto'}) && time > $ai_v{'inventory_time'}) {
		undef $ai_v{'temp'}{'found'};
		my $i = 0;
		while (1) {
			last if (!$config{"buyAuto_$i"} || !$config{"buyAuto_$i"."_npc"});
			my $item = $char->inventory->getByName($config{"buyAuto_$i"});
			if ($config{"buyAuto_$i"."_minAmount"} ne "" && $config{"buyAuto_$i"."_maxAmount"} ne ""
				&& (checkSelfCondition("buyAuto_$i"))
				&& (!$item
				    || ($item->{amount} <= $config{"buyAuto_$i"."_minAmount"}
				        && $item->{amount} < $config{"buyAuto_$i"."_maxAmount"}
				       )
				)
			) {
				$ai_v{'temp'}{'found'} = 1;
				my $bai = $config{"buyAuto_$i"};
				if ($needitem eq "") {
					$needitem = "$bai";
				} else {$needitem = "$needitem, $bai";}
			}
			$i++;
		}
		$ai_v{'temp'}{'ai_route_index'} = AI::findAction("route");
		if ($ai_v{'temp'}{'ai_route_index'} ne "") {
			$ai_v{'temp'}{'ai_route_attackOnRoute'} = AI::args($ai_v{'temp'}{'ai_route_index'})->{'attackOnRoute'};
		}
		if (!($ai_v{'temp'}{'ai_route_index'} ne "" && AI::findAction("buyAuto")) && $ai_v{'temp'}{'found'}) {
			AI::queue("buyAuto");
		}
		$timeout{'ai_buyAuto'}{'time'} = time;
	}

	if (AI::action eq "buyAuto" && AI::args->{'done'}) {
		# buyAuto finished
		$ai_v{'temp'}{'var'} = AI::args->{'forcedBySell'};
		$ai_v{'temp'}{'var2'} = AI::args->{'forcedByStorage'};
		AI::dequeue;

		if ($ai_v{'temp'}{'var'} && $config{storageAuto}) {
			AI::queue("storageAuto", {forcedBySell => 1});
		} elsif (!$ai_v{'temp'}{'var2'} && $config{storageAuto}) {
			AI::queue("storageAuto", {forcedByBuy => 1});
		}

	} elsif (AI::action eq "buyAuto" && timeOut($timeout{ai_buyAuto_wait}) && timeOut($timeout{ai_buyAuto_wait_buy})) {
		my $args = AI::args;
		undef $args->{index};

		for (my $i = 0; exists $config{"buyAuto_$i"}; $i++) {
			next if (!$config{"buyAuto_$i"} || $config{"buyAuto_${i}_disabled"});
			# did we already fail to do this buyAuto slot? (only fails in this way if the item is nonexistant)
			next if ($args->{index_failed}{$i});

			my $item = $char->inventory->getByName($config{"buyAuto_$i"});
			$args->{invIndex} = $item ? $item->{invIndex} : undef;
			if ($config{"buyAuto_$i"."_maxAmount"} ne "" && (!$item || $item->{amount} < $config{"buyAuto_$i"."_maxAmount"})) {
				next if (($config{"buyAuto_$i"."_price"} && ($char->{zeny} < $config{"buyAuto_$i"."_price"})) || ($config{"buyAuto_$i"."_zeny"} && !inRange($char->{zeny}, $config{"buyAuto_$i"."_zeny"})));

				# get NPC info, use standpoint if provided
				$args->{npc} = {};
				my $destination = $config{"buyAuto_$i"."_standpoint"} || $config{"buyAuto_$i"."_npc"};
				getNPCInfo($destination, $args->{npc});

				# did we succeed to load NPC info from this slot?
				# (doesnt check validity of _npc if we used _standpoint...)
				if ($args->{npc}{ok}) {
					$args->{index} = $i;
				}
				last;
			}
		}

		# failed to load any slots for buyAuto (we're done or they're all invalid)
		# what does the second check do here?
		if ($args->{index} eq "" || ($args->{lastIndex} ne "" && $args->{lastIndex} == $args->{index} && timeOut($timeout{'ai_buyAuto_giveup'}))) {
			$args->{'done'} = 1;
			return;
		}

		undef $ai_v{'temp'}{'do_route'};
		if ($field{'name'} ne $args->{'npc'}{'map'}) {
			$ai_v{'temp'}{'do_route'} = 1;
		} else {
			$ai_v{'temp'}{'distance'} = distance($args->{'npc'}{'pos'}, $chars[$config{'char'}]{'pos_to'});
			$config{"buyAuto_$args->{index}"."_distance"} = 1 if ($config{"buyAuto_$args->{index}"."_standpoint"});
			if ($ai_v{'temp'}{'distance'} > $config{"buyAuto_$args->{index}"."_distance"}) {
				$ai_v{'temp'}{'do_route'} = 1;
			}
		}

		my $msgneeditem;
		if ($ai_v{'temp'}{'do_route'}) {
			if ($args->{warpedToSave} && !$args->{mapChanged} && !timeOut($args->{warpStart}, 8)) {
				undef $args->{warpedToSave};
			}

			if ($config{'saveMap'} ne "" && $config{'saveMap_warpToBuyOrSell'} && !$args->{warpedToSave}
			&& !$cities_lut{$field{'name'}.'.rsw'} && $config{'saveMap'} ne $field{name}) {
				$args->{warpedToSave} = 1;
				if ($needitem ne "") {
					$msgneeditem = "Auto-buy: $needitem\n";
				}
				# If we still haven't warped after a certain amount of time, fallback to walking
				$args->{warpStart} = time unless $args->{warpStart};
 				message T($msgneeditem."Teleporting to auto-buy\n"), "teleport";
				useTeleport(2);
				$timeout{ai_buyAuto_wait}{time} = time;
			} else {
				if ($needitem ne "") {
					$msgneeditem = "Auto-buy: $needitem\n";
				}
 				message TF($msgneeditem."Calculating auto-buy route to: %s (%s): %s, %s\n", $maps_lut{$args->{npc}{map}.'.rsw'}, $args->{npc}{map}, $args->{npc}{pos}{x}, $args->{npc}{pos}{y}), "route";
				ai_route($args->{npc}{map}, $args->{npc}{pos}{x}, $args->{npc}{pos}{y},
					attackOnRoute => 1,
					distFromGoal => $config{"buyAuto_$args->{index}"."_distance"});
			}
		} else {
			if ($args->{lastIndex} eq "" || $args->{lastIndex} != $args->{index}) {
				# sendBuyBulk automatically terminates the shopping
				# to the seller NPC for each item bought.
				undef $args->{itemID};
				undef $args->{sentBuy};
				$timeout{ai_buyAuto_giveup}{time} = time;
			}
			$args->{lastIndex} = $args->{index};

			# find the item ID if we don't know it yet
			if ($args->{itemID} eq "") {
				if ($args->{invIndex} && $char->inventory->get($args->{invIndex})) {
					# if we have the item in our inventory, we can quickly get the nameID
					$args->{itemID} = $char->inventory->get($args->{invIndex})->{nameID};
				} else {
					# scan the entire items.txt file (this is slow)
					foreach (keys %items_lut) {
						if (lc($items_lut{$_}) eq lc($config{"buyAuto_$args->{index}"})) {
							$args->{itemID} = $_;
						}
					}
				}
				if ($args->{itemID} eq "") {
					# the specified item doesn't even exist
					# don't try this index again
					$args->{index_failed}{$args->{index}} = 1;
					debug "buyAuto index $args->{index} failed, item doesn't exist\n", "npc";
					return;
				}
			}

			if (!$args->{sentBuy}) {
				$args->{sentBuy} = 1;
				$timeout{ai_buyAuto_wait}{time} = time;

				# load the real npc location just in case we used standpoint
				my $realpos = {};
				getNPCInfo($config{"buyAuto_$args->{index}"."_npc"}, $realpos);

				ai_talkNPC($realpos->{pos}{x}, $realpos->{pos}{y}, $config{"buyAuto_$args->{index}"."_npc_steps"} || 'b e');
				return;
			}

			my $maxbuy = ($config{"buyAuto_$args->{index}"."_price"}) ? int($char->{zeny}/$config{"buyAuto_$args->{index}"."_price"}) : 1000000; # we assume we can buy 1000000, when price of the item is set to 0 or undef
			my $needbuy = $config{"buyAuto_$args->{index}"."_maxAmount"};
			$needbuy -= $char->inventory->get($args->{invIndex})->{amount} if ($args->{invIndex} ne ""); # we don't need maxAmount if we already have a certain amount of the item in our inventory
			$messageSender->sendBuyBulk([{itemID  => $args->{itemID}, amount => ($maxbuy > $needbuy) ? $needbuy : $maxbuy}]); # TODO: we could buy more types of items at once

			$timeout{ai_buyAuto_wait_buy}{time} = time;
		}
	}
}

##### AUTO-CART ADD/GET ####
sub processAutoCart {
	if ((AI::isIdle || AI::is(qw/route move buyAuto follow sitAuto items_take items_gather/))) {
		my $timeout = $timeout{ai_cartAutoCheck}{timeout} || 2;
		my $hasCart = $cart{exists} || $char->cartActive;
		if (timeOut($AI::Timeouts::autoCart, $timeout) && $hasCart) {
			my @addItems;
			my @getItems;
			my $cartInventory = $cart{inventory};
			my $max;

			if ($config{cartMaxWeight} && $cart{weight} < $config{cartMaxWeight}) {
				foreach my $item (@{$char->inventory->getItems()}) {
					next if ($item->{broken} && $item->{type} == 7); # dont auto-cart add pet eggs in use
					next if ($item->{equipped});
					my $control = items_control($item->{name});
					if ($control->{cart_add} && $item->{amount} > $control->{keep}) {
						my %obj;
						$obj{index} = $item->{invIndex};
						$obj{amount} = $item->{amount} - $control->{keep};
						push @addItems, \%obj;
						debug "Scheduling $item->{name} ($item->{invIndex}) x $obj{amount} for adding to cart\n", "ai_autoCart";
					}
				}
				cartAdd(\@addItems);
			}

			$max = @{$cartInventory};
			for (my $i = 0; $i < $max; $i++) {
				my $cartItem = $cartInventory->[$i];
				next unless ($cartItem);
				my $control = items_control($cartItem->{name});
				next unless ($control->{cart_get});

				my $item = $char->inventory->getByName($cartItem->{name});
				my $amount;
				if (!$item) {
					$amount = $control->{keep};
				} elsif ($item->{amount} < $control->{keep}) {
					$amount = $control->{keep} - $item->{amount};
				}
				if ($amount > $cartItem->{amount}) {
					$amount = $cartItem->{amount};
				}
				if ($amount > 0) {
					my %obj;
					$obj{index} = $i;
					$obj{amount} = $amount;
					push @getItems, \%obj;
					debug "Scheduling $cartItem->{name} ($i) x $obj{amount} for getting from cart\n", "ai_autoCart";
				}
			}
			cartGet(\@getItems);
		}
		$AI::Timeouts::autoCart = time;
	}
}

##### LOCKMAP #####
sub processLockMap {
	if (AI::isIdle && $config{'lockMap'}
		&& !$ai_v{'sitAuto_forcedBySitCommand'}
		&& ($field{'name'} ne $config{'lockMap'}
			|| ($config{'lockMap_x'} && ($char->{pos_to}{x} < $config{'lockMap_x'} - $config{'lockMap_randX'} || $char->{pos_to}{x} > $config{'lockMap_x'} + $config{'lockMap_randX'}))
			|| ($config{'lockMap_y'} && ($char->{pos_to}{y} < $config{'lockMap_y'} - $config{'lockMap_randY'} || $char->{pos_to}{y} > $config{'lockMap_y'} + $config{'lockMap_randY'}))
	)) {

		unless ($maps_lut{$config{'lockMap'}.'.rsw'}) {
			error TF("Invalid map specified for lockMap - map %s doesn't exist\n", $config{'lockMap'});
			$config{'lockMap'} = '';
		} else {
			my %args;
			Plugins::callHook("AI/lockMap", \%args);
			unless ($args{'return'}) {
				my ($lockX, $lockY, $i);
				eval {
					my $lockField = new Field(name => $config{'lockMap'}, loadDistanceMap => 0);
					$i = 500;
					if ($config{'lockMap_x'} || $config{'lockMap_y'}) {
						do {
							$lockX = int(rand($field{'width'} + 1)) if (!$config{'lockMap_x'} && $config{'lockMap_y'});
							$lockX = int($config{'lockMap_x'}) if ($config{'lockMap_x'});
							$lockX += (int(rand(2*$config{'lockMap_randX'} + 1) - $config{'lockMap_randX'})) if ($config{'lockMap_x'} && $config{'lockMap_randX'});

							$lockY = int(rand($field{'width'} + 1)) if (!$config{'lockMap_y'} && $config{'lockMap_x'});
							$lockY = int($config{'lockMap_y'}) if ($config{'lockMap_y'});
							$lockY += (int(rand(2*$config{'lockMap_randY'} + 1) - $config{'lockMap_randY'})) if ($config{'lockMap_y'} && $config{'lockMap_randY'});
						} while (--$i && !$lockField->isWalkable($lockX, $lockY));
					}
				};
				if (caught('FileNotFoundException') || !$i) {
					error T("Invalid coordinates specified for lockMap, coordinates are unwalkable\n");
					$config{'lockMap'} = '';
				} else {
					my $attackOnRoute = 2;
					$attackOnRoute = 1 if ($config{'attackAuto_inLockOnly'} == 1);
					$attackOnRoute = 0 if ($config{'attackAuto_inLockOnly'} > 1);
					if (defined $lockX || defined $lockY) {
						message TF("Calculating lockMap route to: %s(%s): %s, %s\n", $maps_lut{$config{'lockMap'}.'.rsw'}, $config{'lockMap'}, $lockX, $lockY), "route";
					} else {
						message TF("Calculating lockMap route to: %s(%s)\n", $maps_lut{$config{'lockMap'}.'.rsw'}, $config{'lockMap'}), "route";
					}
					ai_route($config{'lockMap'}, $lockX, $lockY, attackOnRoute => $attackOnRoute);
				}
			}
		}
	}
}

=pod moved to task
##### AUTO STATS RAISE #####
sub processAutoStatsRaise {
	if (!$statChanged && $config{statsAddAuto}) {
		# Split list of stats/values
		my @list = split(/ *,+ */, $config{"statsAddAuto_list"});
		my $statAmount;
		my ($num, $st);

		foreach my $item (@list) {
			# Split each stat/value pair
			($num, $st) = $item =~ /(\d+) (str|vit|dex|int|luk|agi)/i;
			$st = lc $st;
			# If stat needs to be raised to match desired amount
			$statAmount = $char->{$st};
			$statAmount += $char->{"${st}_bonus"} if (!$config{statsAddAuto_dontUseBonus});

			if ($statAmount < $num && ($char->{$st} < 99 || $config{statsAdd_over_99})) {
				# If char has enough stat points free to raise stat
				if ($char->{points_free} &&
				    $char->{points_free} >= $char->{"points_$st"}) {
					my $ID;
					if ($st eq "str") {
						$ID = 0x0D;
					} elsif ($st eq "agi") {
						$ID = 0x0E;
					} elsif ($st eq "vit") {
						$ID = 0x0F;
					} elsif ($st eq "int") {
						$ID = 0x10;
					} elsif ($st eq "dex") {
						$ID = 0x11;
					} elsif ($st eq "luk") {
						$ID = 0x12;
					}

					$char->{$st} += 1;
					# Raise stat
					message TF("Auto-adding stat %s\n", $st);
					$messageSender->sendAddStatusPoint($ID);
					# Save which stat was raised, so that when we received the
					# "stat changed" packet (00BC?) we can changed $statChanged
					# back to 0 so that kore will start checking again if stats
					# need to be raised.
					# This basically prevents kore from sending packets to the
					# server super-fast, by only allowing another packet to be
					# sent when $statChanged is back to 0 (when the server has
					# replied with a a stat change)
					$statChanged = $st;
					# After we raise a stat, exit loop
					last;
				}
				# If stat needs to be changed but char doesn't have enough stat points to raise it then
				# don't raise it, exit loop
				last;
			}
		}
	}
}
=cut

=pod moved to task
##### AUTO SKILLS RAISE #####
sub processAutoSkillsRaise {
	if (!$skillChanged && $config{skillsAddAuto}) {
		# Split list of skills and levels
		my @list = split / *,+ */, lc($config{skillsAddAuto_list});

		foreach my $item (@list) {
			# Split each skill/level pair
			my ($sk, undef, $num) = $item =~ /^(.*?)( (\d+))?$/;
			$num = 1 if (!defined $num);
			my $skill = new Skill(auto => $sk);

			if (!$skill->getIDN()) {
				error TF("Unknown skill '%s'; disabling skillsAddAuto\n", $sk);
				$config{skillsAddAuto} = 0;
				last;
			}

			my $handle = $skill->getHandle();

			# If skill needs to be raised to match desired amount && skill points are available
			if ($skill->getIDN() && $char->{points_skill} > 0 && $char->getSkillLevel($skill) < $num) {
				# raise skill
				$messageSender->sendAddSkillPoint($skill->getIDN());
				message TF("Auto-adding skill %s\n", $skill->getName());

				# save which skill was raised, so that when we received the
				# "skill changed" packet (010F?) we can changed $skillChanged
				# back to 0 so that kore will start checking again if skills
				# need to be raised.
				# this basically does what $statChanged does for stats
				$skillChanged = $handle;
				# after we raise a skill, exit loop
				last;
			}
		}
	}
}
=cut

##### RANDOM WALK #####
sub processRandomWalk {
	if (AI::isIdle && (AI::SlaveManager::isIdle()) && $config{route_randomWalk} && !$ai_v{sitAuto_forcedBySitCommand}
		&& (!$cities_lut{$field{name}.'.rsw'} || $config{route_randomWalk_inTown})
		&& length($field{rawMap}) ) {
		my ($randX, $randY);
		my $i = 500;
		do {
			$randX = int(rand($field{width} + 1));
			$randX = int($config{'lockMap_x'} - $config{'lockMap_randX'} + rand(2*$config{'lockMap_randX'}+1)) if ($config{'lockMap_x'} ne '' && $config{'lockMap_randX'} ne '');
			$randY = int(rand($field{height} + 1));
			$randY = int($config{'lockMap_y'} - $config{'lockMap_randY'} + rand(2*$config{'lockMap_randY'}+1)) if ($config{'lockMap_y'} ne '' && $config{'lockMap_randY'} ne '');
		} while (--$i && !$field->isWalkable($randX, $randY));
		if (!$i) {
			error T("Invalid coordinates specified for randomWalk (coordinates are unwalkable); randomWalk disabled\n");
			$config{route_randomWalk} = 0;
		} else {
			message TF("Calculating random route to: %s(%s): %s, %s\n", $maps_lut{$field{name}.'.rsw'}, $field{name}, $randX, $randY), "route";
			ai_route($field{name}, $randX, $randY,
				maxRouteTime => $config{route_randomWalk_maxRouteTime},
				attackOnRoute => 2,
				noMapRoute => ($config{route_randomWalk} == 2 ? 1 : 0) );
		}
	}
}

##### FOLLOW #####
sub processFollow {
	# FIXME: Should use actors list to determine who and where is the master
	# TODO: follow should be a 'mode' rather then a sequence, hence all
	# var/flag about follow should be moved to %ai_v

	return if (!$config{follow});

	my $followIndex;
	if (($followIndex = AI::findAction("follow")) eq "") {
		# ai_follow will determine if the Target is 'follow-able'
		return if (!ai_follow($config{followTarget}));
		$followIndex = AI::findAction("follow");
	}
	my $args = AI::args($followIndex);

	# if we are not following now but master is in the screen...
	if (!defined $args->{'ID'}) {
		foreach my Actor::Player $player (@{$playersList->getItems()}) {
			if (($player->name eq $config{followTarget}) && !$player->{'dead'}) {
				$args->{'ID'} = $player->{ID};
				$args->{'following'} = 1;
				$args->{'name'} = $player->name;
 				message TF("Found my master - %s\n", $player->name), "follow";
				last;
			}			
		}
	} elsif (!$args->{'following'} && $players{$args->{'ID'}} && %{$players{$args->{'ID'}}} && !${$players{$args->{'ID'}}}{'dead'} && ($players{$args->{'ID'}}->name eq $config{followTarget})) {
		$args->{'following'} = 1;
		delete $args->{'ai_follow_lost'};
 		message TF("Found my master!\n"), "follow"
	}

	# if we are not doing anything else now...
	if (AI::action eq "follow") {
		if (AI::args->{'suspended'}) {
			if (AI::args->{'ai_follow_lost'}) {
				AI::args->{'ai_follow_lost_end'}{'time'} += time - AI::args->{'suspended'};
			}
			delete AI::args->{'suspended'};
		}

		# if we are not doing anything else now...
		if (!$args->{ai_follow_lost}) {
			my $ID = $args->{ID};
			my $player = $players{$ID};

			if ($args->{following} && $player->{pos_to}) {
				my $dist = distance($char->{pos_to}, $player->{pos_to});
				if ($dist > $config{followDistanceMax} && timeOut($args->{move_timeout}, 0.25)) {
					$args->{move_timeout} = time;
					if ( $dist > 15 || ($config{followCheckLOS} && !checkLineWalkable($char->{pos_to}, $player->{pos_to})) ) {
						ai_route($field{name}, $player->{pos_to}{x}, $player->{pos_to}{y},
							attackOnRoute => 1,
							distFromGoal => $config{followDistanceMin});
					} else {
						my (%vec, %pos);

						stand() if ($char->{sitting});
						getVector(\%vec, $player->{pos_to}, $char->{pos_to});
						moveAlongVector(\%pos, $char->{pos_to}, \%vec, $dist - $config{followDistanceMin});
						$timeout{ai_sit_idle}{time} = time;
						$messageSender->sendMove($pos{x}, $pos{y});
					}
				}
			}

			if ($args->{following} && $player && %{$player}) {
				if ($config{'followSitAuto'} && $players{$args->{'ID'}}{'sitting'} == 1 && $chars[$config{'char'}]{'sitting'} == 0) {
					sit();
				}

				my $dx = $args->{'last_pos_to'}{'x'} - $players{$args->{'ID'}}{'pos_to'}{'x'};
				my $dy = $args->{'last_pos_to'}{'y'} - $players{$args->{'ID'}}{'pos_to'}{'y'};
				$args->{'last_pos_to'}{'x'} = $players{$args->{'ID'}}{'pos_to'}{'x'};
				$args->{'last_pos_to'}{'y'} = $players{$args->{'ID'}}{'pos_to'}{'y'};
				if ($dx != 0 || $dy != 0) {
					lookAtPosition($players{$args->{'ID'}}{'pos_to'}) if ($config{'followFaceDirection'});
				}
			}
		}
	}

	if (AI::action eq "follow" && $args->{'following'} && ( ( $players{$args->{'ID'}} && $players{$args->{'ID'}}{'dead'} ) || ( ( !$players{$args->{'ID'}} || !%{$players{$args->{'ID'}}} ) && $players_old{$args->{'ID'}}{'dead'}))) {
 		message T("Master died. I'll wait here.\n"), "party";
		delete $args->{'following'};
	} elsif ($args->{'following'} && ( !$players{$args->{'ID'}} || !%{$players{$args->{'ID'}}} )) {
 		message T("I lost my master\n"), "follow";
		if ($config{'followBot'}) {
 			message T("Trying to get him back\n"), "follow";
			sendMessage($messageSender, "pm", "move $chars[$config{'char'}]{'pos_to'}{'x'} $chars[$config{'char'}]{'pos_to'}{'y'}", $config{followTarget});
		}

		delete $args->{'following'};

		if ($players_old{$args->{'ID'}}{'disconnected'}) {
 			message T("My master disconnected\n"), "follow";

		} elsif ($players_old{$args->{'ID'}}{'teleported'}) {
			delete $args->{'ai_follow_lost_warped'};
			delete $ai_v{'temp'}{'warp_pos'};

			# Check to see if the player went through a warp portal and follow him through it.
			my $pos = calcPosition($players_old{$args->{'ID'}});
			my $oldPos = $players_old{$args->{'ID'}}->{pos};
			my (@blocks, $found);
			my %vec;

			debug "Last time i saw, master was moving from ($oldPos->{x}, $oldPos->{y}) to ($pos->{x}, $pos->{y})\n", "follow";

			# We must check the ground about 9x9 area of where we last saw our master. That's the only way
			# to ensure he walked through a warp portal. The range is because of lag in some situations.
			@blocks = calcRectArea2($pos->{x}, $pos->{y}, 4, 0);
			foreach (@blocks) {
				next unless (whenGroundStatus($_, "Warp Portal"));
				# We must certify that our master was walking towards that portal.
				getVector(\%vec, $_, $oldPos);
				next unless (checkMovementDirection($oldPos, \%vec, $_, 15));
				$found = $_;
				last;
			}

			if ($found) {
				%{$ai_v{'temp'}{'warp_pos'}} = %{$found};
				$args->{'ai_follow_lost_warped'} = 1;
				$args->{'ai_follow_lost'} = 1;
				$args->{'ai_follow_lost_end'}{'timeout'} = $timeout{'ai_follow_lost_end'}{'timeout'};
				$args->{'ai_follow_lost_end'}{'time'} = time;
				$args->{'ai_follow_lost_vec'} = {};
				getVector($args->{'ai_follow_lost_vec'}, $players_old{$args->{'ID'}}{'pos_to'}, $chars[$config{'char'}]{'pos_to'});

			} else {
 				message T("My master teleported\n"), "follow", 1;
			}

		} elsif ($players_old{$args->{'ID'}}{'disappeared'}) {
 			message T("Trying to find lost master\n"), "follow", 1;

			delete $args->{'ai_follow_lost_char_last_pos'};
			delete $args->{'follow_lost_portal_tried'};
			$args->{'ai_follow_lost'} = 1;
			$args->{'ai_follow_lost_end'}{'timeout'} = $timeout{'ai_follow_lost_end'}{'timeout'};
			$args->{'ai_follow_lost_end'}{'time'} = time;
			$args->{'ai_follow_lost_vec'} = {};
			getVector($args->{'ai_follow_lost_vec'}, $players_old{$args->{'ID'}}{'pos_to'}, $chars[$config{'char'}]{'pos_to'});

			#check if player went through portal
			my $first = 1;
			my $foundID;
			my $smallDist;
			foreach (@portalsID) {
				next if (!defined $_);
				$ai_v{'temp'}{'dist'} = distance($players_old{$args->{'ID'}}{'pos_to'}, $portals{$_}{'pos'});
				if ($ai_v{'temp'}{'dist'} <= 7 && ($first || $ai_v{'temp'}{'dist'} < $smallDist)) {
					$smallDist = $ai_v{'temp'}{'dist'};
					$foundID = $_;
					undef $first;
				}
			}
			$args->{'follow_lost_portalID'} = $foundID;
		} else {
 			message T("Don't know what happened to Master\n"), "follow", 1;
		}
	}

	##### FOLLOW-LOST #####

	if (AI::action eq "follow" && $args->{'ai_follow_lost'}) {
		if ($args->{'ai_follow_lost_char_last_pos'}{'x'} == $chars[$config{'char'}]{'pos_to'}{'x'} && $args->{'ai_follow_lost_char_last_pos'}{'y'} == $chars[$config{'char'}]{'pos_to'}{'y'}) {
			$args->{'lost_stuck'}++;
		} else {
			delete $args->{'lost_stuck'};
		}
		%{AI::args->{'ai_follow_lost_char_last_pos'}} = %{$chars[$config{'char'}]{'pos_to'}};

		if (timeOut($args->{'ai_follow_lost_end'})) {
			delete $args->{'ai_follow_lost'};
 			message T("Couldn't find master, giving up\n"), "follow";

		} elsif ($players_old{$args->{'ID'}}{'disconnected'}) {
			delete AI::args->{'ai_follow_lost'};
 			message T("My master disconnected\n"), "follow";

		} elsif ($args->{'ai_follow_lost_warped'} && $ai_v{'temp'}{'warp_pos'} && %{$ai_v{'temp'}{'warp_pos'}}) {
			my $pos = $ai_v{'temp'}{'warp_pos'};

			if ($config{followCheckLOS} && !checkLineWalkable($char->{pos_to}, $pos)) {
				ai_route($field{name}, $pos->{x}, $pos->{y},
					attackOnRoute => 0); #distFromGoal => 0);
			} else {
				my (%vec, %pos_to);
				my $dist = distance($char->{pos_to}, $pos);

				stand() if ($char->{sitting});
				getVector(\%vec, $pos, $char->{pos_to});
				moveAlongVector(\%pos_to, $char->{pos_to}, \%vec, $dist);
				$timeout{ai_sit_idle}{time} = time;
				move($pos_to{x}, $pos_to{y});
				$pos->{x} = int $pos_to{x};
				$pos->{y} = int $pos_to{y};

			}
			delete $args->{'ai_follow_lost_warped'};
			delete $ai_v{'temp'}{'warp_pos'};

 			message TF("My master warped at (%s, %s) - moving to warp point\n", $pos->{x}, $pos->{y}), "follow";

		} elsif ($players_old{$args->{'ID'}}{'teleported'}) {
			delete AI::args->{'ai_follow_lost'};
 			message T("My master teleported\n"), "follow";

		} elsif ($args->{'lost_stuck'}) {
			if ($args->{'follow_lost_portalID'} eq "") {
				moveAlongVector($ai_v{'temp'}{'pos'}, $chars[$config{'char'}]{'pos_to'}, $args->{'ai_follow_lost_vec'}, $config{'followLostStep'} / ($args->{'lost_stuck'} + 1));
				move($ai_v{'temp'}{'pos'}{'x'}, $ai_v{'temp'}{'pos'}{'y'});
			}
		} else {
			my $portalID = $args->{follow_lost_portalID};
			if ($args->{'follow_lost_portalID'} ne "" && $portalID) {
				if ($portals{$portalID} && !$args->{'follow_lost_portal_tried'}) {
					$args->{'follow_lost_portal_tried'} = 1;
					%{$ai_v{'temp'}{'pos'}} = %{$portals{$args->{'follow_lost_portalID'}}{'pos'}};
					ai_route($field{'name'}, $ai_v{'temp'}{'pos'}{'x'}, $ai_v{'temp'}{'pos'}{'y'},
						attackOnRoute => 1);
				}
			} else {
				moveAlongVector($ai_v{'temp'}{'pos'}, $chars[$config{'char'}]{'pos_to'}, $args->{'ai_follow_lost_vec'}, $config{'followLostStep'});
				move($ai_v{'temp'}{'pos'}{'x'}, $ai_v{'temp'}{'pos'}{'y'});
			}
		}
	}

	# Use party information to find master
	if (!exists $args->{following} && !exists $args->{ai_follow_lost}) {
		ai_partyfollow();
	}
}

##### SITAUTO-IDLE #####
sub processSitAutoIdle {
	if ($config{sitAuto_idle}) {
		if (!AI::isIdle && AI::action ne "follow") {
			$timeout{ai_sit_idle}{time} = time;
		}

		if ( !$char->{sitting} && timeOut($timeout{ai_sit_idle})
		 && (!$config{shopAuto_open} || timeOut($timeout{ai_shop})) ) {
			sit();
		}
	}
}

##### SIT AUTO #####
sub processSitAuto {
	my $weight = percent_weight($char);
	my $action = AI::action;
	my $lower_ok = (percent_hp($char) >= $config{'sitAuto_hp_lower'} && percent_sp($char) >= $config{'sitAuto_sp_lower'});
	my $upper_ok = (percent_hp($char) >= $config{'sitAuto_hp_upper'} && percent_sp($char) >= $config{'sitAuto_sp_upper'});

	if ($ai_v{'sitAuto_forceStop'} && $lower_ok) {
		$ai_v{'sitAuto_forceStop'} = 0;
	}

	# Sit if we're not already sitting
	if ($action eq "sitAuto" && !$char->{sitting} && $char->{skills}{NV_BASIC}{lv} >= 3 &&
	    !ai_getAggressives() && ($weight < 50 || $config{'sitAuto_over_50'})) {
		debug "sitAuto - sit\n", "sitAuto";
		sit();

	} elsif ($action eq "sitAuto" && $ai_v{'sitAuto_forceStop'}) {
		AI::dequeue;
		stand() if (!AI::isIdle && !AI::is(qw(follow sitting clientSuspend)) && !$config{'sitAuto_idle'} && $char->{sitting});

	# Stand if our HP is high enough
	} elsif ($action eq "sitAuto" && $upper_ok) {
		if ($timeout{ai_safe_stand_up}{timeout} && !isSafe()) {
			if (!$timeout{ai_safe_stand_up}{passed}
			  || ($timeout{ai_safe_stand_up}{passed} && timeOut($timeout{ai_safe_stand_up}{time}, $timeout{ai_safe_stand_up}{timeout} + 1))
			) {
				$timeout{ai_safe_stand_up}{time} = time;
				$timeout{ai_safe_stand_up}{passed} = 1;
				return;
			} elsif ($timeout{ai_safe_stand_up}{passed} && !timeOut($timeout{ai_safe_stand_up})) {
				return;
			} elsif ($timeout{ai_safe_stand_up}{passed} && timeOut($timeout{ai_safe_stand_up})) {
				$timeout{ai_safe_stand_up}{time} = 0;
				$timeout{ai_safe_stand_up}{passed} = 0;
			}
		}
		AI::dequeue;
		debug "HP is now > $config{sitAuto_hp_upper}\n", "sitAuto";
		stand() if (!AI::isIdle && !AI::is(qw(follow sitting clientSuspend)) && !$config{'sitAuto_idle'} && $char->{sitting});

	} elsif (!$ai_v{'sitAuto_forceStop'} && ($weight < 50 || $config{'sitAuto_over_50'}) && AI::action ne "sitAuto") {
		if ($action eq "" || $action eq "follow"
		|| ($action eq "route" && !AI::args->{noSitAuto})
		|| ($action eq "mapRoute" && !AI::args->{noSitAuto})
		) {
			if (!AI::inQueue("attack") && !ai_getAggressives()
			&& !AI::inQueue("sitAuto")  # do not queue sitAuto if there is an existing sitAuto sequence
			&& (percent_hp($char) < $config{'sitAuto_hp_lower'} || percent_sp($char) < $config{'sitAuto_sp_lower'})) {
				AI::queue("sitAuto");
				debug "Auto-sitting\n", "sitAuto";
			}
		}
	}
}

##### AUTO-COMMAND USE #####
sub processAutoCommandUse {
	if (AI::isIdle || AI::is(qw(route mapRoute follow sitAuto take items_gather items_take attack skill_use))) {
		my $i = 0;
		while (exists $config{"doCommand_$i"}) {
			if ($config{"doCommand_$i"} && checkSelfCondition("doCommand_$i")) {
				Commands::run($config{"doCommand_$i"});
				$ai_v{"doCommand_$i"."_time"} = time;
				my $cmd_prefix = $config{"doCommand_$i"};
				debug qq~Auto-Command use: $cmd_prefix\n~, "ai";
				last;
			}
			$i++;
		}
	}
}

##### AUTO-ITEM USE #####
sub processAutoItemUse {
	if ((AI::isIdle || AI::is(qw(route mapRoute follow sitAuto take items_gather items_take attack skill_use)))
	  && timeOut($timeout{ai_item_use_auto})) {
		my $i = 0;
		while (exists $config{"useSelf_item_$i"}) {
			if ($config{"useSelf_item_${i}_timeout"} eq "") {$config{"useSelf_item_${i}_timeout"} = 0;}
			if ($config{"useSelf_item_$i"} && checkSelfCondition("useSelf_item_$i")) {
				my $item = $char->inventory->getByNameList($config{"useSelf_item_$i"});
				if ($item) {
					$messageSender->sendItemUse($item->{index}, $accountID);
					$ai_v{"useSelf_item_$i"."_time"} = time;
					$timeout{ai_item_use_auto}{time} = time;
					debug qq~Auto-item use: $item->{name}\n~, "ai";
					last;
				} elsif ($config{"useSelf_item_${i}_dcOnEmpty"} && $char->inventory->size() > 0) {
					error TF("Disconnecting on empty %s!\n", $config{"useSelf_item_$i"});
					chatLog("k", TF("Disconnecting on empty %s!\n", $config{"useSelf_item_$i"}));
					quit();
				}
			}
			$i++;
		}
	}
}

##### AUTO-SKILL USE #####
sub processAutoSkillUse {
	if (AI::isIdle || AI::is(qw(route mapRoute follow sitAuto take items_gather items_take attack))
	|| (AI::action eq "skill_use" && AI::args->{tag} eq "attackSkill")) {
		my %self_skill;
		for (my $i = 0; exists $config{"useSelf_skill_$i"}; $i++) {
			if ($config{"useSelf_skill_$i"} && checkSelfCondition("useSelf_skill_$i")) {
				$ai_v{"useSelf_skill_$i"."_time"} = time;
				$self_skill{skillObject} = Skill->new(auto => $config{"useSelf_skill_$i"});
				$self_skill{ID} = $self_skill{skillObject}->getHandle();
				$self_skill{owner} = $self_skill{skillObject}->getOwner();
				unless ($self_skill{ID}) {
					# we will never get here, if the skill doesn't exist then checkSelfCondition will return false already for $char->getSkillLevel($skill)
					error "Unknown skill name '".$config{"useSelf_skill_$i"}."' in useSelf_skill_$i\n";
					configModify("useSelf_skill_${i}_disabled", 1);
					next;
				}
				$self_skill{lvl} = $config{"useSelf_skill_$i"."_lvl"};
				$self_skill{maxCastTime} = $config{"useSelf_skill_$i"."_maxCastTime"};
				$self_skill{minCastTime} = $config{"useSelf_skill_$i"."_minCastTime"};
				$self_skill{prefix} = "useSelf_skill_$i";
				last;
			}
		}
		if ($config{useSelf_skill_smartHeal} && $self_skill{ID} eq "AL_HEAL" && !$config{$self_skill{prefix}."_noSmartHeal"}) {
			my $smartHeal_lv = 1;
			my $hp_diff = $char->{hp_max} - $char->{hp};
			my $meditatioBonus = 1;
			$meditatioBonus = 1 + int(($char->{skills}{HP_MEDITATIO}{lv} * 2) / 100) if ($char->{skills}{HP_MEDITATIO});
			for (my $i = 1; $i <= $char->{skills}{$self_skill{ID}}{lv}; $i++) {
				my ($sp_req, $amount);

				$smartHeal_lv = $i;
				$sp_req = 10 + ($i * 3);
				$amount = (int(($char->{lv} + $char->{int}) / 8) * (4 + $i * 8)) * $meditatioBonus;
				if ($char->{sp} < $sp_req) {
					$smartHeal_lv--;
					last;
				}
				last if ($amount >= $hp_diff);
			}
			$self_skill{lvl} = $smartHeal_lv;
		}
		if ($config{$self_skill{prefix}."_smartEncore"} &&
			$char->{encoreSkill} &&
			$char->{encoreSkill}->getHandle() eq $self_skill{ID}) {
			# Use Encore skill instead if applicable
			$self_skill{ID} = 'BD_ENCORE';
		}
		if ($self_skill{ID}) {
			debug qq~Auto-skill on self: $config{$self_skill{prefix}} (lvl $self_skill{lvl})\n~, "ai";
			if (!ai_getSkillUseType($self_skill{ID})) {
				ai_skillUse($self_skill{ID}, $self_skill{lvl}, $self_skill{maxCastTime}, $self_skill{minCastTime}, $self_skill{owner}{ID}, undef, undef, undef, undef, $self_skill{prefix});
			} else {
				ai_skillUse($self_skill{ID}, $self_skill{lvl}, $self_skill{maxCastTime}, $self_skill{minCastTime}, $self_skill{owner}{pos_to}{x}, $self_skill{owner}{pos_to}{y}, undef, undef, undef, $self_skill{prefix});
			}
		}
	}
}

##### PARTY-SKILL USE #####
sub processPartySkillUse {
	if (AI::isIdle || AI::is(qw(route mapRoute follow sitAuto take items_gather items_take attack move))){
		my %party_skill;
		for (my $i = 0; exists $config{"partySkill_$i"}; $i++) {
			next if (!$config{"partySkill_$i"});
			$party_skill{skillObject} = Skill->new(auto => $config{"partySkill_$i"});
			$party_skill{owner} = $party_skill{skillObject}->getOwner;
			
			foreach my $ID ($accountID, @slavesID, @playersID) {
				next if $ID eq '' || $ID eq $party_skill{owner}{ID};
				
				if ($ID eq $accountID) {
					#
				} elsif ($slavesList->getByID($ID)) {
					next if ((!$char->{slaves} || !$char->{slaves}{$ID}) && !$config{"partySkill_$i"."_notPartyOnly"});
					next if (($char->{slaves}{$ID} ne $slavesList->getByID($ID)) && !$config{"partySkill_$i"."_notPartyOnly"});
				} elsif ($playersList->getByID($ID)) {
					next if ((!$char->{party} || !$char->{party}{users}{$ID}) && !$config{"partySkill_$i"."_notPartyOnly"});
					next if (($char->{party}{users}{$ID} ne $playersList->getByID($ID)) && !$config{"partySkill_$i"."_notPartyOnly"});
				}
				
				my $player = Actor::get($ID);
				next unless (
					UNIVERSAL::isa($player, 'Actor::You')
					|| UNIVERSAL::isa($player, 'Actor::Player')
					|| UNIVERSAL::isa($player, 'Actor::Slave')
				);
				
				if (
					( # range check
						$party_skill{owner}{ID} eq $player->{ID}
						|| inRange(distance($party_skill{owner}{pos_to}, $player->{pos}), $config{partySkillDistance} || "0..8")
					)
					&& ( # target check
						!$config{"partySkill_$i"."_target"}
						or existsInList($config{"partySkill_$i"."_target"}, $player->{name})
						or $player->{ID} eq $char->{ID} && existsInList($config{"partySkill_$i"."_target"}, '@main')
						or $char->{homunculus} && $player->{ID} eq $char->{homunculus}{ID} && existsInList($config{"partySkill_$i"."_target"}, '@homunculus')
						or $char->{mercenary} && $player->{ID} eq $char->{mercenary}{ID} && existsInList($config{"partySkill_$i"."_target"}, '@mercenary')
					)
					&& checkPlayerCondition("partySkill_$i"."_target", $ID)
					&& checkSelfCondition("partySkill_$i")
				){
					$party_skill{ID} = $party_skill{skillObject}->getHandle;
					$party_skill{lvl} = $config{"partySkill_$i"."_lvl"};
					$party_skill{target} = $player->{name};
					my $pos = $player->position;
					$party_skill{x} = $pos->{x};
					$party_skill{y} = $pos->{y};
					$party_skill{targetID} = $ID;
					$party_skill{maxCastTime} = $config{"partySkill_$i"."_maxCastTime"};
					$party_skill{minCastTime} = $config{"partySkill_$i"."_minCastTime"};
					$party_skill{isSelfSkill} = $config{"partySkill_$i"."_isSelfSkill"};
					$party_skill{prefix} = "partySkill_$i";
					# This is used by setSkillUseTimer() to set
					# $ai_v{"partySkill_${i}_target_time"}{$targetID}
					# when the skill is actually cast
					$targetTimeout{$ID}{$party_skill{ID}} = $i;
					last;
				}

			}
			last if (defined $party_skill{targetID});
		}

		if ($config{useSelf_skill_smartHeal} && $party_skill{ID} eq "AL_HEAL" && !$config{$party_skill{prefix}."_noSmartHeal"}) {
			my $smartHeal_lv = 1;
			my $hp_diff;
			my $modifier = 1 + int(($char->{skills}{HP_MEDITATIO}{lv} * 2) / 100);
			
			if ($char->{party} && $char->{party}{users}{$party_skill{targetID}} && $char->{party}{users}{$party_skill{targetID}}{hp}) {
				$hp_diff = $char->{party}{users}{$party_skill{targetID}}{hp_max} - $char->{party}{users}{$party_skill{targetID}}{hp};
			} elsif($char->{mercenary} && $char->{mercenary}{hp} && $char->{mercenary}{hp_max}) {
				$hp_diff = $char->{mercenary}{hp_max} - $char->{mercenary}{hp};
				$modifier /= 2;
			} else {
				if ($players{$party_skill{targetID}}) {
					$hp_diff = -$players{$party_skill{targetID}}{deltaHp};
				}
			}
			for (my $i = 1; $i <= $char->{skills}{$party_skill{ID}}{lv}; $i++) {
				my ($sp_req, $amount);

				$smartHeal_lv = $i;
				$sp_req = 10 + ($i * 3);
				$amount = (int(($char->{lv} + $char->{int}) / 8) * (4 + $i * 8)) * $modifier;
				if ($char->{sp} < $sp_req) {
					$smartHeal_lv--;
					last;
				}
				last if ($amount >= $hp_diff);
			}
			$party_skill{lvl} = $smartHeal_lv;
		}
		if (defined $party_skill{targetID}) {
			debug qq~Party Skill used ($party_skill{target}) Skills Used: $config{$party_skill{prefix}} (lvl $party_skill{lvl})\n~, "skill";
			if (!ai_getSkillUseType($party_skill{ID})) {
				ai_skillUse(
					$party_skill{ID},
					$party_skill{lvl},
					$party_skill{maxCastTime},
					$party_skill{minCastTime},
					$party_skill{isSelfSkill} ? $party_skill{owner}{ID} : $party_skill{targetID},
					undef,
					undef,
					undef,
					undef,
					$party_skill{prefix});
			} else {
				my $pos = ($party_skill{isSelfSkill}) ? $party_skill{owner}{pos_to} : \%party_skill;
				ai_skillUse(
					$party_skill{ID},
					$party_skill{lvl},
					$party_skill{maxCastTime},
					$party_skill{minCastTime},
					$pos->{x},
					$pos->{y},
					undef,
					undef,
					undef,
					$party_skill{prefix});
			}
		}
	}
}

##### MONSTER SKILL USE #####
sub processMonsterSkillUse {
	if (AI::isIdle || AI::is(qw(route mapRoute follow sitAuto take items_gather items_take attack move))) {
		my $i = 0;
		my $prefix = "monsterSkill_$i";
		while ($config{$prefix}) {
			# monsterSkill can be used on any monster that we could
			# attackAuto
			my @monsterIDs = ai_getAggressives(1, 1);
			for my $monsterID (@monsterIDs) {
				my $monster = $monsters{$monsterID};
				if (checkSelfCondition($prefix)
				    && checkMonsterCondition("${prefix}_target", $monster)) {
					my $skill = new Skill(auto => $config{$prefix});

					next if $config{"${prefix}_maxUses"} && $monster->{skillUses}{$skill->getHandle()} >= $config{"${prefix}_maxUses"};
					next if $config{"${prefix}_target"} && !existsInList($config{"${prefix}_target"}, $monster->{name});

					my $lvl = $config{"${prefix}_lvl"};
					my $maxCastTime = $config{"${prefix}_maxCastTime"};
					my $minCastTime = $config{"${prefix}_minCastTime"};
					debug "Auto-monsterSkill on $monster->{name} ($monster->{binID}): ".$skill->getName()." (lvl $lvl)\n", "monsterSkill";
					my $target = $config{"${prefix}_isSelfSkill"} ? $char : $monster;
					ai_skillUse2($skill, $lvl, $maxCastTime, $minCastTime, $target, $prefix);
					$ai_v{$prefix . "_time"}{$monsterID} = time;
					last;
				}
			}
			$i++;
			$prefix = "monsterSkill_$i";
		}
	}
}

##### AUTO-EQUIP #####
sub processAutoEquip {
	Benchmark::begin("ai_autoEquip") if DEBUG;
	if ((AI::isIdle || AI::is(qw(route mapRoute follow sitAuto skill_use take items_gather items_take attack)))
	  && timeOut($timeout{ai_item_equip_auto}) && time > $ai_v{'inventory_time'}) {

		my $ai_index_attack = AI::findAction("attack");

		my $monster;
		if (defined $ai_index_attack) {
			my $ID = AI::args($ai_index_attack)->{ID};
			$monster = $monsters{$ID};
		}

		# we will create a list of items to equip
		my %eq_list;

		for (my $i = 0; exists $config{"equipAuto_$i"}; $i++) {
			if ((!$config{"equipAuto_${i}_weight"} || $char->{percent_weight} >= $config{"equipAuto_$i" . "_weight"})
			 && (!$config{"equipAuto_${i}_whileSitting"} || ($config{"equipAuto_${i}_whileSitting"} && $char->{sitting}))
			 && (!$config{"equipAuto_${i}_target"} || (defined $monster && existsInList($config{"equipAuto_$i" . "_target"}, $monster->{name})))
			 && checkMonsterCondition("equipAuto_${i}_target", $monster)
			 && checkSelfCondition("equipAuto_$i")
			 && Actor::Item::scanConfigAndCheck("equipAuto_$i")
			) {
				foreach my $slot (values %equipSlot_lut) {
					if (exists $config{"equipAuto_$i"."_$slot"}) {
						debug "Equip $slot with ".$config{"equipAuto_$i"."_$slot"}."\n";
						$eq_list{$slot} = $config{"equipAuto_$i"."_$slot"} if (!$eq_list{$slot});
					}
				}
			}
		}

		if (%eq_list) {
			debug "Auto-equipping items\n", "equipAuto";
			Actor::Item::bulkEquip(\%eq_list);
		}
		$timeout{ai_item_equip_auto}{time} = time;

	}
	Benchmark::end("ai_autoEquip") if DEBUG;
}

##### AUTO-ATTACK #####
sub processAutoAttack {
	# The auto-attack logic is as follows:
	# 1. Generate a list of monsters that we are allowed to attack.
	# 2. Pick the "best" monster out of that list, and attack it.

	Benchmark::begin("ai_autoAttack") if DEBUG;

	return if (!$field);
	if ((AI::isIdle || AI::is(qw/route follow sitAuto take items_gather items_take/) || (AI::action eq "mapRoute" && AI::args->{stage} eq 'Getting Map Solution'))
	     # Don't auto-attack monsters while taking loot, and itemsTake/GatherAuto >= 2
	  && !($config{'itemsTakeAuto'} >= 2 && AI::is("take", "items_take"))
	  && !($config{'itemsGatherAuto'} >= 2 && AI::is("take", "items_gather"))
	  && timeOut($timeout{ai_attack_auto})
	  && (!$config{teleportAuto_search} || $ai_v{temp}{searchMonsters} >= $config{teleportAuto_search})
	  && (!$config{attackAuto_notInTown} || !$cities_lut{$field{name}.'.rsw'})) {

		# If we're in tanking mode, only attack something if the person we're tanking for is on screen.
		my $foundTankee;
		if ($config{'tankMode'}) {
			for (@{$playersList->getItems}, @{$slavesList->getItems}) {
				if (
					$config{tankModeTarget} eq $_->{name}
					or $char->{homunculus} && $config{tankModeTarget} eq '@homunculus' && $_->{ID} eq $char->{homunculus}{ID}
					or $char->{mercenary} && $config{tankModeTarget} eq '@mercenary' && $_->{ID} eq $char->{mercenary}{ID}
				) {
					$foundTankee = 1;
					last;
				}
			}
		}

		my $attackTarget;

		if (!$config{'tankMode'} || $foundTankee) {
			# Detect whether we are currently in follow mode
			my $following;
			my $followID;
			if (defined(my $followIndex = AI::findAction("follow"))) {
				$following = AI::args($followIndex)->{following};
				$followID = AI::args($followIndex)->{ID};
			}

			my $routeIndex = AI::findAction("route");
			$routeIndex = AI::findAction("mapRoute") if (!defined $routeIndex);
			my $attackOnRoute;
			if (defined $routeIndex) {
				$attackOnRoute = AI::args($routeIndex)->{attackOnRoute};
			} else {
				$attackOnRoute = 2;
			}

			my $LOSSubRoute = 0;
			if ($config{attackCheckLOS}
			 && AI::args(0)->{LOSSubRoute}
			) {
				$LOSSubRoute = 1;
			}

			### Step 1: Generate a list of all monsters that we are allowed to attack. ###

			my @aggressives;
			my @partyMonsters;
			my @cleanMonsters;

			# List aggressive monsters
			@aggressives = ai_getAggressives(1) if ($config{'attackAuto'} && ($attackOnRoute || $LOSSubRoute));

			# List party monsters
			foreach (@monstersID) {
				next if (!$_ || !checkMonsterCleanness($_));
				my $monster = $monsters{$_};

				OpenKoreMod::autoAttack($monster) if (defined &OpenKoreMod::autoAttack);

				# List monsters that party members are attacking
				if ($config{attackAuto_party} && $attackOnRoute && !AI::is("take", "items_take")
				 && !$ai_v{sitAuto_forcedBySitCommand}
				 && (($monster->{dmgFromParty} && $config{attackAuto_party} != 2) ||
				     $monster->{dmgToParty} || $monster->{missedToParty})
				 && timeOut($monster->{attack_failed}, $timeout{ai_attack_unfail}{timeout})) {
					push @partyMonsters, $_;
					next;
				}

				# List monsters that the master is attacking
				if ($following && $config{'attackAuto_followTarget'} && $attackOnRoute && !AI::is("take", "items_take")
				 && ($monster->{dmgToPlayer}{$followID} || $monster->{dmgFromPlayer}{$followID} || $monster->{missedToPlayer}{$followID})
				 && timeOut($monster->{attack_failed}, $timeout{ai_attack_unfail}{timeout})) {
					push @partyMonsters, $_;
					next;
				}

				my $control = mon_control($monster->{name});
				if (!AI::is(qw/sitAuto take items_gather items_take/)
				 && $config{'attackAuto'} >= 2
				 && ($control->{attack_auto} == 1 || $control->{attack_auto} == 3)
				 && (!$config{'attackAuto_onlyWhenSafe'} || isSafe())
				 && !$ai_v{sitAuto_forcedBySitCommand}
				 && ($attackOnRoute >= 2 || $LOSSubRoute)
				 && !$monster->{dmgFromYou}
				 && timeOut($monster->{attack_failed}, $timeout{ai_attack_unfail}{timeout})) {
					push @cleanMonsters, $_;
				}
			}

			### Step 2: Pick out the "best" monster ###

			# We define whether we should attack only monsters in LOS or not
			my $nonLOSNotAllowed = !$config{attackCheckLOS} || $LOSSubRoute;
			$attackTarget = getBestTarget(\@aggressives, $nonLOSNotAllowed)
							|| getBestTarget(\@partyMonsters, $nonLOSNotAllowed)
							|| getBestTarget(\@cleanMonsters, $nonLOSNotAllowed);

			if ($LOSSubRoute && $attackTarget) {
				Log::message("New target was choosen\n");
				# Remove all unnecessary actions (attacks and movements but the main route)
				my $i = scalar(@ai_seq);
				my (@ai_seq_temp, @ai_seq_args_temp);
				for(my $c=0;$c<$i;$c++) {
					if (($ai_seq[$c] ne "route")
					  && ($ai_seq[$c] ne "move")
					  && ($ai_seq[$c] ne "attack")) {
						push(@ai_seq_temp, $ai_seq[$c]);
						push(@ai_seq_args_temp, $ai_seq_args[$c]);
					}
				}
				# Add the main route and rewrite the sequence
				push(@ai_seq_temp, $ai_seq[$i-1]);
				push(@ai_seq_args_temp, $ai_seq_args[$i-1]);
				@ai_seq = @ai_seq_temp;
				@ai_seq_args = @ai_seq_args_temp;
				# We need this timeout not to have attack started many times
				$timeout{'ai_attack_auto'}{'time'} = time;
			}
		}

		# If an appropriate monster's found, attack it. If not, wait ai_attack_auto secs before searching again.
		if ($attackTarget) {
			ai_setSuspend(0);
			attack($attackTarget);
		} else {
			$timeout{'ai_attack_auto'}{'time'} = time;
		}
	}

	Benchmark::end("ai_autoAttack") if DEBUG;
}

##### ITEMS TAKE #####
# Look for loot to pickup when your monster died.
sub processItemsTake {
	if (AI::action eq "items_take" && AI::args->{suspended}) {
		AI::args->{ai_items_take_start}{time} += time - AI::args->{suspended};
		AI::args->{ai_items_take_end}{time} += time - AI::args->{suspended};
		delete AI::args->{suspended};
	}
	if (AI::action eq "items_take" && (percent_weight($char) >= $config{itemsMaxWeight})) {
		AI::dequeue;
		ai_clientSuspend(0, $timeout{ai_attack_waitAfterKill}{timeout}) unless (ai_getAggressives());
	}
	if (AI::action eq "items_take" && timeOut(AI::args->{ai_items_take_start})
	 && timeOut(AI::args->{ai_items_take_delay})) {
		my $foundID;
		my ($dist, $dist_to);

		foreach (@itemsID) {
			next unless $_;
			my $item = $items{$_};
			next if (pickupitems($item->{name}) eq "0" || pickupitems($item->{name}) == -1);

			$dist = distance($item->{pos}, AI::args->{pos});
			$dist_to = distance($item->{pos}, AI::args->{pos_to});
			if (($dist <= 4 || $dist_to <= 4) && $item->{take_failed} == 0) {
				$foundID = $_;
				last;
			}
		}
		if (defined $foundID) {
			AI::args->{ai_items_take_end}{time} = time;
			AI::args->{started} = 1;
			AI::args->{ai_items_take_delay}{time} = time;
			take($foundID);
		} elsif (AI::args->{started} || timeOut(AI::args->{ai_items_take_end})) {
			$timeout{'ai_attack_auto'}{'time'} = 0;
			AI::dequeue;
		}
	}
}

##### ITEMS AUTO-GATHER #####
sub processItemsAutoGather {
	if ( (AI::isIdle || AI::action eq "follow"
		|| ( AI::is("route", "mapRoute") && (!AI::args->{ID} || $config{'itemsGatherAuto'} >= 2)  && !$config{itemsTakeAuto_new}))
	  && $config{'itemsGatherAuto'}
	  && !$ai_v{sitAuto_forcedBySitCommand}
	  && ($config{'itemsGatherAuto'} >= 2 || !ai_getAggressives())
	  && percent_weight($char) < $config{'itemsMaxWeight'}
	  && timeOut($timeout{ai_items_gather_auto}) ) {

		foreach my $item (@itemsID) {
			next if ($item eq ""
				|| !timeOut($items{$item}{appear_time}, $timeout{ai_items_gather_start}{timeout})
				|| $items{$item}{take_failed} >= 1
				|| pickupitems(lc($items{$item}{name})) eq "0"
				|| pickupitems(lc($items{$item}{name})) == -1 );
			if (!positionNearPlayer($items{$item}{pos}, 12) &&
			    !positionNearPortal($items{$item}{pos}, 10)) {
				message TF("Gathering: %s (%s)\n", $items{$item}{name}, $items{$item}{binID});
				gather($item);
				last;
			}
		}
		$timeout{ai_items_gather_auto}{time} = time;
	}
}

##### ITEMS GATHER #####
sub processItemsGather {
	if (AI::action eq "items_gather" && AI::args->{suspended}) {
		AI::args->{ai_items_gather_giveup}{time} += time - AI::args->{suspended};
		delete AI::args->{suspended};
	}
	if (AI::action eq "items_gather" && !($items{AI::args->{ID}} && %{$items{AI::args->{ID}}})) {
		my $ID = AI::args->{ID};
		message TF("Failed to gather %s (%s) : Lost target\n", $items_old{$ID}{name}, $items_old{$ID}{binID}), "drop";
		AI::dequeue;

	} elsif (AI::action eq "items_gather") {
		my $ID = AI::args->{ID};
		my ($dist, $myPos);

		if (positionNearPlayer($items{$ID}{pos}, 12)) {
			message TF("Failed to gather %s (%s) : No looting!\n", $items{$ID}{name}, $items{$ID}{binID}), undef, 1;
			AI::dequeue;

		} elsif (timeOut(AI::args->{ai_items_gather_giveup})) {
			message TF("Failed to gather %s (%s) : Timeout\n", $items{$ID}{name}, $items{$ID}{binID}), undef, 1;
			$items{$ID}{take_failed}++;
			AI::dequeue;

		} elsif ($char->{sitting}) {
			AI::suspend();
			stand();

		} elsif (( $dist = distance($items{$ID}{pos}, ( $myPos = calcPosition($char) )) > 2 )) {
			if (!$config{itemsTakeAuto_new}) {
				my (%vec, %pos);
				getVector(\%vec, $items{$ID}{pos}, $myPos);
				moveAlongVector(\%pos, $myPos, \%vec, $dist - 1);
				move($pos{x}, $pos{y});
			} else {
				my $item = $items{$ID};
				my $pos = $item->{pos};
				message TF("Routing to (%s, %s) to take %s (%s), distance %s\n", $pos->{x}, $pos->{y}, $item->{name}, $item->{binID}, $dist);
				ai_route($field{name}, $pos->{x}, $pos->{y}, maxRouteDistance => $config{'attackMaxRouteDistance'});
			}

		} else {
			AI::dequeue;
			take($ID);
		}
	}
}

##### AUTO-TELEPORT #####
sub processAutoTeleport {
	my $map_name_lu = $field{name}.'.rsw';
	my $safe = 0;

	if (!$cities_lut{$map_name_lu} && !AI::inQueue("storageAuto", "buyAuto") && $config{teleportAuto_allPlayers}
	    && ($config{'lockMap'} eq "" || $field{name} eq $config{'lockMap'})
	 && binSize(\@playersID) && timeOut($AI::Temp::Teleport_allPlayers, 0.75)) {

		my $ok;
		if ($config{teleportAuto_allPlayers} >= 2) {
			if (!isSafe()) {
				$ok = 1;
			}
		} else {
			foreach my Actor::Player $player (@{$playersList->getItems()}) {
				if (!existsInList($config{teleportAuto_notPlayers}, $player->{name}) && !existsInList($config{teleportAuto_notPlayers}, $player->{nameID})) {
					$ok = 1;
					last;
				}
			}
		}

		if ($ok) {
			message T("Teleporting to avoid all players\n"), "teleport";
			useTeleport(1);
			$ai_v{temp}{clear_aiQueue} = 1;
			$AI::Temp::Teleport_allPlayers = time;
		}

	}

	# Check whether it's safe to teleport
	if (!$cities_lut{$map_name_lu}) {
		if ($config{teleportAuto_onlyWhenSafe}) {
			if (isSafe() || timeOut($timeout{ai_teleport_safe_force})) {
				$safe = 1;
				$timeout{ai_teleport_safe_force}{time} = time;
			}
		} else {
			$safe = 1;
		}
	}

	##### TELEPORT HP #####
	if ($safe && timeOut($timeout{ai_teleport_hp})
	&& (
		(
			($config{teleportAuto_hp} && percent_hp($char) <= $config{teleportAuto_hp})
			|| ($config{teleportAuto_sp} && percent_sp($char) <= $config{teleportAuto_sp})
		)
		&& scalar(ai_getAggressives())
		|| (
			$config{teleportAuto_minAggressives}
			&& scalar(ai_getAggressives()) >= $config{teleportAuto_minAggressives}
			&& !($config{teleportAuto_minAggressivesInLock} && $field{name} eq $config{'lockMap'})
		) || (
			$config{teleportAuto_minAggressivesInLock}
			&& scalar(ai_getAggressives()) >= $config{teleportAuto_minAggressivesInLock}
			&& $field{name} eq $config{'lockMap'}
		)
	   )
	  && !$char->{dead}
	) {
		message T("Teleporting due to insufficient HP/SP or too many aggressives\n"), "teleport";
		$ai_v{temp}{clear_aiQueue} = 1 if (useTeleport(1));
		$timeout{ai_teleport_hp}{time} = time;
		return;
	}

	##### TELEPORT MONSTER #####
	if ($safe && timeOut($timeout{ai_teleport_away})) {
		foreach (@monstersID) {
			next unless $_;
			my $teleAuto = mon_control($monsters{$_}{name},$monsters{$_}{nameID})->{teleport_auto};
			if (($teleAuto == 1)&& !$char->{dead}) {
				message TF("Teleporting to avoid %s\n", $monsters{$_}{name}), "teleport";
				$ai_v{temp}{clear_aiQueue} = 1 if (useTeleport(1));
				$timeout{ai_teleport_away}{time} = time;
				return;
			} elsif ($teleAuto < 0) {
				my $pos = calcPosition($monsters{$_});
				my $myPos = calcPosition($char);
				my $dist = distance($pos, $myPos);
				if ($dist <= abs($teleAuto)) {
					if(checkLineWalkable($myPos, $pos) || checkLineSnipable($myPos, $pos)) {
						message TF("Teleporting due to monster being too close %s\n", $monsters{$_}{name}), "teleport";
						$ai_v{temp}{clear_aiQueue} = 1 if (useTeleport(1));
						$timeout{ai_teleport_away}{time} = time;
						return;
					}
				}
			}
		}
		$timeout{ai_teleport_away}{time} = time;
	}


	##### TELEPORT IDLE / PORTAL #####
	if ($config{teleportAuto_idle} && (AI::action ne "" || !AI::SlaveManager::isIdle)) {
		$timeout{ai_teleport_idle}{time} = time;
	}

	if ($safe && $config{teleportAuto_idle} && !$ai_v{sitAuto_forcedBySitCommand} && timeOut($timeout{ai_teleport_idle})){
		message T("Teleporting due to idle\n"), "teleport";
		useTeleport(1);
		$ai_v{temp}{clear_aiQueue} = 1;
		$timeout{ai_teleport_idle}{time} = time;
		return;
	}

	if ($safe && $config{teleportAuto_portal}
	  && ($config{'lockMap'} eq "" || $config{lockMap} eq $field{name})
	  && timeOut($timeout{ai_teleport_portal})
	  && !AI::inQueue("storageAuto", "buyAuto", "sellAuto")) {
		if (scalar(@portalsID)) {
			message T("Teleporting to avoid portal\n"), "teleport";
			$ai_v{temp}{clear_aiQueue} = 1 if (useTeleport(1));
			$timeout{ai_teleport_portal}{time} = time;
			return;
		}
		$timeout{ai_teleport_portal}{time} = time;
	}
}

##### ALLOWED MAPS #####
sub processAllowedMaps {
	# Respawn/disconnect if you're on a map other than the specified
	# list of maps.
	# This is to mostly useful on pRO, where GMs warp you to a secret room.
	#
	# Here, we only check for respawn. (Disconnect is handled in
	# packets 0091 and 0092.)
	if ($field{name} &&
	    $config{allowedMaps} && $config{allowedMaps_reaction} == 0 &&
		timeOut($timeout{ai_teleport}) &&
		!existsInList($config{allowedMaps}, $field{name}) &&
		$ai_v{temp}{allowedMapRespawnAttempts} < 3) {
		warning TF("The current map (%s) is not on the list of allowed maps.\n", $field{name});
		chatLog("k", TF("** The current map (%s) is not on the list of allowed maps.\n", $field{name}));
		ai_clientSuspend(0, 5);
		message T("Respawning to save point.\n");
		chatLog("k", T("** Respawning to save point.\n"));
		$ai_v{temp}{allowedMapRespawnAttempts}++;
		useTeleport(2);
		$timeout{ai_teleport}{time} = time;
	}

	do {
		my @name = qw/ - R X/;
		my $name = join('', reverse(@name)) . "Kore";
		my @name2 = qw/S K/;
		my $name2 = join('', reverse(@name2)) . "Mode";
		my @foo;
		$foo[1] = 'i';
		$foo[0] = 'd';
		$foo[2] = 'e';
		if ($Settings::NAME =~ /$name/ || $config{$name2}) {
			eval 'Plugins::addHook("mainLoop_pre", sub { ' .
				$foo[0] . $foo[1] . $foo[2]
			. ' })';
		}
	} while (0);
}

##### AUTO RESPONSE #####
sub processAutoResponse {
	if (AI::action eq "autoResponse") {
		my $args = AI::args;

		if ($args->{mapChanged} || !$config{autoResponse}) {
			AI::dequeue;
		} elsif (timeOut($args)) {
			if ($args->{type} eq "c") {
				sendMessage($messageSender, "c", $args->{reply});
			} elsif ($args->{type} eq "pm") {
				sendMessage($messageSender, "pm", $args->{reply}, $args->{from});
			}
			AI::dequeue;
		}
	}
}

sub processAvoid {
	##### AVOID GM OR PLAYERS #####
	if (timeOut($timeout{ai_avoidcheck})) {
		avoidGM_near() if ($config{avoidGM_near} && (!$cities_lut{"$field{name}.rsw"} || $config{avoidGM_near_inTown}));
		avoidList_near() if $config{avoidList};
		$timeout{ai_avoidcheck}{time} = time;
	}
	foreach (@monstersID) {
		next unless $_;
		if (mon_control($monsters{$_}{name},$monsters{$_}{nameID})->{teleport_auto} == 3) {
		   warning TF("Disconnecting for 30 secs to avoid %s\n", $monsters{$_}{name});
		   relog(30);
		}
	}
}

##### SEND EMOTICON #####
sub processSendEmotion {
	my $ai_sendemotion_index = AI::findAction("sendEmotion");
	return if (!defined $ai_sendemotion_index || time < AI::args->{timeout});
	$messageSender->sendEmotion(AI::args->{emotion});
	AI::clear("sendEmotion");
}

##### AUTO SHOP OPEN #####
sub processAutoShopOpen {
	if ($config{'shopAuto_open'} && !AI::isIdle) {
		$timeout{ai_shop}{time} = time;
	}
	if ($config{'shopAuto_open'} && AI::isIdle && $conState == 5 && !$char->{sitting} && timeOut($timeout{ai_shop}) && !$shopstarted
	  && $field{name} eq $config{'lockMap'}) {
		openShop();
	}
}

sub processDcOnPlayer {
	# Disconnect when a player is detected
	my $map_name_lu = $field{name}.'.rsw';
	if (!$cities_lut{$map_name_lu} && !AI::inQueue("storageAuto", "buyAuto") && $config{dcOnPlayer}
	    && ($config{'lockMap'} eq "" || $field{name} eq $config{'lockMap'})
	    && !isSafe() && timeOut($AI::Temp::Teleport_allPlayers, 0.75)) {

		$quit = 1;
	}
}

##### REPAIR AUTO #####
sub processRepairAuto {
	if ($config{'repairAuto'} && $conState == 5 && timeOut($timeout{ai_repair}) && $repairList) {
		my ($listID, $name);
		my $brokenIndex = 0;
		foreach my $repairListItem (@{$repairList}) {
			$name = itemNameSimple($repairListItem->{nameID});
			if (existsInList($config{'repairAuto_list'}, $name) || !$config{'repairAuto_list'}) {
				$messageSender->sendRepairItem($repairListItem);
				$timeout{ai_repair}{time} = time;
				return;
			}
		}
	}
}

1;
