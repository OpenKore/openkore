#########################################################################
#  OpenKore - Commandline
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
# MODULE DESCRIPTION: Commandline input processing
#
# This module processes commandline input.
#
# (At this time, some stuff is still handled by the parseCommand() function in functions.pl. The plan is to eventually move everything to this module.)

package Commands;

use strict;
use warnings;
no warnings qw(redefine uninitialized);

use Globals;
use Log qw(message error);
use Network::Send;
use Settings;
use Plugins;
use Utils;
use Misc;


our %handlers = (
	ai	=> \&cmdAI,
	aiv	=> \&cmdAIv,
	chist	=> \&cmdChist,
	e	=> \&cmdEmotion,
	eq	=> \&cmdEquip,
	i	=> \&cmdInventory,
	ignore	=> \&cmdIgnore,
	il	=> \&cmdItemList,
	im	=> \&cmdUseItemOnMonster,
	ip	=> \&cmdUseItemOnPlayer,
	is	=> \&cmdUseItemOnSelf,
	help	=> \&cmdHelp,
	reload	=> \&cmdReload,
	memo	=> \&cmdMemo,
	plugin	=> \&cmdPlugin,
	s	=> \&cmdStatus,
	stat_add => \&cmdStatAdd,
	uneq	=> \&cmdUnequip,
	warp	=> \&cmdWarp,
	who	=> \&cmdWho,
);

our %descriptions = (
	ai	=> 'Enable/disable AI.',
	aiv	=> 'Display current AI sequences.',
	chist	=> 'Display last few entries from the chat log.',
	e	=> 'Show emotion.',
	eq	=> 'Equip an item.',
	i	=> 'Display inventory items.',
	ignore	=> 'Ignore a user (block his messages).',
	il	=> 'Display items on the ground.',
	im	=> 'Use item on monster.',
	ip	=> 'Use item on player.',
	is	=> 'Use item on yourself.',
	reload	=> 'Reload configuration files.',
	memo	=> 'Save current position for warp portal.',
	plugin	=> 'Control plugins.',
	s	=> 'Display character status.',
	stat_add => 'Add status point.',
	warp	=> 'Open warp portal.',
	who	=> 'Display the number of people on the current server.',
);


##
# Commands::run(input)
# input: a command.
#
# Processes $input. See also <a href="http://openkore.sourceforge.net/wiki/">the user documentation</a>
# for a list of commands.
#
# Example:
# # Same effect as typing 's' in the console. Displays character status
# Commands::run("s");
sub run {
	my $input = shift;
	my ($switch, $args) = split(' ', $input, 2);

	# Resolve command aliases
	if (my $alias = $config{"alias_$switch"}) {
		$input = $alias;
		$input .= " $args" if defined $args;
		($switch, $args) = split(' ', $input, 2);
	}

	if ($handlers{$switch}) {
		$handlers{$switch}->($switch, $args);
		return 1;
	} else {
		# TODO: print error message here once we've fully migrated this stuff
		return 0;
	}
}


##################################


sub cmdAI {
	# Toggle AI
	if ($AI) {
		undef $AI;
		$AI_forcedOff = 1;
		message "AI turned off\n", "success";
	} else {
		$AI = 1;
		undef $AI_forcedOff;
		message "AI turned on\n", "success";
	}
}

sub cmdAIv {
	# Display current AI sequences
	message("ai_seq = @ai_seq\n", "list");
	message("waitingForMapSolution\n", "list") if ($ai_seq_args[0]{'waitingForMapSolution'});
	message("waitingForSolution\n", "list") if ($ai_seq_args[0]{'waitingForSolution'});
	message("solution\n", "list") if ($ai_seq_args[0]{'solution'});
}

sub cmdChist {
	# Display chat history
	my (undef, $args) = @_;
	$args = 5 if ($args eq "");

	if (!($args =~ /^\d+$/)) {
		error	"Syntax Error in function 'chist' (Show Chat History)\n" .
			"Usage: chist [<number of entries #>]\n";

	} elsif (open(CHAT, "<", $Settings::chat_file)) {
		my @chat = <CHAT>;
		close(CHAT);
		message("------ Chat History --------------------\n", "list");
		my $i = @chat - $args;
		$i = 0 if ($i < 0);
		for (; $i < @chat; $i++) {
			message($chat[$i], "list");
		}
		message("----------------------------------------\n", "list");

	} else {
		error "Unable to open $Settings::chat_file\n";
	}
}

sub cmdEmotion {
	# Show emotion
	my (undef, $args) = @_;
	my ($num) = $args =~ /^(\d+)$/;

	if ($num eq "" || $num > 33 || $num < 0) {
		error	"Syntax Error in function 'e' (Emotion)\n" .
			"Usage: e <emotion # (0-33)>\n";
	} else {
		sendEmotion(\$remote_socket, $num);
	}
}

sub cmdEquip {
	# Equip an item
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\d+)/;
	my ($arg2) = $args =~ /^\d+ (\w+)/;
	if ($arg1 eq "") {
		error	"Syntax Error in function 'equip' (Equip Inventory Item)\n" .
			"Usage: equip <item #> [r]\n";

	} elsif (!%{$chars[$config{'char'}]{'inventory'}[$arg1]}) {
		error	"Error in function 'equip' (Equip Inventory Item)\n" .
			"Inventory Item $arg1 does not exist.\n";

	} elsif ($chars[$config{'char'}]{'inventory'}[$arg1]{'type_equip'} == 0 && $chars[$config{'char'}]{'inventory'}[$arg1]{'type'} != 10) {
		error	"Error in function 'equip' (Equip Inventory Item)\n" .
			"Inventory Item $arg1 can't be equipped.\n";

	} else {
		sendEquip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg1]{'index'}, $chars[$config{'char'}]{'inventory'}[$arg1]{'type_equip'});
	}
}

sub cmdHelp {
	# Display help message
	my (undef, $args) = @_;
	my @commands = split(/ +/, $args);
	@commands = sort keys %descriptions if (!@commands);
	my @unknown;

	message("--------------- Available commands ---------------\n", "list");
	foreach my $switch (@commands) {
		if ($descriptions{$switch}) {
			message(sprintf("%-10s  %s\n", $switch, $descriptions{$switch}), "list");
		} else {
			push @unknown, $switch;
		}
	}

	if (@unknown) {
		if (@unknown == 1) {
			error("The command \"$unknown[0]\" doesn't exist.\n");
		} else {
			error("These commands don't exist: " . join(', ', @unknown) . "\n");
		}
		error("Type 'help' to see a list of all available commands.\n");
	}
	message("--------------------------------------------------\n", "list");
}

sub cmdIgnore {
	my (undef, $args) = @_;
	my ($arg1, $arg2) = $args =~ /^(\d+) ([\s\S]*)/;
	if ($arg1 eq "" || $arg2 eq "" || ($arg1 ne "0" && $arg1 ne "1")) {
		error	"Syntax Error in function 'ignore' (Ignore Player/Everyone)\n" .
			"Usage: ignore <flag> <name | all>\n";
	} else {
		if ($arg2 eq "all") {
			sendIgnoreAll(\$remote_socket, !$arg1);
		} else {
			sendIgnore(\$remote_socket, $arg2, !$arg1);
		}
	}
}

sub cmdItemList {
	my $display;
	message("-----------Item List-----------\n" .
		"#    Name                      \n",
		"list");
	for (my $i = 0; $i < @itemsID; $i++) {
		next if ($itemsID[$i] eq "");
		$display = $items{$itemsID[$i]}{'name'};
		$display .= " x $items{$itemsID[$i]}{'amount'}";
		message(swrite(
			"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
			[$i, $display]),
			"list");
	}
	message("-------------------------------\n", "list");
}

sub cmdInventory {
	# Display inventory items
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\w+)/;
	my ($arg2) = $args =~ /^\w+ (\d+)/;

	if ($arg1 eq "" || $arg1 eq "eq" || $arg1 eq "u" || $arg1 eq "nu") {
		my @useable;
		my @equipment;
		my @non_useable;
		my ($i, $display, $index);

		for ($i = 0; $i < @{$chars[$config{'char'}]{'inventory'}};$i++) {
			next if (!%{$chars[$config{'char'}]{'inventory'}[$i]});
			if ($chars[$config{'char'}]{'inventory'}[$i]{'type_equip'} != 0) {
				push @equipment, $i;
			} elsif ($chars[$config{'char'}]{'inventory'}[$i]{'type'} <= 2) {
				push @useable, $i;
			} else {
				push @non_useable, $i;
			} 
		}

		message("-----------Inventory-----------\n", "list");
		if ($arg1 eq "" || $arg1 eq "eq") {
			message("-- Equipment --\n", "list");
			for ($i = 0; $i < @equipment; $i++) {
				$index = $equipment[$i];
				$display = $chars[$config{'char'}]{'inventory'}[$index]{'name'};
				$display .= " ($itemTypes_lut{$chars[$config{'char'}]{'inventory'}[$index]{'type'}})";
					if ($chars[$config{'char'}]{'inventory'}[$index]{'equipped'}) {
					$display .= " -- Eqp: $equipTypes_lut{$chars[$config{'char'}]{'inventory'}[$index]{'type_equip'}}";
				}

				if (!$chars[$config{'char'}]{'inventory'}[$index]{'identified'}) {
					$display .= " -- Not Identified";
				}

				message(swrite(
					"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
					[$index, $display]),
					"list");
			}
		}
		if ($arg1 eq "" || $arg1 eq "nu") {
			message("-- Non-Useable --\n", "list");
			for ($i = 0; $i < @non_useable; $i++) {
				$index = $non_useable[$i];
				$display = $chars[$config{'char'}]{'inventory'}[$index]{'name'};
				$display .= " x $chars[$config{'char'}]{'inventory'}[$index]{'amount'}";
				message(swrite(
					"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
					[$index, $display]),
					"list");
			}
		}
		if ($arg1 eq "" || $arg1 eq "u") {
			message("-- Useable --\n", "list");
			for ($i = 0; $i < @useable; $i++) {
				$display = $chars[$config{'char'}]{'inventory'}[$useable[$i]]{'name'};
				$display .= " x $chars[$config{'char'}]{'inventory'}[$useable[$i]]{'amount'}";
				$index = $useable[$i];
				message(swrite(
					"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
					[$index, $display]),
					"list");
			}
		}
		message("-------------------------------\n", "list");

	} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/ && $chars[$config{'char'}]{'inventory'}[$arg2] eq "") {
		error	"Error in function 'i' (Inventory Item Desciption)\n" .
			"Inventory Item $arg2 does not exist\n";
	} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/) {
		main::printItemDesc($chars[$config{'char'}]{'inventory'}[$arg2]{'nameID'});

	} else {
		error	"Syntax Error in function 'i' (Inventory List)\n" .
			"Usage: i [<u|eq|nu|desc>] [<inventory #>]\n";
	}
}

sub cmdMemo {
	sendMemo(\$remote_socket);
}

sub cmdPlugin {
	my (undef, $input) = @_;
	my @args = split(/ +/, $input, 2);

	if (@args == 0) {
		message("--------- Currently loaded plugins ---------\n", "list");
		message("#   Name              Description\n", "list");
		my $i = 0;
		foreach my $plugin (@Plugins::plugins) {
			message(swrite(
				"@<< @<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
				[$i, $plugin->{name}, $plugin->{description}]
			), "list");
			$i++;
		}
		message("--------------------------------------------\n", "list");

	} elsif ($args[0] eq 'reload') {
		my @names;

		if ($args[1] =~ /^\d+$/) {
			push @names, $Plugins::plugins[$args[1]]{name};

		} elsif ($args[1] eq '') {
			error	"Syntax Error in function 'plugin reload' (Reload Plugin)\n" .
				"Usage: plugin reload <plugin name|plugin number#|\"all\">\n";
			return;

		} elsif ($args[1] eq 'all') {
			foreach my $plugin (@Plugins::plugins) {
				push @names, $plugin->{name};
			}

		} else {
			foreach my $plugin (@Plugins::plugins) {
				if ($plugin->{name} =~ /$args[1]/i) {
					push @names, $plugin->{name};
				}
			}
			if (!@names) {
				error	"Error in function 'plugin reload' (Reload Plugin)\n" .
					"The specified plugin names do not exist.\n";
				return;
			}
		}

		foreach (my $i = 0; $i < @names; $i++) {
			Plugins::reload($names[$i]);
		}

	} else {
		my $msg;
		$msg =	"--------------- Plugin command syntax ---------------\n" .
			"Command:                                              Description:\n" .
			" plugin                                                List loaded plugins\n" .
			" plugin load <filename>                                Load a plugin\n" .
			" plugin unload <plugin name|plugin number#|\"all\">    Unload a loaded plugin\n" .
			" plugin reload <plugin name|plugin number#|\"all\">    Reload a loaded plugin\n" .
			"-----------------------------------------------------\n";
		if ($args[0] eq 'help') {
			message($msg, "info");
		} else {
			error "Syntax Error in function 'plugin' (Control Plugins)\n";
			error($msg);
		}
	}
}

sub cmdReload {
	my (undef, $args) = @_;
	if ($args eq '') {
		error	"Syntax Error in function 'reload' (Reload Configuration Files)\n" .
			"Usage: reload <name|\"all\">\n";

	} else {
		Settings::parseReload($args);
	}
}

sub cmdStatAdd {
	# Add status point
	my (undef, $arg) = @_;
	if ($arg ne "str" && $arg ne "agi" && $arg ne "vit" && $arg ne "int" 
	 && $arg ne "dex" && $arg ne "luk") {
		error	"Syntax Error in function 'stat_add' (Add Status Point)\n" .
			"Usage: stat_add <str | agi | vit | int | dex | luk>\n";

	} elsif ($chars[$config{'char'}]{"points_$arg"} > $chars[$config{'char'}]{'points_free'}) {
			error	"Error in function 'stat_add' (Add Status Point)\n" .
				"Not enough status points to increase $arg\n";

	} else {
		my $ID;
		if ($arg eq "str") {
			$ID = 0x0D;
		} elsif ($arg eq "agi") {
			$ID = 0x0E;
		} elsif ($arg eq "vit") {
			$ID = 0x0F;
		} elsif ($arg eq "int") {
			$ID = 0x10;
		} elsif ($arg eq "dex") {
			$ID = 0x11;
		} elsif ($arg eq "luk") {
			$ID = 0x12;
		}

		$chars[$config{'char'}]{$arg} += 1;
		sendAddStatusPoint(\$remote_socket, $ID);
	}
}

sub cmdStatus {
	# Display character status
	my ($baseEXPKill, $jobEXPKill);

	if ($chars[$config{'char'}]{'exp_last'} > $chars[$config{'char'}]{'exp'}) {
		$baseEXPKill = $chars[$config{'char'}]{'exp_max_last'} - $chars[$config{'char'}]{'exp_last'} + $chars[$config{'char'}]{'exp'};
	} elsif ($chars[$config{'char'}]{'exp_last'} == 0 && $chars[$config{'char'}]{'exp_max_last'} == 0) {
		$baseEXPKill = 0;
	} else {
		$baseEXPKill = $chars[$config{'char'}]{'exp'} - $chars[$config{'char'}]{'exp_last'};
	}
	if ($chars[$config{'char'}]{'exp_job_last'} > $chars[$config{'char'}]{'exp_job'}) {
		$jobEXPKill = $chars[$config{'char'}]{'exp_job_max_last'} - $chars[$config{'char'}]{'exp_job_last'} + $chars[$config{'char'}]{'exp_job'};
	} elsif ($chars[$config{'char'}]{'exp_job_last'} == 0 && $chars[$config{'char'}]{'exp_job_max_last'} == 0) {
		$jobEXPKill = 0;
	} else {
		$jobEXPKill = $chars[$config{'char'}]{'exp_job'} - $chars[$config{'char'}]{'exp_job_last'};
	}


	my ($hp_string, $sp_string, $base_string, $job_string, $weight_string, $job_name_string, $zeny_string);

	$hp_string = $chars[$config{'char'}]{'hp'}."/".$chars[$config{'char'}]{'hp_max'}." ("
		.int($chars[$config{'char'}]{'hp'}/$chars[$config{'char'}]{'hp_max'} * 100)
		."%)" if $chars[$config{'char'}]{'hp_max'};
	$sp_string = $chars[$config{'char'}]{'sp'}."/".$chars[$config{'char'}]{'sp_max'}." ("
		.int($chars[$config{'char'}]{'sp'}/$chars[$config{'char'}]{'sp_max'} * 100)
		."%)" if $chars[$config{'char'}]{'sp_max'};
	$base_string = $chars[$config{'char'}]{'exp'}."/".$chars[$config{'char'}]{'exp_max'}." /$baseEXPKill ("
			.sprintf("%.2f",$chars[$config{'char'}]{'exp'}/$chars[$config{'char'}]{'exp_max'} * 100)
			."%)" if $chars[$config{'char'}]{'exp_max'};
	$job_string = $chars[$config{'char'}]{'exp_job'}."/".$chars[$config{'char'}]{'exp_job_max'}." /$jobEXPKill ("
			.sprintf("%.2f",$chars[$config{'char'}]{'exp_job'}/$chars[$config{'char'}]{'exp_job_max'} * 100)
			."%)" if $chars[$config{'char'}]{'exp_job_max'};
	$weight_string = $chars[$config{'char'}]{'weight'}."/".$chars[$config{'char'}]{'weight_max'} .
			" (" . sprintf("%.1f", $chars[$config{'char'}]{'weight'}/$chars[$config{'char'}]{'weight_max'} * 100)
			. "%)"
			if $chars[$config{'char'}]{'weight_max'};
	$job_name_string = "$jobs_lut{$chars[$config{'char'}]{'jobID'}} $sex_lut{$chars[$config{'char'}]{'sex'}}";
	$zeny_string = formatNumber($chars[$config{'char'}]{'zenny'}) if (defined($chars[$config{'char'}]{'zenny'}));

	message("-----------------Status-----------------\n", "info");
	message(swrite(
		"@<<<<<<<<<<<<<<<<<<<<<<<<<<   HP: @<<<<<<<<<<<<<<<<<<",
		[$chars[$config{'char'}]{'name'}, $hp_string],
		"@<<<<<<<<<<<<<<<<<<<<<<<<<<   SP: @<<<<<<<<<<<<<<<<<<",
		[$job_name_string, $sp_string],
		"Base: @<< @>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>",
		[$chars[$config{'char'}]{'lv'}, $base_string],
		"Job:  @<< @>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>",
		[$chars[$config{'char'}]{'lv_job'}, $job_string],
		"Weight: @>>>>>>>>>>>>>>>>>>   Zenny: @<<<<<<<<<<<<<<",
		[$weight_string, $zeny_string]),
		"info");

	my $activeSkills = 'none';
	my $ailments = 'none';
	my $looks = 'none';
	my $state = '';
	if (defined $chars[$config{char}]{statuses} && %{$chars[$config{char}]{statuses}}) {
		$activeSkills = join(", ", keys %{$chars[$config{char}]{statuses}});
	}
	if (defined $chars[$config{char}]{ailments} && %{$chars[$config{char}]{ailments}}) {
		$ailments = join(", ", keys %{$chars[$config{char}]{ailments}});
	}
	if (defined $chars[$config{char}]{state} && %{$chars[$config{char}]{state}}) {
		$state = join(", ", keys %{$chars[$config{char}]{state}});
	}
	if (defined $chars[$config{char}]{looks} && %{$chars[$config{char}]{looks}}) {
		$looks = join(", ", keys %{$chars[$config{char}]{looks}});
	}
	message("Active skills: $activeSkills\n", "info");
	message("Ailments: $ailments $state\n", "info");
	message("Looks: $looks\n", "info");
	message("----------------------------------------\n", "info");


	my $dmgpsec_string = sprintf("%.2f", $dmgpsec);
	my $totalelasped_string = sprintf("%.2f", $totalelasped);
	my $elasped_string = sprintf("%.2f", $elasped);

	message(swrite(
		"Total Damage: @>>>>>>>>>>>>> Dmg/sec: @<<<<<<<<<<<<<<",
		[$totaldmg, $dmgpsec_string],
		"Total Time spent (sec): @>>>>>>>>",
		[$totalelasped_string],
		"Last Monster took (sec): @>>>>>>>",
		[$elasped_string]),
		"info");
	message("----------------------------------------\n", "info");
}

sub cmdUnequip {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\d+)/;
	if ($arg1 eq "") {
		error	"Syntax Error in function 'unequip' (Unequip Inventory Item)\n" .
			"Usage: unequip <item #>\n";

	} elsif (!%{$chars[$config{'char'}]{'inventory'}[$arg1]}) {
		error	"Error in function 'unequip' (Unequip Inventory Item)\n" .
			"Inventory Item $arg1 does not exist.\n";

	} elsif ($chars[$config{'char'}]{'inventory'}[$arg1]{'equipped'} == 0 && $chars[$config{'char'}]{'inventory'}[$arg1]{'type'} != 10) {
		error	"Error in function 'unequip' (Unequip Inventory Item)\n" .
			"Inventory Item $arg1 is not equipped.\n";

	} else {
		sendUnequip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg1]{'index'});
	}
}

sub cmdUseItemOnMonster {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\d+)/;
	my ($arg2) = $args =~ /^\d+ (\d+)/;

	if ($arg1 eq "" || $arg2 eq "") {
		error	"Syntax Error in function 'im' (Use Item on Monster)\n" .
			"Usage: im <item #> <monster #>\n";
	} elsif (!%{$chars[$config{'char'}]{'inventory'}[$arg1]}) {
		error	"Error in function 'im' (Use Item on Monster)\n" .
			"Inventory Item $arg1 does not exist.\n";
	} elsif ($chars[$config{'char'}]{'inventory'}[$arg1]{'type'} > 2) {
		error	"Error in function 'im' (Use Item on Monster)\n" .
			"Inventory Item $arg1 is not of type Usable.\n";
	} elsif ($monstersID[$arg2] eq "") {
		error	"Error in function 'im' (Use Item on Monster)\n" .
			"Monster $arg2 does not exist.\n";
	} else {
		sendItemUse(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg1]{'index'}, $monstersID[$arg2]);
	}
}

sub cmdUseItemOnPlayer {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\d+)/;
	my ($arg2) = $args =~ /^\d+ (\d+)/;
	if ($arg1 eq "" || $arg2 eq "") {
		error	"Syntax Error in function 'ip' (Use Item on Player)\n" .
			"Usage: ip <item #> <player #>\n";
	} elsif (!%{$chars[$config{'char'}]{'inventory'}[$arg1]}) {
		error	"Error in function 'ip' (Use Item on Player)\n" .
			"Inventory Item $arg1 does not exist.\n";
	} elsif ($chars[$config{'char'}]{'inventory'}[$arg1]{'type'} > 2) {
		error	"Error in function 'ip' (Use Item on Player)\n" .
			"Inventory Item $arg1 is not of type Usable.\n";
	} elsif ($playersID[$arg2] eq "") {
		error	"Error in function 'ip' (Use Item on Player)\n" .
			"Player $arg2 does not exist.\n";
	} else {
		sendItemUse(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg1]{'index'}, $playersID[$arg2]);
	}
}

sub cmdUseItemOnSelf {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\d+)/;
	if ($arg1 eq "") {
		error	"Syntax Error in function 'is' (Use Item on Yourself)\n" .
			"Usage: is <item #>\n";
	} elsif (!%{$chars[$config{'char'}]{'inventory'}[$arg1]}) {
		error	"Error in function 'is' (Use Item on Yourself)\n" .
			"Inventory Item $arg1 does not exist.\n";
	} elsif ($chars[$config{'char'}]{'inventory'}[$arg1]{'type'} > 2) {
		error	"Error in function 'is' (Use Item on Yourself)\n" .
			"Inventory Item $arg1 is not of type Usable.\n";
	} else {
		sendItemUse(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg1]{'index'}, $accountID);
	}
}

sub cmdWarp {
	my (undef, $map) = @_;

	if ($map eq '') {
		error	"Error in function 'warp' (Open/List Warp Portal)\n" .
			"Usage: warp <map name | map number# | list>\n";

	} elsif ($map =~ /^\d+$/) {
		if ($map < 0 || $map > @{$chars[$config{'char'}]{'warp'}{'memo'}}) {
			error "Invalid map number $map.\n";
		} else {
			my $name = $chars[$config{'char'}]{'warp'}{'memo'}[$map];
			my $rsw = "$name.rsw";
			message "Attempting to open a warp portal to $maps_lut{$rsw} ($name)\n", "info";
			sendOpenWarp(\$remote_socket, "$name.gat");
		}

	} elsif ($map eq 'list') {
		message("----------------- Warp Portal --------------------\n", "list");
		message("#  Place                           Map\n", "list");
		for (my $i = 0; $i < @{$chars[$config{'char'}]{'warp'}{'memo'}}; $i++) {
			message(swrite(
				"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<",
				[$i, $maps_lut{$chars[$config{'char'}]{'warp'}{'memo'}[$i].'.rsw'},
				$chars[$config{'char'}]{'warp'}{'memo'}[$i]]),
				"list");
		}
		message("--------------------------------------------------\n", "list");

	} elsif (!defined $maps_lut{$map.'.rsw'}) {
		error "Map '$map' does not exist.\n";

	} else {
		my $rsw = "$map.rsw";
		message "Attempting to open a warp portal to $maps_lut{$rsw} ($map)\n", "info";
		sendOpenWarp(\$remote_socket, "$map.gat");
	}
}

sub cmdWho {
	sendWho(\$remote_socket);
}

return 1;
