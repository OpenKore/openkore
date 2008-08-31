#########################################################################
#  OpenKore - X-Kore Mode 2
#  Copyright (c) 2007 OpenKore developers
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Account server implementation.

package Network::XKore2::AccountServer;

use strict;
use Globals;
use Base::Ragnarok::AccountServer;
use base qw(Base::Ragnarok::AccountServer);

# Overrided method.
sub login {
	my ($self, $session, $username, $password) = @_;
	if ($char) {
		$session->{accountID} = $char->{ID};
		$session->{sex} = $char->{sex};
	} else {
		$session->{accountID} = pack("V", 123456);
		$session->{sex} = 0;
		$session->{dummy} = 1;
	}

	if ($config{username} ne $username || $config{adminPassword} ne $password ){
		return Base::Ragnarok::AccountServer::PASSWORD_INCORRECT;
	}

	return Base::Ragnarok::AccountServer::LOGIN_SUCCESS;
}

1;

