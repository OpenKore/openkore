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
#
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

our @ISA = qw(Exporter);
our @EXPORT = qw(
	%config

	@ai_seq @ai_seq_args %ai_v $AI

	@chars @playersID %players @monstersID %monsters @portalsID %portals @itemsID %items @npcsID %npcs
	%field

	$remote_socket

	%timeout_ex $isOnline
);

our %config;

# AI
our @ai_seq;
our @ai_seq_args;
our %ai_v;
our $AI = 1;

# Game state
our @chars;
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

# Connection
our $remote_socket;

# Misc
our %timeout_ex;
our $isOnline; # for determining whether a guild member logged in or out

return 1;
