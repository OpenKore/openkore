#########################################################################
#  OpenKore - Account object
#  Copyright (c) 2004-17 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#
#########################################################################
##
# MODULE DESCRIPTION: Account related routines variables
#
#
#
#
# Planning and testing:
#
# Stage 1: Break out variables from Globals.pm into their own file
# --------
#  First, make Account.pm, and put all variables for a future account
#  object into the file -- duplicating what is in Globals.pm
#
#  Second, remove the variables from Globals.pm, and add Accounts in a
#  uses clause for each affected file.  Only 'use' the specific
#  variables required by each file!  Ensure that openkore both compiles
#  and runs cleanly.
#
#  This will require more testing from other users, to ensure that we
#  can move onto the next stage.
#
# Stage 2: Move all account-related routines into Account module.
# --------
#
#  Search through Globals.pm and all other files for account-related
#  code, and move them over to Account.pm, *ONE MODULE AT A TIME*.
#
#  Test and fix all routine references, to ensure openkore both compiles
#  and runs cleanly.  Have others test periodically to ensure there are
#  no bugs or breakages.
#
# Stage 3: Convert Account.pm from a simple module into an object.
# --------
#
#  Convert the disjoint variables and routines into an object.  This
#  will cause many changes throughout the code again.  Testing will be
#  important here to ensure a clean build and that there are not any
#  problems running openkore.
#
#  Converting to an object will allow for the possibility to have one
#  instance of openkore control multiple accounts.
#
#
##


package Account;

use strict;
use warnings;

use Exporter;
use base qw(Exporter);
use Modules 'register';



our %EXPORT_TAGS = (
	config  => [qw($char)],
	state   => [qw(@chars @chars_old)],
);

our @EXPORT = (
	@{$EXPORT_TAGS{config}},
	@{$EXPORT_TAGS{state}}
);


# AI

#Config
our $char;

# Game state
our @chars;
our @chars_old;


# Network


return 1;

