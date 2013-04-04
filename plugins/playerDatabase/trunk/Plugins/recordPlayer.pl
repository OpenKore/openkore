#############################################
# This plugin is licensed under the GNU GPL #
# Copyright 2005 original plugin by iseo    #
# Adapted by Alison and KeplerBR            #
#############################################

package playerRecord;
	use strict;
	use warnings; 
	use Plugins;
	use Log qw(message error);
	use Globals;
	use Settings;
	use Utils qw(binAdd existsInList getFormattedDate swrite getHex);
	use DBI;

# Register Plugin and Hooks
	Plugins::register("PlayerRecord", "playerRecord", \&on_unload, \&on_reload);
		my $hooks = Plugins::addHooks(
		['charNameUpdate', \&write_player],					# Escrever os dados gerais
		['packet/show_eq', \&write_player_equips],			# Escrever os dados dos equipamentos
		['packet/character_name', \&list_player_id_name],	# Salvar na lista o ID <-> Nick do char
		['mainLoop::setTitle',  \&change_title, undef],		# Alterar o título da janela
		# Dos Top10
		['packet/top10_alchemist_rank', \&top10_main, 'topalchemist'],
		['packet/top10_blacksmith_rank', \&top10_main, 'topblacksmith'],
		['packet/top10_taekwon_rank', \&top10_main, 'toptaekwon'],
		);

	##################################
	# Definition of global variables #
	# Referring to the window title
	my $playersNew = 0;
	my $playersUpdated = 0;
	my $showEqNew = 0;
	my $showEqUpdated = 0;

	# Database Information
	my $database = "broplayer";
	my $hostname= "127.0.0.1";
	my $port = 3306;
	my $table = "personagem";
	my $user = "root";
	my $password = "";
	my $dsn = "DBI:mysql:database=$database;host=$hostname;port=$port;mysql_enable_utf8=1";
	my $dbh = DBI->connect($dsn, $user, $password); # Connect to the database

	# Other
	my $exist = 0;

	######################
	# Sub's basic plugin #
	#On Unload code
	sub on_unload {
		Plugins::delHooks($hooks);
		$dbh->disconnect; # Desconectar banco de dados
	}

	#On Reload code
	sub on_reload {
		$playersNew = 0;
		$playersUpdated = 0;
		$showEqNew = 0;
		$showEqUpdated = 0;
	}

	################################
	# Write general data of player #
	sub write_player {
		my $hookname = shift;
		my $args = shift;

		# Account and Char Information
		my $targetAccountId = $args->{player}{nameID};
		my $targetId = $args->{player}{nameID};

		# Name and Sex Information
		my $targetName = $args->{player}{name};
		my $targetSex = $args->{player}{sex};

		# Hair and Cloth Information
		my $targetHairColor = $args->{player}{hair_color};
		my $targetHairStyle = $args->{player}{hair_style};
		my $targetclothColor = $args->{player}{clothes_color};

		# Job Information
		my $targetJob = $args->{player}{jobID};

		# Lvl Information
		my $targetLvl = $args->{player}{lv};

		# Party Information
		my $targetPartyName = $args->{player}{party}{name};

		# Guild Information
		my $targetGuildId = unpack("v1", $args->{player}{guildID});
		my $targetGuildEmblemId = unpack("v1", $args->{player}{emblemID});
		my $targetGuildName = $args->{player}{guild}{name};
		my $targetGuildPosition = $args->{player}{guild}{title};

		# Equips Head Information
		my $targetEquipHeadTop = $args->{player}{headgear}{top};
		my $targetEquipHeadMid = $args->{player}{headgear}{mid};
		my $targetEquipHeadLow = $args->{player}{headgear}{low};

		# Equips Body Information
		my $targetEquipBodyWeapon = $args->{player}{weapon};
		my $targetEquipBodyShield = $args->{player}{shield};
		my $targetEquipBodyShoes = $args->{player}{shoes};

		# Time Information
		my $targetTime = localtime time;

		# Validators
		if(not defined $targetclothColor) { $targetclothColor = 0; }
		if(not defined $targetEquipBodyShoes) { $targetEquipBodyShoes = 0; }
		if(not defined $targetPartyName or $targetPartyName eq "") { $targetPartyName = "NULL"; }
		if(not defined $targetGuildName or $targetGuildName eq "") { $targetGuildName = "NULL"; }
		if(not defined $targetGuildPosition or $targetGuildPosition eq "" ) { $targetGuildPosition = "NULL"; }

		# Convert
		$targetAccountId = int($targetAccountId);				$targetId = int($targetId);
		$targetSex = int($targetSex);							$targetHairColor = int($targetHairColor);
		$targetHairStyle = int($targetHairStyle);				$targetclothColor = int($targetclothColor);
		$targetJob = int($targetJob);							$targetLvl = int($targetLvl);
		$targetEquipHeadTop = int($targetEquipHeadTop);			$targetEquipHeadMid =  int($targetEquipHeadMid);
		$targetEquipHeadLow = int($targetEquipHeadLow);			$targetEquipBodyWeapon = int($targetEquipBodyWeapon);
		$targetEquipBodyShield = int($targetEquipBodyShield);	$targetEquipBodyShoes = int($targetEquipBodyShoes);

		# Query for validate if charId exist
		my $sth = $dbh->prepare("SELECT * FROM personagem WHERE charName = ?")
			or die "Couldn't prepare statement";
		$sth->execute($targetName) 
			or die "Couldn't execute the query";
		$sth->finish;
		
		if ($sth->rows > 0) {
			$exist = 1;
		} else {
			$exist = 0;
		}

		# Query to Update
		if ($exist == 1) {
			my $sth = $dbh->prepare("UPDATE personagem SET accountId = ?, charId = ?, charName = ?, sex = ?, hairColor = ?, hairStyle = ?, clothColor = ?, job = ?, lvl = ?, partyName = ?, guildId = ?, guildEmblemId = ?, guildName = ?, guildPosition = ?, equipHeadTop = ?, equipHeadMid = ?, equipHeadLow = ?, equipBodyWeapon = ?, equipBodyShield =  ?, equipBodyShoes = ?, DateandHour = ? WHERE charId = ?") 
				or die "Couldn't prepare statement";
			$sth->execute($targetAccountId, $targetId, "$targetName", $targetSex, $targetHairColor, $targetHairStyle, $targetclothColor, $targetJob, $targetLvl, "$targetPartyName", $targetGuildId, $targetGuildEmblemId, "$targetGuildName", "$targetGuildPosition", $targetEquipHeadTop, $targetEquipHeadMid, $targetEquipHeadLow, $targetEquipBodyWeapon, $targetEquipBodyShield, $targetEquipBodyShoes, "$targetTime", $targetId)
				or die "Couldn't execute the query";
			$sth->finish;
			message swrite("[PLAYER RERCORD] @<<<<<<<<<<<<<<<<<<<<<<<< (@<<<<<<<<<<)  [ALTERED]",
							[$targetName, $targetAccountId]), "playerRecord";
			
			$playersUpdated++;
		} else {
		# Query to Insert
			my $sth = $dbh->prepare("INSERT into personagem(accountId, charId, charName, sex, hairColor, hairStyle, clothColor, job, lvl, partyName, guildId, guildEmblemId, guildName,guildPosition, equipHeadTop, equipHeadMid, equipHeadLow, equipBodyWeapon, equipBodyShield, equipBodyShoes, DateandHour) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)")
				or die "Couldn't prepare statement";
			$sth->execute($targetAccountId, $targetId, $targetName, $targetSex, $targetHairColor, $targetHairStyle, $targetclothColor, $targetJob, $targetLvl, $targetPartyName,  $targetGuildId, $targetGuildEmblemId, $targetGuildName, $targetGuildPosition, $targetEquipHeadTop, $targetEquipHeadMid, $targetEquipHeadLow, $targetEquipBodyWeapon, $targetEquipBodyShield, $targetEquipBodyShoes, $targetTime)
				or die "Couldn't execute the query";
			$sth->finish;
			message swrite("[PLAYER RERCORD] @<<<<<<<<<<<<<<<<<<<<<<<< (@<<<<<<<<<<)  [INSERTED]",
							[$targetName, $targetAccountId]), "playerRecord";

			$playersNew++;
		}

		# Request to get the remaining data
		my $numberActor = Match::player($targetName);
		$messageSender->sendShowEquipPlayer($numberActor->{ID});
	}

	##################################
	# Write data equipment of player #
	sub write_player_equips {
	my ($self, $args) = @_;
	my $name = $args->{name};

	my %equips = (
		'1'		=> { slotName => 'lowHead'},			'2'		=> { slotName => 'rightHand'},
		'4'		=> { slotName => 'robe'},				'8'		=> { slotName => 'rightAccessory'},
		'16'	=> { slotName => 'armor'},				'32'	=> { slotName => 'leftHand'},
		'64'	=> { slotName => 'shoes'},				'128'	=> { slotName => 'leftAccessory'},
		'256'	=> { slotName => 'topHead'},			'512'	=> { slotName => 'midHead'},
		'1024'	=> { slotName => 'costumeTopHand'},		'2048'	=> { slotName => 'costumeMidHead'},
		'4096'	=> { slotName => 'costumeLowHead'},
	);

	for (my $offset = 0; $offset < length($args->{equips_info}); $offset += 28) {
		my ($ID, $slot, $refine, $slot1, $slot2, $slot3, $slot4) = unpack("x2 v x4 v6 x8", substr($args->{equips_info}, $offset, 28));

		# Interpreting the equipment data
		if ($slot1 == 255) {
			# Collect the nick of who created the weapon
			$slot3 = unpack("x16 a4 x10", substr($args->{equips_info}, $offset, 28));
			$slot3 = getHex($slot3);
			$messageSender->sendRaw("68 03 $slot3");
			$slot3 = unpack("V1", $slot3);

			# Element of weapon
			$slot2 = $slot2 % 10;
			
			# Enjoy the slot4 to send the force
			$slot4 = ($slot2 >> 8) / 5;
			
		# The organization of the data will be as follows
		#  slot1 -> 255					|	slot3 -> ID with the char
		#  slot2 -> Element of weapon	|	slot4 -> Force weapon
		}

		if (not exists $equips{$slot}) {
			# If the equipment occupies more than one slot,
			if ($slot == 34) {
				# leftHand + rightHand
				$equips{32}{ID} = $ID;					$equips{2}{ID} = $ID;
				$equips{32}{refine} = $refine / 256;	$equips{2}{refine} = $refine / 256;
				$equips{32}{slot1} = $slot1;			$equips{2}{slot1} = $slot1;
				$equips{32}{slot2} = $slot2;			$equips{2}{slot2} = $slot2;
				$equips{32}{slot3} = $slot3;			$equips{2}{slot3} = $slot3;
				$equips{32}{slot4} = $slot4;			$equips{2}{slot4} = $slot4;
			} elsif ($slot == 513) {
				# midHead + lowHead
				$equips{512}{ID} = $ID;					$equips{1}{ID} = $ID;
				$equips{512}{refine} = $refine / 256;	$equips{1}{refine} = $refine / 256;
				$equips{512}{slot1} = $slot1;			$equips{1}{slot1} = $slot1;
				$equips{512}{slot2} = $slot2;			$equips{1}{slot2} = $slot2;
				$equips{512}{slot3} = $slot3;			$equips{1}{slot3} = $slot3;
				$equips{512}{slot4} = $slot4;			$equips{1}{slot4} = $slot4;
			} elsif ($slot == 768) {
				# topHead + midHead
				$equips{256}{ID} = $ID;					$equips{512}{ID} = $ID;
				$equips{256}{refine} = $refine / 256;	$equips{512}{refine} = $refine / 256;
				$equips{256}{slot1} = $slot1;			$equips{512}{slot1} = $slot1;
				$equips{256}{slot2} = $slot2;			$equips{512}{slot2} = $slot2;
				$equips{256}{slot3} = $slot3;			$equips{512}{slot3} = $slot3;
				$equips{256}{slot4} = $slot4;			$equips{512}{slot4} = $slot4;
			} elsif ($slot == 769) {
				# topHead + midHead + lowHead
				$equips{256}{ID} = $ID;					$equips{512}{ID} = $ID;					$equips{1}{ID} = $ID;
				$equips{256}{refine} = $refine / 256;	$equips{512}{refine} = $refine / 256;	$equips{1}{refine} = $refine / 256;
				$equips{256}{slot1} = $slot1;			$equips{512}{slot1} = $slot1;			$equips{1}{slot1} = $slot1;
				$equips{256}{slot2} = $slot2;			$equips{512}{slot2} = $slot2;			$equips{1}{slot2} = $slot2;
				$equips{256}{slot3} = $slot3;			$equips{512}{slot3} = $slot3;			$equips{1}{slot3} = $slot3;
				$equips{256}{slot4} = $slot4;			$equips{512}{slot4} = $slot4;			$equips{1}{slot4} = $slot4;
			}
		} else {
			# If the equipment occupies only one slot
			$equips{$slot}{ID} = $ID;
			$equips{$slot}{refine} = $refine / 256;
			$equips{$slot}{slot1} = $slot1;
			$equips{$slot}{slot2} = $slot2;
			$equips{$slot}{slot3} = $slot3;
			$equips{$slot}{slot4} = $slot4;
			}
		}

	# Check if at any slot value was nil. If you have been, will put 0
	for (my $analiseEquips = 1; $analiseEquips < 4097; $analiseEquips = $analiseEquips * 2) {
		if (not defined $equips{$analiseEquips}{ID}) {
			$equips{$analiseEquips}{ID} = '0';
			$equips{$analiseEquips}{refine} = '0';
			$equips{$analiseEquips}{slot1} = '0';
			$equips{$analiseEquips}{slot2} = '0';
			$equips{$analiseEquips}{slot3} = '0';
			$equips{$analiseEquips}{slot4} = '0';
		}
	}

	# Query for validate if charName exist
	my $sth = $dbh->prepare("SELECT * FROM equips WHERE charName = ?") 
		or die "Couldn't prepare statement";
	$sth->execute($name) 
		or die "Couldn't execute the query";
	$sth->finish;

	if ($sth->rows > 0) {
		$exist = 1;
	} else {
		$exist = 0;
	}

	# Time Information
	my $targetTime = localtime time;

		if ($exist == 1) {
		# ShowEq player already added anteriorly, will check if it has news
			# Check if you have news in showEq
			my $sth = $dbh->prepare("SELECT * FROM equips WHERE charName = ? ORDER BY historic LIMIT 1") 
				or die "Couldn't prepare statement";
			$sth->execute($name) 
				or die "Couldn't execute the query";
				
			my @data = $sth->fetchrow_array();
			$sth->finish;

			my $analiseEquips = 1;
			my $novidade = 0;

			# * Will begin on the column of equipment (3°, but as the count starts at 0, it is 2);
			# * The table "equips" has 66 columns, but the analysis is only of 3° to 65°;
			# * As the analysis will be performed in blocks of equipment, and each machine has
			#   about 6 columns, will go from 6 to 6;
			# * As there are only three equips visual then left them. So it has a special space
			#   for only analyzes them.

			for (my $colunaAtual = 2; ($colunaAtual < 63) || ($novidade < 0); $colunaAtual += 6) {
				if ($colunaAtual == 62) {
					# If equips for visual
					$novidade = 1 if ($equips{$analiseEquips}{ID} != $data[$colunaAtual]);
					$novidade = 1 if ($equips{$analiseEquips * 2}{ID} != $data[$colunaAtual + 1]);
					$novidade = 1 if ($equips{$analiseEquips * 4}{ID} != $data[$colunaAtual + 2]);
					
				} else {
					# If the equipment to normal
					$novidade = 1 if ($equips{$analiseEquips}{ID} != $data[$colunaAtual]);
					$novidade = 1 if ($equips{$analiseEquips}{refine} != $data[$colunaAtual + 1]);
					$novidade = 1 if ($equips{$analiseEquips}{slot1} != $data[$colunaAtual + 2]);
						if ($data[$colunaAtual + 2] == 255) {
							# Case for weapons created by players
							$novidade = 1 if ($equips{$analiseEquips}{slot2} ne $data[$colunaAtual + 3]);
							$novidade = 1 if ($equips{$analiseEquips}{slot3} ne $data[$colunaAtual + 4]);
							$novidade = 1 if ($equips{$analiseEquips}{slot4} ne $data[$colunaAtual + 5]);
						} else {
							# If the weapons to "normal"
							$novidade = 1 if ($equips{$analiseEquips}{slot2} != $data[$colunaAtual + 3]);
							$novidade = 1 if ($equips{$analiseEquips}{slot3} != $data[$colunaAtual + 4]);
							$novidade = 1 if ($equips{$analiseEquips}{slot4} != $data[$colunaAtual + 5]);
						}
					}
				$analiseEquips = $analiseEquips * 2;
			}

			if ($novidade == 1) {
				# If you have news, change the "historic" the old and insert new showEq
				$sth = $dbh->prepare("UPDATE equips SET historic = 1 WHERE charName = ?") 
					or die "Couldn't prepare statement";
				$sth->execute($name)
					or die "Couldn't execute the query";
				$sth->finish;

			# Create new record
			my $sth = $dbh->prepare("insert into equips(charName," .
									"historic, " .
									"lowHeadId, lowHeadRefine, lowHeadSlot1, lowHeadSlot2, lowHeadSlot3, lowHeadSlot4," .
									"rightHandId, rightHandRefine, rightHandSlot1, rightHandSlot2, rightHandSlot3, rightHandSlot4," .
									"robeId, robeRefine, robeSlot1, robeSlot2, robeSlot3, robeSlot4," .
									"rightAccessoryId, rightAccessoryRefine, rightAccessorySlot1, rightAccessorySlot2, rightAccessorySlot3, rightAccessorySlot4," .
									"armorId, armorRefine, armorSlot1, armorSlot2, armorSlot3, armorSlot4," .
									"leftHandId, leftHandRefine, leftHandSlot1, leftHandSlot2, leftHandSlot3, leftHandSlot4," .
									"shoesId, shoesRefine, shoesSlot1, shoesSlot2, shoesSlot3, shoesSlot4," .
									"leftAccessoryId, leftAccessoryRefine, leftAccessorySlot1, leftAccessorySlot2, leftAccessorySlot3, leftAccessorySlot4," .
									"topHeadId, topHeadRefine, topHeadSlot1, topHeadSlot2, topHeadSlot3, topHeadSlot4," .
									"midHeadId, midHeadRefine, midHeadSlot1, midHeadSlot2, midHeadSlot3, midHeadSlot4," .
									"costumeTopHandId, costumeMidHeadId, costumeLowHeadId, DateandHour)" .
									"values(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,  ?, ?, ?, ?, ?)") 
				or die "Couldn't prepare statement";
			$sth->execute($name,
						  '0',
						  $equips{1}{ID},    $equips{1}{refine},   $equips{1}{slot1},   $equips{1}{slot2},   $equips{1}{slot3},   $equips{1}{slot4},
  						  $equips{2}{ID},    $equips{2}{refine},   $equips{2}{slot1},   $equips{2}{slot2},   $equips{2}{slot3},   $equips{2}{slot4},
						  $equips{4}{ID},    $equips{4}{refine},   $equips{4}{slot1},   $equips{4}{slot2},   $equips{4}{slot3},   $equips{4}{slot4},
  						  $equips{8}{ID},    $equips{8}{refine},   $equips{8}{slot1},   $equips{8}{slot2},   $equips{8}{slot3},   $equips{8}{slot4},
						  $equips{16}{ID},   $equips{16}{refine},  $equips{16}{slot1},  $equips{16}{slot2},  $equips{16}{slot3},  $equips{16}{slot4},
  						  $equips{32}{ID},   $equips{32}{refine},  $equips{32}{slot1},  $equips{32}{slot2},  $equips{32}{slot3},  $equips{32}{slot4},
						  $equips{64}{ID},   $equips{64}{refine},  $equips{64}{slot1},  $equips{64}{slot2},  $equips{64}{slot3},  $equips{64}{slot4},
  						  $equips{128}{ID},  $equips{128}{refine}, $equips{128}{slot1}, $equips{128}{slot2}, $equips{128}{slot3}, $equips{128}{slot4},
  						  $equips{256}{ID},  $equips{256}{refine}, $equips{256}{slot1}, $equips{256}{slot2}, $equips{256}{slot3}, $equips{256}{slot4},
  						  $equips{512}{ID},  $equips{512}{refine}, $equips{512}{slot1}, $equips{512}{slot2}, $equips{512}{slot3}, $equips{512}{slot4},
						  $equips{1024}{ID}, $equips{2048}{ID},    $equips{4096}{ID},   $targetTime)
				or die "Couldn't execute the query";
				$sth->finish;
				message swrite("[PLAYER RERCORD] @<<<<<<<<<<<<<<<<<<<<<<<<      [ALTERED SHOW EQ]",
								[$name]), "playerRecord";
				
				$showEqUpdated++;
			}
		} else {
		# Player new, will add it to the database
		# Query to Insert
			my $sth = $dbh->prepare("insert into equips(charName," .
									"historic, " .
									"lowHeadId, lowHeadRefine, lowHeadSlot1, lowHeadSlot2, lowHeadSlot3, lowHeadSlot4," .
									"rightHandId, rightHandRefine, rightHandSlot1, rightHandSlot2, rightHandSlot3, rightHandSlot4," .
									"robeId, robeRefine, robeSlot1, robeSlot2, robeSlot3, robeSlot4," .
									"rightAccessoryId, rightAccessoryRefine, rightAccessorySlot1, rightAccessorySlot2, rightAccessorySlot3, rightAccessorySlot4," .
									"armorId, armorRefine, armorSlot1, armorSlot2, armorSlot3, armorSlot4," .
									"leftHandId, leftHandRefine, leftHandSlot1, leftHandSlot2, leftHandSlot3, leftHandSlot4," .
									"shoesId, shoesRefine, shoesSlot1, shoesSlot2, shoesSlot3, shoesSlot4," .
									"leftAccessoryId, leftAccessoryRefine, leftAccessorySlot1, leftAccessorySlot2, leftAccessorySlot3, leftAccessorySlot4," .
									"topHeadId, topHeadRefine, topHeadSlot1, topHeadSlot2, topHeadSlot3, topHeadSlot4," .
									"midHeadId, midHeadRefine, midHeadSlot1, midHeadSlot2, midHeadSlot3, midHeadSlot4," .
									"costumeTopHandId, costumeMidHeadId, costumeLowHeadId, DateandHour)" .
									"values(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,  ?, ?, ?, ?, ?)") 
				or die "Couldn't prepare statement";
			$sth->execute($name,
						  '0',
						  $equips{1}{ID},    $equips{1}{refine},   $equips{1}{slot1},   $equips{1}{slot2},   $equips{1}{slot3},   $equips{1}{slot4},
  						  $equips{2}{ID},    $equips{2}{refine},   $equips{2}{slot1},   $equips{2}{slot2},   $equips{2}{slot3},   $equips{2}{slot4},
						  $equips{4}{ID},    $equips{4}{refine},   $equips{4}{slot1},   $equips{4}{slot2},   $equips{4}{slot3},   $equips{4}{slot4},
  						  $equips{8}{ID},    $equips{8}{refine},   $equips{8}{slot1},   $equips{8}{slot2},   $equips{8}{slot3},   $equips{8}{slot4},
						  $equips{16}{ID},   $equips{16}{refine},  $equips{16}{slot1},  $equips{16}{slot2},  $equips{16}{slot3},  $equips{16}{slot4},
  						  $equips{32}{ID},   $equips{32}{refine},  $equips{32}{slot1},  $equips{32}{slot2},  $equips{32}{slot3},  $equips{32}{slot4},
						  $equips{64}{ID},   $equips{64}{refine},  $equips{64}{slot1},  $equips{64}{slot2},  $equips{64}{slot3},  $equips{64}{slot4},
  						  $equips{128}{ID},  $equips{128}{refine}, $equips{128}{slot1}, $equips{128}{slot2}, $equips{128}{slot3}, $equips{128}{slot4},
  						  $equips{256}{ID},  $equips{256}{refine}, $equips{256}{slot1}, $equips{256}{slot2}, $equips{256}{slot3}, $equips{256}{slot4},
  						  $equips{512}{ID},  $equips{512}{refine}, $equips{512}{slot1}, $equips{512}{slot2}, $equips{512}{slot3}, $equips{512}{slot4},
						  $equips{1024}{ID}, $equips{2048}{ID},    $equips{4096}{ID},   $targetTime)
				or die "Couldn't execute the query";
			$sth->finish;
			message swrite("[PLAYER RERCORD] @<<<<<<<<<<<<<<<<<<<<<<<<     [INSERTED SHOW EQ]",
							[$name]), "playerRecord";

			$showEqNew++;
		}
	}

	#################################################
	# Write a list of ID <-> Nick of chars          #
	# This will be used when displaying the weapon, #
	# to show the nick of the person who created    #
	sub list_player_id_name {
		my $hookname = shift;
		my $args = shift;

		# Defining variables
		my $id = unpack("V1", $args->{ID});
		my $nick = $args->{name};
		
		# Query for validate if ID exist
		my $sth = $dbh->prepare("SELECT * FROM list_id_nick WHERE ID = ?")
			or die "Couldn't prepare statement";
		$sth->execute($id) 
			or die "Couldn't execute the query";
		$sth->finish;
		
		if ($sth->rows > 0) {
			$exist = 1;
		} else {
			$exist = 0;
		}

		if ($exist == 1) {
		# Query to Update
			my $sth = $dbh->prepare("UPDATE list_id_nick SET ID = ?, nick = ? WHERE ID = ?") 
				or die "Couldn't prepare statement";
			$sth->execute($id, $nick, $id)
				or die "Couldn't execute the query";
			$sth->finish;
			message swrite("[WRITE PLAYER] @<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<  [ALTERED]",
							[$id, $nick]), "playerRecord";
		} else {
		# Query to Insert
			my $sth = $dbh->prepare("INSERT into list_id_nick(ID, nick) values(?,?)")
				or die "Couldn't prepare statement";
			$sth->execute($id, $nick)
				or die "Couldn't execute the query";
			$sth->finish;
			message swrite("[WRITE PLAYER] @<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<  [ALTERED]",
							[$id, $nick]), "playerRecord";
		}
	}

	###########################
	# Change the window title #
	sub change_title {
		my (undef, $args) = @_;
		$args->{return} = "Players new: $playersNew |Players updated: $playersUpdated |ShowEq new: $showEqNew |ShowEq updated: $showEqUpdated";
	}

	######################################################
	## The TOP10
	
	# Definition of variables
	my (@nickList, @pontoList);
	my ($i, $msg);
	my ($d1, $d2, $d3,	$d4, $d5, $d6);

	# Listings
	sub top10_makeList {
		for ($i = 0; $i < 10; $i++) {
			$nickList[$i] = unpack("Z24", substr($msg, 2 + (24*$i), 24));
		}
		for ($i = 0; $i < 10; $i++) {
			$pontoList[$i] = unpack("V1", substr($msg, 242 + ($i*4), 4));
		}
	}

	# Perform update Top10
	sub top10_main {
		# Prepare variables
		my ($self, $args) = @_;

		$msg = $args->{RAW_MSG};
		my $tableName = $_[2];

		&top10_makeList;

		# Verify that already has content or not in table
		my $sthTamanhoTabela = $dbh->prepare("SELECT * FROM $tableName")
			or die "Couldn't prepare statement";
		$sthTamanhoTabela->execute
			or die "Couldn't execute the query";
		$sthTamanhoTabela->finish;

		if ($sthTamanhoTabela->rows == 0) {
			# Prepare query de envio
			my $sthEnvio = $dbh->prepare("INSERT into $tableName(lugar, nick, pontos) values(?,?,?)")
				|| die "Couldn't prepare statement";

			# Table is still empty
			for ($i = 0; $i<10; $i++) {
				# Send to database
				$sthEnvio->execute($i+1, $nickList[$i], $pontoList[$i])
					|| die "Couldn't execute the query";
				$sthEnvio->finish;
			}
			
			# Finish: See message
			message "[TOP10 LIST] $tableName created!\n";
		} else {
			# Prepare query's
			my $sthAtualizar = $dbh->prepare("UPDATE $tableName SET nick = ?, pontos = ?, d1 = ?, d2 = ?, d3 = ?, d4 = ?, d5 = ?, d6 = ? WHERE lugar = ?")
				|| die "Couldn't prepare statement";
			my $sthPesquisa = $dbh->prepare("SELECT * FROM $tableName WHERE lugar = ?")
				|| die "Couldn't prepare statement";
			my $sthMudarLugarDesc = $dbh->prepare("UPDATE $tableName SET lugar = ? WHERE lugar = ? ORDER BY pontos DESC LIMIT 1")
				|| die "Couldn't prepare statement";
			my $sthMudarLugarAsc = $dbh->prepare("UPDATE $tableName SET lugar = ? WHERE lugar = ? ORDER BY pontos ASC LIMIT 1")
				|| die "Couldn't prepare statement";

			# Sending loop
			for ($i = 0; $i<10; $i++) {
				$sthPesquisa->execute($i+1) 
					or die "Couldn't execute the query";

				my @data = $sthPesquisa->fetchrow_array();
				$sthPesquisa->finish;

				# Check if there have been changes in the positions of places
				if ($data[1] ne $nickList[$i]) {
					# The list nickList starts from position 1 and is increasing...
					if ($i == 9) {
						# If you have a new player on the list:
						#  Simply have to delete the old scoring
						$d1 = '0'; $d2 = '0';  $d3 = '0'; $d4 = '0'; $d5 = '0'; $d6 = '0';

						# Enviar para o banco de dados
						$sthAtualizar->execute($nickList[$i], $pontoList[$i],
										   $d1, $d2, $d3, $d4, $d5, $d6,
										   $i+1) || die "Couldn't execute the query";
						$sthAtualizar->finish;
					} else {
						# If you have had a change in the positions of the players who were already among the list:
						#  Change the value of 'lugar' to +1 be relegated than and -1 of which will be promoted
						$sthMudarLugarAsc->execute($i+1, $i+2)
							|| die "Couldn't execute the query";
						$sthMudarLugarAsc->finish;

						$sthMudarLugarDesc->execute($i+2, $i+1)
							|| die "Couldn't execute the query";
						$sthMudarLugarDesc->finish;

						# To complete the changes, will repeat the loop
						$i--;
					}
				} else {
					# If you have anything that will do everything normally...
					# atual       |:| a 1 dia  |:| a 2 dias |:| a 3 dias |:| a 4 dias |:| a 5 dias |:| a 6 dias
					# pontos -> 2 |:| d1 -> 3  |:| d2 -> 4  |:| d3 -> 5  |:| d4 -> 6  |:| d5 -> 7  |:| d6 -> 8
					$d1 = $data[2]; $d2 = $data[3]; $d3 = $data[4];
					$d4 = $data[5]; $d5 = $data[6]; $d6 = $data[7];

					# Send to database
					$sthAtualizar->execute($nickList[$i], $pontoList[$i],
									   $d1, $d2, $d3, $d4, $d5, $d6,
									   $i+1) || die "Couldn't execute the query";
					$sthAtualizar->finish;
				}
			}
			
			# Finish: See message
			message "[TOP10 LIST] $tableName updated!\n";
		}

		# Finish: Clear variables
		@nickList = ();	@pontoList = ();
	}

	1;