#########################################################################
#  OpenKore - Miscellaneous functions
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision$
#  $Id$
#
#########################################################################
##
# MODULE DESCRIPTION: Miscellaneous functions
#
# This module contains functions that do not belong in any other modules.
# The difference between Misc.pm and Utils.pm is that Misc.pm can have
# dependancies on other Kore modules.

package Misc;

use strict;
use Exporter;
use base qw(Exporter);

use Globals;
use Log qw(message warning error);
use Plugins;
use FileParsers;
use Settings;
use Utils;
use Network::Send qw(sendToClientByInject sendCharCreate sendCharDelete sendCharLogin sendMove);

our @EXPORT = qw(
	auth
	configModify
	setTimeout
	saveConfigFile

	debug_showSpots

	calcRectArea
	center
	charSelectScreen
	checkFieldWalkable
	checkFollowMode
	checkMonsterCleanness
	closestWalkableSpot
	createCharacter
	getFieldPoint
	getPortalDestName
	getPlayer
	getSpellName
	objectAdded
	objectInsideSpell
	objectIsMovingTowardsPlayer
	printItemDesc
	stopAttack
	stripLanguageCode
	whenStatusActive
	whenStatusActiveMon
	whenStatusActivePL
	whenGroundStatus

	launchURL
	);



#######################################
#######################################
#CONFIG MODIFIERS
#######################################
#######################################

sub auth {
	my $user = shift;
	my $flag = shift;
	if ($flag) {
		message "Authorized user '$user' for admin\n", "success";
	} else {
		message "Revoked admin privilages for user '$user'\n", "success";
	}	
	$overallAuth{$user} = $flag;
	writeDataFile("$Settings::control_folder/overallAuth.txt", \%overallAuth);
}

##
# configModify(key, val, [silent])
# key: a key name.
# val: the new value.
# silent: if set to 1, do not print a message to the console.
#
# Changes the value of the configuration variable $key to $val.
# %config and config.txt will be updated.
sub configModify {
	my $key = shift;
	my $val = shift;
	my $silent = shift;

	Plugins::callHook('configModify', {
		key => $key,
		val => $val,
		silent => $silent
	});

	message("Config '$key' set to $val\n", "info") unless ($silent);
	$config{$key} = $val;
	saveConfigFile();
}

##
# saveConfigFile()
#
# Writes %config to config.txt.
sub saveConfigFile {
	writeDataFileIntact($Settings::config_file, \%config);
}

sub setTimeout {
	my $timeout = shift;
	my $time = shift;
	$timeout{$timeout}{'timeout'} = $time;
	message "Timeout '$timeout' set to $time\n", "info";
	writeDataFileIntact2("$Settings::control_folder/timeouts.txt", \%timeout);
}


#######################################
#######################################
#DEBUGGING FUNCTIONS
#######################################
#######################################

our %debug_showSpots_list;

sub debug_showSpots {
	return unless $config{XKore};
	my $ID = shift;
	my $spots = shift;
	my $special = shift;

	if ($debug_showSpots_list{$ID}) {
		foreach (@{$debug_showSpots_list{$ID}}) {
			my $msg = pack("C*", 0x20, 0x01) . pack("L", $_);
			sendToClientByInject(\$remote_socket, $msg);
		}
	}

	my $i = 1554;
	$debug_showSpots_list{$ID} = [];
	foreach (@{$spots}) {
		next if !defined $_;
		my $msg = pack("C*", 0x1F, 0x01)
			. pack("L*", $i, 1550)
			. pack("S*", $_->{x}, $_->{y})
			. pack("C*", 0x93, 0);
		sendToClientByInject(\$remote_socket, $msg);
		sendToClientByInject(\$remote_socket, $msg);
		push @{$debug_showSpots_list{$ID}}, $i;
		$i++;
	}

	if ($special) {
		my $msg = pack("C*", 0x1F, 0x01)
			. pack("L*", 1553, 1550)
			. pack("S*", $special->{x}, $special->{y})
			. pack("C*", 0x83, 0);
		sendToClientByInject(\$remote_socket, $msg);
		sendToClientByInject(\$remote_socket, $msg);
		push @{$debug_showSpots_list{$ID}}, 1553;
	}
}


#######################################
#######################################
# OTHER STUFF
#######################################
#######################################


##
# calcRectArea($x, $y, $radius)
# Returns: an array with position hashes. Each has contains an x and a y key.
#
# Creates a rectangle with center ($x,$y) and radius $radius,
# and returns a list of positions of the border of the rectangle.
sub calcRectArea {
	my ($x, $y, $radius) = @_;
	my (%topLeft, %topRight, %bottomLeft, %bottomRight);
		
	sub capX {
		return 0 if ($_[0] < 0);
		return $field{width} - 1 if ($_[0] >= $field{width});
		return int $_[0];
	}
	sub capY {
		return 0 if ($_[0] < 0);
		return $field{height} - 1 if ($_[0] >= $field{height});
		return int $_[0];
	}

	# Get the avoid area as a rectangle
	$topLeft{x} = capX($x - $radius);
	$topLeft{y} = capY($y + $radius);
	$topRight{x} = capX($x + $radius);
	$topRight{y} = capY($y + $radius);
	$bottomLeft{x} = capX($x - $radius);
	$bottomLeft{y} = capY($y - $radius);
	$bottomRight{x} = capX($x + $radius);
	$bottomRight{y} = capY($y - $radius);

	# Walk through the border of the rectangle
	# Record the blocks that are walkable
	my @walkableBlocks;
	for (my $x = $topLeft{x}; $x <= $topRight{x}; $x++) {
		if (checkFieldWalkable(\%field, $x, $topLeft{y})) {
			push @walkableBlocks, {x => $x, y => $topLeft{y}};
		}
	}
	for (my $x = $bottomLeft{x}; $x <= $bottomRight{x}; $x++) {
		if (checkFieldWalkable(\%field, $x, $bottomLeft{y})) {
			push @walkableBlocks, {x => $x, y => $bottomLeft{y}};
		}
	}
	for (my $y = $bottomLeft{y} + 1; $y < $topLeft{y}; $y++) {
		if (checkFieldWalkable(\%field, $topLeft{x}, $y)) {
			push @walkableBlocks, {x => $topLeft{x}, y => $y};
		}
	}
	for (my $y = $bottomRight{y} + 1; $y < $topRight{y}; $y++) {
		if (checkFieldWalkable(\%field, $topLeft{x}, $y)) {
			push @walkableBlocks, {x => $topRight{x}, y => $y};
		}
	}

	return @walkableBlocks;
}

##
# center(string, width, [fill])
#
# This function will center $string within a field $width characters wide,
# using $fill characters for padding on either end of the string for
# centering. If $fill is not specified, a space will be used.
sub center {
	my ($string, $width, $fill) = @_;

	$fill ||= ' ';
	my $left = int(($width - length($string)) / 2);
	my $right = ($width - length($string)) - $left;
	return $fill x $left . $string . $fill x $right;
}

# Returns: 0 if user chose to quit, 1 if user chose a character, 2 if user created or deleted a character
sub charSelectScreen {
	my %plugin_args = (autoLogin => shift);
	my $msg;
	my $mode;
	my $input2;

	TOP: {
		undef $mode;
		undef $input2;
	}

	for (my $num = 0; $num < @chars; $num++) {
		next unless $chars[$num];
		if (0) {
		$msg .= swrite(
			"-------  Character @< ---------",
			[$num],
			"Name: @<<<<<<<<<<<<<<<<<<<<<<<<",
			[$chars[$num]{'name'}],
			"Job:  @<<<<<<<      Job Exp: @<<<<<<<",
			[$jobs_lut{$chars[$num]{'jobID'}}, $chars[$num]{'exp_job'}],
			"Lv:   @<<<<<<<      Str: @<<<<<<<<",
			[$chars[$num]{'lv'}, $chars[$num]{'str'}],
			"J.Lv: @<<<<<<<      Agi: @<<<<<<<<",
			[$chars[$num]{'lv_job'}, $chars[$num]{'agi'}],
			"Exp:  @<<<<<<<      Vit: @<<<<<<<<",
			[$chars[$num]{'exp'}, $chars[$num]{'vit'}],
			"HP:   @||||/@||||   Int: @<<<<<<<<",
			[$chars[$num]{'hp'}, $chars[$num]{'hp_max'}, $chars[$num]{'int'}],
			"SP:   @||||/@||||   Dex: @<<<<<<<<",
			[$chars[$num]{'sp'}, $chars[$num]{'sp_max'}, $chars[$num]{'dex'}],
			"Zenny: @<<<<<<<<<<  Luk: @<<<<<<<<",
			[$chars[$num]{'zenny'}, $chars[$num]{'luk'}],
			"-------------------------------", []);
		}
		$msg .= sprintf("%3s %-34s %-15s %2d/%2d\n",
			$num, $chars[$num]{name},
			$jobs_lut{$chars[$num]{'jobID'}},
			$chars[$num]{lv}, $chars[$num]{lv_job});
	}

	if ($msg) {
		message
			"---------------------- Character List ----------------------\n".
			sprintf("%3s %-34s %-15s %-6s\n", '#', 'Name', 'Job', 'Lv').
			$msg.
			"------------------------------------------------------------\n",
			"connection";
	}
	return 1 if $xkore;

	Plugins::callHook('charSelectScreen', \%plugin_args);
	return $plugin_args{return} if ($plugin_args{return});

	if ($plugin_args{autoLogin} && @chars && $config{'char'} ne "" && $chars[$config{'char'}]) {
		sendCharLogin(\$remote_socket, $config{'char'});
		$timeout{'charlogin'}{'time'} = time;
		return 1;
	}


	if (@chars) {
		message("Type 'c' to create a new character, or type 'd' to delete a character.\n" .
			"Or choose a character by entering its number.\n", "input");
		while (!$quit) {
			my $input = $interface->getInput(-1);
			next if (!defined $input);

			my @args = parseArgs($input);

			if ($args[0] eq "c") {
				$mode = "create";
				($input2) = $input =~ /^.*? +(.*)/;
				last;
			} elsif ($args[0] eq "d") {
				$mode = "delete";
				($input2) = $input =~ /^.*? +(.*)/;
				last;
			} elsif ($args[0] eq "quit") {
				main::quit();
				return 0;
			} elsif ($input !~ /^\d+$/) {
				error "\"$input\" is not a valid character number.\n";
			} elsif (!$chars[$input]) {
				error "Character #$input does not exist.\n";
			} else {
				configModify('char', $input, 1);
				sendCharLogin(\$remote_socket, $config{'char'});
				$timeout{'charlogin'}{'time'} = time;
				return 1;
			}
		}
	} else {
		message("There are no characters on this account.\n", "connection");
		$mode = "create";
	}

	if ($mode eq "create") {
		my $message = "Please enter the desired properties for your characters, in this form:\n" .
				"(slot) \"(name)\" [(str) (agi) (vit) (int) (dex) (luk)]\n";
		message($message, "input") if ($input2 eq "");

		while (!$quit) {
			my $input;
			if ($input2 ne "") {
				$input = $input2;
				undef $input2;
			} else {
				$input = $interface->getInput(-1);
			}
			next if (!defined $input);
			goto TOP if ($input eq "quit");

			my @args = parseArgs($input);
			if (@args < 2) {
				error $message;
				next;
			}

			message "Creating character \"$args[1]\" in slot \"$args[0]\"...\n", "connection";
			last if (createCharacter(@args));
			message($message, "input");
		}

	} elsif ($mode eq "delete") {
		my $message = "Enter the number of the character you want to delete, and your email,\n" .
				"in this form: (slot) (email address)\n";
		message $message, "input" unless($input2 eq "");

		while (!$quit) {
			my $input;
			if ($input2 ne "") {
				$input = $input2;
				undef $input2;
			} else {
				$input = $interface->getInput(-1);
			}
			next if (!defined $input);
			goto TOP if ($input eq "quit");

			my @args = parseArgs($input);
			if (@args < 2) {
				error $message;
				next;
			} elsif ($args[0] !~ /^\d+/) {
				error "\"$args[0]\" is not a valid character number.\n";
				next;
			} elsif (!$chars[$args[0]]) {
				error "Character #$args[0] does not exist.\n";
				next;
			}

			warning "Are you ABSOLUTELY SURE you want to delete $chars[$args[0]]{name} ($args[0])? (y/n) ";
			$input = $interface->getInput(-1);
			if ($input eq "y") {
				sendCharDelete(\$remote_socket, $chars[$args[0]]{ID}, $args[1]);
				message "Deleting character $chars[$args[0]]{name}...\n", "connection";
				$AI::temp::delIndex = $args[0];
			} else {
				message "Deletion aborted\n", "info";
				goto TOP;
			}
			last;
		}
	}
	return 2;
}

##
# checkFieldWalkable(r_field, x, y)
# r_field: a reference to a field hash.
# x, y: the coordinate to check.
# Returns: 1 (true) or 0 (false).
#
# Check whether ($x, $y) on field $r_field is walkable.
sub checkFieldWalkable {
	my $p = getFieldPoint(@_);
	return ($p == 0 || $p == 3);
}

##
# checkFollowMode()
# Returns: 1 if in follow mode, 0 if not.
#
# Check whether we're current in follow mode.
sub checkFollowMode { 	 
	my $followIndex;
	if ($config{follow} && defined($followIndex = binFind(\@ai_seq, "follow"))) {
		return 1 if ($ai_seq_args[$followIndex]{following});
	}
	return 0;
}

##
# checkMonsterCleanness(ID)
# ID: the monster's ID.
#
# Checks whether a monster is "clean" (not being attacked by anyone).
sub checkMonsterCleanness {
	return 1 if (!$config{attackAuto});
	my $ID = shift;
	my $monster = $monsters{$ID};

	# If party attacked monster, or if monster attacked/missed party
	if ($monster->{'dmgFromParty'} > 0 || $monster->{'dmgToParty'} > 0 || $monster->{'missedToParty'} > 0) {
		return 1;
	}

	# If we're in follow mode
	if (defined(my $followIndex = binFind(\@ai_seq, "follow"))) {
		my $following = $ai_seq_args[$followIndex]{following};
		my $followID = $ai_seq_args[$followIndex]{ID};

		if ($following) {
			# And master attacked monster, or the monster attacked/missed master
			if ($monster->{dmgToPlayer}{$followID} > 0
			 || $monster->{missedToPlayer}{$followID} > 0
			 || $monster->{dmgFromPlayer}{$followID} > 0) {
				return 1;
			}
		}
	}

	# If monster attacked/missed you
	return 1 if ($monster->{'dmgToYou'} || $monster->{'missedYou'});

	# If monster hasn't been attacked by other players
	if (!binSize([keys %{$monster->{'missedFromPlayer'}}])
	 && !binSize([keys %{$monster->{'dmgFromPlayer'}}])
	 && !binSize([keys %{$monster->{'castOnByPlayer'}}])

	 # and it hasn't attacked any other player
	 && !binSize([keys %{$monster->{'missedToPlayer'}}])
	 && !binSize([keys %{$monster->{'dmgToPlayer'}}])
	 && !binSize([keys %{$monster->{'castOnToPlayer'}}])
	) {
		# The monster might be getting lured by another player.
		# So we check whether it's walking towards any other player, but only
		# if we haven't already attacked the monster.
		if ($monster->{'dmgFromYou'} || $monster->{'missedFromYou'}) {
			return 1;
		} else {
			return objectIsMovingTowardsPlayer($monster);
		}
	}

	# The monster didn't attack you.
	# Other players attacked it, or it attacked other players.
	if ($monster->{'dmgFromYou'} || $monster->{'missedFromYou'}) {
		# If you have already attacked the monster before, then consider it clean
		return 1;
	}
	# If you haven't attacked the monster yet, it's unclean.

	return 0;
}

##
# closestWalkableSpot(r_field, pos)
# r_field: a reference to a field hash.
# pos: reference to a position hash (which contains 'x' and 'y' keys).
# Returns: 1 if %pos has been modified, 0 of not.
#
# If the position specified in $pos is walkable, this function will do nothing.
# If it's not walkable, this function will find the closest position that is walkable (up to 2 blocks away),
# and modify the x and y values in $pos.
sub closestWalkableSpot {
	my $r_field = shift;
	my $pos = shift;

	foreach my $z ( [0,0], [0,1],[1,0],[0,-1],[-1,0], [-1,1],[1,1],[1,-1],[-1,-1],[0,2],[2,0],[0,-2],[-2,0] ) {
		next if !checkFieldWalkable($r_field, $pos->{'x'} + $z->[0], $pos->{'y'} + $z->[1]);
		$pos->{'x'} += $z->[0];
		$pos->{'y'} += $z->[1];
		return 1;
	}
	return 0;
}

##
# createCharacter(slot, name, [str,agi,vit,int,dex,luk] = 5)
# slot: the slot in which to create the character (1st slot is 0).
# name: the name of the character to create.
#
# Create a new character. You must be currently connected to the character login server.
sub createCharacter {
	my $slot = shift;
	my $name = shift;
	my ($str,$agi,$vit,$int,$dex,$luk) = @_;

	if (!@_) {
		($str,$agi,$vit,$int,$dex,$luk) = (5,5,5,5,5,5);
	}

	if ($conState != 3) {
		error "We're not currently connected to the character login server.\n";
	} elsif ($slot !~ /^\d+$/) {
		error "Slot \"$slot\" is not a valid number.\n";
	} elsif ($slot < 0 || $slot > 4) {
		error "The slot must be comprised between 0 and 2\n";
	} elsif ($chars[$slot]) {
		error "Slot $slot already contains a character ($chars[$slot]{name}).\n";
	} elsif (length($name) > 23) {
		error "Name must not be longer than 23 characters\n";

	} else {
		for ($str,$agi,$vit,$int,$dex,$luk) {
			if ($_ > 9 || $_ < 1) {
				error "Stats must be comprised between 1 and 9\n";
				return;
			}
		}
		for ($str+$int, $agi+$luk, $vit+$dex) {
			if ($_ != 10) {
				error "The sums Str + Int, Agi + Luk and Vit + Dex must all be equal to 10\n" ;
				return;
			}
		}

		sendCharCreate(\$remote_socket, $slot, $name, $str, $agi, $vit, $int, $dex, $luk);
		return 1;
	}
}

##
# getFieldPoint(r_field, x, y)
# r_field: a reference to a field hash.
# x, y: the coordinate on the field to check.
# Returns: An integer: 0 = walkable, 1 = not walkable, 3 = water (walkable), 5 = cliff (not walkable, but you can snipe)
#
# Get the raw value of the specified coordinate on the map. If you want to check whether
# ($x, $y) is walkable, use checkFieldWalkable instead.
sub getFieldPoint {
	my $r_field = shift;
	my $x = shift;
	my $y = shift;

	if ($x < 0 || $x >= $r_field->{'width'} || $y < 0 || $y >= $r_field->{'height'}) {
		return 1;
	}
	return ord(substr($r_field->{rawMap}, ($y * $r_field->{'width'}) + $x, 1));
}

sub getPortalDestName {
	my $ID = shift;
	my %hash; # We only want unique names, so we use a hash
	foreach (keys %{$portals_lut{$ID}{'dest'}}) {
		my $key = $portals_lut{$ID}{'dest'}{$_}{'map'};
		$hash{$key} = 1;
	}

	my @destinations = sort keys %hash;
	return join('/', @destinations);
}

##
# getPlayer(ID, [partial_match])
# ID: either a number in the player list, or a player name.
# Returns: a player hash, or undef if not found.
sub getPlayer {
	my $ID = shift;
	my $partial = shift;

	if ($ID =~ /^\d+$/) {
		if (defined($ID = $playersID[$ID])) {
			return $players{$ID};
		}
	} elsif ($partial) {
		$ID = quotemeta $ID;
		foreach (@playersID) {
			next if (!$_);
			return $players{$_} if ($players{$_}{name} =~ /^$ID/i);
		}
	} else {
		foreach (@playersID) {
			next if (!$_);
			return $players{$_} if (lc($players{$_}{name}) eq lc($ID));
		}
	}
	return undef;
}

sub objectAdded {
	my $type = shift;
	my $ID = shift;
	my $obj = shift;

	if ($type eq 'player' || $type eq 'npc') {
		push @unknownObjects, $ID;
	}
}

##
# objectInsideSpell(object)
# object: reference to a player or monster hash.
#
# Checks whether an object is inside someone else's spell area.
# (Traps are also "area spells").
sub objectInsideSpell {
	my $object = shift;
	my ($x, $y) = ($object->{pos_to}{x}, $object->{pos_to}{y});
	foreach (@spellsID) {
		my $spell = $spells{$_};
		if ($spell->{sourceID} ne $accountID && $spell->{pos}{x} == $x && $spell->{pos}{y} == $y) {
			return 1;
		}
	}
	return 0;
}

##
# objectIsMovingTowardsPlayer(object, [ignore_party_members = 1])
#
# Check whether an object is moving towards a player.
sub objectIsMovingTowardsPlayer {
	my $obj = shift;
	my $ignore_party_members = shift;
	$ignore_party_members = 1 if (!defined $ignore_party_members);

	if (!timeOut($obj->{time_move}, $obj->{time_move_calc}) && @playersID) {
		# Monster is still moving, and there are players on screen
		my %vec;
		getVector(\%vec, $obj->{pos_to}, $obj->{pos});

		foreach (@playersID) {
			next if (!$_ || ( $ignore_party_members && $char->{party}{users}{$_} ));
			if (checkMovementDirection($obj->{pos}, \%vec, $players{$_}{pos}, 15)) {
				return 1;
			}
		}
	}
	return 0;
}

##
# printItemDesc(itemID)
#
# Print the description for $itemID.
sub printItemDesc {
	my $itemID = shift;
	message("===============Item Description===============\n", "info");
	message("Item: $items_lut{$itemID}\n\n", "info");
	message($itemsDesc_lut{$itemID}, "info");
	message("==============================================\n", "info");
}

sub stopAttack {
	my $pos = calcPosition($char);
	sendMove(\$remote_socket, $pos->{x}, $pos->{y});
}

sub stripLanguageCode {
	my $r_msg = shift;
	if ($config{chatLangCode} ne "none" && $config{chatLangCode} ne "0") {
		configModify("chatLangCode", 1, 1) if ($config{chatLangCode} eq "");
		$$r_msg =~ s/^\|..//;
		return 1;
	} else {
		return 0;
	}
}

sub whenStatusActive {
	my $statuses = shift;
	my @arr = split /,/, $statuses;
	foreach (@arr) {
		s/^\s+//g;
		s/\s+$//g;
		return 1 if exists($char->{statuses}{$_});
	}
	return 0;
}

sub whenStatusActiveMon {
	my ($ID, $statuses) = @_;
	my @arr = split /,/, $statuses;
	foreach (@arr) {
		s/^\s+//g;
		s/\s+$//g;
		return 1 if $monsters{$ID}{statuses}{$_};
	}
	return 0;
}

sub whenStatusActivePL {
	my ($ID, $statuses) = @_;
	if ($ID eq $accountID) { return whenStatusActive($statuses) }
	my @arr = split /,/, $statuses;
	foreach (@arr) {
		s/^\s+//g;
		s/\s+$//g;
		return 1 if $players{$ID}{statuses}{$_};
	}
	return 0;
}


#########################################
#########################################
# ABSTRACTION AROUND OS-SPECIFIC STUFF
#########################################
#########################################

##
# launchURL(url)
#
# Open $url in the operating system's preferred web browser.
sub launchURL {
	my $url = shift;

	if ($^O eq 'MSWin32') {
		eval "use Win32::API;";
		my $ShellExecute = new Win32::API("shell32", "ShellExecute", "NPPPPN", "V");
		$ShellExecute->Call(0, '', $url, '', '', 1);

	} else {
		my $mod = 'POSIX';
		require $mod;
		import $mod;

		# This is a script I wrote for the autopackage project
		# It autodetects the current desktop environment
		my $detectionScript = <<"		EOF";
			function detectDesktop() {
				if [[ "\$DISPLAY" = "" ]]; then
                			return 1
				fi

				local LC_ALL=C
				local clients
				if ! clients=`xlsclients`; then
			                return 1
				fi

				if echo "\$clients" | grep -qE '(gnome-panel|nautilus|metacity)'; then
					echo gnome
				elif echo "\$clients" | grep -qE '(kicker|slicker|karamba|kwin)'; then
        			        echo kde
				else
        			        echo other
				fi
				return 0
			}
			detectDesktop
		EOF

		my ($r, $w, $desktop);
		my $pid = IPC::Open2::open2($r, $w, '/bin/bash');
		print $w $detectionScript;
		close $w;
		$desktop = <$r>;
		$desktop =~ s/\n//;
		close $r;
		waitpid($pid, 0);

		sub checkCommand {
			foreach (split(/:/, $ENV{PATH})) {
				return 1 if (-x "$_/$_[0]");
			}
			return 0;
		}

		if ($desktop eq "gnome" && checkCommand('gnome-open')) {
			launchApp('gnome-open', $url);

		} elsif ($desktop eq "kde") {
			launchApp('kfmclient', 'exec', $url);

		} else {
			if (checkCommand('firefox')) {
				launchApp('firefox', $url);
			} elsif (checkCommand('mozillaa')) {
				launchApp('mozilla', $url);
			} else {
				$interface->errorDialog("No suitable browser detected. " .
					"Please launch your favorite browser and go to:\n$url");
			}
		}
	}
}

##
# whenGroundStatus($target, $statuses)
#
# $target: $char, $players{$ID} or $monsters{$ID}
# $statuses: a comma-separated list of ground effects e.g. Safety Wall,Pneuma
#
# Returns 1 iff $target is affected by one of $statuses.
sub whenGroundStatus {
	my ($target, $statuses) = @_;

	my $pos = calcPosition($target);
	for my $ID (@spellsID) {
		next unless my $spell = $spells{$ID};
		if ($pos->{x} == $spell->{pos}{x} &&
		    $pos->{y} == $spell->{pos}{y}) {
			return 1 if existsInList($statuses, getSpellName($spell->{type}));
		}
	}
	return 0;
}

sub getSpellName {
	my $spell = shift;
	return $spells_lut{$spell} || "Unknown $spell";
}

return 1;
