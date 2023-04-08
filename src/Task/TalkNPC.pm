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
use utf8;

use Modules 'register';
use Task;
use base qw(Task);
use Globals qw($char %timeout $npcsList $monstersList %ai_v $messageSender %config $storeList $net %talk);
use Log qw(message debug error warning);
use Utils;
use Commands;
use Network;
use Misc;
use Plugins;
use Translation qw(T TF);

# Error codes:
use enum qw(
	NPC_NOT_FOUND
	NPC_NO_RESPONSE
	NO_SHOP_ITEM
	WRONG_NPC_INSTRUCTIONS
	NPC_TIMEOUT_AFTER_ASWER
	STEPS_AFTER_AFTER_NPC_CLOSE
	STEPS_AFTER_BUY_OR_SELL
	WRONG_SYNTAX_IN_STEPS
);

# Mutexes used by this task.
use constant MUTEXES => ['npc'];

use enum qw(
	NOT_STARTED
	TALKING_TO_NPC
	AFTER_NPC_CLOSE
	AFTER_NPC_CANCEL
);


##
# Task::TalkNPC->new(options...)
#
# Create a new Task::TalkNPC object. The following options are allowed:
# `l
# - All options allowed in Task->new(), except 'mutexes'.
# - <tt>x</tt> (required): The X-coordinate of the NPC to talk to.
# - <tt>y</tt> (required): The Y-coordinate of the NPC to talk to.
# - <tt>nameID</tt> (required): The nameID of the NPC to talk to (you may use this instead of x and y).
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
	my $self = $class->SUPER::new(@_, mutexes => MUTEXES);

	$self->{type} = $args{type};
	$self->{x} = $args{x};
	$self->{y} = $args{y};
	$self->{ID} = $args{ID};
	$self->{nameID} = $args{nameID};
	$self->{sequence} = $args{sequence};
	$self->{sequence} =~ s/^ +| +$//g;
	$self->{steps} = [];
	$self->{trying_to_cancel} = 0;
	$self->{sent_talk_response_cancel} = 0;
	$self->{wait_for_answer} = 0;
	$self->{error_code} = undef;
	$self->{error_message} = undef;
	$self->{map_change} = 0;
	$self->{disconnected} = 0;

	$ai_v{'npc_talk'}{'ID'} = $args{ID} if $args{ID};
	
	debug "Task::TalkNPC::new has been called with sequence '".$self->{sequence}."'.\n", "ai_npcTalk";
	
	return $self;
}

sub handleNPCTalk {
	my ($hook_name, $args, $holder) = @_;
	my $self = $holder->[0];
	
	# TODO: maybe better create a new task
	if ($self->{stage} == AFTER_NPC_CANCEL) {
		debug "Npc has restarted conversation after talk cancel was sent.\n", "ai_npcTalk";
		
		if ($self->noMoreSteps) {
			debug "Continuing the talk within the same task, no conversation steps left.\n", 'ai_npcTalk';
		} else {
			debug "Continuing the talk within the same task and remaining conversation steps.\n", 'ai_npcTalk';
		}
		
		$self->find_and_set_target;
		$self->{stage} = TALKING_TO_NPC;
		$self->{time} = time;
	}
	
	if ($hook_name eq 'npc_talk_done') {
		if ($self->{stage} == NOT_STARTED) {
			debug "Npc which started autotalk has automatically sent a 'npc_talk_done'.\n", "ai_npcTalk";
			return;
			
		} elsif ($self->{stage} != TALKING_TO_NPC || !$self->{target} || $self->{ID} ne $args->{ID}) {
			debug "We received an strange 'npc_talk_done', ignoring it.\n", "ai_npcTalk";
			return;
		}
		$self->{stage} = AFTER_NPC_CLOSE;
		message TF("%s: Done talking\n", $self->{target}), "npc";
	
	} elsif ($self->noMoreSteps) {
		if ($hook_name eq 'packet/npc_talk_continue') {
			message TF("%s: Type 'talk cont' to continue talking\n", $self->{target}), "npc";
			
		} elsif ($hook_name eq 'packet/npc_talk_number') {
			message TF("%s: Type 'talk num <number #>' to input a number.\n", $self->{target}), "npc";
			
		} elsif ($hook_name eq 'npc_talk_responses') {
			message TF("%s: Type 'talk resp #' to choose a response.\n", $self->{target}), "npc";
			
		} elsif ($hook_name eq 'packet/npc_store_begin') {
			message TF("%s: Type 'store' to start buying, type 'sell' to start selling or type 'canceltransaction' to cancel\n", $self->{target}), "npc";
			
		} elsif ($hook_name eq 'packet/npc_talk_text') {
			message TF("%s: Type 'talk text' (Respond to NPC)\n", $self->{target}), "npc";
			
		} elsif ($hook_name eq 'packet/cash_dealer') {
			message TF("%s: Type 'cashbuy' to start buying\n", $self->{target}), "npc";
		}
	}
	$self->{time} = time;
	$self->{sent_talk_response_cancel} = 0;
	$self->{wait_for_answer} = 0;
}

sub delHooks {
	my ($self) = @_;

	Plugins::delHooks($_) for @{$self->{hookHandles}};
	delete $self->{hookHandles};
	
	Plugins::delHook($self->{mapChangedHook}) if $self->{mapChangedHook};
	delete $self->{mapChangedHook};
	
	Plugins::delHook($self->{disconnectedHook}) if $self->{disconnectedHook};
	delete $self->{disconnectedHook};
}

sub DESTROY {
	my ($self) = @_;
	debug "$self->{target}: Task::TalkNPC::DESTROY was called\n", "ai_npcTalk";
	delete $ai_v{'npc_talk'} unless ($ai_v{'npc_talk'}{'talk'} =~ /^(buy_or_sell|store|sell|cash)$/);
	$self->delHooks;
	$self->SUPER::DESTROY;
}

# Overrided method.
sub activate {
	my ($self) = @_;
	$self->SUPER::activate(); # Do not forget to call this!
	$self->{time} = time;
	$self->{stage} = NOT_STARTED;

	my @holder = ($self);
	Scalar::Util::weaken($holder[0]);

	push @{$self->{hookHandles}}, Plugins::addHooks(
		['npc_talk',                                 \&handleNPCTalk, \@holder],
		['packet/npc_talk_continue',                 \&handleNPCTalk, \@holder],
		['npc_talk_done',                            \&handleNPCTalk, \@holder],
		['npc_talk_responses',                       \&handleNPCTalk, \@holder],
		['packet/npc_talk_number',                   \&handleNPCTalk, \@holder],
		['packet/npc_talk_text',                     \&handleNPCTalk, \@holder],
		['packet/npc_store_begin',                   \&handleNPCTalk, \@holder],
		['packet/npc_store_info',                    \&handleNPCTalk, \@holder],
		['packet/npc_sell_list',                     \&handleNPCTalk, \@holder],
		['packet/cash_dealer',                       \&handleNPCTalk, \@holder],
		['packet/npc_market_info',                   \&handleNPCTalk, \@holder],
		['packet/npc_market_purchase_result',        \&handleNPCTalk, \@holder]
	);
	
	$self->{mapChangedHook} = Plugins::addHook('Network::Receive::map_changed', \&mapChanged, \@holder);
	$self->{disconnectedHook} = Plugins::addHook('serverDisconnect/success', \&serverDisconnectSuccess, \@holder);
}
 
sub mapChanged {
	my (undef, undef, $holder) = @_;
	my $self = $holder->[0];
	$self->{map_change} = 1;
}

sub serverDisconnectSuccess {
	my (undef, undef, $holder) = @_;
	return if $holder->[0]->{disconnected};
	
	debug "Disconnected during TalkNPC, cancelling task...\n";
	$holder->[0]->{disconnected} = 1;
}

# Overrided method.
sub stop {
	my ($self) = @_;

	$self->delHooks;

	$self->SUPER::stop;
}

sub setTarget {
	my ($self, $target) = @_;

	if ($target) {
		debug "Talking with $target at ($target->{pos}{x},$target->{pos}{y}), ID ".getHex($target->{ID})."\n", "ai_npcTalk";
		$ai_v{'npc_talk'}{'ID'} = $target->{ID};
	}

	$self->{target} = $target;
	$self->{ID} = $target->{ID};

	# FIXME: We probably need to look at the target->pos_to (if defined),
	# not at self, as coordinates can be omitted.
	if (defined $self->{x} && defined $self->{y}) {
		lookAtPosition($self) unless (%talk);
	}

	return 1;
}

sub find_and_set_target {
	my ($self) = @_;
	my $target = $self->findTarget($npcsList) || $self->findTarget($monstersList);

	if ($target) {
		return unless $self->setTarget($target);
	} elsif (exists $talk{nameID} && $ai_v{'npc_talk'}{'talk'} ne 'buy_or_sell') {#check if this is really necessary
		$self->{ID} = $talk{ID};
		$self->{target} = Actor::NPC->new;
		$self->{target}->{appear_time} = time;
		$self->{target}->{name} = 'Unknown';
	}
	
	return $target;
}

# Overrided method.
sub iterate {
	my ($self) = @_;
	$self->SUPER::iterate(); # Do not forget to call this!
	return unless ($net->getState() == Network::IN_GAME);
	my $timeResponse = ($config{npcTimeResponse} >= 5) ? $config{npcTimeResponse}:5;
	my $ai_npc_talk_wait_to_answer = $timeout{'ai_npc_talk_wait_to_answer'}{'timeout'} ? $timeout{'ai_npc_talk_wait_to_answer'}{'timeout'} : 1.5;
	my $ai_npc_talk_wait_after_close_to_cancel = $timeout{'ai_npc_talk_wait_after_close_to_cancel'}{'timeout'} ? $timeout{'ai_npc_talk_wait_after_close_to_cancel'}{'timeout'} : 0.5;
	my $ai_npc_talk_wait_after_cancel_to_destroy = $timeout{'ai_npc_talk_wait_after_cancel_to_destroy'}{'timeout'} ? $timeout{'ai_npc_talk_wait_after_cancel_to_destroy'}{'timeout'} : 0.5;

	if ($self->{map_change} || $self->{disconnected}) {
		
		#A conversation started right after mapchange/disconnection (eg. payon guards)
		if (%talk) {
			debug "Done talking with $self->{target}, but another NPC initiated a talk instantly\n", 'ai_npcTalk';
			# TODO: maybe better create a new task and pass remaining steps to it
			debug "Continuing the talk within the same task and remaining conversation steps\n", 'ai_npcTalk';
			$self->{map_change} = 0;
			$self->{disconnected} = 0;
			$self->find_and_set_target;
			$self->{stage} = TALKING_TO_NPC;
			$self->{time} = time;
			
		#If there's no conversation clear this task
		} else {
			debug "Ending Task::TalkNPC due to mapchange or disconnection, ";
			
			if ($self->{stage} == TALKING_TO_NPC) {
				debug "conversation interrupted and finished.\n";
			} elsif ($self->{stage} == AFTER_NPC_CLOSE) {
				debug "talk cancel won't be sent.\n";
			} elsif ($self->{stage} == AFTER_NPC_CANCEL) {
				debug "ending task before timeout.\n";
			} elsif ($self->{stage} == NOT_STARTED) {
				debug "ending task before conversation started.\n";
			} else {
				debug "conversation ended during unhandled stage ". $self->{stage} . ".\n";
			}
			
			$self->conversation_end;
		}
	
	} elsif ($self->{stage} == NOT_STARTED) {
		if ((!%talk || $ai_v{'npc_talk'}{'talk'} eq 'close') && $self->{type} eq 'autotalk') {
			debug "Talking was initiated by the other side and finished instantly\n", "ai_npcTalk";
			#We must still send talk cancel or otherwise the character can't move.
			$self->{stage} = AFTER_NPC_CLOSE;
			$self->find_and_set_target;
			$self->{time} = time;
			return;
			
		} elsif (!timeOut($char->{time_move}, $char->{time_move_calc} + 0.2)) {
			# Wait for us to stop moving before talking.
			return;

		} elsif (timeOut($self->{time}, $timeResponse)) {
			if ($self->{nameID}) {
				$self->setError(NPC_NOT_FOUND, TF("Could not find an NPC with id (%d).",
					$self->{nameID}));
			} else {
				$self->setError(NPC_NOT_FOUND, TF("Could not find an NPC at location (%d,%d).",
					$self->{x}, $self->{y}));
			}

		} elsif (defined $self->{error_code}) {
			debug "Can't talk with $self->{target}, because of errors\n", 'ai_npcTalk';
			$self->setError($self->{error_code}, $self->{error_message});
		} else {
			my $target = $self->find_and_set_target;
			
			unless (exists $talk{nameID} || $self->{steps}[0] eq 'x') {
				$self->addSteps('x');
				undef $ai_v{'npc_talk'}{'time'};
				undef $ai_v{'npc_talk'}{'talk'};
			}

			if ($target || %talk) {
				return unless ($self->addSteps($self->{sequence}));
				$self->{stage} = TALKING_TO_NPC;
				$self->{time} = time;
			}
		}
	
	# This is where things may bug in npcs which have no chat (private healers)
	} elsif (!$ai_v{'npc_talk'}{'time'} && timeOut($self->{time}, $timeResponse)) {
		# If NPC does not respond before timing out, then by default, it's
		# a failure.
		$messageSender->sendTalkCancel($self->{ID});
		$self->setError(NPC_NO_RESPONSE, T("The NPC did not respond."));

	} elsif ($self->{stage} == TALKING_TO_NPC && timeOut($ai_v{'npc_talk'}{'time'}, $ai_npc_talk_wait_to_answer)) {
		# $config{npcTimeResponse} seconds have passed since we sent the last conversation step
		# or $ai_npc_talk_wait_to_answer seconds have passed since the npc answered us.
		
		#In theory after the talk_response_cancel is sent we shouldn't receive anything, so just wait the timer and assume it's over
		if ($self->{sent_talk_response_cancel}) {
			undef %talk;
			if (defined $self->{error_code}) {
				debug "Done talking with $self->{target}, but with conversation sequence errors\n", 'ai_npcTalk';
				$self->setError($self->{error_code}, $self->{error_message});
			} else {
				$self->conversation_end;
			}
			return;
		
		#This will try to get out of this conversation as much as possible
		} elsif ($self->{trying_to_cancel}) {
			$ai_v{'npc_talk'}{'time'} = time + $timeResponse;
			$self->{time} = time;
			$self->cancelTalk;
			return;
		}
		
		#We must always wait for the last sent step to be answered, if it hasn't then cancel this task.
		if ($self->{wait_for_answer}) {
			$self->{error_code} = NPC_TIMEOUT_AFTER_ASWER;
			$self->{error_message} = "We have waited for too long after we sent a response to the npc.";
			$self->cancelTalk;
			return;
		}
		
		# Wait x seconds.
		if ($self->{steps}[0] =~ /^w(\d+)/i) {
			my $time = $1;
			debug "$self->{target}: Waiting for $time seconds...\n", 'ai_npcTalk';
			$ai_v{'npc_talk'}{'time'} = time + $time;
			$self->{time} = time + $time;
			shift @{$self->{steps}};
			return;
			
		# Run a command.
		} elsif ($self->{steps}[0] =~ /^a=(.*)/i) {
			my $command = $1;
			my $timeout = $timeResponse - 4;
			$timeout = 0 if $timeout < 0;
			$ai_v{'npc_talk'}{'time'} = time + $timeout;
			$self->{time} = time + $timeout;
			Commands::run($command);
			shift @{$self->{steps}};
			return;
		}
		
		if ($ai_v{'npc_talk'}{'talk'} ne 'next') {
			while ($self->{steps}[0] =~ /^c/i) {
				warning "Ignoring excessive use 'c' in conversation with npc.\n";
				shift(@{$self->{steps}});
			}
		
		#This is to make non-autotalkcont sequences compatible with autotalkcont ones
		} elsif ($ai_v{'npc_talk'}{'talk'} eq 'next' && $config{autoTalkCont}) {
			if ( $self->noMoreSteps || $self->{steps}[0] !~ /^c/i ) {
				unshift(@{$self->{steps}}, 'c');
			}
			debug "$self->{target}: Auto-continuing talking\n", 'ai_npcTalk';
		}
			
		#This is done to restart the conversation (check if this is necessary)
		if ($ai_v{'npc_talk'}{'talk'} eq 'close' && $self->{steps}[0] =~ /x/i) {
			undef $ai_v{'npc_talk'}{'talk'};
		}

		if ($self->noMoreSteps) {
			# We arrived at a buy or sell selection, but there are no more steps regarding this, so end the conversation
			if ($ai_v{'npc_talk'}{'talk'} =~ /^(buy_or_sell|store|sell|cash)$/) {
				$self->conversation_end;
			}
			#Wait for more commands
			return;
		
		#We give the NPC some time to respond. This time will be reset once the NPC responds.
		} else {
			$ai_v{'npc_talk'}{'time'} = time + $timeResponse;
			$self->{time} = time;
		}
		
		my $step = $self->{steps}[0];
		my $current_talk_step = $ai_v{'npc_talk'}{'talk'};

		while ( $step =~ /^if~\/(.*?)\/,(.*)/i ) {
			my ( $regex, $code ) = ( $1, $2 );
			if ( "$talk{msg}:$talk{image}" =~ /$regex/s ) {
				$step = $code;
			} else {
				shift @{ $self->{steps} };
				$step = $self->{steps}->[0];
			}
		}
		
		debug "Iteration at Task::TalkNPC, current_talk_step '".$current_talk_step."', next step '".$step."'.\n", "ai_npcTalk", 2;
		
		# Initiate NPC conversation.
		if ( $step =~ /^x/i ) {
			debug "$self->{target}: Initiating the talk\n", 'ai_npcTalk';
			$self->{target}->sendTalk;
		
		# Select an answer
		} elsif ($current_talk_step eq 'select') {
		
			if ( $step =~ /^r(?:(\d+)|=(.+)|~\/(.*?)\/(i?))/i ) {
				my $choice = $1;
				
				# Regex or text match
				if ($2 || $3) {
					# Choose a menu item by matching options against a regular expression.
					my $pattern = $2 ? "^\Q$2\E\$" : $3;
					my $postCondition = $4;
					( $choice ) = grep { $postCondition ? $talk{responses}[$_] =~ /$pattern/i : $talk{responses}[$_] =~ /$pattern/ } 0..$#{$talk{responses}};
					
					# Found valid response
					if (defined $choice && $choice < $#{$talk{responses}}) {
						$messageSender->sendTalkResponse($talk{ID}, $choice + 1);
						
					# Found response is fake 'Cancel Chat'
					} elsif (defined $choice) {
						$self->{trying_to_cancel} = 1;
						$self->cancelTalk;
					
					# No match was found
					} else {
						$self->manage_wrong_sequence(TF("According to the given NPC instructions, a menu " .
							"item matching '%s' must now be selected, but no " .
							"such menu item exists.", $pattern));
						return;
					}
					
				#Normal number response
				} else {
					
					#Normal number response is valid
					if ($choice < $#{$talk{responses}}) {
						debug "$self->{target}: Sending talk response #$choice\n", 'ai_npcTalk';
						$messageSender->sendTalkResponse($talk{ID}, $choice + 1);
					
					#Normal number response is a fake "Cancel Chat" response.
					} elsif ($choice == $#{$talk{responses}}) {
						$self->{trying_to_cancel} = 1;
						$self->cancelTalk;
					
					#Normal number response is not valid
					} else {
						$self->manage_wrong_sequence(TF("According to the given NPC instructions, menu item %d must " .
							"now be selected, but there are only %d menu items.",
							$choice, @{$talk{responses}} - 1));
						return;
					}
				}
			
			# Wrong sequence
			} else {
				$self->manage_wrong_sequence(TF("NPC requires a response to be selected, but the given instructions don't match that (current step: %s).", $step));
				return;
			}
		
		# Click Next.
		} elsif ($current_talk_step eq 'next') {
			if ($step =~ /^c/i) {
				debug "$self->{target}: Sending talk continue (next)\n", 'ai_npcTalk';
				$messageSender->sendTalkContinue($talk{ID});
			
			# Wrong sequence
			} else {
				$self->manage_wrong_sequence(TF("NPC requires the next button to be pressed now, but the given instructions don't match that (current step: %s).", $step));
				return;
			}
			
		# Send NPC talk number.
		} elsif ($current_talk_step eq 'number') {
			if ( $step =~ /^d(\d+)/i ) {
				my $number = $1;
				debug "$self->{target}: Sending the number: $number\n", 'ai_npcTalk';
				$messageSender->sendTalkNumber($talk{ID}, $number);
			
			# Wrong sequence
			} else {
				$self->manage_wrong_sequence(TF("NPC requires a number to be sent now, but the given instructions don't match that (current step: %s).", $step));
				return;
			}
			
		# Send NPC talk text.
		} elsif ($current_talk_step eq 'text') {
			if ( $step =~ /^t=(.*)/i ) {
				my $text = $1;
				debug "$self->{target}: Sending the text: $text\n", 'ai_npcTalk';
				$messageSender->sendTalkText($talk{ID}, $text);
			
			# Wrong sequence
			} else {
				$self->manage_wrong_sequence(TF("NPC requires a text to be sent now, but the given instructions don't match that (current step: %s).", $step));
				return;
			}
		
		# Get the sell or buy list in a shop.
		} elsif ( $current_talk_step eq 'buy_or_sell' ) {
		
			# Get the sell list in a shop.
			if ( $step =~ /^s/i ) {
				$messageSender->sendNPCBuySellList($talk{ID}, 1);
				
			# Get the buy list in a shop.
			} elsif ($step =~ /^b$/i) {
				$messageSender->sendNPCBuySellList($talk{ID}, 0);
				
			# Click the cancel button in a shop.
			} elsif ($step =~ /^e$/i) {
				cancelNpcBuySell();
				$ai_v{'npc_talk'}{'talk'} = 'close';
				
				if ($self->noMoreSteps) {
					$self->conversation_end;
				} else {
					$self->{time} = time + 2;
				}
			
			# Wrong sequence
			} else {
				$self->manage_wrong_sequence(TF("This npc requires the sell, buy or cancel button to be pressed, but the given instructions don't match that (current step: %s).", $step));
				return;
			}
		
		} elsif ( $current_talk_step eq 'store' ) {
			
			# Buy Items
			if ($step =~ /^b(\d+),(\d+)/i) {
				my @bulkitemlist;
				while ($self->{steps}[0] =~ /^b(\d+),(\d+)/i){
					my $index = $1;
					my $amount = $2;
					if ($storeList->get($index)) {
						# support to market
						my $item = $storeList->get($index);

						if ($item->{amount} && $item->{amount} < $amount) {
							$amount = $item->{amount};
						}

						my $itemID = $storeList->get($index)->{nameID};
						push (@{$ai_v{npc_talk}{itemsIDlist}},$itemID);
						push (@bulkitemlist,{itemID  => $itemID, amount => $amount});
					} else {
						# ? Maybe better to use something else, but not error?
						error TF("Shop item %s not found.\n", $index);
					}
					shift @{$self->{steps}};
				}
				completeNpcBuy(\@bulkitemlist);
				# We give some time to get inventory_item_added packet from server.
				# And skip this itteration.
				if ($self->noMoreSteps) {
					$self->conversation_end;
				} else {
					$ai_v{'npc_talk'}{'talk'} = 'close';
					$self->{time} = time + 2;
				}
				return;
				
			# Click the cancel button in a shop.
			} elsif ($step =~ /^e$/i) {
				my @bulkitemlist;
				completeNpcBuy(\@bulkitemlist);
				
				if ($self->noMoreSteps) {
					$self->conversation_end;
				} else {
					$ai_v{'npc_talk'}{'talk'} = 'close';
					$self->{time} = time + 2;
				}
				
				return;
				
			# Wrong sequence
			} else {
				$self->manage_wrong_sequence(TF("NPC requires the buy or cancel button to be pressed, but the given instructions don't match that (current step: %s).", $step));
				return;
			}
		
		} elsif ( $current_talk_step eq 'sell' ) {
			$self->conversation_end;

		} else {
			if ( $step =~ /^n$/i ) {
				#Here for backwards compatibility
				shift @{$self->{steps}};
				
			} else {
				$self->manage_wrong_sequence(T("According to the given NPC instructions, a npc conversation code ") .
					TF("should be used (%s), but it doesn't exist.", $step));
				return;
			}
		}
		
		$self->{wait_for_answer} = 1;
		shift @{$self->{steps}};
	
	# After a 'npc_talk_done' hook we must always send a 'npc_talk_cancel' after a timeout
	# I noticed that the RO client doesn't send a 'talk cancel' packet
	# when it receives a 'npc_talk_closed' packet from the server'.
	# But on pRO Thor (with Kapra password) this is required in order to
	# open the storage.
	#
	# UPDATE: not sending 'talk cancel' breaks autostorage on iRO.
	# This needs more investigation.
	} elsif ($self->{stage} == AFTER_NPC_CLOSE) {
		return unless (timeOut($self->{time}, $ai_npc_talk_wait_after_close_to_cancel));
		#Now 'n' step is totally unnecessary as we always send it but this must be done for backwards compatibility
		if ( $self->{steps}[0] =~ /^n/i ) {
			shift(@{$self->{steps}});
		}
		$self->{time} = time;
		$self->{stage} = AFTER_NPC_CANCEL;
		debug "$self->{target}: Sending talk cancel after NPC has done talking\n", 'ai_npcTalk';
		$messageSender->sendTalkCancel($self->{ID});
	
	# After a 'npc_talk_cancel' and a timeout we decide what to do next
	} elsif ($self->{stage} == AFTER_NPC_CANCEL) {
		return unless (timeOut($self->{time}, $ai_npc_talk_wait_after_cancel_to_destroy));
		
		if (defined $self->{error_code}) {
			$self->setError($self->{error_code}, $self->{error_message});
			debug $self->{error_message} . "\n", 'ai_npcTalk';
			return;
		}
		
		# No more steps to be sent
		# Usual end of a conversation
		if ($self->noMoreSteps && !%talk) {
			$self->conversation_end;
		
		# There are more steps but no conversation with npc
		} elsif (!%talk) {
			# Usual 'x' step
			if ($self->{steps}[0] =~ /x/i) {
				debug "$self->{target}: Reinitiating the talk\n", 'ai_npcTalk';
				$self->{stage} = TALKING_TO_NPC;
				$self->{time} = time;
			
			# Too many steps
			} else {
				if ( scalar @{$self->{steps}} == 1 && $self->{steps}[0] =~ /^n$/i ) {
					#Here for backwards compatibility
					$self->conversation_end;
					
				} else {
					# TODO: maybe just warn about remaining steps and do not set error flag?
					$self->setError(STEPS_AFTER_AFTER_NPC_CLOSE, "There are still steps to be done but the conversation has already ended (current step: ".$self->{steps}[0].").");
				}
			}
		}
	}
}

sub manage_wrong_sequence {
	my ( $self, $error_message ) = @_;
	
	$self->{error_code} = WRONG_NPC_INSTRUCTIONS;
	$self->{error_message} = $error_message;
	error $self->{error_message}."\n";
	
	my $method = (defined $config{'npcWrongStepsMethod'} ? $config{'npcWrongStepsMethod'} : 0);
	warning "Using method '".$method."' defined on config key 'npcWrongStepsMethod' to deal with the error.\n";
	
	# Will clean all remaining steps and wait for command
	if ($method == 0) {
		warning "Cleaning all remaining conversation steps, please input more steps using commands.\n";
		$self->{steps} = [];
	
	# Will move to the next step
	} elsif ($method == 1) {
		warning "Cleaning the current wrong step and moving to the next in queue.\n";
		shift @{$self->{steps}};
	
	# Will try to end the conversation using a custom logic
	} elsif ($method == 2) {
		warning "Now openkore will try to auto-end this npc conversation.\n";
		$self->{trying_to_cancel} = 1;
		$self->cancelTalk;
	
	# Will relog to get out of the npc conversation
	} elsif ($method == 3) {
		warning "Now openkore will relog to try to end this conversation.\n";
		relog();
	}
}

sub conversation_end {
	my ($self) = @_;
	$self->delHooks;
	$self->setDone();
	debug "Task::TalkNPC::conversation_end called at ai npc_talk '".$ai_v{'npc_talk'}{'talk'}."'.\n", "ai_npcTalk";
	message TF("Done talking with %s.\n", $self->{target}), "ai_npcTalk";
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

#only for testing
my $default_text = "eye lol";
my $default_number = 1234;

sub cancelTalk {
	my ($self) = @_;
	
	if (defined $self->{error_message}) {
		debug "Trying to auto close the conversation due to error.\n", 'ai_npcTalk';
	}
	
	if ($ai_v{'npc_talk'}{'talk'} eq 'select') {
		$messageSender->sendTalkResponse($self->{ID}, 255);
		$self->{sent_talk_response_cancel} = 1;
		
	} elsif ($ai_v{'npc_talk'}{'talk'} eq 'next') {
		$messageSender->sendTalkContinue($talk{ID});
		
	} elsif ($ai_v{'npc_talk'}{'talk'} eq 'number') {
		$messageSender->sendTalkNumber($talk{ID}, $default_number);
		
	} elsif ($ai_v{'npc_talk'}{'talk'} eq 'text') {
		$messageSender->sendTalkText($talk{ID}, $default_text);
		
	} elsif ( $ai_v{'npc_talk'}{'talk'} eq 'buy_or_sell' ) {
		$self->conversation_end;
		$ai_v{'npc_talk'}{'talk'} = 'close';
	} elsif ( $ai_v{'npc_talk'}{'talk'} eq 'cash' ) {
		$self->conversation_end;
		$ai_v{'npc_talk'}{'talk'} = 'close';
	
	} elsif ( $ai_v{'npc_talk'}{'talk'} eq 'store' ) {
		$self->conversation_end;
		$ai_v{'npc_talk'}{'talk'} = 'close';
		
	} elsif ( $ai_v{'npc_talk'}{'talk'} eq 'sell' ) {
		$self->conversation_end;
		$ai_v{'npc_talk'}{'talk'} = 'close';
		
	} elsif (!$ai_v{'npc_talk'}{'talk'}) {
		$self->conversation_end;
		$ai_v{'npc_talk'}{'talk'} = 'close';
		
	}
	
}

# Actor findTarget(ActorList actorList)
#
# Check whether the target as specified in $self->{x} and $self->{y} is in the given
# actor list. Or if the target as specified in $self->{nameID} is in the given actor list.
# Returns the actor object if it's currently on screen and has a name, undef otherwise.
#
# Note: we require that the NPC's name is known, because otherwise talking
# may fail (TODO: what's the case exactly?).
sub findTarget {
	my ($self, $actorList) = @_;
	if ($self->{nameID}) {
		my ($actor) = grep { $self->{nameID} eq $_->{nameID} } @{$actorList->getItems};
		if ( $actor && 
		( $actor->{statuses}->{EFFECTSTATE_BURROW} || ($config{avoidHiddenActors} && ($actor->{type} == 111 || $actor->{type} == 139 || $actor->{type} == 2337)) ) && # HIDDEN_ACTOR TYPES
		$self->{type} ne 'autotalk' )
		{
			$self->setError(NPC_NOT_FOUND, T("Talk with a hidden NPC prevented."));
			return;
		}
		return $actor;
	}
	foreach my $actor (@{$actorList->getItems()}) {
		my $pos = ($actor->isa('Actor::NPC')) ? $actor->{pos} : $actor->{pos_to};
		next if ($actor->{statuses}->{EFFECTSTATE_BURROW});
		next if ($config{avoidHiddenActors} && ($actor->{type} == 111 || $actor->{type} == 139 || $actor->{type} == 2337)); # HIDDEN_ACTOR TYPES
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

sub noMoreSteps {
	my ($self) = @_;
	return (@{$self->{steps}} ? 0 : 1);
}

sub waitingForSteps {
	my ($self) = @_;
	return 0 unless ($self->{stage} == TALKING_TO_NPC);
	return 0 unless ($self->noMoreSteps);
	return 0 if ($ai_v{'npc_talk'}{'talk'} eq 'next' && $config{autoTalkCont});
	my $ai_npc_talk_wait_to_answer = $timeout{'ai_npc_talk_wait_to_answer'}{'timeout'} ? $timeout{'ai_npc_talk_wait_to_answer'}{'timeout'} : 1.5;
	return 0 unless (timeOut($ai_v{'npc_talk'}{'time'}, $ai_npc_talk_wait_to_answer));
	return 1;
}

sub addSteps {
	my ($self, $steps) = @_;
	my @new_steps = parseArgs($steps);
	
	debug "Task::TalkNPC::addSteps has been called with value '".$steps."'.\n", "ai_npcTalk";
	
	foreach my $step (@new_steps) {
		return 0 unless $self->validateStep($step);
	}
	push(@{$self->{steps}}, @new_steps);
	return 1;
}

sub validateStep {
	my ($self, $step) = @_;
	return 1 if ($step =~ /^(?:c|w\d+|n|t=.+|d\d+|a=.+|r(?:\d+|=.+|~\/.*?\/i?)|x|s|b|e|b\d+,\d+)$/);
	$self->{error_code} = WRONG_SYNTAX_IN_STEPS;
	$self->{error_message} = TF("Invalid NPC conversation code: %s.", $step);
	return 0;
}

1;
