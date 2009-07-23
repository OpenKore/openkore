package Misc::Other;

# Make all References Strict
use strict;

# MultiThreading Support
use threads;
use threads::shared;

# Others (Perl Related)
use Exporter;
use base qw(Exporter);

# Others (Kore related)
use Globals qw($quit);
use Log qw(error debug message warning);
use Translation qw(T TF);

our %EXPORT_TAGS = (
	other  => [qw(
		quit)],
);

our @EXPORT = (
	@{$EXPORT_TAGS{other}},
);

#######################################
#######################################
### CATEGORY: Other functions
#######################################
#######################################

sub quit {
	lock ($quit);
	$quit = 1;
	message T("Exiting...\n"), "system";
}
