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

package Network::Send::kRO::Sakexe_2004_07_13a;

use strict;
use Network::Send::kRO::Sakexe_2004_07_05a;
use base qw(Network::Send::kRO::Sakexe_2004_07_05a);

use Log qw(message warning error debug);
use Utils qw(getTickCount getCoordString);

# TODO: maybe we should try to not use globals in here at all but instead pass them on?
use Globals qw($char);

sub version {
	return 7;
}

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

# 0x0072,39,wanttoconnection,12:22:30:34:38
sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)

	my $msg = pack('v x10 a4 x6 a4 x4 a4 V C', 0x0072, $accountID, $charID, $sessionID, getTickCount(), $sex);

	$self->sendToServer($msg);
}

# 0x0085,9,walktoxy,6
sub sendMove {
	my $self = shift;
	my $x = int scalar shift;
	my $y = int scalar shift;

	my $msg = pack('v x4 a3', 0x0085, getCoordString($x, $y));

	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

# 0x009b,13,changedir,5:12
sub sendLook {
	my ($self, $body, $head) = @_;
	my $msg = pack('v x3 C x6 C', 0x009B, $head, $body);
	$self->sendToServer($msg);
	debug "Sent look: $body $head\n", "sendPacket", 2;
	$char->{look}{head} = $head;
	$char->{look}{body} = $body;
}

# 0x009f,10,takeitem,6
sub sendTake {
	my ($self, $itemID) = @_;
	my $msg = pack('v x4 a4', 0x009F, $itemID);
	$self->sendToServer($msg);
	debug "Sent take\n", "sendPacket", 2;
}

# 0x00a7,17,useitem,6:13
sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg = pack('v x4 v x5 a4', 0x00A7, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

# 0x0113,19,useskilltoid,7:9:15
sub sendSkillUse {
	my ($self, $ID, $lv, $targetID) = @_;

	my %args;
	$args{ID} = $ID;
	$args{lv} = $lv;
	$args{targetID} = $targetID;
	Plugins::callHook('packet_pre/sendSkillUse', \%args);
	if ($args{return}) {
		$self->sendToServer($args{msg});
		return;
	}

	my $msg = pack('v x5 V v x2 a4', 0x0113, $lv, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

# 0x0116,19,useskilltopos,7:9:15:17
sub sendSkillUseLoc {
	my ($self, $ID, $lv, $x, $y) = @_;

	my $msg = pack('v x5 v2 x4 v2', 0x0116, $lv, $ID, $x, $y);

	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

# 0x0190,99,useskilltoposinfo,7:9:15:17:19
sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;

	my $msg = pack('v x5 v2 x4 v2 Z80', 0x0190, $lv, $ID, $x, $y, $moreinfo);

	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

=pod
//2004-07-13aSakexe
packet_ver: 7
0x0072,39,wanttoconnection,12:22:30:34:38
0x0085,9,walktoxy,6
0x009b,13,changedir,5:12
0x009f,10,takeitem,6
0x00a7,17,useitem,6:13
0x0113,19,useskilltoid,7:9:15
0x0116,19,useskilltopos,7:9:15:17
0x0190,99,useskilltoposinfo,7:9:15:17:19
=cut

1;