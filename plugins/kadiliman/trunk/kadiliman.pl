    package kadiliman;

    #
    # This plugin is licensed under the GNU GPL
    # Copyright 2005 by kaliwanagan, now know as Kali
    # Ported by Thrice aka Noface
    # Adds by Mucilon
    # Version 1.3 - 03/04/2008
    # --------------------------------------------------
    #
    # How to install this thing..:
    #
    # in control\config.txt add:
    #
    #chatBot Kadiliman {
    #   inLockOnly 1      # (0|1) Just answer to public chat at lockmap, pm will be answered normally
    #       scriptfile lines.txt   # Name of the file where all sentences are storage, it will be create at openkore root directory
    #       replyRate 80      # (0..100) Rate to answer, 80 means: answer 80% of chats and don't answer 20%
    #       onPublicChat 1      # (0|1) Enable to answer any plublic chat
    #       onPrivateMessage 1   # (0|1) Enable to answer any private message
    #       onSystemChat 1      # (0|1) Enable to answer any system message
    #       onGuildChat 1      # (0|1) Enable to answer any guild chat
    #       onPartyChat 1      # (0|1) Enable to answer any party chat
    #       wpm 65         # Don't need to change - words per minute, simulate typing speed
    #       smileys ^_^,xD,^^,:),XD   # Smileys that may end your sentences on chat (separeted by commas)
    #       smileyRate 20      # Rate to add smiley to the sentences, means: add smileys to 20% of messages
    #       learn 1         # This plugin can "learn" every sentence read by the bot, this sentences are storage at the scriptfile
    #   noPlayers , ,      # Name of the players (supported by regexp) you don't want to answer any thing, like party members (separeted by commas)
    #   noWords  , , ,       # Words (supported by regexp) at the chats you don't want to answer, like "bot", "heal", "buffs" or something like this (separeted by commas)
    #   timesToBlockPM 10   # Number of times of pms received by each player to ignore him, work just to pm
    #   timeToResetCount 300   # Number of seconds to reset the count to ignore any player
    #}

    #This new add will ignore any player that send 10 or more pms to you in 300 seconds. But if he send 9 pms to you and the
    # count is reseted, he will need to send more 10 pms inside the 300 seconds to the plugin ignore him.
    #You can change this 2 last values as you like.

    use strict;
    use Plugins;
    use Globals;
    use Log qw(message warning error debug);
    use Misc;
    use Network;
    use Network::Send;
    use Network::Receive;
    use Chatbot::Kadiliman;
    use I18N qw(bytesToString);
    #use Utils;


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
    my %chatcountPrivate;
    my %chatcountPublic;
    my %Timecount;

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
                    message "[Kadiliman] done.\n", "plugins";
                    $bot{$i} = new Chatbot::Kadiliman {
                            name        => $config{$prefix.$i},
                            scriptfile      => $config{$prefix.$i."_scriptfile"},
                            learn      => $config{$prefix.$i."_learn"},
                            reply      => 1,
                    };
            }
    }

    sub onMessage {
            my ($packet, $args) = @_;
            my $prefix = "chatBot_";

            for (my $i = 0; (exists $config{$prefix.$i}); $i++) {
          #Don't answer, case it is the own message
          my $msg = $args->{message};
                    my ($chatMsgUser, $chatMsg);
                
          if ($msg =~/:/) {
                            ($chatMsgUser, $chatMsg) = $msg =~ /(.*?).:.(.*)/;
                    } else {
                            $chatMsg = $msg;
                    }
                    return if ($chatMsgUser eq $char->{name});
                
          #Don't answer the player, if he is at _noPlayers from config file
          my @noplayers = split /\s*\,+\s*/, $config{$prefix.$i."_noPlayers"};
          foreach my $player (@noplayers) {
                if ((match($player,$chatMsgUser)) || (match($player,$args->{privMsgUser}))){
                   message "[Kadiliman] Don't answering player $player\n", "plugins";
                   return 1;
                }
          }
          
          #Message Count         
          if ($packet eq 'packet/public_chat') {
                $chatcountPublic{$i}{$chatMsgUser}++;
                message "[Kadiliman] Player $chatMsgUser has spoken on public chat $chatcountPublic{$i}{$chatMsgUser} time(s)\n", "plugins";
                    } elsif ($packet eq 'packet/private_message') {
                my $pmuser = $args->{privMsgUser};
                $chatcountPrivate{$i}{$pmuser}++;
                message "[Kadiliman] Player $pmuser has spoken on PM $chatcountPrivate{$i}{$pmuser} time(s)\n", "plugins";
                if (($chatcountPrivate{$i}{$pmuser} >= $config{$prefix.$i."_timesToBlockPM"}) && ($config{$prefix.$i."_timesToBlockPM"} > 0)) {
                      Commands::cmdIgnore "ignore","1 $pmuser";
                }
                    }
          
          #Don't answer the player, if some word of the message is at _noWords from config file
          my @nowords = split /\s*\,+\s*/, $config{$prefix.$i."_noWords"};
          foreach my $word (@nowords) {
                if (match($word,$chatMsg)){
                   message "[Kadiliman] Don't answering message with word: $word\n", "plugins";
                   return 1;
                }
          }
                
                    $bot{$i}->{reply} = ($config{$prefix.$i."_replyRate"}) ? 1 : 0;
                    $config{$prefix.$i."_replyRate"} = 80 if (!exists $config{$prefix.$i."_replyRate"});
                    $config{$prefix.$i."_replyRate"} = 100 if ($config{$prefix.$i."_replyRate"} > 100);

                    my $type;
                    my $reply;

                    if ($packet eq 'packet/public_chat' && $config{$prefix.$i."_onPublicChat"}) {
             #return if bot isn't at lockmap
             return if (($config{$prefix.$i."_inLockOnly"} > 0) && ($field{name} ne $config{lockMap}));
             $reply = $bot{$i}->transform($chatMsg);
                            $type = "c";
                    } elsif ($packet eq 'packet/system_chat' && $config{$prefix.$i."_onSystemChat"}) {
             $reply = $bot{$i}->transform();
                            $type = "c";
                    } elsif ($packet eq 'packet/guild_chat' && $config{$prefix.$i."_onGuildChat"}) {
                            $reply = $bot{$i}->transform($chatMsg);
                            $type = "g";
                    } elsif ($packet eq 'packet/party_chat' && $config{$prefix.$i."_onPartyChat"}) {
                            $reply = $bot{$i}->transform($chatMsg);
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
                    debug "[Kadiliman] $rand: " . $config{$prefix.$i."_replyRate"} . "\n";
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
                    message "[Kadiliman] done.\n", "plugins";
                    $bot{$i} = new Chatbot::Kadiliman {
                            name        => $config{$prefix.$i},
                            scriptfile      => $config{$prefix.$i."_scriptfile"},
                            learn      => $config{$prefix.$i."_learn"},
                            reply      => 1,
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
                            sendMessage($messageSender, $args->{type}, $args->{reply}, $args->{privMsgUser});
                            debug "[Kadiliman] chatBot: $args->{reply}\n", "plugins";
                            $args->{stage} = 'end';
                    }
            }
          #Time to reset the message count (loopless code)
          for (my $i = 0; (exists $config{$prefix.$i}); $i++) {
                if ($Timecount{$i}{start} eq ''){
                      $Timecount{$i}{start} = time;
                      debug "[Kadiliman] start: $Timecount{$i}{start}\n", "plugins";
                }
                $Timecount{$i}{current} = time;

                $Timecount{$i}{toreset} = $config{$prefix.$i."_timeToResetCount"};
                if (($Timecount{$i}{toreset} ne '') || ($Timecount{$i}{toreset} > 0)) {
                      $Timecount{$i}{after} = $Timecount{$i}{start} + $Timecount{$i}{toreset};
                      if ($Timecount{$i}{current} >= $Timecount{$i}{after}){
                            #message "[Kadiliman] Reseted, start: $Timecount{$i}{start}, time now: $Timecount{$i}{current}, next: $Timecount{$i}{after}, time to count: $Timecount{$i}{toreset}\n", "plugins";
                            message "[Kadiliman] Chat count reseted, next in $Timecount{$i}{toreset} secs\n", "plugins";
                            $Timecount{$i}{start} = time;
                            delete $chatcountPublic{$i};
                            delete $chatcountPrivate{$i};
                      }
                }
          }
    }


    sub match
    {
            my ($pattern,$subject) = @_;
            if (my ($re, $ci) = $pattern =~ /^\/(.+?)\/(i?)$/)
            {       
                    if (($ci && $subject =~ /$re/i) || (!$ci && $subject =~ /$re/))
                    {
                            return 1;
                    }
            }
            elsif ($subject eq $pattern)
            {
                    return 1;
            }
            return 0;
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
