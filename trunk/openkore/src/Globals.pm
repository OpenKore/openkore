#########################################################################
#  OpenKore - Global variables
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
# MODULE DESCRIPTION: Global variables
#
# This module defines all kinds of global variables.

package Globals;

use strict;
use Exporter;
use base qw(Exporter);
# Do not use any other Kore modules here. It will create circular dependancies.

our %EXPORT_TAGS = (
	config	=> [qw(%config %consoleColors %maps_lut %npcs_lut %shop %timeout)],
	ai	=> [qw(@ai_seq @ai_seq_args %ai_v $AI)],
	state	=> [qw(@chars %cart @playersID %players @monstersID %monsters @portalsID %portals
			@itemsID %items @npcsID %npcs %field)],
	network	=> [qw($remote_socket $conState $encryptVal)],
	misc	=> [qw($buildType %timeout_ex $isOnline $shopstarted)],
	);

our @EXPORT = (
	@{$EXPORT_TAGS{config}},
	@{$EXPORT_TAGS{ai}},
	@{$EXPORT_TAGS{state}},
	@{$EXPORT_TAGS{network}},
	@{$EXPORT_TAGS{misc}},
);


# Configuration variables
our %config;
our %consoleColors;
our %maps_lut;
our %npcs_lut;
our %shop;
our %timeout;

# AI
our @ai_seq;
our @ai_seq_args;
our %ai_v;
our $AI = 1;

# Game state
our @chars;
our %cart;
our @playersID;
our %players;
our @monstersID;
our %monsters;
our @portalsID;
our %portals;
our @itemsID;
our %items;
our @npcsID;
our %npcs;
our %field;

# Network
our $remote_socket;
our $conState;
our $encryptVal;

# Misc
our $buildType;
our %timeout_ex;
our $isOnline; # for determining whether a guild member logged in or out
our $shopstarted;


# Detect operating system
if ($^O eq 'MSWin32' || $^O eq 'cygwin') {
	$buildType = 0;
} else {
	$buildType = 1;
}

return 1;
