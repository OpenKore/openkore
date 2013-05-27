# Plugin to play Hangman at Ragnarok
# by KeplerBR - Translated by Triper
#
# Topic:
#  [EN]		http://forums.openkore.com/viewtopic.php?f=34&t=29111
#  [PT-BR]	http://forums.openkore-brasil.com/index.php?/topic/22-jogo-da-forca/

package forca;
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
	Plugins::register("forca", "Hangman at Ragnarok!", \&on_unload);
		my $hooks = Plugins::addHooks(
			['start3', \&start],
			['packet/received_sync', \&informPublic],
			['packet_privMsg', \&informPM],
			['packet/map_loaded', \&startGame],
			#['packet_pubMsg', \&analyzeResponse],
		);

	my $commandHangmanGame = Commands::register(
		["inform", "Shows the ranking table and info about the current Hangman Game", \&commandInform]
	);
 
# Global variables
my ($currentTip, $currentWord, @currentWordHidden, @lettersUsed, @wordListUsed);
my $type = 2;
my $inform = 0;
my $delayPlacar = 0;
my $datadir = $Plugins::current_plugin_folder;
my (%scoreboard, %listSkills, %listSkillsHandle, %listItems, %listMonster, %nickListTime);
my @alphabet = ('a' .. 'z', 'á', 'é', 'í', 'ó', 'ú', 'â', 'ê', 'î', 'ô', 'û', 'à', 'è', 'ì', 'ò', 'ù', 'ã', 'õ', 'ç');

# Database info
my $hostname= "127.0.0.1";
my $port = 3306;
my $user = "ragnarok";
my $password = "ragnarok";
my $database = "ragna4fun";
my $dsn = "DBI:mysql:database=$database;host=$hostname;port=$port;mysql_enable_utf8=1";
my $dbh = DBI->connect($dsn, $user, $password); # Connect to the database

	################################
	#On Unload code
	sub on_unload {
		Plugins::delHooks($hooks);
		Commands::unregister($commandHangmanGame);
	}

	################################
	# Load words and scoreboard
	sub start {
		# Load words
		%listSkills = reverse %Skill::StaticInfo::names;
		%listSkillsHandle = reverse %Skill::StaticInfo::handles;
	
		for (keys %items_lut) {
			$items_lut{$_} = lc($items_lut{$_});
		}
		%listItems = reverse %items_lut;
		
		open my $fileListMonster,"<" . $datadir . '\listMonsterSpecial.txt' or die $!;
		while (<$fileListMonster>) {
			my $line = $_;
			$line =~ s/\R//g;
			$line =~ /(.*)\t(\d*)\t(.*)\t(.*)\t(\d*)\t(\d*)\t(\d*)\t(\d*)/;
			$listMonster{$1}{name} = $1;	$listMonster{$1}{lvl} = $2;			 $listMonster{$1}{size} = $3;
			$listMonster{$1}{race} = $4;	$listMonster{$1}{drop1} = $5;   $listMonster{$1}{drop2} = $6;
			$listMonster{$1}{drop3} = $7;   $listMonster{$1}{drop4} = $8;
		}
		close $fileListMonster;
			
		# Load scoreboard
		my $sth = $dbh->prepare("SELECT * FROM $config{table}");
		$sth->execute();
		while (my $ref = $sth->fetchrow_hashref()) {
			$scoreboard{$ref->{nick}} = $ref->{points};
		}
		$sth->finish();
	}
	
	################################
	# Starts an Hangman round
	sub startGame {
		look(3, 2);
		
		# Anti-bug
		return 0 if ($currentWord);
		return 0 if ($taskManager->countTasksByName('pluginForcaRecomeçarPart2'));
	
		# Get a random word
		my $attempts = 0;
		chooseWord:
			$type++;
			$type = 0 if ($type > 2);
	
			if ($type == 2) {
				$currentWord = lc($items_lut{(keys %items_lut)[rand keys %items_lut]});
			} elsif ($type == 1) {
				$currentWord = lc($listSkills{(keys %listSkills)[rand keys %listSkills]});
			} else {
				$currentWord = $listMonster{(keys %listMonster)[rand keys %listMonster]}{name};
			}
			$attempts++;
			# If the loop was repeated a ton of times, it's probable that you've used all the possible words
			@wordListUsed = () if ($attempts > 100);
		goto chooseWord if ($currentWord ~~ @wordListUsed); # Repeated word
			push (@wordListUsed, $currentWord);
	
			# Generate secret word
			@currentWordHidden = ();
			for (my $i = 0; $i < length($currentWord); $i++) {
				my $key = substr($currentWord, $i, 1);
				if ($key ~~ @alphabet) {
					(substr($currentWord, $i + 1, 1) ~~ @alphabet) ?
						push (@currentWordHidden, '_ ') :
						push (@currentWordHidden, '_');
				} else {
					($key eq ' ') ?
						push (@currentWordHidden, '  ') :
						push (@currentWordHidden, $key);
				}
			}
			my $count = 0;
				for (my $i = 0; $i <= @currentWordHidden; $i++) {
					$count += length($currentWordHidden[$i]);
				}
		goto chooseWord if ($count + 60 > $config{message_length_max}); # Evade big words that can break the text into two
	
		# Generate tip
		$currentTip = '';
		if ($type == 2) {
			my $descItem = $itemsDesc_lut{$listItems{$currentWord}} || 0;
			if ($descItem) {
				message "-> $currentWord\n\n$descItem\n", "list";
				my @num = (0..5);
				while (!$currentTip) {
					my $typeTip = $num[(rand @num)];
					if ($typeTip == 0) {
						$descItem =~ /Tipo: (.+)/i;
						
						$currentTip = "Item of the type '$1'" if ($1);
					} elsif ($typeTip == 1) {
						$descItem =~ /Equipa em: (.+)/i;
						
						$currentTip = "Item that you equip at '$1'" if ($1);
					} elsif ($typeTip == 2) {
						$descItem =~ /Classes que utilizam: (.+?)\./;
						
						$currentTip = "Item that you can equipe '$1'"  if (length($1) < 70 && $1);
					} elsif ($typeTip == 3) {
						$descItem =~ /(.+?)\./i;
						
						$currentTip = $1 if ($1 && length($1) + length($currentWord) < $config{message_length_max} && !($1 =~ /$currentWord/i));
					} elsif ($typeTip == 4) {
						$descItem =~ /Nível da Arma: (.+?)/i;
						
						$currentTip = "Gear of the level '$1'" if ($1);
					} else {
						$descItem =~ /Nível necessário: (.+?)/i;
							
						$currentTip = "Gear that needs the following level to use: '$1'" if ($1);
					}
	
					# Deletes the value of $num that was used previously
					@num = grep($_ != $typeTip, @num);
					
					if (!@num) {
						$descItem =~ /Peso: (.+)/i;
							
						if ($1) {
							$currentTip = "Item with the weight '$1'" if ($1);
						} else {
							$currentTip = 'An item!'
						}
					}
				}
			} else {
				$currentTip = 'An item';
			}
		} elsif ($type == 1) {
			my $descSkill = $skillsDesc_lut{$listSkillsHandle{$Skill::StaticInfo::names{$currentWord}}} || 0;
			if ($descSkill) {
			message "-> $currentWord\n\n$descSkill\n", "list";
			my @num = (0..2);
				while (!$currentTip) {
					my $typeTip = $num[(rand @num)];
					if ($typeTip == 0) {
						$descSkill =~ /(?:Tipo|Forma de Habilidade)\s*:\s* (.+)/i;
						
						$currentTip = "Skill of the type '$1'" if ($1);
					} elsif ($typeTip == 1) {
						$descSkill =~ /Alvo\s*:\s* (.+)/i;
						
						$currentTip = "Skill that the target is '$1'" if ($1);
					} else {
						$descSkill =~ /(?:Resultado|Descrição|Content|Conteúdo)\s*:\s* (.+)(?:\.|)/i;
	
						$currentTip = $1 if ($1 && length($1) + length($currentWord) < $config{message_length_max});
					}
	
					# Deletes the value of $num that was used previously
					@num = grep($_ != $typeTip, @num);
	
					$currentTip = 'Uma habilidade!' if (!@num);
				}
			} else {
				$currentTip = 'A skill';
			}
		} else {
			message "->$currentWord\n\n$listMonster{$currentWord}{lvl} $listMonster{$currentWord}{size} $listMonster{$currentWord}{race}\n", "list";
			my $typeTip = int(rand(4)) - 1;
			
			if ($typeTip == 3) {
				$currentTip = "Monster of the level '$listMonster{$currentWord}{lvl}'";
			} elsif ($typeTip == 2) {
				$currentTip = "Monster of the size '$listMonster{$currentWord}{size}'";
			} elsif ($typeTip == 1) {
				$currentTip = "Monster of the race '$listMonster{$currentWord}{race}'";
			} else {
				my $randDrop = 0;
				$randDrop++ if ($items_lut{$listMonster{$currentWord}{drop1}});
				$randDrop++ if ($items_lut{$listMonster{$currentWord}{drop2}});
				$randDrop++ if ($items_lut{$listMonster{$currentWord}{drop3}});
				$randDrop++ if ($items_lut{$listMonster{$currentWord}{drop4}});
				
				$randDrop = int(rand($randDrop));
				
				if ($randDrop == 1) {
					$currentTip = "Monster that drops '" . $items_lut{$listMonster{$currentWord}{drop1}} . "'";
				} elsif ($randDrop == 2) {
					$currentTip = "Monster that drops '" . $items_lut{$listMonster{$currentWord}{drop2}} . "'";
				} elsif ($randDrop == 3) {
					$currentTip = "Monster that drops '" . $items_lut{$listMonster{$currentWord}{drop3}} . "'";
				} elsif ($randDrop == 4) {
					$currentTip = "Monster that drops '" . $items_lut{$listMonster{$currentWord}{drop4}} . "'";
				} else {
					$currentTip = "Monster of the level '$listMonster{$currentWord}{lvl}'";
				}
			}
		}
		
		# Sending messages informing
		Commands::run("c Tip: $currentTip!");
		Commands::run("e heh") if $config{sendEmoticon};
		$taskManager->add(Task::Timeout->new(
			name => 'pluginForcaRecomeçarPart2',
			inGame => 1,
			function => sub {
				Commands::run("c Current word: @currentWordHidden");
				@lettersUsed = ();
				$hooks = Plugins::addHooks(
					['packet_pubMsg', \&analyzeResponse],
				);
			},
			seconds => 2,
		));
		$inform = 0;
	}
	
	################################
	# Check public message
	sub analyzeResponse {
		my $hookname = shift;
		my $args = shift;
	
		return 0 if (!$currentWord);
		
		# Collecting variables ...
		my $nickPlayer = $args->{pubMsgUser};
		my $chatMessage = lc($args->{Msg});
		my $initialLetter = substr($chatMessage, 0, 1);
	
		return 0 if !($initialLetter ~~ @alphabet);
	
		# Key-words of commands
		if ($chatMessage eq "tip") {
			Commands::run("c Tip: $currentTip!");
			return 0;
		} elsif ($chatMessage eq "word") {
			Commands::run("c Word: @currentWordHidden");
			return 0;
		}
	
		# Checking answers
		if (length($chatMessage) != 1 &&
			((length($chatMessage) + 2) < length($currentWord)) ||
			(length($currentWord) < (length($chatMessage) - 2))) {
			# Ignoring words with a size abnormaly different from the secret word
	
			return 0;
		} elsif (length($chatMessage) > 1 && $chatMessage ne $currentWord) {
			# Guessed the word wrong
	
			if (26 + length($chatMessage) + length($currentTip) >= $config{message_length_max}) {
				Commands::run("c The word isn't '$chatMessage'!");
			} else {
				Commands::run("c The word isn't '$chatMessage'! Tip: $currentTip");
			}
			Commands::run("e ??") if $config{sendEmoticon};
			return 0;
		} elsif ($chatMessage eq $currentWord) {
			# Guessed the full word
			
			# Calculate points and store them
			my $hiddenLetters = 0;
			for (@currentWordHidden) {
				$hiddenLetters++ if ($_ eq '_ ' || $_ eq '_');
			}
			
			my $pointsEarned = 5 + int($hiddenLetters/2);
			&saveScores($nickPlayer, $pointsEarned);
			
			# Informing
			Commands::run("c $nickPlayer, gratz! You guessed the word! +$pointsEarned points! You've $scoreboard{$nickPlayer} points!");
			Commands::run("e e11") if $config{sendEmoticon};
			
			# Starts a new round
			undef $currentWord;
			Plugins::delHook('packet_pubMsg', $hooks);
			unless ($taskManager->countTasksByName('pluginForcaRecomeçarPart1')) {
				$taskManager->add(Task::Timeout->new(
				name => 'pluginForcaRecomeçarPart1',
				inGame => 1,
				function => sub {&startGame;},
				seconds => 5,
				));
			}
			
			$inform = 0;
			return 1;
		}
	
		# Checks if there is a repeated letter
	
		my $contidion = $initialLetter;
		$contidion = "/|ã|á|à|â|a|/" if ($initialLetter eq 'a');	$contidion = "/|é|è|ê|e|/" if ($initialLetter eq 'e');
		$contidion = "/|í|ì|î|i|/" if ($initialLetter eq 'i');			   $contidion = "/|õ|ó|ò|ô|o|/" if ($initialLetter eq 'o');
		$contidion = "/|ú|ù|u|/" if ($initialLetter eq 'u');
	
		my $i = 0;
		my $repeatingLetter = 0;
		for (@lettersUsed) {
			if ($contidion =~ $lettersUsed[$i]) {
				$repeatingLetter = 1;
				last;
			}
		$i++;
		}
	
		if ($repeatingLetter) {
			# Repeating a letter
			
			exists $scoreboard{$nickPlayer} ?
				Commands::run("c $nickPlayer, '$initialLetter' was already used! (You've $scoreboard{$nickPlayer} point(s))") :
				Commands::run("c $nickPlayer, '$initialLetter' was already used! (To check scores, send me a PM!)");
			Commands::run("e !") if $config{sendEmoticon};
			
			$inform = 0;
			return 0;
		} else {
			# Not a repeated letter
			
			push (@lettersUsed, $initialLetter);
		}
	
		# Checks if got a letter right
		my $pointsEarned = 0;
		for (my $i = 0; $i < length($currentWord); $i++) {
			my $letter = substr($currentWord, $i, 1);
	
			if ($letter ~~ @alphabet) {
				if ($contidion =~ $letter) {
					$pointsEarned++;
					$currentWordHidden[$i] = substr($currentWord, $i, 1);
				}
			}
		}
		
		if ($pointsEarned) {
			# Got a letter right
			
			# Saving won points
			&saveScores($nickPlayer, $pointsEarned);
	
			# Checks if completed the word
			my $incompleteWord = 0;
			for (@currentWordHidden) {
				$incompleteWord = 1 if ($_ eq '_ ' || $_ eq '_');
			}
	
			if ($incompleteWord) {
				Commands::run("c Right, $nickPlayer! +$pointsEarned! The word is now: @currentWordHidden");
				Commands::run("e ok") if $config{sendEmoticon};
			} else {
				Commands::run("c Right, $nickPlayer! +$pointsEarned! Concluded word: @currentWordHidden");
				Commands::run("e ok") if $config{sendEmoticon};
			
				# Start a new round
				undef $currentWord;
				Plugins::delHook('packet_pubMsg', $hooks);
				unless ($taskManager->countTasksByName('pluginForcaRecomeçarPart1')) {
					$taskManager->add(Task::Timeout->new(
					name => 'pluginForcaRecomeçarPart1',
					inGame => 1,
					function => sub {&startGame;},
					seconds => 5,
					));
				}
			}
		} else {
			# Não acertou
			exists $scoreboard{$nickPlayer} ?
				Commands::run("c $nickPlayer, '$initialLetter' isn't present on the word! (You've $scoreboard{$nickPlayer} point(s))") :
				Commands::run("c $nickPlayer, '$initialLetter' isn't present on the word! (To check scores, send me a PM!)");
			Commands::run("e ??") if $config{sendEmoticon};
		}
		
		# Finalizar
		$inform = 0; # Evade flood
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
			# Add player
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
	sub informPublic {
		$inform++;
		if ($inform == 3) { # Evade flood
			my $count = 0;
			for (my $i = 0; $i <= @currentWordHidden; $i++) {
				$count += length($currentWordHidden[$i]);
			}
	
			Commands::run("c Play Hangman! Each letter is worth 1 point; guessing the word is worth 5!");
			Commands::run("c To check the Scoreboard and how to join, send me a PM!");
			if (length($currentTip) + $count + 22 > $config{message_length_max}) {
				Commands::run("c Tip: $currentTip!");
				Commands::run("c Current word: @currentWordHidden");
			} else {
				Commands::run("c Tip: $currentTip! Current word: @currentWordHidden");
			}
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
				Commands::run("pm \"$nick\" * $i° - $_ - $scoreboard{$_} pontos");
				last if ($i == 100);
			}
		} elsif ($message =~ /comment:/i) {
			# Anti-flood
			my $sth = $dbh->prepare("SELECT * FROM hangman_comment WHERE nick = ?")
				or die "Couldn't prepare statement";
			$sth->execute($nick)
				or die "Couldn't execute the query";
			$sth->finish;
			
			if ($sth->rows < 2) {
				$message =~ s/comment://i;
				my $sth = $dbh->prepare("INSERT into hangman_comment(server, nick, comment) value(?,?,?)")
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
			Commands::run("pm \"$nick\" $message you've $scoreboard{$message} points and you're at $i° place!");
		} else {
			Commands::run("pm \"$nick\" To join, discover the word by sending a letter or a word that you believe it's!");
			Commands::run("pm \"$nick\" SEND THE MESSAGE THROUGH PUBLIC CHAT, NOT by PM! By public chat!!");
			Commands::run("pm \"$nick\" The more incomplete the word is, the more points you will get!");
			Commands::run("pm \"$nick\" -------------------");
			Commands::run("pm \"$nick\" Tip: Send, through public chat (NOT by PM):");
			Commands::run("pm \"$nick\" * 'tip' -> to show the tip of current word");
			Commands::run("pm \"$nick\" * 'word' -> to show the state of the current word");
			Commands::run("pm \"$nick\" -------------------");
			Commands::run("pm \"$nick\" Scoreboard of the top 15 players:");
	
			my $i = 0;
			for ( sort {$scoreboard{$b} <=> $scoreboard{$a}} keys %scoreboard) {
				$i++;
				Commands::run("pm \"$nick\" * $i° - $_ - $scoreboard{$_} pontos");
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
			$message .= "* $i° - $_ - $scoreboard{$_} pontos\n";
			last if ($i == 50);
		}
	
		$message .= "Total: " . scalar (keys %scoreboard) . "\n";
	
		$message .= center('Information about current Hangman Game', 50, '-') . "\n";
		$message .= "Current word: $currentWord\n";
		$message .= "Current state: @currentWordHidden\n";
		$message .= "Used letters: @lettersUsed\n";
		$message .= "Current tip: $currentTip\n";
	
		message $message, "list";
	}
	
1;