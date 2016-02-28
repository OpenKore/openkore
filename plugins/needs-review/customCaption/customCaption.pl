#############################################################################
# customCaption plugin by imikelance										
#																			
# Openkore: http://openkore.com/											
# Openkore Brazil: http://openkore.com.br/	
# Plugin Discussion (in portuguese): http://openkore.com.br/index.php?/topic/2157-customcaption-by-imikelance/
#																			
# Usage:														
#	add this line inside config.txt:
#		windowTitle <line>
# 	Where <line> stands for openkore's caption replacement string.
#	You can use some variables for string replacement:
#
# %n			Character nickname
# %basel		Base Level
# %jobl			Job Level
# %baseperc		Base EXP Percentage
# %jobperc		Job EXP Percentage
# %w			Current Weight
# %pos			Position (x and y)
# %map			Current Map
# %hpab			Absolute HP Values
# %spab			Absolute SP Values
# %hpp			Current HP Percentage
# %spp			Current SP Percentage
# %z			Current Zeny
# %c			Character Class
# %pt			Party Name
#
# For example, if you set windowTitle to "%n - %z zeny - Openkore" (without quotes) and your character
# name is iMikeLance and you have 9,000 zeny, Openkore's caption will change into: 
# "iMikeLance - 9,000 zeny - Openkore"
#
#	This is OpenKore's default caption syntax, you can use it as windowTitle value:
#		%n: B%basel (%baseperc), %jobl (%jobperc) : p%w : %pos %map - OpenKore
#
# 01:52 quinta-feira, 8 de março de 2012
# 	- released !			
#
# TODO: maybe we should add more "variables".
#																			
# This source code is licensed under the									
# GNU General Public License, Version 3.									
# See http://www.gnu.org/licenses/gpl.html									
#############################################################################

package customCaption;

use strict;
use Plugins;
use Globals;
use Log qw( warning message error );
use Misc;
use Utils;


# you can change some of this plugin settings below !
use constant {
	PLUGINNAME				=>	"customCaption",
	VERSION					=>	"rev 00",
	# disable almost every message. error messages will still be shown
	SILENT					=>	0,
	# set to 1 to show debug messages
	DEBUG					=>	0,
	
};


# Plugin
Plugins::register(PLUGINNAME, "customize OpenKore's window caption", \&unload);

my $myHooks = Plugins::addHooks(
	['mainLoop::setTitle',       \&setTitle,     undef],
	['start3',       \&onKStart, undef],
);

#my $workingFolder = $Plugins::current_plugin_folder; # currently unused

# Plugin unload
sub unload {
	if (defined $myHooks) {
		message("\n".PLUGINNAME." unloading.\n\n");
		Plugins::delHooks($myHooks);
		undef $myHooks;
	}
}

# Subs

sub onKStart {
	#if (!$config{windowTitle}) {
	#	configModify('windowTitle', '%n: B%basel (%baseperc), %jobl (%jobperc) : p%w : %pos %map - OpenKore', silent => 1);
	#}
}

sub setTitle {
	my (undef, $args) = @_;
	if ($net->getState() == Network::IN_GAME) {
		my $charName;
		$charName = $char->{name} if ($char);
		my ($hpab, $spab, $hpp, $spp, $basePercent, $jobPercent, $weight, $pos, $map, $zeny, $class, $ptname, $server);
		$args->{return} = $config{windowTitle};
		# get in-game variables
		$basePercent = sprintf("%.2f", $char->{exp} / $char->{exp_max} * 100) if ($char->{exp_max});$jobPercent = sprintf("%.2f", $char->{exp_job} / $char->{exp_job_max} * 100) if ($char->{exp_job_max});
		$weight = int($char->{weight} / $char->{weight_max} * 100) . "%" if ($char->{weight_max});$ptname = $char->{'party'}{'name'} if ($char->{'party'}{'name'}); $class = $jobs_lut{$char->{'jobID'}};
		$map = $field->name if ($field);$pos = "$char->{pos_to}{x},$char->{pos_to}{y}" if ($char->{pos_to});$hpab = $char->{'hp'}."/".$char->{'hp_max'}  if $char->{'hp_max'};$spab = $char->{'sp'}."/".$char->{'sp_max'} if $char->{'sp_max'};
		$hpp = int($char->{'hp'}/$char->{'hp_max'} * 100)."%" if $char->{'hp_max'};$spp = int($char->{'sp'}/$char->{'sp_max'} * 100)."%" if $char->{'sp_max'};$zeny = formatNumber($char->{'zeny'}) if (defined($char->{'zeny'}));
		$server = $servers[$config{'server'}]{'name'};
		# replace string
		$args->{return} =~ s/%conf\{(.*)\}/$config{$1}/;$args->{return} =~ s/%n/$charName/;$args->{return} =~ s/%basel/$char->{lv}/;$args->{return} =~ s/%jobl/$char->{lv_job}/;$args->{return} =~ s/%baseperc/$basePercent/;$args->{return} =~ s/%jobperc/$jobPercent/;
		$args->{return} =~ s/%w/$weight/;$args->{return} =~ s/%pos/$pos/;$args->{return} =~ s/%map/$map/;$args->{return} =~ s/%hpab/$hpab/;$args->{return} =~ s/%spab/$spab/;$args->{return} =~ s/%hpp/$hpp/;$args->{return} =~ s/%spp/$spp/;
		$args->{return} =~ s/%z/$zeny/;$args->{return} =~ s/%c/$class/;$args->{return} =~ s/%pt/$ptname/;$args->{return} =~ s/%server/$server/;
	}
}

sub msg {
	# SILENT constant support and sprintf.
	my ($msg, $msglevel, $debug) = @_;
	
	unless ($debug eq 1 && DEBUG ne 1) {
		if (!defined $msglevel || $msglevel == "" || $msglevel == 0) {
			warning($msg) unless (SILENT == 1);
		} elsif ($msglevel == 1) {
			message($msg) unless (SILENT == 1);
		} elsif ($msglevel == 2) {
			warning($msg) unless (SILENT == 1);
		} elsif ($msglevel == 3) {
			error($msg);
		}
	}
	return 1;
}

1;
# i luv u mom