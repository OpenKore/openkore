# Plugin to play Scattergories
# by KeplerBR
#
# Topic: http://forums.openkore.com/viewtopic.php?f=34&t=27892&p=77343#p77343

package scattergories;
	use strict;
	use warnings; 
	use Plugins;
	use Globals;
	use Skill;
	use Misc qw(look center);
	use Log qw(message);
	use Commands;

	# Register Plugin and Hooks
	Plugins::register("scattergories", "Scattergories Game in Ragnarok!", \&on_unload);
		my $hooks = Plugins::addHooks(
			['start3', \&start],
			['packet/received_sync', \&inform],
			['packet_privMsg', \&informPM],
			['packet/map_loaded', \&startGame],
			['packet_pubMsg', \&analyzeResponse],
		);

	my $commandAdedonha = Commands::register(
		["inform", "Showing ranking and recently used answered", \&commandInform]
	);

my $currentLetter;
my $inform = 0;
my $alert = 0;
my @recentLetters;
my (%scoreboard, %listItens, %recentAnswers);

	################################
	#On Unload code
	sub on_unload {
		Plugins::delHooks($hooks);
		Commands::unregister($commandAdedonha);
	}

	################################
	# Loading word list
	sub start {
		for (keys %items_lut) {
			$items_lut{$_} = lc($items_lut{$_});
		}
		%listItens = reverse %items_lut;

		# Loading rankings
		if (-e $Settings::logs_folder . "/" . 'scoreboard.txt') {
			open my $fileScoreboard, '<', $Settings::logs_folder . "/" . 'scoreboard.txt' or die $!;
			while (<$fileScoreboard>) {
				my ($nick, $pontos) = split(/\t+/, $_);
				$pontos++; $pontos--; # TODO: Need a better way to clean the break line!
				$scoreboard{$nick} = $pontos if ($nick);
			}
			close $fileScoreboard;
		}
	}

	################################
	# Starts a round of "Scattergories"
	sub startGame {
		look(3, 2);

		# Choosing a letter
		my %alphabet;
		if ($config{alphabet}) {
			%alphabet = (
				0  => 'a',	1  => 'b',	2  => 'c',	3  => 'd',	4  => 'e',	5  => 'f',	6  => 'g',	7  => 'h', 8  => 'i',
				9  => 'j',	10 => 'l',	11 => 'm',	12 => 'n',	13 => 'o',	14 => 'p',	15 => 'q',	16 => 'r', 17 => 's',
				18 => 't',	19 => 'u',	20 => 'v',	21 => 'z',
			);
		} else {
			%alphabet = (
				0  => 'a',	1  => 'b',	2  => 'c',	3  => 'd',	4  => 'e',	5  => 'f',	6  => 'g',	7  => 'h', 8  => 'i',
				9  => 'j',	10 => 'k',	11 => 'l',	12 => 'm',	13 => 'n',	14 => 'o',	15 => 'p',	16 => 'q', 17 => 'r',
				18 => 's',	19 => 't',	20 => 'u',	21 => 'v',  22 => 'x',  23 => 'w',  24 => 'y',  25 => 'z',
			);
		}
		my $alphabetCount = scalar keys %alphabet;
		my $chooseLetter = int(rand($alphabetCount));
		$currentLetter = $alphabet{$chooseLetter};
		$recentAnswers{$currentLetter} = '' if (!exists $recentAnswers{$currentLetter});

		# Prevents the usage of last letter as new one
		if ($currentLetter ~~ @recentLetters) {
			&startGame;
		} else {
			@recentLetters = () if (scalar @recentLetters == $alphabetCount - 1);
			push (@recentLetters, $currentLetter);

			# Inform
			Commands::run("c Chosen Letter: '" . uc($currentLetter) . "' !");
			Commands::run("c Shout an item or skill from Ragnarok that starts with the letter '" . uc($currentLetter) . "' !");
			Commands::run("e heh") if $config{sendEmoticon};
		}
	}

	################################
	# Checks if the answer corresponds to a valid item/skills
	sub analyzeResponse {
		my $hookname = shift;
		my $args = shift;

		# Checks if the answer is right
		my $nickPlayer = $args->{pubMsgUser};
		my $chatMessage = lc($args->{Msg});
		my $initialLetter = substr($chatMessage, 0, 1);

		my $currentAnalysis = $currentLetter;
		$currentAnalysis = "/ã|á|à|â|a|/i" if ($currentLetter eq 'a');	$currentAnalysis = "/é|è|ê|e|/i" if ($currentLetter eq 'e');
		$currentAnalysis = "/í|ì|î|i|/i" if ($currentLetter eq 'i');	$currentAnalysis = "/õ|ó|ò|ô|o|/i" if ($currentLetter eq 'o');
		$currentAnalysis = "/ú|ù|ô|u|/i" if ($currentLetter eq 'u');
		if ($initialLetter =~ $currentAnalysis) {
			if (exists $listItens{$chatMessage} || exists $Skill::StaticInfo::names{$chatMessage}) {
				if ($recentAnswers{$currentLetter} ne $chatMessage) {
					# Right Answer
					if (exists $scoreboard{$nickPlayer}) {
						$scoreboard{$nickPlayer}++;
					} else {
						$scoreboard{$nickPlayer} = 1;
					}
					
					Commands::run("c Congratulations, $nickPlayer! You guessed it right, your score is now $scoreboard{$nickPlayer} point(s)!");
					Commands::run("e e11") if $config{sendEmoticon};
					$recentAnswers{$currentLetter} = $chatMessage;

					# Saves rankings
					open my $fileScoreboard, '>:raw', $Settings::logs_folder . "/" . 'scoreboard.txt' or die $!;
					for (keys %scoreboard) {
						print $fileScoreboard "$_	$scoreboard{$_}\r\n";
					}
					close $fileScoreboard;

					# Starts new round
					sleep 5;
					&startGame;
				} else {
					# Repeated answer
					Commands::run("c '$chatMessage' was already shouted! You can't shout the same word twice in a row!");
					Commands::run("e ??") if $config{sendEmoticon};
				}
			} else {
			# Wrong answer
			exists $scoreboard{$nickPlayer} ?
				Commands::run("c $nickPlayer, '$chatMessage' isn't yet on the ranks! (You have now $scoreboard{$nickPlayer} point(s))") :
				Commands::run("c $nickPlayer, '$chatMessage' isn't yet on the ranks!");
				Commands::run("e ??") if $config{sendEmoticon};
			}
		$inform = 0;
		} else {
		# Wrong answer
			$alert++;
			if ($alert == 3) { # Prevents flood
				Commands::run("c Item should start with the letter '" . uc($currentLetter) . "', not with '" . uc($initialLetter) . "'!");
				Commands::run("e !") if $config{sendEmoticon};
				$alert = 0;
				$inform = 0;
			}
		}
	}


	################################
	# Info about Scattergories
	sub inform {
		$inform++;
		if ($inform == 3) { # Prevents flood
			Commands::run("c Play Scattergories in Ragnarok! Send me a PM if you want to check the rankings.");
			Commands::run("c Shout through public chat, an item or skill from Ragnarok starting with letter " . uc($currentLetter));
			$inform = 0;
		}
	}

	################################
	# After a PM, some info is sent back
	sub informPM {
		my $hookname = shift;
		my $args = shift;
		my $nick = $args->{privMsgUser};
		my $message = $args->{privMsg};

		Commands::run("pm $nick To start playing Scattergories, just do a public shout of an item or skill present in Ragnarok");
		Commands::run("pm $nick that starts with the letter shouted (currently, '" . uc($currentLetter) . "')!");
		Commands::run("pm $nick -------------------");
		Commands::run("pm $nick Ranking:");
		if ($message =~ s/full scoreboard/i/) {
			for (keys %scoreboard) {
				Commands::run("pm $nick * $_ - $scoreboard{$_} point(s)");
			}
			Commands::run("pm $nick -------------------");
			Commands::run("pm $nick Total: " . scalar (keys %scoreboard) . "  players");
		} else {
			for (keys %scoreboard) {
				Commands::run("pm $nick * $_ - $scoreboard{$_} point(s)") if ($scoreboard{$_} > 30);
			}
			Commands::run("pm $nick -------------------");
			Commands::run("pm $nick Displayed the players with more than 30 points.");
			Commands::run("pm $nick To see the whole scoreboard, send 'full scoreboard'!");
		}
	}

	################################
	# Module of the command "inform"
	sub commandInform {
		my $message;

		$message = center('Current Ranking', 50, '-') . "\n";
		for (keys %scoreboard) {
			$message .= "* $_ - $scoreboard{$_}\n";
		}
		$message .= "Total: " . scalar (keys %scoreboard) . "  players\n";

		$message .= center('Recently given answers', 50, '-') . "\n";
		for (keys %recentAnswers) {
			$message .= "* $_ - $recentAnswers{$_}\n";
		}

		message $message, "list";
	}

	1;