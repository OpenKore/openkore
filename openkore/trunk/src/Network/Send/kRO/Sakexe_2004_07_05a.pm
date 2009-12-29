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

package Network::Send::kRO::Sakexe_2004_07_05a;

use strict;
use base qw(Network::Send::kRO::Sakexe_0);

use Log qw(message warning error debug);
use Utils qw(getTickCount getCoordString);

sub version {
	return 6;
}

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

# 0x0072,22,wanttoconnection,5:9:13:17:21
sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)

	my $msg = pack('v x3 a4 a4 a4 V C', 0x0072, $accountID, $charID, $sessionID, getTickCount(), $sex);

	$self->sendToServer($msg);
}

# 0x0085,8,walktoxy,5
sub sendMove {
	my ($self, $x, $y) = @_;
	my $msg = pack('v x3 a3', 0x0085, getCoordString(int $x, int $y));
	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

# 0x00a7,13,useitem,5:9
sub sendItemUse {
	my ($self, $ID, $targetID) = @_;

	my $msg = pack('v x3 v x2 a4', 0x00A7 ,$ID, $targetID);

	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

# 0x0113,15,useskilltoid,4:9:11
sub sendSkillUse {
	my ($self, $ID, $lv, $targetID) = @_;

	my $msg = pack('v x2 v x3 v a4', 0x0113, $lv, $ID, $targetID);

	$self->sendToServer($msg);
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

# 0x0116,15,useskilltopos,4:9:11:13
sub sendSkillUseLoc {
	my ($self, $ID, $lv, $x, $y) = @_;

	my $msg = pack('v x2 v x3 v3', 0x0116, $lv, $ID, $x, $y);

	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

# 0x0190,95,useskilltoposinfo,4:9:11:13:15
sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;

	my $msg = pack('v x2 v x3 v3 Z80', 0x0190, $lv, $ID, $x, $y, $moreinfo);

	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

# 0x0208,14,friendslistreply,2:6:10
sub sendFriendListReply { # 1 accept, 0 deny
	my ($self, $accountID, $charID, $flag) = @_;
	my $msg = pack('v a4 a4 V', 0x0208, $accountID, $charID, $flag);
	$self->sendToServer($msg);
	debug "Sent Reject friend request\n", "sendPacket";
}

=pod
//2004-07-05aSakexe
packet_ver: 6
0x0072,22,wanttoconnection,5:9:13:17:21
0x0085,8,walktoxy,5
0x00a7,13,useitem,5:9
0x0113,15,useskilltoid,4:9:11
0x0116,15,useskilltopos,4:9:11:13
0x0190,95,useskilltoposinfo,4:9:11:13:15
0x0208,14,friendslistreply,2:6:10
=cut

1;