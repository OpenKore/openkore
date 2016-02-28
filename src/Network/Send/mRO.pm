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
# tRO (Thai) for 2008-09-16Ragexe12_Th
# Servertype overview: http://wiki.openkore.com/index.php/ServerType
package Network::Send::mRO;

use strict;
use Globals;
use Network::Send::ServerType0;
use base qw(Network::Send::ServerType0);
use Log qw(error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString pin_encode);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %handlers = qw(
		buy_bulk_vender 0801
		sync 0360
		character_move 035F
		actor_info_request 0368
		actor_look_at 0361
		item_take 0362
		item_drop 0363
		storage_item_add 0364
		storage_item_remove 0365
		skill_use_location 0366
		party_setting 07D7
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	return $self;
}

sub sendLoginPinCode {
	my $self = shift;
	# String's with PIN codes
	my $pin1 = shift;
	my $pin2 = shift;
        # Actually the Key
	my $key_v = shift;
	# 2 = set password
	# 3 = enter password
	my $type = shift;
	my $encryptionKey = shift;

	my $msg;
	if ($pin1 !~ /^\d*$/) {
		ArgumentException->throw("PIN code 1 must contain only digits.");
	}
	if ($type == 2 && $pin2 !~ /^\d*$/) {
		ArgumentException->throw("PIN code 2 must contain only digits.");
	}
	if (!$encryptionKey) {
		ArgumentException->throw("No encryption key given.");
	}

	my $crypton = new Utils::Crypton(pack("V*", @{$encryptionKey}), 32);
	my $num1 = pin_encode($pin1, $key_v);
	my $num2 = pin_encode($pin2, $key_v);
	if ($type == 2) {
		if ((length($pin1) > 3) && (length($pin1) < 9) && (length($pin2) > 3) && (length($pin2) < 9)) {
			my $ciphertextblock1 = $crypton->encrypt(pack("V*", $num1, 0, 0, 0)); 
			my $ciphertextblock2 = $crypton->encrypt(pack("V*", $num2, 0, 0, 0));
			$msg = pack("C C v", 0x3B, 0x02, $type).$ciphertextblock1.$ciphertextblock2;
			$self->sendToServer($msg);
		} else {
			ArgumentException->throw("Both PIN codes must be more than 3 and less than 9 characters long.");
		}
	} elsif ($type == 3) {
		if ((length($pin1) > 3) && (length($pin1) < 9)) {
			my $ciphertextblock1 = $crypton->encrypt(pack("V*", $num1, 0, 0, 0)); 
			my $ciphertextblock2 = $crypton->encrypt(pack("V*", 0, 0, 0, 0)); 
			$msg = pack("C C v", 0x3B, 0x02, $type).$ciphertextblock1.$ciphertextblock2;
			$self->sendToServer($msg);
		} else {
			ArgumentException->throw("PIN code 1 must be more than 3 and less than 9 characters long.");
		}
	} else {
		ArgumentException->throw("The 'type' argument has invalid value ($type).");
	}
}

1;