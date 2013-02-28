# Plugin to play Hangman on Ragnarok Online
# by KeplerBR
#
# Topic: http://forums.openkore.com/viewtopic.php?f=34&t=29111

package forca;
	use strict;
	use warnings; 
	use Plugins;
	use Globals;
	use Skill;
	use Misc qw(look center);
	use Log qw(message);
	use Commands;

	# Register Plugin and Hooks
	Plugins::register("forca", "Hangman in Ragnarok!", \&on_unload);
		my $hooks = Plugins::addHooks(
			['start3', \&start],
			['packet/received_sync', \&inform],
			['packet_privMsg', \&informPM],
			['packet/map_loaded', \&startGame],
			['packet_pubMsg', \&analyzeResponse],
		);

	my $commandHangmanGame = Commands::register(
		["inform", "Shows the rankings and the actual situation of the game", \&commandInform]
	);

my ($currentTip, $currentWord, @currentWordHidden, @lettersUsed, @wordListUsed);
my $type = 0;
my $inform = 0;
my (%scoreboard, %listSkills, %listSkillsHandle, %listItems);
my @alphabet = ('a' .. 'z', 'á', 'é', 'í', 'ó', 'ú', 'â', 'ê', 'î', 'ô', 'û', 'à', 'è', 'ì', 'ò', 'ù', 'ã', 'õ', 'ç');

	################################
	#On Unload code
	sub on_unload {
		Plugins::delHooks($hooks);
		Commands::unregister($commandHangmanGame);
	}

	################################
	# Load wordlist and rankings
	sub start {
		%listSkills = reverse %Skill::StaticInfo::names;
		%listSkillsHandle = reverse %Skill::StaticInfo::handles;
		
		for (keys %items_lut) {
			$items_lut{$_} = lc($items_lut{$_});
		}
		%listItems = reverse %items_lut;
		
		# Loads rankings
		if (-e $Settings::logs_folder . "/" . 'scoreboardHangmanGame.txt') {
			open my $fileScoreboard, '<', $Settings::logs_folder . "/" . 'scoreboardHangmanGame.txt' or die $!;
			while (<$fileScoreboard>) {
				my ($nick, $pontos) = split(/\t+/, $_);
				$pontos++; $pontos--; # TODO: There must be a better way to clean the break line!
				$scoreboard{$nick} = $pontos if ($nick);
			}
			close $fileScoreboard;
		}
	}

	################################
	# Starts a round of Hangman
	sub startGame {
		look(3, 2);

		# Gets a random word
		if ($type) {
			$type = 0;
		} else {
			$type = 1;
		}

		choseWord:
			if ($type) {
				$currentWord = lc($items_lut{(keys %items_lut)[rand keys %items_lut]});
			} else {
				$currentWord = lc($listSkills{(keys %listSkills)[rand keys %listSkills]});
			}
		goto choseWord if ($currentWord ~~ @wordListUsed); # Repeated word
			push (@wordListUsed, $currentWord);

			# Generate the hidden word
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
		goto choseWord if ($count + 61 > $config{message_length_max}); # Try to evade big words that can end broken in two lines

		# Generate the tip
		$currentTip = '';
		if ($type) {
			my $descItem = $itemsDesc_lut{$listItems{$currentWord}} || 0;
			if ($descItem) {
			message "$descItem\n", "list";
			my @num = (0..5);
				while (!$currentTip) {
					my $typeTip = $num[(rand @num)];
					if ($typeTip == 0) {
						$descItem =~ /Class\s*:\s* (.+)/i;
						
						$currentTip = "Item of the type '$1'" if ($1);
					} elsif ($typeTip == 1) {
						$descItem =~ /Weight\s*:\s* (.+)/i;
						
						$currentTip = "Item with the weight '$1'" if ($1);
					} elsif ($typeTip == 2) {
						$descItem =~ /Location\s*:\s* (.+)/i;
						
						$currentTip = "Item that you equip into '$1'" if ($1);
					} elsif ($typeTip == 3) {
						$descItem =~ /Classes that use it\s*:\s* (.+?)\./;

						$currentTip = "Item that you can equip '$1'"  if (length($1) < 70 && $1);
					} elsif ($typeTip == 4) {
						$descItem =~ /(.+?)\./i;

						$currentTip = $1 if ($1 && length($1) < 70 && !($1 =~ /$currentWord/i));
					} elsif ($typeTip == 5) {
						$descItem =~ /Weapon Level\s*:\s* (.+?)/i;
						
						$currentTip = "Level of the gear '$1'" if ($1);
					} else {
						$descItem =~ /Required Level\s*:\s* (.+?)/i;
						
						$currentTip = "Needs the following level to use '$1'" if ($1);
					}

					# Deletes the $num value used
					@num = grep($_ != $typeTip, @num);

					$currentTip = 'One item' if (!@num);
				}
			} else {
				$currentTip = 'One item';
			}
		} else {
			my $descSkill = $skillsDesc_lut{$listSkillsHandle{$Skill::StaticInfo::names{$currentWord}}} || 0;
			if ($descSkill) {
			message "$descSkill\n", "list";
			my @num = (0..2);
				while (!$currentTip) {
					my $typeTip = $num[(rand @num)];
					if ($typeTip == 0) {
						$descSkill =~ /(?:Type|Skill)\s*:\s* (.+)/i;
						
						$currentTip = "Skill of the type '$1'" if ($1);
					} elsif ($typeTip == 1) {
						$descSkill =~ /Target\s*:\s* (.+)/i;
						
						$currentTip = "Skill with the following type of target '$1'" if ($1);
					} else {
						$descSkill =~ /Description\s*:\s* (.+)(?:\.|)/i;

						$currentTip = $1 if (length($1) < 70 && $1);
					}

					# Deletes the $num value used
					@num = grep($_ != $typeTip, @num);

					$currentTip = 'One skill!' if (!@num);
				}
			} else {
				$currentTip = 'One skill';
			}
		}
		
		# Sends messages informing
		Commands::run("c Tip: $currentTip!");
		Commands::run("e heh") if $config{sendEmoticon};
		sleep 2;
		Commands::run("c Current Word: @currentWordHidden");
		
		@lettersUsed = ();
	}

	################################
	# Checks public messages
	sub analyzeResponse {
		my $hookname = shift;
		my $args = shift;

		# Gets variables...
		my $nickPlayer = $args->{pubMsgUser};
		my $chatMessage = lc($args->{Msg});
		my $initialLetter = substr($chatMessage, 0, 1);

		return 0 if !($initialLetter ~~ @alphabet);

		# Command keywords
		if ($chatMessage eq "tip") {
			Commands::run("c Tip: $currentTip!");
			return 0;
		} elsif ($chatMessage eq "word") {
			Commands::run("c Word: @currentWordHidden");
			return 0;
		}

		# Checks answer
		if (length($chatMessage) > 1 && $chatMessage ne $currentWord) {
			# Wrong word

			Commands::run("c The word isn't '$chatMessage'!");
			Commands::run("e ??") if $config{sendEmoticon};
			return 0;
		} elsif ($chatMessage eq $currentWord) {
			# Correct word
			
			# Calculate points and store them
			my $hiddenLetters = 0;
			for (@currentWordHidden) {
				$hiddenLetters++ if ($_ eq '_ ' || $_ eq '_');
			}

			my $pointsEarned = 5 + int($hiddenLetters/2);
			if (exists $scoreboard{$nickPlayer}) {
				$scoreboard{$nickPlayer} += $pointsEarned;
			} else {
				$scoreboard{$nickPlayer} = $pointsEarned;
			}

			# Save rankings
			open my $fileScoreboard, '>:raw', $Settings::logs_folder . "/" . 'scoreboardHangmanGame.txt' or die $!;
			for (keys %scoreboard) {
				print $fileScoreboard "$_	$scoreboard{$_}\r\n";
			}
			close $fileScoreboard;

			# Informs
			Commands::run("c $nickPlayer, congratulations! You got it! +$pointsEarned points! You've now $scoreboard{$nickPlayer}!");
			Commands::run("e e11") if $config{sendEmoticon};
			
			# Starts a new round
			sleep 5;
			&startGame;
			return 1;
		}

		# Checks if it's not repeating a word

		my $contidion = $initialLetter;
		$contidion = "/|ã|á|à|â|a|/" if ($initialLetter eq 'a');	$contidion = "/|é|è|ê|e|/" if ($initialLetter eq 'e');
		$contidion = "/|í|ì|î|i|/" if ($initialLetter eq 'i');		$contidion = "/|õ|ó|ò|ô|o|/" if ($initialLetter eq 'o');
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
			# It's repeating the word
			
			exists $scoreboard{$nickPlayer} ?
				Commands::run("c $nickPlayer, '$initialLetter' was already used! (You got $scoreboard{$nickPlayer} point(s))") :
				Commands::run("c $nickPlayer, '$initialLetter' was already used! (To check the Board, send me a PM!)");
			Commands::run("e !") if $config{sendEmoticon};
		
			$inform = 0;
			return 0;
		} else {
			# Isn't repeating letters
			
			push (@lettersUsed, $initialLetter);
		}

		# Checks if guessed a letter
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
			# Guessed a letter
			
			# Stores points earned
			if (exists $scoreboard{$nickPlayer}) {
				$scoreboard{$nickPlayer} += $pointsEarned;
			} else {
				$scoreboard{$nickPlayer} = $pointsEarned;
			}

			my $points;

			# Saves board
			open my $fileScoreboard, '>:raw', $Settings::logs_folder . "/" . 'scoreboardHangmanGame.txt' or die $!;
			for (keys %scoreboard) {
				print $fileScoreboard "$_	$scoreboard{$_}\r\n";
			}
			close $fileScoreboard;

			# Checks if the word was completed
			my $incompleteWord = 0;
			for (@currentWordHidden) {
				$incompleteWord = 1 if ($_ eq '_ ' || $_ eq '_');
			}

			if ($incompleteWord) {
				Commands::run("c Right, $nickPlayer! +$pointsEarned! The name is now: @currentWordHidden");
				Commands::run("e ok") if $config{sendEmoticon};
			} else {
				Commands::run("c Right, $nickPlayer! +$pointsEarned! Word concluded: @currentWordHidden");
				Commands::run("e ok") if $config{sendEmoticon};
				sleep 5;
				&startGame;
			}
		} else {
			# Failed to guess
			exists $scoreboard{$nickPlayer} ?
				Commands::run("c $nickPlayer, '$initialLetter' isn't present on the word! (You got $scoreboard{$nickPlayer} point(s))") :
				Commands::run("c $nickPlayer, '$initialLetter' isn't present on the word! (To check the Board, send me a PM!)");
			Commands::run("e ??") if $config{sendEmoticon};
		}
		
		# Finishes it
		$inform = 0; # Evades flood
	}

	################################
	# Informs that a round is on going
	sub inform {
		$inform++;
		if ($inform == 3) { # Evades flood
			my $count = 0;
			for (my $i = 0; $i <= @currentWordHidden; $i++) {
				$count += length($currentWordHidden[$i]);
			}

			Commands::run("c Play the Hangman Game! Each letter is worth 1 point; full word is worth 5!");
			if (length($currentTip) + $count + 21 > $config{message_length_max}) {
				Commands::run("c Tip: $currentTip!");
				Commands::run("c Current Word: @currentWordHidden");
			} else {
				Commands::run("c Tip: $currentTip! Current Word: @currentWordHidden");
			}
			$inform = 0;
		}
	}

	################################
	# After getting a PM, will send some info
	sub informPM {
		my $hookname = shift;
		my $args = shift;
		my $nick = $args->{privMsgUser};
		my $message = $args->{privMsg};

		Commands::run("pm \"$nick\" To join the Hangman Game, just try to guess the word or a letter through public chat!");
		Commands::run("pm \"$nick\" The more incomplete is the word, the more points you win by guessing it!");
		Commands::run("pm \"$nick\" Current tip is '$currentTip' and the current word is '@currentWordHidden'!");
		Commands::run("pm \"$nick\" -------------------");
		Commands::run("pm \"$nick\" Tip: Send, through public chat (not by PM), 'tip' to show the tip and 'word' to show the word!");
		Commands::run("pm \"$nick\" -------------------");
		Commands::run("pm \"$nick\" Board:");
		if ($message =~ s/full board/i/) {
			for (keys %scoreboard) {
				Commands::run("pm \"$nick\" * $_ - $scoreboard{$_} point(s)");
			}
			Commands::run("pm \"$nick\" -------------------");
			Commands::run("pm \"$nick\" Total: " . scalar (keys %scoreboard) . " players");
		} else {
			for (keys %scoreboard) {
				Commands::run("pm \"$nick\" * $_ - $scoreboard{$_} ponto(s)") if ($scoreboard{$_} > 40);
			}
			Commands::run("pm \"$nick\" -------------------");
			Commands::run("pm \"$nick\" All the players with 40+ points have been shown.");
			Commands::run("pm \"$nick\" To visualize the full board, send through pm, 'full board'!");
		}
	}

	################################
	# Function of the command "inform"
	sub commandInform {
		my $message;

		$message = center('Current Board', 50, '-') . "\n";
		for (keys %scoreboard) {
			$message .= "* $_ - $scoreboard{$_}\n";
		}
		$message .= "Total: " . scalar (keys %scoreboard) . "\n";

		$message .= center('Information about current Hangman round', 50, '-') . "\n";
		$message .= "Current word: $currentWord\n";
		$message .= "Current state: @currentWordHidden\n";
		$message .= "Letters already used: @lettersUsed\n";
		$message .= "Current tip: $currentTip\n";

		message $message, "list";
	}

1;