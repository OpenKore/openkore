#########################################################################
#  OpenKore - Packet Receiveing
#  This module contains functions for Receiveing packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
########################################################################
# Korea (kRO) #bysctnightcore
# The majority of private servers use eAthena, this is a clone of kRO
package Network::Receive::kRO::RagexeRE_2018_07_04a;
use strict;
use base qw(Network::Receive::kRO::RagexeRE_2018_06_21a);


sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'010A' => ['mvp_item', 'V', [qw(itemID)]], #itemID 2 byte => 4 byte
		'0B02' => ['login_error', 'V Z20', [qw(type date)]],#if PACKETVER >= 20180627 Need to copy to sT20180627
	);
	
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}
1;
