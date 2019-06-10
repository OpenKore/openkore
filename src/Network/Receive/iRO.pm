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
# iRO (International)
# Servertype overview: http://wiki.openkore.com/index.php/ServerType
package Network::Receive::iRO;

use strict;
use base qw(Network::Receive::ServerType0);

use Globals qw($messageSender %timeout %config);
use Log qw(message debug);
use Misc qw(center itemName);
use Translation qw(T TF);
use Utils qw(formatNumber swrite timeOut);

use Time::HiRes qw(time);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'0097' => ['private_message', 'v Z24 V Z*', [qw(len privMsgUser flag privMsg)]], # -1
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}
	
	my %handlers = qw(
		received_characters 099D
		received_characters_info 082D
		sync_received_characters 09A0
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

    # Version 2 of the 0800 vender items packet (with options).
	$self->{vender_items_list_item_pack} = 'V v2 C v C3 a8 a25';

	return $self;
}

1;