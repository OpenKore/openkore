#########################################################################
#  OpenKore - Generic utility functions
#
#  Copyright (c) 2006 OpenKore Development Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Abstraction layer for launching Perl scripts
#
# <div class="derived">This class is derived from: @CLASS(AppLauncher)</div>
#
# This class provides a cross-platform way to launch other Perl
# scripts. It automatically uses the system's Perl interpreter,
# or uses (wx)start.exe if that's not available.

package PerlLauncher;

use strict;
use Config;
use Utils::AppLauncher;
use base qw(AppLauncher);


### CATEGORY: Class PerlLauncher

##
# PerlLauncher PerlLauncher->new(Array<String>* modulePaths, String script, [String arg...])
# modulePaths: Additional Perl module paths. This may be undef.
# script: The script you want to run.
# arg: The arguments to pass to the script.
# Requires: defined($script)
# Ensures: !$self->isLaunched()
#
# Create a PerlLauncher object. The specified script isn't
# run until you call $AppLauncher->launch()
sub new {
	my $class = shift;
	my $modulePaths = shift;
	my ($self, @interp);

	# Find a Perl interpreter
	if ($ENV{INTERPRETER}) {
		# Prefer (wx)start.exe. Because if a user uses wxstart.exe *and*
		# has ActivePerl installed, but not WxPerl, then things will go wrong.
		@interp = ($ENV{INTERPRETER}, '!');
	} else {
		@interp = ($Config{perlpath});
	}

	# Append Perl module search paths
	if ($modulePaths) {
		foreach my $path (@{$modulePaths}) {
			push @interp, "-I$path";
		}
	}

	$self = $class->SUPER::new(@interp, @_);
	return $self;
}

1;
