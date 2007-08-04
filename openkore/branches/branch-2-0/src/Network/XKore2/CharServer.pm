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
# MODULE DESCRIPTION: Character server implementation.

package Network::XKore2::CharServer;

use strict;
use Globals qw($char);
use Base::Ragnarok::CharServer;
use base qw(Base::Ragnarok::CharServer);

# Overrided method.
sub getCharacters {
	my ($self, $session) = @_;
	my @chars;
	if (!$session->{dummy} && $char) {
		for (my $i = 0; $i < 5; $i++) {
			push @chars, $char;
		}
	} else {
		$session->{dummy} = 1;
		for (my $i = 0; $i < 5; $i++) {
			push @chars, Base::Ragnarok::CharServer::DUMMY_CHARACTER;
		}
	}
	return @chars;
}

1;

