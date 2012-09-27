#########################################################################
#  OpenKore - Network subsystem
#  Copyright (c) 2006 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# rRO-Phoenix (Russia)
# Servertype overview: http://www.openkore.com/wiki/index.php/ServerType
package Network::Receive::rROphoenix;

use strict;
use base 'Network::Receive::ServerType0';

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'08B9' => ['account_id', 'x4 a4 x2', [qw(accountID)]], # 12 
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}
	my %handlers = qw(
		account_id 08B9
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

1;