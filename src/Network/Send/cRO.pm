#########################################################################
#  OpenKore - Network subsystem
#  This module contains functions for sending messages to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
package Network::Send::cRO;

use strict;
use base qw(Network::Send::ServerType0);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %handlers = qw(
		master_login 0987
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self
}

1;
