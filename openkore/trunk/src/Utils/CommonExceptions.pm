#########################################################################
#  OpenKore - Common exception objects
#
#  Copryight (c) 2006 OpenKore Development Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Common exception objects.
#
# This module defines the following commonly-used exception objects:
# `l
# - IOException - Input/output exception occured.
# - FileNotFoundException - A file is not found.
# - UTF8MalformedException - Invalid UTF-8 data encountered.
# `l`
package Utils::CommonExceptions;

use Exception::Class (
	'IOException',
	'FileNotFoundException'  => { isa => 'IOException' },
	'UTF8MalformedException' => { fields => 'line' }
);

1;
