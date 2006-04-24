package kadiliman;

#
# This plugin is licensed under the GNU GPL
# Copyright 2005 by kaliwanagan
# --------------------------------------------------
#
# How to install this thing..:
#
# in control\config.txt add:
#  
#chatBot Kadiliman {
#	scriptfile lines.txt
#	replyRate 80
#	onPublicChat 1
#	onPrivateMessage 1
#	onSystemChat 1
#	onGuildChat 1
#	onPartyChat 1
#	wpm 65
#	smileys ^_^, :D, :), >:(, XD
#	smileyRate 20
#	learn 1
#}

use strict;
use Plugins;
use Globals;
use Log qw(message warning error);
use Misc;
use Network;
use Network::Send;
use FindBin qw($RealBin);
use lib "$RealBin/plugins/kadiliman";
use Chatbot::Kadiliman;

Plugins::register('kadiliman', 'autoresponse bot', \&Unload, \&Reload);
my $hooks = Plugins::addHooks(
	['packet/public_chat', \&onMessage, undef],
	['packet/private_message', \&onMessage, undef],
	['packet/system_chat', \&onMessage, undef],
	['packet/guild_chat', \&onMessage, undef],
	['packet/party_chat', \&onMessage, undef],
	['start3', \&start3, undef],
	['AI_post', \&AI_post, undef]
);

my $prefix = "chatBot_";
my %bot;
message "Initializing chatBot\n", "plugins";
for (my $i = 0; (exists $config{$prefix.$i}); $i++) {
	$bot{$i} = new Chatbot::Kadiliman {
	};
}

sub Unload {
	Plugins::delHooks($hooks);
}

sub Reload {
	for (my $i = 0; (exists $config{$prefix.$i}); $i++) {
		message "Plugin Kadiliman: checking for duplicate lines in ". $config{$prefix.$i."_scriptfile"} ."...", "plugins";
		checkForDupes($config{$prefix.$i."_scriptfile"});
		message "done.\n", "plugins";
		$bot{$i} = new Chatbot::Kadiliman {
			name		=> $config{$prefix.$i},
			scriptfile	=> $config{$prefix.$i."_scriptfile"},
			learn		=> $config{$prefix.$i."_learn"},
			reply		=> 1,
		};
	}
}

sub onMessage {
	my ($packet, $args) = @_;
	my $prefix = "chatBot_";
	for (my $i = 0; (exists $config{$prefix.$i}); $i++) {
		return if (($args->{privMsgUser} || $args->{chatMsgUser}) eq $char->{name});

		$bot{$i}->{reply} = ($config{$prefix.$i."_replyRate"}) ? 1 : 0;
		$config{$prefix.$i."_replyRate"} = 80 if (!exists $config{$prefix.$i."_replyRate"});
		$config{$prefix.$i."_replyRate"} = 100 if ($config{$prefix.$i."_replyRate"} > 100);

		my $type;
		my $reply;
		if ($packet eq 'packet/public_chat' && $config{$prefix.$i."_onPublicChat"}) {
			$reply = $bot{$i}->transform($args->{chatMsg});
			$type = "c";
		} elsif ($packet eq 'packet/system_chat' && $config{$prefix.$i."_onSystemChat"}) {
			my $msg = $args->{message};
			my ($chatMsgUser, $chatMsg);
			if ($msg =~/:/) {
				($chatMsgUser, $chatMsg) = $msg =~ /(.*?).:.(.*)/;
			} else {
				$chatMsg = $msg;
			}
			$reply = $bot{$i}->transform($chatMsg);
			$type = "c";
		} elsif ($packet eq 'packet/guild_chat' && $config{$prefix.$i."_onGuildChat"}) {
			$reply = $bot{$i}->transform($args->{chatMsg});
			$type = "g";
		} elsif ($packet eq 'packet/party_chat' && $config{$prefix.$i."_onPartyChat"}) {
			$reply = $bot{$i}->transform($args->{chatMsg});
			$type = "p";
		} elsif ($packet eq 'packet/private_message' && $config{$prefix.$i."_onPrivateMessage"}) {
			$reply = $bot{$i}->transform($args->{privMsg});
			$type = "pm";
		}

		# exit if the config option is not enabled
		return if (!$type);

		# exit if we don't have any reply
		return if (!$reply);
		
		# add a smiley at the end of the reply
		my @smileys = split /\,+/, $config{$prefix.$i."_smileys"};
		$reply .= $smileys[rand(@smileys)] if ((rand(100) < ($config{$prefix.$i."_smileyRate"})));
	
		## COPIED FROM processChatResponse, ChatQueue.pm
		# Calculate a small delay (to simulate typing)
		# The average typing speed is 65 words per minute.
		# The average length of a word used by RO players is 4.25 characters (yes I measured it).
		# So the average user types 65 * 4.25 = 276.25 charcters per minute, or
		# 276.25 / 60 = 4.6042 characters per second
		# We also add a random delay of 0.5-1.5 seconds.
		$args->{wpm} = $config{$prefix.$i."_wpm"} || 65;
		my @words = split /\s+/, $reply;
		my $average;
		foreach my $word (@words) {
			$average += length($word);
		}
		$average /= (scalar @words);
		my $typeSpeed = $args->{wpm} * $average / 60;
	
		$args->{timeout} = (0.5 + rand(1)) + (length($reply) / $typeSpeed);
		$args->{time} = time;
		$args->{stage} = "start";
		$args->{reply} = $reply;
		$args->{prefix} = $prefix.$i;
		$args->{type} = $type;
		my $rand = rand(100);
		message "$rand : " . $config{$prefix.$i."_replyRate"} . "\n";
		AI::queue("chatBot", $args)
			if ((AI::action ne 'chatBot')
				&& ($rand < ($config{$prefix.$i."_replyRate"}))
				&& ($bot{$i}->{reply})
				&& (main::checkSelfCondition($prefix))
			);
	}
}

sub start3 {
	for (my $i = 0; (exists $config{$prefix.$i}); $i++) {
		#message "Plugin Kadiliman: checking for duplicate lines in ". $config{$prefix.$i."_scriptfile"} ."...", "plugins";
		#checkForDupes($config{$prefix.$i."_scriptfile"});
		message "done.\n", "plugins";
		$bot{$i} = new Chatbot::Kadiliman {
			name		=> $config{$prefix.$i},
			scriptfile	=> $config{$prefix.$i."_scriptfile"},
			learn		=> $config{$prefix.$i."_learn"},
			reply		=> 1,
		};
	}
}

sub AI_post {
	if (AI::action eq 'chatBot') {
		my $args = AI::args;
		if ($args->{stage} eq 'end') {
			AI::dequeue;
		} elsif ($args->{stage} eq 'start') {
			$args->{stage} = 'message' if (main::timeOut($args->{time}, $args->{timeout}));
		} elsif ($args->{stage} eq 'message') {
			sendMessage($net, $args->{type}, $args->{reply}, $args->{privMsgUser});
			message "chatBot: $args->{reply}\n", "plugins";
			$args->{stage} = 'end';
		}
	}
}


sub checkForDupes {
	my $scriptfile = shift;
	my %self;

	$scriptfile = "lines.txt" if ($scriptfile eq 1);

	# read scriptfile in (the whole thing, all at once). 
	my @scriptlines;
	if (open (SCRIPTFILE, "<$scriptfile")) {
		@scriptlines = <SCRIPTFILE>; # read in script data 
		close (SCRIPTFILE);
	}

	# check for duplicate lines
	for (my $i = 0; $i < (scalar @scriptlines); $i++) {
		for (my $j = $i + 1; $j < (scalar @scriptlines); $j++) {
			$scriptlines[$i] = '' if ($scriptlines[$i] eq $scriptlines[$j]);
		}
	}

	# save cleaned-up file
	open (SCRIPTFILE, ">$scriptfile");
	foreach my $line (@scriptlines) {
		print SCRIPTFILE ("$line");
	}
	close (SCRIPTFILE);
}

return 1;
