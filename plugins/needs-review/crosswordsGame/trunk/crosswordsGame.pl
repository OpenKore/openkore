# Plugin to play a Crosswords Game at Ragnarok
# by KeplerBR - Translated by Triper
#
# Topic:
#  [EN]		http://forums.openkore.com/viewtopic.php?f=34&t=49616
#  [PT-BR]	http://forums.openkore-brasil.com/index.php?/topic/384-plugin-4fun-ca%C3%A7a-palavras/

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
	Plugins::register("crossWords", "Crosswords at Ragnarok", \&on_unload);
		my $hooks = Plugins::addHooks(
			['start3', \&start],
			['packet/received_sync', \&informPublic],
			['packet_privMsg', \&informPM],
			['packet/map_loaded', \&startGame],
			#['packet_pubMsg', \&analyzeResponse],
		);
 
	my $commandHangmanGame = Commands::register(
		["inform", "Shows the ranking table and info about the curent Crosswords", \&commandInform]
	);

# Global Variables
my (@currentsWords, @totalWordListSkill, @wordListSkill, @wordListMonster, @totalWordListMonster, @totalWordListItem, @wordListItem, @scenery, @placePosition, @placeX, @placeY,
	$wordsFound, $totalWords, $tip, $remainingTime, %scoreboard, %nickListTime);
my @alphabet = ('a' .. 'z'); my $row = 6; my $column = 9; my $inform = 0;
my $datadir = $Plugins::current_plugin_folder;

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
	# Load word list and ranking table
	sub start {
		# Loading words
		&loadWordList;

		# Loading ranking table
		my $sth = $dbh->prepare("SELECT * FROM $config{table}");
		$sth->execute();
		while (my $ref = $sth->fetchrow_hashref()) {
			$scoreboard{$ref->{nick}} = $ref->{points};
		}
		$sth->finish();
	}

	################################
	# Stars a Word Finder Game
	sub startGame {
		return if (@scenery);

		srand;
		look(3, 2);
		$wordsFound = 0;

		# Get the words randomly
		if (scalar(@wordListItem) + scalar(@wordListSkill) + scalar(@wordListMonster) < 6) {
			@wordListSkill = @totalWordListSkill;
			@wordListItem = @totalWordListItem;
			@wordListMonster = @totalWordListMonster;
		}
		 
		# TODO: Make this part more legible
		$totalWords = int(rand(5));
		my $rand; my $countItem = 0; my $countMonster = 0; my $countSkill = 0;
		for (my $i = 0; $i <= $totalWords; $i++) {
			my $type = int(rand(3));
			if ($type == 2 && @wordListSkill) {
				$rand = int(rand scalar(@wordListSkill));
				$currentsWords[$i] = $wordListSkill[$rand];
				delete $wordListSkill[$rand];
				if ($currentsWords[$i]) {
					$countSkill++;
				} else {
					$i--
				}
			} elsif ($type == 1 && @wordListMonster) {
				$rand = int(rand scalar(@wordListMonster));
				$currentsWords[$i] = $wordListMonster[$rand];
				delete $wordListMonster[$rand];
				if ($currentsWords[$i]) {
					$countMonster++;
				} else {
					$i--
				}
			} elsif (@wordListItem) {
				$rand = int(rand scalar(@wordListItem));
				$currentsWords[$i] = $wordListItem[$rand];
				delete $wordListItem[$rand];
				if ($currentsWords[$i]) {
					$countItem++;
				} else {
					$i--
				}
			}
		}
		
		# Make tip
		message "countItem: $countItem | countSkill: $countSkill | countMonter: $countMonster\n";
		
		$tip = 'There is ';
		if ($countItem > 1) {
			$tip .= "$countItem items";
			if ($countSkill && $countMonster) {
				$tip .= ', ';
			} elsif ($countSkill || $countMonster) {
				$tip .= ' and ';
			}
		} elsif ($countItem == 1) {
			$tip .= '1 item';
			if ($countSkill && $countMonster) {
				$tip .= ', ';
			} elsif ($countSkill || $countMonster) {
				$tip .= ' and ';
			}
		}
		if ($countSkill > 1) {
			$tip .= "$countSkill skills ";
			$tip .= 'and ' if ($countMonster);
		} elsif ($countSkill == 1) {
			$tip .= '1 skill ';
			$tip .= 'and ' if ($countMonster);
		}
		if ($countMonster > 1) {
			$tip .= "$countMonster monster ";
		} elsif ($countMonster == 1) {
			$tip .= "1 monsters ";
		}
		 
		# Create Word Finder scenary
			for (my $i = 0; $i <= $totalWords; $i++) {
				positionWord:
				#  Randomize the place of the words
				$placePosition[$i] = int(rand(2)) - 1; # 1 -> Vertical |:| 0 -> Horizontal
				my ($coordinatesPossibleX, $coordinatesPossibleY);
				if ($placePosition[$i]) {
					$coordinatesPossibleX = $column - length($currentsWords[$i]);
					$coordinatesPossibleY = $row;
				} else {
					$coordinatesPossibleX = $row - length($currentsWords[$i]);
					$coordinatesPossibleY = $column;
				}
				$placeX[$i] = int(rand($coordinatesPossibleX)); $placeY[$i] = int(rand($coordinatesPossibleY));
				 
				# Checks if a word doesn't come from another and the interception letter is the same				
				if ($i) { # No need for analyze if the scenary just has one single word
					for (my $i2 = 0; $i2 <= length($currentsWords[$i]); $i2++) {
						if ($placePosition[$i]) {
							# Vertical
							goto positionWord if ($scenery[$placeX[$i]][$placeY[$i] + $i2] &&
								$scenery[$placeX[$i]][$placeY[$i] + $i2] ne substr($currentsWords[$i], $i2, 1));
						} else {
							# Horizontal
							goto positionWord if ($scenery[$placeX[$i] + $i2][$placeY[$i]] &&
								$scenery[$placeX[$i] + $i2][$placeY[$i]] ne substr($currentsWords[$i], $i2, 1));
						}
					}
				}
				 
				# Place the word on the scenary
				for (my $i2 = 0; $i2 <= length($currentsWords[$i]); $i2++) {
					if ($placePosition[$i]) {
						# Vertical
						$scenery[$placeX[$i]][$placeY[$i] + $i2] = substr($currentsWords[$i], $i2, 1);
					} else {
						# Horizontal
						$scenery[$placeX[$i] + $i2][$placeY[$i]] = substr($currentsWords[$i], $i2, 1);
					}
				}
			}
			 
			# Leftover spaces with be fill with random letters
			for (my $X = 0; $X < $row; $X++) {
				for (my $Y = 0; $Y < $column; $Y++) {
					chooseRandomLetter:
					$scenery[$X][$Y] = $alphabet[rand( scalar @alphabet)] if (!$scenery[$X][$Y]);
					 
					# Checks if there is a false positive
					# TODO: works, but needs to be optimized to be faster!
					
					# my $analysisLine = '';
					# for (my $analysisX = 0; $analysisX < $X; $analysisX++) {
						# $analysisLine .= $scenery[$analysisX][$Y];
					# }
					 
					# my $analysisColumn = '';
					# for (my $analysisY = 0; $analysisY < $Y; $analysisY++) {
						# $analysisColumn .= $scenery[$X][$analysisY];
					# }
					 
					# while (<@totalWordListSkill>) {
						# next if ($_ ~~ @currentsWords);
						# if (((length($analysisLine) >= length($_)) && $_ =~ /$analysisLine/) || ((length($analysisColumn) >= length($_)) && $_ =~ /$analysisColumn/)) {
							# message "[REPETIDA SKILL] $_ - $analysisLine - $analysisColumn\n";
							# goto chooseRandomLetter;
						# }
						# #goto chooseRandomLetter if ($_ =~ /$analysisLine/ || $_ =~ /analysisColumn/);
					# }
					 
					# while (<@totalWordListItem>) {
						# next if ($_ ~~ @currentsWords);
						# if (((length($analysisLine) >= length($_)) && $_ =~ /$analysisLine/) || ((length($analysisColumn) >= length($_)) && $_ =~ /$analysisColumn/)) {
							# message "[REPETIDA ITEM] $_ - $analysisLine - $analysisColumn\n";
							# goto chooseRandomLetter;
						# }
						# #goto chooseRandomLetter if ($_ =~ /$analysisLine/ || $_ =~ /$analysisColumn/);
					# }
				}
			}
		 
		# Time of the current round
		$remainingTime = time + ($totalWords + 1) * 20 + 300;
		 
		$taskManager->add(Task::Timeout->new(
				name => 'pluginCrosswordsTimeout',
				function => sub {
						Commands::run("c Current Time for this Round has ended! The words were: @currentsWords");
						@scenery = ();  @currentsWords = (); $inform = 0;
						Plugins::delHook('packet_pubMsg', $hooks);
						sleep 2; # TODO: Change to task later!
						&startGame;
					},
				seconds => $remainingTime - time,
		));
		 
		# Send messages about the round
		message "Words: @currentsWords\n", "list";
		&sendScenario;
		Commands::run("e heh") if $config{sendEmoticon};
		$hooks = Plugins::addHooks(
			['packet_pubMsg', \&analyzeResponse],
		);
		 
		$inform = 0;
	}

	################################
	# Check public message
	sub analyzeResponse {
		my $hookname = shift;
		my $args = shift;

		# Collecting variables ...
		my $nickPlayer = $args->{pubMsgUser};
		my $chatMessage = lc($args->{Msg});
		my $initialLetter = substr($chatMessage, 0, 1);

		return if (length($chatMessage) == 1);
		for (my $i = 0; $i < length($chatMessage); $i++) {
			return unless (substr($chatMessage, $i, 1) ~~ @alphabet);
		}
		$inform = 0; # Evading flood
		 
		# Command Key-Words
		if ($chatMessage eq "game") {
			&sendScenario;
			return;
		}

		# Checking answers
		my $answer = -1;
		for (my $i = 0; $i <= $totalWords; $i++) {
			if (lc($currentsWords[$i]) eq lc($chatMessage)) {
				if ($currentsWords[$i] =~ /[A-Z]+/) {
					Commands::run("c The word '$chatMessage' was already found on the current Crossword!");
					Commands::run("e ??") if $config{sendEmoticon};
					return;
				} else {
					$answer = $i;
					last;
				}
			}
		}
		 
		if ($answer == -1) {
			# Errou

			Commands::run("c In this current crossword, there is no '$chatMessage'!");
			Commands::run("e ??") if $config{sendEmoticon};
			return;
		} else {
			# Found a word
			$wordsFound++;

			# Giving points
			my $pointsEarned = 5; # TODO: Is this variable really needed??
			&saveScores($nickPlayer, $pointsEarned);
		 
			# Updating scenary
			for (my $i = 0; $i < length($currentsWords[$answer]); $i++) {
				if ($placePosition[$answer]) {
					# Vertical
					$scenery[$placeX[$answer]][$placeY[$answer] + $i] = uc($scenery[$placeX[$answer]][$placeY[$answer] + $i]);
				} else {
					# Horizontal
					$scenery[$placeX[$answer] + $i][$placeY[$answer]] = uc($scenery[$placeX[$answer] + $i][$placeY[$answer]]);
				}
				$currentsWords[$answer] = uc($currentsWords[$answer]);
			}
			 
			# Informing
			if ($wordsFound != $totalWords + 1) {
				Commands::run("c $nickPlayer, congratulations! You found a word! +$pointsEarned points! You've now $scoreboard{$nickPlayer} points!");
				$remainingTime += 15;
				&sendScenario;
			} else {
				# Begin new round if all words has been found
				&sendScenario;
				Commands::run("c $nickPlayer, congratulations! Crossword concluded! +$pointsEarned! You've now $scoreboard{$nickPlayer} points!");
				 
				Plugins::delHook('packet_pubMsg', $hooks);
				@scenery = ();  @currentsWords = (); $inform = 0;
				$taskManager->add(Task::Timeout->new(
						name => 'pluginPalavrasRecomeзarPart1',
						function => sub {&startGame;},
						seconds => 5,
				));
			}
			 
			# Finishing
			Commands::run("e e11") if $config{sendEmoticon};
			return 1;
		}
	}

	################################
	# Misc: Saving the points of the players
	sub saveScores {
		my ($nickPlayer, $pointsEarned) = @_;

		if (exists $scoreboard{$nickPlayer}) {
			# Updating the ranking table
			$scoreboard{$nickPlayer} += $pointsEarned;
			 
			my $sth = $dbh->prepare("UPDATE $config{table} SET points = ? WHERE nick = ?")
				or die "Couldn't prepare statement";
			$sth->execute($scoreboard{$nickPlayer}, $nickPlayer)
				or die "Couldn't execute the query";
			$sth->finish;
		} else {
			# Adding a player
			$scoreboard{$nickPlayer} = $pointsEarned;
			 
			my $sth = $dbh->prepare("INSERT into $config{table}(nick, points) values(?,?)")
				or die "Couldn't prepare statement";
			$sth->execute($nickPlayer, $scoreboard{$nickPlayer})
				or die "Couldn't execute the query";
			$sth->finish;
		}
	}
	 
	################################
	# Misc: Loading word list
	sub loadWordList {
		my $limit;
		($row > $column) ? $limit = $column : $limit = $row;
		
		open my $fileListSkill,"<" . $datadir . '\listSkill.txt' or die $!;
			while (<$fileListSkill>) {
				my $jump = 0;
				my $word = lc($_);
				$word =~ s/\R//g;
				next if (length($word) >= $limit); 
				
				for (my $i = 0; $i < length($word); $i++) {
					unless (substr($word, $i, 1) ~~ @alphabet) {
						$jump = 1;
						last;
					}
				}
				push (@totalWordListSkill, $word) if (!$jump);
			}
		close $fileListSkill;

		open my $fileListMonster,"<" . $datadir . '\listMonster.txt' or die $!;
			while (<$fileListMonster>) {
				my $jump = 0;
				my $word = lc($_);
				$word =~ s/\R//g;
				next if (length($word) >= $limit); 
				
				for (my $i = 0; $i < length($word); $i++) {
					unless (substr($word, $i, 1) ~~ @alphabet) {
						$jump = 1;
						last;
					}
				}
				push (@totalWordListMonster, $word) if (!$jump);
			}
		close $fileListMonster;
		
		for (keys %items_lut) {
			my $jump = 0;
			my $word = lc($items_lut{$_});
			next if (length($word) >= $limit);
			
			for (my $i = 0; $i < length($word); $i++) {
				unless (substr($word, $i, 1) ~~ @alphabet) {
					$jump = 1;
					last;
				}
			}
			push (@totalWordListItem, $word) if (!$jump);
		}
		
		@wordListSkill = @totalWordListSkill;
		@wordListMonster = @totalWordListMonster;
		@wordListItem = @totalWordListItem;
	}
 
	################################
	# Misc: Sending scenary
	sub sendScenario {
		my $messageRemainingTime = $remainingTime - time;
		 
		Commands::run("c § ################################ CrossWords:");
		if (($totalWords + 1 - $wordsFound) > 1) {
			Commands::run("c § #### This round will last more $messageRemainingTime seconds!");
			Commands::run("c § #### Still missing " . scalar($totalWords + 1 - $wordsFound) . " words! $tip");
		} elsif (($totalWords + 1 - $wordsFound) == 1) {
			 
			Commands::run("c § #### This round will last more $messageRemainingTime seconds!\"");
			Commands::run("c § #### Crosswords: Still missing " . scalar($totalWords + 1 - $wordsFound) . " word! $tip");
		} else {
			Commands::run("c § #### Finished while $messageRemainingTime seconds were missing!! Congratulations!!!");
		}
		 
		my %spacing = (
			'a' => '  ',
			'b' => '  ',
			'c' => '  ',
			'd' => '  ',
			'e' => '  ',
			'f' => '   ',
			'g' => '  ',
			'h' => '  ',
			'i' => '   ',
			'j' => '   ',
			'k' => '  ',
			'l' => '   ',
			'm' => ' ',
			'n' => '  ',
			'o' => '  ',
			'p' => '  ',
			'q' => '  ',
			'r' => '   ',
			's' => '  ',
			't' => '   ',
			'u' => '  ',
			'v' => '  ',
			'x' => '  ',
			'w' => '  ',
			'y' => '  ',
			'z' => '  ',
			'A' => '  ',
			'B' => '  ',
			'C' => '  ',
			'D' => '  ',
			'E' => '  ',
			'F' => '  ',
			'G' => '  ',
			'H' => '  ',
			'I' => '   ',
			'J' => '  ',
			'K' => '  ',
			'L' => '  ',
			'M' => '  ',
			'N' => '  ',
			'O' => ' ',
			'P' => '  ',
			'Q' => '  ',
			'R' => '  ',
			'S' => '  ',
			'T' => '  ',
			'U' => '  ',
			'V' => '  ',
			'X' => '  ',
			'W' => ' ',
			'Y' => '  ',
			'Z' => '  ',
		);
		 
		for (my $X = 0; $X < $row; $X++) {
			my $message = '';
			for (my $Y = 0; $Y < $column; $Y++) {
				$message .= $scenery[$X][$Y] . $spacing{$scenery[$X][$Y]} . '|';
			}
			Commands::run("c $message");
		}
	}
		 
	################################
	# Informing that there is an Crossword Game taking place
	sub informPublic {
		$inform++;
		if ($inform == 4) { # Evade flood
			Commands::run("c Play Crosswords at Ragnarok! Find a word and get 5 points!");
			Commands::run("c To check the ranking and how to play, send me a PM!");
			&sendScenario;
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
			Commands::run("pm \"$nick\" Sorry, you sent me a PM not much time ago! Try again in 10 seconds!");
			return;
		}
		$nickListTime{$nick} = time;

		# Analyzing PM
		if ($message =~ /full ranking/i) {
			my $i = 0;
			for ( sort {$scoreboard{$b} <=> $scoreboard{$a}} keys %scoreboard) {
				$i++;
				last if (!$_);
				Commands::run("pm \"$nick\" * $i° - $_ - $scoreboard{$_} pontos");
				last if ($i == 100);
			}
		} elsif ($message =~ /Comment:/i) {
			# Anti-flood
			my $sth = $dbh->prepare("SELECT * FROM crosswords_comment WHERE nick = ?")
				or die "Couldn't prepare statement";
			$sth->execute($nick)
				or die "Couldn't execute the query";
			$sth->finish;
			 
			if ($sth->rows < 2) {
				$message =~ s/comment://i;
				my $sth = $dbh->prepare("INSERT into crosswords_comment(server, nick, comment) value(?,?,?)")
					or die "Couldn't prepare statement";
				$sth->execute($config{master}, $nick, $message)
					or die "Couldn't execute the query";
				$sth->finish;
				 
				Commands::run("pm \"$nick\" Thank you, $nick! Your comment was sent with success! I will read it later.");
			} else {
				Commands::run("pm \"$nick\" Sorry, $nick, but it's not possible to send more then 1 comment per character...");
			}
		} elsif ($scoreboard{$message}) {
			my $i = 0;
			for (sort {$scoreboard{$b} <=> $scoreboard{$a}} keys %scoreboard) {
				$i++;
				last if ($_ eq $message);
			}
			Commands::run("pm \"$nick\" $message has $scoreboard{$message} points and is at $i° place!");
		} else {
			Commands::run("pm \"$nick\" To join the Crosswords Game, just search and type the hidding word(s)!");
			Commands::run("pm \"$nick\" Send the message through public chat, not by PM!! Send it through PUBLIC CHAT!!");
			Commands::run("pm \"$nick\" Each round has a time limit! Guess one word and increase that time in 15 seconds");
			Commands::run("pm \"$nick\" -------------------");
			Commands::run("pm \"$nick\" Tip: Send, through public chat (NOT by PM):");
			Commands::run("pm \"$nick\" * 'game' -> to show the scenary where are the words to be found");
			Commands::run("pm \"$nick\" -------------------");
			Commands::run("pm \"$nick\" Ranking table of the first 15 places:");

			my $i = 0;
			for ( sort {$scoreboard{$b} <=> $scoreboard{$a}} keys %scoreboard) {
				$i++;
				last if (!$_);
				Commands::run("pm \"$nick\" * $i° - $_ - $scoreboard{$_} points");
				last if ($i == 15);
			}
			 
			Commands::run("pm \"$nick\" Total of Players: " . scalar (keys %scoreboard));
			Commands::run("pm \"$nick\" -------------------");
			Commands::run("pm \"$nick\" If you want to send me a comment, send me a PM with the text and 'Comment:'");
			Commands::run("pm \"$nick\" Exemplo: 'Comment: This Crossword game is really cool =)'");
			Commands::run("pm \"$nick\" -------------------");
			Commands::run("pm \"$nick\" To visualize the points of a specific player, send, through PM, his exact nick");
			Commands::run("pm \"$nick\" To check the first 100 places, send, through PM, 'Full Ranking'!");
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

		$message .= center('Crossword Information', 50, '-') . "\n";
		$message .= "Tip: $tip\n";
		$message .= "Hidding Words: @currentsWords\n";
		my $messageRemainingTime = $remainingTime - time;
		$message .= "Leftover Time: $messageRemainingTime\n";
		$message .= "Scenary: \n";
		 
		for (my $X = 0; $X < $row; $X++) {
			my $messageScenery = '';
			for (my $Y = 0; $Y < $column; $Y++) {
				$messageScenery .= $scenery[$X][$Y] . ' ';
			}
			$message .= $messageScenery . "\n";
		}

		message $message, "list";
	}

1;