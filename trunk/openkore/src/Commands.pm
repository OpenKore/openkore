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
package Commands;

use strict;
use warnings;
no warnings qw(redefine uninitialized);
use Globals;
use Log qw(message error);
use Network::Send;
use Utils;


our %handlers = (
	'ai',	\&cmdAI,
	'aiv',	\&cmdAIv,
	'help',	\&cmdHelp,
	's',	\&cmdStatus,
);

our %descriptions = (
	'ai'	=> 'Enable/disable AI.',
	'aiv'	=> 'Display current AI sequences.',
	's'	=> 'Display character status.',
);


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

sub cmdHelp {
	# Show help message
	my (undef, $args) = @_;

	$args =~ s/ .*//;
	if ($args ne '' && $descriptions{$args}) {
		message("--------------- Command description ---------------\n", "list");
		message(sprintf("%-10s  %s\n", $args, $descriptions{$args}), "list");
		message("---------------------------------------------------\n", "list");
	} else {
		message("--------------- Available commands ---------------\n", "list");
		foreach my $switch (sort keys %descriptions) {
			message(sprintf("%-10s  %s\n", $switch, $descriptions{$switch}), "list");
		}
		message("--------------------------------------------------\n", "list");

	} 
}

sub cmdStatus {
	# Character status
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

	my $activeStatuses = 'none';
	if (defined $chars[$config{char}]{statuses} && %{$chars[$config{char}]{statuses}}) {
		$activeStatuses = join(", ", keys %{$chars[$config{char}]{statuses}});
	}
	message("Special status: $activeStatuses\n", "info");
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

return 1;
