package Misc::Other;

use strict;
use threads;
use threads::shared;
use Exporter;
use base qw(Exporter);

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
