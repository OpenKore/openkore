#########################################################################
#  OpenKore - NPC talking task
#  Copyright (c) 2004-2006 OpenKore Developers
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# This task is responsible for automatically talking to NPCs, using a
# pre-defined NPC talking sequence.
package Task::TalkNPC;

use strict;
use Time::HiRes qw(time);
use Scalar::Util;
use encoding 'utf8';

use Modules 'register';
use Task;
use base qw(Task);
use Globals qw($char %timeout $npcsList $monstersList %ai_v $messageSender %config @storeList $net %talk);
use Log qw(debug);
use Utils;
use Commands;
use Network;
use Misc;
use Plugins;
use Translation qw(T TF);

# Error codes:
use constant NPC_NOT_FOUND => 1;
use constant NPC_NO_RESPONSE => 2;
use constant NO_SHOP_ITEM => 3;
use constant WRONG_INSTRUCTIONS => 4;


##
# Task::TalkNPC->new(options...)
#
# Create a new Task::TalkNPC object. The following options are allowed:
# `l
# - All options allowed in Task->new(), except 'mutexes'.
# - <tt>x</tt> (required): The X-coordinate of the NPC to talk to.
# - <tt>y</tt> (required): The Y-coordinate of the NPC to talk to.
# - <tt>sequence</tt> (required): A string which describes how to talk to the NPC.
# `l`
# Note that the NPC is assumed to be on the same map as where the character currently is.
#
# <tt>sequence</tt> is a string of whitespace-separated instructions:
# ~l
# - c       : Continue
# - r#      : Select option # from menu.
# - n       : Stop talking to NPC.
# - b       : Send the "Show shop item list" (Buy) packet.
# - w#      : Wait # seconds.
# - x       : Initialize conversation with NPC. Useful to perform multiple transaction with a single NPC.
# - t="str" : send the text str to NPC, double quote is needed only if the string contains space
# ~l~
sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new(@_, mutexes => ['npc']);

	$self->{x} = $args{x};
	$self->{y} = $args{y};
	$self->{sequence} = $args{sequence};
	$self->{sequence} =~ s/^ +| +$//g;

	# Watch for map change events. Pass a weak reference to ourselves in order
	# to avoid circular references (memory leaks).
	my $weak_self = $self;
	Scalar::Util::weaken($weak_self);
	$self->{mapChangedHook} = Plugins::addHook('Network::Receive::map_changed', \&mapChanged, $weak_self);

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	Plugins::delHook($self->{mapChangedHook});
}

# Overrided method.
sub activate {
	my ($self) = @_;
	$self->SUPER::activate(); # Do not forget to call this!
	$self->{time} = time;
	$self->{stage} = 'Not Started';
	$self->{mapChanged} = 0;
}

# Overrided method.
sub iterate {
	my ($self) = @_;
	$self->SUPER::iterate(); # Do not forget to call this!
	return unless ($net->getState() == Network::IN_GAME);

	if ($self->{stage} eq 'Not Started') {
		if (!timeOut($char->{time_move}, $char->{time_move_calc} + 0.2)) {
			# Wait for us to stop moving before talking.
			return;

		} elsif (timeOut($self->{time}, $timeout{ai_npcTalk}{timeout})) {
			$self->setError(NPC_NOT_FOUND, TF("Could not find an NPC at location (%d,%d).",
				$self->{x}, $self->{y}));

		} else {
			my $target = $self->findTarget($npcsList);
			if ($target) {
				debug "Target NPC " . $target->name() . " at ($self->{pos}{x},$self->{pos}{y}) found.\n", "ai_npcTalk";
			} else {
				$target = $self->findTarget($monstersList);
				if ($target) {
					debug "Target Monster-NPC " . $target->name() . " at ($self->{pos}{x},$self->{pos}{y}) found.\n", "ai_npcTalk";
				}
			}

			if ($target) {
				$self->{target} = $target;
				$self->{ID} = $target->{ID};
				$self->{stage} = 'Talking to NPC';
				$self->{steps} = [parseArgs("x $self->{sequence}")];
				$self->{time} = time;
				undef $ai_v{npc_talk}{time};
				undef $ai_v{npc_talk}{talk};
				lookAtPosition($self);
			}
		}

	} elsif ($self->{mapChanged} || ($ai_v{npc_talk}{talk} eq 'close' && $self->{steps}[0] !~ /x/i)) {
		# Cancel conversation only if NPC is still around; otherwise
		# we could get disconnected.
		#$messageSender->sendTalkCancel($self->{ID}) if ($npcsList->getByID($self->{ID}));
		$self->setDone();

	} elsif (timeOut($self->{time}, $timeout{ai_npcTalk}{timeout})) {
		# If NPC does not respond before timing out, then by default, it's
		# a failure.
		$messageSender->sendTalkCancel($self->{ID});
		$self->setError(NPC_NO_RESPONSE, T("The NPC did not respond."));

	} elsif (timeOut($ai_v{npc_talk}{time}, 0.25)) {
		# 0.25 seconds have passed since we last talked to the NPC.

		if ($ai_v{npc_talk}{talk} eq 'close' && $self->{steps}[0] =~ /x/i) {
			undef $ai_v{npc_talk}{talk};
		}
		$self->{time} = time;

		# We give the NPC some time to respond. This time will be reset once
		# the NPC responds.
		$ai_v{npc_talk}{time} = time + $timeout{ai_npcTalk}{timeout} + 5;

		if ($config{autoTalkCont}) {
			while ($self->{steps}[0] =~ /c/i) {
				shift @{$self->{steps}};
			}
		}

		my $step = $self->{steps}[0];
		my $npcTalkType = $ai_v{npc_talk}{talk};

		if ($step =~ /w(\d+)/i) {
			# Wait x seconds.
			my $time = $1;
			$ai_v{npc_talk}{time} = time + $time;
			$self->{time} = time + $time;

		} elsif ( $step =~ /^t=(.*)/i ) {
			# Send NPC talk text.
			$messageSender->sendTalkText($self->{ID}, $1);

		} elsif ( $step =~ /^a=(.*)/i ) {
			# Run a command.
			my $command = $1;
			$ai_v{npc_talk}{time} = time + 1;
			$self->{time} = time + 1;
			Commands::run($command);

		} elsif ( $step =~ /d(\d+)/i ) {
			# Send NPC talk number.
			$messageSender->sendTalkNumber($self->{ID}, $1);

		} elsif ( $step =~ /x/i ) {
			# Initiate NPC conversation.
			if (!$self->{target}->isa('Actor::Monster')) {
				$messageSender->sendTalk($self->{ID});
			} else {
				$messageSender->sendAttack($self->{ID}, 0);
			}

		} elsif ( $step =~ /c/i ) {
			# Click Next.
			if ($npcTalkType eq 'next') {
				$messageSender->sendTalkContinue($self->{ID});
			} else {
				$self->setError(WRONG_INSTRUCTIONS,
					"According to the instructions, the Next button " .
					"must now be clicked on, but that's not possible.");
				$self->cancelTalk();
			}

		} elsif ( $step =~ /r(\d+)/i ) {
			# Choose a menu item.
			my $choice = $1;
			if ($npcTalkType eq 'select') {
				if ($choice < @{$talk{responses}} - 1) {
					$messageSender->sendTalkResponse($self->{ID}, $choice + 1);
				} else {
					$self->setError(WRONG_INSTRUCTIONS,
						"According to the instructions, menu item $choice must " .
						"now be selected, but there are only " .
						(@{$talk{responses}} - 1) . " menu items.");
					$self->cancelTalk();
				}
			} else {
				$self->setError(WRONG_INSTRUCTIONS,
					"According to the instructions, a menu item " .
					"must now be selected, but that's not possible.");
				$self->cancelTalk();
			}

		} elsif ( $step =~ /n/i ) {
			# Click Close or Cancel.
			$self->cancelTalk();
			$ai_v{npc_talk}{time} = time;
			$self->{time} = time;

		} elsif ( $step =~ /^b(\d+),(\d+)/i ) {
			# Buy an shop item.
			my $index = $1;
			my $amount = $2;
			if ($storeList[$index]) {
				my $itemID = $storeList[$index]{nameID};
				$ai_v{npc_talk}{itemID} = $itemID;
				$messageSender->sendBuy($itemID, $amount);
			} else {
				$self->setError(NO_SHOP_ITEM, TF("Shop item %d not found.", $index));
			}

		} elsif ( $step =~ /b/i ) {
			# Get the shop's item list.
			$messageSender->sendGetStoreList($self->{ID});

		} elsif ( $step =~ /s/i ) {
			# Get the sell list in a shop.
			$messageSender->sendGetSellList($self->{ID});

		} elsif ( $step =~ /e/i ) {
			# ? Pretend like the conversation was stopped by the NPC?
			$ai_v{npc_talk}{talk} = 'close';
		}

		shift @{$self->{steps}};
	}
}

##
# Actor $Task_TalkNPC->target()
# Requires: $self->getStatus() == Task::DONE && !defined($self->getError())
# Ensures: defined(result)
#
# Returns the target Actor object.
sub target {
	my ($self) = @_;
	return $self->{target};
}

sub cancelTalk {
	my ($self) = @_;
	if ($ai_v{npc_talk}{talk} eq 'select') {
		$messageSender->sendTalkResponse($self->{ID}, 255);
	} elsif ($ai_v{npc_talk}{talk} ne 'close' && !$talk{canceled}) {
		$messageSender->sendTalkCancel($self->{ID});
		$talk{canceled} = 1;
	}
}

sub mapChanged {
	my (undef, undef, $self) = @_;
	$self->{mapChanged} = 1;
}

# Actor findTarget(ActorList actorList)
#
# Check whether the target as specified in $self->{x} and $self->{y} is in the given
# actor list. Returns the actor object if it's currently on screen and has a name,
# undef otherwise.
#
# Note: we require that the NPC's name is known, because otherwise talking
# may fail.
sub findTarget {
	my ($self, $actorList) = @_;
	foreach my $actor (@{$actorList->getItems()}) {
		my $pos = ($actor->isa('Actor::NPC')) ? $actor->{pos} : $actor->{pos_to};
		if ($pos->{x} == $self->{x} && $pos->{y} == $self->{y}) {
			if (defined $actor->{name}) {
				return $actor;
			} else {
				return undef;
			}
		}
	}
	return undef;
}

1;
