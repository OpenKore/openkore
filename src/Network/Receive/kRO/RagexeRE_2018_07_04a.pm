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
		'0ADD' => ['item_exists', 'a4 V v C v2 C2 v C v', [qw(ID nameID type identified x y subx suby amount show_effect effect_type )]],#nameID 2 byte => 4 byte
		'0A37' => ['inventory_item_added', 'a2 v V C3 a8 V C2 a4 v a25', [qw(ID amount nameID identified broken upgrade cards type_equip type fail expire unknown options)]],#nameID 2 byte => 4 byte
		'0A0A' => ['storage_item_added', 'a2 V2 C4 a8 a25', [qw(ID amount nameID type identified broken upgrade cards options)]],#nameID 2 byte => 4 byte
		'0110' => ['skill_use_failed', 'v V2 C2', [qw(skillID btype itemID fail type)]],#unknown = > itemID
		'0A0B' => ['cart_item_added', 'a2 V2 C4 a8 a25', [qw(ID amount nameID type identified broken upgrade cards options)]],#nameID 2 byte => 4 byte

		);
	
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}
1;
