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
#
#  $Revision: 6687 $
#  $Id: kRO.pm 6687 2009-04-19 19:04:25Z technologyguild $
########################################################################
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO

package Network::Send::kRO::Sakexe_2005_04_11a;

use strict;
use Network::Send::kRO::Sakexe_2005_04_04a;
use base qw(Network::Send::kRO::Sakexe_2005_04_04a);
use Log qw(message warning error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

# 0x022d,5,hommenu,4
sub sendHomunculusCommand {
	my ($self, $command, $type) = @_; # $type is ignored, $command can be 0, 1 or 2
	
	my $msg = pack ('v2 C', 0x022D, $type, $command);
	$self->sendToServer ($msg);
	debug "Sent Homunculus Command", "sendPacket", 2;
}

# 0x0232,9,hommoveto,6
sub sendHomunculusMove {
	my $self = shift;
	my $homunID = shift;
	my $x = int scalar shift;
	my $y = int scalar shift;
	my $msg = pack('v a4 a3', 0x0232, $homunID, getCoordString($x, $y, 1));
	$self->sendToServer($msg);
	debug "Sent Homunculus move to: $x, $y\n", "sendPacket", 2;
}

# 0x0233,11,homattack,0
sub sendHomunculusAttack {
	my $self = shift;
	my $homunID = shift;
	my $targetID = shift;
	my $flag = shift;
	my $msg = pack('v a4 a4 C', 0x0233, $homunID, $targetID, $flag);
	$self->sendToServer($msg);
	debug "Sent Homunculus attack: ".getHex($targetID)."\n", "sendPacket", 2;
}

# 0x0234,6,hommovetomaster,0
sub sendHomunculusStandBy {
	my $self = shift;
	my $homunID = shift;
	my $msg = pack('v a4', 0x0234, $homunID);
	$self->sendToServer($msg);
	debug "Sent Homunculus standby\n", "sendPacket", 2;
}

=pod
//2005-04-25aSakexe
0x022d,5,hommenu,4
0x0232,9,hommoveto,6
0x0233,11,homattack,0
0x0234,6,hommovetomaster,0
=cut

1;