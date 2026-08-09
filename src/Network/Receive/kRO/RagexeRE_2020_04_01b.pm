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
# Korea (kRO) # by ya4ept
# The majority of private servers use eAthena, this is a clone of kRO
package Network::Receive::kRO::RagexeRE_2020_04_01b;
use strict;
use base qw(Network::Receive::kRO::RagexeRE_2020_03_04a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	# PacketParser keeps several generations for these handler names. Pin the
	# opcodes expected by this client so XKore2 reconstructs modern snapshots.
	my %handlers = qw(
		account_id 0283
		inventory_expansion_result 0B18
		skills_list 0B32
		map_loaded 02EB
		actor_moved 09FD
		actor_connected 09FE
		actor_exists 09FF
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->{vender_items_list_item_pack} = 'V v2 C V C3 a16 a25 V v';
	$self->{npc_store_info_pack} = "V V C V";
	$self->{buying_store_items_list_pack} = "V v C V";
	$self->{makable_item_list_pack} = "V4";

	return $self;
}

1;
