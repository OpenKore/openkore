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
# Korea (kRO) #by sctnightcore
# The majority of private servers use eAthena, this is a clone of kRO
package Network::Receive::kRO::RagexeRE_2020_03_04a;
use strict;
use base qw(Network::Receive::kRO::RagexeRE_2018_11_21);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

    my %packets = (
		'009D' => ['item_exists', 'a4 V C v3 C2', [qw(ID nameID identified x y amount subx suby)]], # 19
		'0ADD' => ['item_appeared', 'a4 V v C v2 C2 v C v', [qw(ID nameID type identified x y subx suby amount show_effect effect_type )]], # 24
		'01C8' => ['item_used', 'a2 V a4 v C', [qw(ID itemID actorID remaining success)]], # 15
		'0A0A' => ['storage_item_added', 'a2 V2 C4 a16 a25', [qw(ID amount nameID type identified broken upgrade cards options)]], # 57
		'0A0B' => ['cart_item_added', 'a2 V2 C4 a16 a25', [qw(ID amount nameID type identified broken upgrade cards options)]], # 57
		'0A37' => ['inventory_item_added', 'a2 v V C3 a16 V C2 a4 v a25 C v', [qw(ID amount nameID identified broken upgrade cards type_equip type fail expire unknown options favorite viewID)]], # 69
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	$self->{buying_store_items_list_pack} = "V v C V";
	$self->{makable_item_list_pack} = "V4";
	$self->{npc_store_info_pack} = "V V C V";
	$self->{vender_items_list_item_pack} = 'V v2 C V C3 a16 a25 V v';

	return $self;
}

1;
