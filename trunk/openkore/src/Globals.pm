#########################################################################
#  OpenKore - Global variables
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
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
	@ai_seq @ai_seq_args
	$remote_socket
	%timeout_ex
	);


# AI
our @ai_seq;
our @ai_seq_args;

# Connection
our $remote_socket;

# Misc
our %timeout_ex;

return 1;
