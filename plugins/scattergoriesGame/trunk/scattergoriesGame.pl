# Plugin to play Scattergories at Ragnarok
# by KeplerBR - Translated by Triper
#
# Topic:
#  [EN]		http://forums.openkore.com/viewtopic.php?f=34&t=27892
#  [PT-BR]	http://forums.openkore-brasil.com/index.php?/topic/21-adedonha/
  
package adedonha;
    use strict;
    use warnings;
    use Plugins;
    use Globals;
    use Skill;
    use Misc qw(look center);
    use Log qw(message);
    use Commands;
    use DBI;
      
    # Register Plugin and Hooks
    Plugins::register("scattergories", "Scattergories at Ragnarok!", \&on_unload);
        my $hooks = Plugins::addHooks(
            ['start3', \&start],
            ['packet/received_sync', \&inform],
            ['packet_privMsg', \&informPM],
            ['packet/map_loaded', \&startGame],
            #['packet_pubMsg', \&analyzeResponse],
        );
   
    my $commandAdedonha = Commands::register(
        ["inform", "Shows the ranking table and info about the current Scattergories game", \&commandInform]
    );
   
my $currentLetter;
my $inform = 0;
my $alert = 0;
my $gameType = 0;
my @listGameType = ('ITEM', 'SKILL', 'MONSTER');
my (@recentLetters, @monsterList, @skillList, %scoreboard, %listItens, %recentAnswers, %nickListTime, %alphabet);
  
# Database info
my $hostname= "127.0.0.1";
my $port = 3306;
my $user = "ragnarok";
my $password = "ragnarok";
my $database = "ragna4fun";
my $dsn = "DBI:mysql:database=$database;host=$hostname;port=$port;mysql_enable_utf8=1";
my $dbh = DBI->connect($dsn, $user, $password); # Connect to the database
my $datadir = $Plugins::current_plugin_folder;
  
    ################################
    #On Unload code
    sub on_unload {
        Plugins::delHooks($hooks);
        Commands::unregister($commandAdedonha);
    }
   
    ################################
    # Loading words and scoreboard
    sub start {
        # Loading words
        for (keys %items_lut) {
            $items_lut{$_} = lc($items_lut{$_});
        }
        %listItens = reverse %items_lut;
  
        open my $fileListMonster,"<" . $datadir . '\listMonster.txt' or die $!;
            while (<$fileListMonster>) {
                my $line = $_;
                $line =~ s/\R//g;
                push (@monsterList, lc($line));
            }
        close $fileListMonster;
  
        open my $fileListSkill,"<" . $datadir . '\listSkill.txt' or die $!;
            while (<$fileListSkill>) {
                my $line = $_;
                $line =~ s/\R//g;
                push (@skillList, lc($line));
            }
        close $fileListSkill;
  
        # Listing alphabet
        if ($config{alphabet}) {
            %alphabet = (
                0  => 'a',   1  => 'b',   2  => 'c',   3  => 'd',   4  => 'e',   5  => 'f',   6  => 'g',   7  => 'h', 8  => 'i',
                9  => 'j',   10 => 'l',   11 => 'm',   12 => 'n',   13 => 'o',   14 => 'p',   15 => 'q',   16 => 'r', 17 => 's',
                18 => 't',   19 => 'u',   20 => 'v',   21 => 'z',
            );
        } else {
            %alphabet = (
                0  => 'a',   1  => 'b',   2  => 'c',   3  => 'd',   4  => 'e',   5  => 'f',   6  => 'g',   7  => 'h', 8  => 'i',
                9  => 'j',   10 => 'k',   11 => 'l',   12 => 'm',   13 => 'n',   14 => 'o',   15 => 'p',   16 => 'q', 17 => 'r',
                18 => 's',   19 => 't',   20 => 'u',   21 => 'v',   22 => 'x',   23 => 'w',   24 => 'y',   25 => 'z',
            );
        }       
          
        # Loading scoreboard
        my $sth = $dbh->prepare("SELECT * FROM $config{table}");
        $sth->execute();
        while (my $ref = $sth->fetchrow_hashref()) {
            $scoreboard{$ref->{nick}} = $ref->{points};
        }
        $sth->finish();
    }
   
    ################################
    # Starts a new round
    sub startGame {
        look(3, 2);
         
        # Anti-bug
        return if ($currentLetter);
          
        randLetter:
        # Get letter
        my $alphabetCount = scalar keys %alphabet;
        my $chooseLetter = int(rand($alphabetCount));
        $currentLetter = $alphabet{$chooseLetter};
   
        # Evade the use of a letter previously used
        if ($currentLetter ~~ @recentLetters) {
            goto randLetter;
        } else {
            @recentLetters = () if (scalar @recentLetters == $alphabetCount - 1);
            push (@recentLetters, $currentLetter);
              
            # Selects the type of the game
            $gameType++;
            $gameType = 0 if ($gameType >= scalar @listGameType);
            $recentAnswers{$gameType}{$currentLetter} = '' if (!exists $recentAnswers{$gameType}{$currentLetter});
   
            # Add hook
            $hooks = Plugins::addHooks(
                ['packet_pubMsg', \&analyzeResponse],
            );
                      
            # Informar
            Commands::run("c Current Scattergories' letter: '" . uc($currentLetter) . "' ! Send PM to check the ranks and how to play!");
            Commands::run("c Type one " . $listGameType[$gameType] . " of Ragnarok that starts with the letter '" . uc($currentLetter) . "' !");
            Commands::run("e heh") if $config{sendEmoticon};
        }
    }
   
    ################################
    # Checks if the typed phrase matchs the Scattergory
    sub analyzeResponse {
        my $hookname = shift;
        my $args = shift;
   
        # Verificar se resposta esta certa
        my $nickPlayer = $args->{pubMsgUser};
        my $chatMessage = lc($args->{Msg});
        my $initialLetter = substr($chatMessage, 0, 1);
   
        if ($chatMessage eq "game") {
            Commands::run("c Type one " . $listGameType[$gameType] . " that starts with the letter " . uc($currentLetter) . "!");
            $inform = 0;
            return;
        }
          
        my $currentAnalysis = $currentLetter;
        $currentAnalysis = "/?|?|?|?|a|/i" if ($currentLetter eq 'a');  $currentAnalysis = "/?|?|?|e|/i" if ($currentLetter eq 'e');
        $currentAnalysis = "/?|?|?|i|/i" if ($currentLetter eq 'i');    $currentAnalysis = "/?|?|?|?|o|/i" if ($currentLetter eq 'o');
        $currentAnalysis = "/?|?|?|u|/i" if ($currentLetter eq 'u');
        if ($initialLetter =~ $currentAnalysis) {
            if (($listGameType[$gameType] eq "ITEM" && exists $listItens{$chatMessage}) ||
                ($listGameType[$gameType] eq "SKILL" &&  $chatMessage ~~ @skillList) ||
                ($listGameType[$gameType] eq "MONSTER" && $chatMessage ~~ @monsterList)) {
                if ($recentAnswers{$gameType}{$currentLetter} ne $chatMessage) {
                    # Acertou
                    &saveScores($nickPlayer, 2);
                                         
                    Commands::run("c Congratulations, $nickPlayer! You got it right! You now have $scoreboard{$nickPlayer} points!");
                    Commands::run("e e11") if $config{sendEmoticon};
                    $recentAnswers{$gameType}{$currentLetter} = $chatMessage;
   
                    # Starts a new round
                    undef $currentLetter;
                    Plugins::delHook('packet_pubMsg', $hooks);
                    unless ($taskManager->countTasksByName('pluginAdedonhaRecome?ar')) {
                        $taskManager->add(Task::Timeout->new(
                        name => 'pluginAdedonhaRecome?ar',
                        inGame => 1,
                        function => sub {&startGame;},
                        seconds => 4,
                        ));
                    }
                } else {
                    # Repeated answer
                    Commands::run("c '$chatMessage' was already used! You can't type the same word twice!");
                    Commands::run("e ??") if $config{sendEmoticon};
                }
            } else {
                # Repeated word
                exists $scoreboard{$nickPlayer} ?
                    Commands::run("c $nickPlayer, '$chatMessage' isn't a valid $listGameType[$gameType]! (You've $scoreboard{$nickPlayer} points)") :
                    Commands::run("c $nickPlayer, '$chatMessage' isnt' a valid $listGameType[$gameType]!");
                Commands::run("e ??") if $config{sendEmoticon};
            }
            $inform = 0;
        } else {
            # Wrong initial letter
            $alert++;
            if ($alert == 3) { # Evades flood
                Commands::run("c The $listGameType[$gameType] should start with the letter '" . uc($currentLetter) . "'!");
                Commands::run("e !") if $config{sendEmoticon};
                $alert = 0;
                $inform = 0;
            }
        }
    }
  
    ################################
    # Misc: Saving points of players
    sub saveScores {
        my ($nickPlayer, $pointsEarned) = @_;
  
        if (exists $scoreboard{$nickPlayer}) {
            # Atualizar placar
            $scoreboard{$nickPlayer} += $pointsEarned;
              
            my $sth = $dbh->prepare("UPDATE $config{table} SET points = ? WHERE nick = ?") 
                or die "Couldn't prepare statement";
            $sth->execute($scoreboard{$nickPlayer}, $nickPlayer)
                or die "Couldn't execute the query";
            $sth->finish;
        } else {
            # Adicionar player
            $scoreboard{$nickPlayer} = $pointsEarned;
              
            my $sth = $dbh->prepare("INSERT into $config{table}(nick, points) values(?,?)")
                or die "Couldn't prepare statement";
            $sth->execute($nickPlayer, $scoreboard{$nickPlayer})
                or die "Couldn't execute the query";
            $sth->finish;
        }
    }
      
    ################################
    # Informing that there is a round ongoing
    sub inform {
        $inform++;
        if ($inform == 3) { # Evitar flood
            Commands::run("c Play Scattergories at Ragnarok! Send me a PM for more information!");
            Commands::run("c Type, in the public chat, one " . $listGameType[$gameType] . " of Ragnarok that starts by '" . uc($currentLetter) . "'!");
            $inform = 0;
            }
    }
      
    ################################
    # When you get a PM, you will get some info
    sub informPM {
        my $hookname = shift;
        my $args = shift;
        my $nick = $args->{privMsgUser};
        my $message = $args->{privMsg};
          
        # Anti-Spam
        if ((time - $nickListTime{$nick}) < 10) {
            Commands::run("pm \"$nick\" Sorry, you sent a PM not so long ago! Try again in 10 seconds!");
            return;
        }
        $nickListTime{$nick} = time;
  
        # Checking PM
        if ($message =~ /full ranking/i) {
            my $i = 0;
            for ( sort {$scoreboard{$b} <=> $scoreboard{$a}} keys %scoreboard) {
                $i++;
                last if (!$_);
                Commands::run("pm \"$nick\" * $i? - $_ - $scoreboard{$_} points");
                last if ($i == 100);
            }
        } elsif ($message =~ /comment:/i) {
            # Anti-flood
            my $sth = $dbh->prepare("SELECT * FROM scattergories_comment WHERE nick = ?")
                or die "Couldn't prepare statement";
            $sth->execute($nick)
                or die "Couldn't execute the query";
            $sth->finish;
              
            if ($sth->rows < 2) {
                $message =~ s/comment://i;
                my $sth = $dbh->prepare("INSERT into scattergories_comment(server, nick, comment) value(?,?,?)")
                    or die "Couldn't prepare statement";
                $sth->execute($config{master}, $nick, $message)
                    or die "Couldn't execute the query";
                $sth->finish;
                  
                Commands::run("pm \"$nick\" Thank you, $nick! Your comment was registed! I will read it later.");
            } else {
                Commands::run("pm \"$nick\" Sorry, $nick, but you can't sent more then 2 comments by char ...");
            }
        } elsif ($scoreboard{$message}) {
            my $i = 0;
            for (sort {$scoreboard{$b} <=> $scoreboard{$a}} keys %scoreboard) {
                $i++;
                last if ($_ eq $message);
            }
            Commands::run("pm \"$nick\" $message you've $scoreboard{$message} points and you're at $iº place!");
        } else {
            Commands::run("pm \"$nick\" To join Scattergories, send a PUBLIC MESSAGE (NOT by PM, by PUBLIC CHAT) with a word!");
            Commands::run("pm \"$nick\" It can be a skill, item or monster! Current category is " . $listGameType[$gameType] . " and starts with '" . uc($currentLetter) . "'!");
            Commands::run("pm \"$nick\" -------------------");
            Commands::run("pm \"$nick\" Tip: Send, through public chat (NOT by PM):");
            Commands::run("pm \"$nick\" * 'game' -> to display the first letter of which is to say");
            Commands::run("pm \"$nick\" -------------------");
            Commands::run("pm \"$nick\" Scoreboard of the top 15 players:");
  
            my $i = 0;
            for ( sort {$scoreboard{$b} <=> $scoreboard{$a}} keys %scoreboard) {
                $i++;
                last if (!$_);
                Commands::run("pm \"$nick\" * $i? - $_ - $scoreboard{$_} pontos");
                last if ($i == 15);
            }
              
            Commands::run("pm \"$nick\" Total of Players: " . scalar (keys %scoreboard));
            Commands::run("pm \"$nick\" -------------------");
            Commands::run("pm \"$nick\" If you want to send me a comment, send me a PM with the text and 'Comment:'");
            Commands::run("pm \"$nick\" Exemple: 'Comment: This game rocks =)'");
            Commands::run("pm \"$nick\" -------------------");
            Commands::run("pm \"$nick\" To visualize the points of a specific player, send, through PM, his nick");
            Commands::run("pm \"$nick\" To check the top 100 players, send, through PM, 'Full Ranking'!");
        }
    }
   
    ################################
    # Functions of the command "inform"
    sub commandInform {
        my $message;
  
        $message = center('Current Ranking Board', 50, '-') . "\n";
          
        my $i = 0;
        for ( sort {$scoreboard{$b} <=> $scoreboard{$a}} keys %scoreboard) {
            $i++;
            $message .= "* $i? - $_ - $scoreboard{$_} pontos\n";
            last if ($i == 50);
        }
  
        $message .= "Total: " . scalar (keys %scoreboard) . "\n";
  
        $message .= center('Scattergories Information', 50, '-') . "\n";
   
        $message .= "Recent used words:\n";
        for (my $i = 0; $i < scalar @listGameType; $i++) {
            $message .= center($listGameType[$i], 10, '-') . "\n";
            my $size = $recentAnswers{$i};
            for (my $i2 = 0; $i2 < scalar (keys %alphabet); $i2++) {
                next if (!$recentAnswers{$i}{$alphabet{$i2}});
                $message .= "* $alphabet{$i2} - $recentAnswers{$i}{$alphabet{$i2}}\n";
            }
        }
  
        $message .= "Current game: " . $currentLetter . " - " . $listGameType[$gameType] . "\n";
   
        message $message, "list";
    }
1;