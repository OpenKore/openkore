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
use Log qw(message warning);
use Plugins;
use FileParsers;
use Settings;
use Utils;
use Network::Send;

our @EXPORT = qw(
	auth
	configModify
	setTimeout
	saveConfigFile

	debug_showSpots

	calcAvoidArea
	center
	checkFieldWalkable
	checkFollowMode
	checkMonsterCleanness
	closestWalkableSpot
	getFieldPoint
	getPortalDestName
	printItemDesc
	whenStatusActive
	whenStatusActiveMon
	whenStatusActivePL

	launchApp
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
# calcAvoidArea($x, $y, $radius)
# Returns: an array with position hashes. Each has contains an x and a y key.
#
# You want to avoid the area with center ($x,$y) and radius $radius.
# This function returns a list of blocks that you can possibly walk to,
# in order to avoid that area.
sub calcAvoidArea {
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
	my $ID = shift;

	return 1 if (!$config{attackAuto});

	# If party attacked monster, or if monster attacked/missed party
	if ($monsters{$ID}{'dmgFromParty'} > 0 || $monsters{$ID}{'dmgToParty'} > 0 || $monsters{$ID}{'missedToParty'} > 0) {
		return 1;
	}

	# If we're in follow mode
	if (defined(my $followIndex = binFind(\@ai_seq, "follow"))) {
		my $following = $ai_seq_args[$followIndex]{'following'};
		my $followID = $ai_seq_args[$followIndex]{'ID'};

		if ($following) {
			# And master attacked monster, or the monster attacked/missed master
			if ($monsters{$ID}{'dmgToPlayer'}{$followID} > 0
			 || $monsters{$ID}{'missedToPlayer'}{$followID} > 0
			 || $monsters{$ID}{'dmgFromPlayer'}{$followID} > 0) {
				return 1;
			}
		}
	}

	# If monster attacked/missed you
	return 1 if ($monsters{$ID}{'dmgToYou'} || $monsters{$ID}{'missedYou'});

	# It monster hasn't been attacked by other players
	if (!binSize([keys %{$monsters{$ID}{'missedFromPlayer'}}])
	 && !binSize([keys %{$monsters{$ID}{'dmgFromPlayer'}}])
	 && !binSize([keys %{$monsters{$ID}{'castOnByPlayer'}}])

	 # and it hasn't attacked any other player
	 && !binSize([keys %{$monsters{$ID}{'missedToPlayer'}}])
	 && !binSize([keys %{$monsters{$ID}{'dmgToPlayer'}}])
	 && !binSize([keys %{$monsters{$ID}{'castOnToPlayer'}}])
	) {
		return 1;
	}

	# my $cleanMonster = (
	#	  !($monsters{$ID}{'dmgFromYou'} == 0 && ($monsters{$ID}{'dmgTo'} > 0 || $monsters{$ID}{'dmgFrom'} > 0 || %{$monsters{$ID}{'missedFromPlayer'}} || %{$monsters{$ID}{'missedToPlayer'}} || %{$monsters{$ID}{'castOnByPlayer'}}))
	#	|| ($monsters{$ID}{'dmgFromParty'} > 0 || $monsters{$ID}{'dmgToParty'} > 0 || $monsters{$ID}{'missedToParty'} > 0)
	#	|| ($following && ($monsters{$ID}{'dmgToPlayer'}{$followID} > 0 || $monsters{$ID}{'missedToPlayer'}{$followID} > 0 || $monsters{$ID}{'dmgFromPlayer'}{$followID} > 0))
	#	|| ($monsters{$ID}{'dmgToYou'} > 0 || $monsters{$ID}{'missedYou'} > 0)
	# );
	# $cleanMonster = 0 if ($monsters{$ID}{'attackedByPlayer'} && (!$following || $monsters{$ID}{'lastAttackFrom'} ne $followID));

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
# launchApp(args...)
# args: The application's name and arguments.
# Returns: a PID on Unix; an object created by Win32::Process::Create() on Windows.
#
# Asynchronously launch an application.
sub launchApp {
	if ($^O eq 'MSWin32') {
		my @args = @_;
		foreach (@args) {
			$_ = "\"$_\"";
		}

		my ($priority, $obj);
		eval 'use Win32::Process; use Win32; $priority = NORMAL_PRIORITY_CLASS;';
		Win32::Process::Create($obj, $_[0], "@args", 0, $priority, '.');
		return $obj;

	} else {
		my $mod = 'POSIX';
		require $mod;
		import $mod;

		my $pid = fork();
		if ($pid == 0) {
			open(STDOUT, "> /dev/null");
			open(STDERR, "> /dev/null");
			POSIX::setsid();
			if (fork() == 0) {
				exec(@_);
			}
			POSIX::_exit(1);
		} elsif ($pid) {
			waitpid($pid, 0);
		}
		return $pid;
	}
}

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

return 1;
