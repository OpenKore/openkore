#########################################################################
#  OpenKore - Networking subsystem
#  This module contains functions for sending packets to the server.
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
package Network;

use strict;
use Modules 'register';

# $conState contains the connection state:
# 1: Not connected to anything		(next step -> connect to master server).
# 2: Connected to master server		(next step -> connect to login server)
# 3: Connected to login server		(next step -> connect to character server)
# 4: Connected to character server	(next step -> connect to map server)
# 5: Connected to map server; ready and functional.
#
# Special states:
# 1.2 (set by $config{gameGuard} == 2): Wait for the server response allowing us
#      to continue login
# 1.3 (set by parseMsg()): The server allowed us to continue logging in, continue
#      where we left off
# 1.5 (set by plugins): There is a special sequence for login servers and we must
#      wait the plugins to finalize before continuing
# 2.5 (set by parseMsg()): Just passed character selection; next 4 bytes will be
#      the account ID

use constant {
	NOT_CONNECTED              => 1,
	CONNECTED_TO_MASTER_SERVER => 2,
	CONNECTED_TO_LOGIN_SERVER  => 3,
	CONNECTED_TO_CHAR_SERVER   => 4,
	IN_GAME                    => 5
};

1;
