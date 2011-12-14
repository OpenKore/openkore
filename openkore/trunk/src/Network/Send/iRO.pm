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
# Servertype overview: http://www.openkore.com/wiki/index.php/ServerType
package Network::Send::iRO;

use strict;
use Globals;
use Network::Send::ServerType0;
use base qw(Network::Send::ServerType0);
use Log qw(error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %handlers = qw(
		sync 0360
		actor_info_request 0368
		actor_look_at 0361
		item_take 0362
		item_drop 0363
		storage_item_add 0364
		storage_item_remove 0365
		skill_use_location 0366
		party_setting 07D7
		buy_bulk_vender 0801
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	return $self;
}

sub sendMove {
   my $self = shift;
   my $x = int scalar shift;
   my $y = int scalar shift;
   my $msg;

   $msg = pack("C*", 0x5F, 0x03) . getCoordString($x, $y, 1);

   $self->sendToServer($msg);
   debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

sub sendHomunculusMove {
	my $self = shift;
	my $homunID = shift;
	my $x = int scalar shift;
	my $y = int scalar shift;
	my $msg = pack("C*", 0x32, 0x02) . $homunID . getCoordString($x, $y, 1);
	$self->sendToServer($msg);
	debug "Sent Homunculus move to: $x, $y\n", "sendPacket", 2;
}

sub sendCharDelete {
	my ($self, $charID, $email) = @_;
	my $msg = pack("C*", 0xFB, 0x01) .
			$charID . pack("a50", stringToBytes($email));
	$self->sendToServer($msg);
}

1;