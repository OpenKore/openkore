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
package Network::Send::kRO::RagexeRE_2010_08_03a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2010_07_14a);
use Log qw(debug);
use Translation qw(TF);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0288' => ['cash_dealer_buy', 'v V v a*', [qw(len kafra_points item_count item_list)]],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		cash_dealer_buy 0288
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

# Buy multiple items from cash dealer
sub sendCashShopBuy {
	my ($self, $points, $items) = @_;
	my $len = (scalar @{$items}) * 4 + 8;

	debug TF("Sent buying request from cash shop for %d items using %d kafra points.\n", scalar @{$items}, $points), "sendPacket", 2;
	$self->sendToServer($self->reconstruct({
		switch => 'cash_dealer_buy',
		len => $len,
		kafra_points => $points,
		item_count => (scalar @{$items}),
		items => $items,
	}));
}

sub reconstruct_cash_dealer_buy {
	my ($self, $args) = @_;
	$args->{item_list} = pack '(a4)*', map { pack 'v2', @{$_}{qw(amount itemID)} } @{$args->{items}};
}

# 0x0842,6,recall2,2

# 0x0843,6,remove2,2

1;
