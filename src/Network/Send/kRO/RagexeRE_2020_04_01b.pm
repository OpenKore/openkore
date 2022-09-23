#########################################################################
#  OpenKore - Packet sending
#  This module contains functions for sending packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
########################################################################
#  by ya4ept
package Network::Send::kRO::RagexeRE_2020_04_01b;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2020_03_04a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0064' => ['master_login', 'V Z24 Z24 C', [qw(version username password master_version)]],
		'0819' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		master_login 0064
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->{send_buy_bulk_pack} = "v V";
	$self->{send_sell_buy_complete} = 1;

	#buyer shop
	$self->{buy_bulk_openShop_size} = "(a10)*";
	$self->{buy_bulk_openShop_size_unpack} = "V v V";

	$self->{buy_bulk_buyer_size} = "(a8)*";
	$self->{buy_bulk_buyer_size_unpack} = "a2 V v";

	return $self;
}

1;
