# rRO (Russia)
package Network::Send::rRO;
use strict;

use base 'Network::Send::ServerType0';

use Log qw(debug);

# Copy from Network::Send::kRO::RagexeRE_2009_12_08a::sendBuyBulkVender
sub sendBuyBulkVender {
	my ($self, $venderID, $r_array, $venderCID) = @_;
	my $msg = pack('v2 a4 a4', 0x0801, 12+4*@{$r_array}, $venderID, $venderCID); # TODO: is it the vender's charID?
	for (my $i = 0; $i < @{$r_array}; $i++) {
		$msg .= pack('v2', $r_array->[$i]{amount}, $r_array->[$i]{itemIndex});
		debug "Sent bulk buy vender: $r_array->[$i]{itemIndex} x $r_array->[$i]{amount}\n", "d_sendPacket", 2;
	}
	$self->sendToServer($msg);
}

1;
