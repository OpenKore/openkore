#########################################################################
#  OpenKore - Kore Stage
#  Copyright (c) 2007 OpenKore Developers
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: 6526 $
#  $Id: Settings.pm 6526 2008-09-10 10:02:49Z kLabMouse $
#
#########################################################################
##
# MODULE DESCRIPTION: First time load, preparing global varuables and loading Data files .
#

package KoreStage;

use strict;
use threads;
use threads::shared;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin";
use lib "$RealBin/src";
use lib "$RealBin/src/deps";
use Exporter;
use base qw(Exporter);

use Modules 'register';

use Globals qw($interface);
use Translation qw(T TF);
use Log qw(message warning error debug);
use Utils::Exceptions;

our @EXPORT = qw(loadStage);


##
# void $stage->loadStage()
#
# Load all Stage's, run them
#
sub loadStage {
	my ($self) = @_;
	my @stage_list;
	my $dir = "$RealBin/src/KoreStage";

	Log::message("$Settings::versionText\n");

	# Read Directory with KoreStage's.
	return if (!opendir(DIR, $dir));
	my @items;
	my @stages;
	@items = readdir DIR;
	closedir DIR;

	# Add all available stages
	foreach my $file (@items) {
		if (-f "$dir/$file" && $file =~ /\.(pm)$/) {
			$file =~ s/\.(pm)$//;
			push @stages, $file; # ToDo. Just push name there.
		}
	}

	# Load all of them
	my $i; $i=0;
	while (@stages) {
		my $stage = shift(@stages);
		my $module = "KoreStage::$stage";

		eval "use $module;";
		if ($@) {
			$interface->errorDialog(TF("Cannot load Stage %s.\nError Message: \n%s", $module, $@));
			next;
		}

		my $constructor = UNIVERSAL::can($module, 'new');
		if (!$constructor) {
			$interface->errorDialog(TF("Class %s has no constructor.\n", $module));
			next;
		}

		my $new_stage = $constructor->($module);
		$stage_list[$i] = $new_stage;
		$i++;
		# $new_stage->load();
	}

	# Load by Priority.
	# A little messy Code. But works just fine.
	my $low_priority;
	my $last_priority = -1;
	foreach my $stage (@stage_list) {
		my $pending_stage;
		$low_priority = 100000000; # Some big value.
		foreach my $stage_prior (@stage_list) {
			if (($stage_prior->{priority} < $low_priority)&&($stage_prior->{priority} > $last_priority)) {
				$low_priority = $stage_prior->{priority};
				$pending_stage = $stage_prior;
			}
		}
		if ($low_priority == 100000000) {
			$interface->errorDialog(TF("Some Kore Stages got wrong priority.\nOpenKore will Exit now.\n"), 1);
			next;
		}
		$last_priority = $low_priority;
		$pending_stage->load();
	}
	
	# Make Message: "All Loaded".
}

##
# void $stage->load()
#
# Load current, active stage.
sub load {
	# Empty overided fuction
}

