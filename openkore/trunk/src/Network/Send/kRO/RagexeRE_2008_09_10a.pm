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

package Network::Send::kRO::RagexeRE_2008_09_10a;

use strict;
use Network::Send::kRO::RagexeRE_2008_08_27a;
use base qw(Network::Send::kRO::RagexeRE_2008_08_27a);

use Log qw(message warning error debug);
use Utils qw(getTickCount getHex);

sub version {
	return 25; # looks a lot like 23, except that 25 inherits from 24
}

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

# 0x0436,19,wanttoconnection,2:6:10:14:18
sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	my $msg = pack('v a4 a4 a4 V C', 0x0436, $accountID, $charID, $sessionID, getTickCount(), $sex);
	$self->sendToServer($msg);
}

# 0x0437,7,actionrequest,2:6
sub sendAction { # flag: 0 attack (once), 7 attack (continuous), 2 sit, 3 stand
	my ($self, $monID, $flag) = @_;

	my %args;
	$args{monID} = $monID;
	$args{flag} = $flag;
	# eventually we'll trow this hooking out so...
	Plugins::callHook('packet_pre/sendAttack', \%args) if ($flag == 0 || $flag == 7);
	Plugins::callHook('packet_pre/sendSit', \%args) if ($flag == 2 || $flag == 3);
	if ($args{return}) {
		$self->sendToServer($args{msg});
		return;
	}

	my $msg = pack('v a4 C', 0x0437, $monID, $flag);
	$self->sendToServer($msg);
	debug "Sent Action: " .$flag. " on: " .getHex($monID)."\n", "sendPacket", 2;
}

# 0x0438,10,useskilltoid,2:4:6
sub sendSkillUse {
	my ($self, $ID, $lv, $targetID) = @_;
	my $msg;

	my %args;
	$args{ID} = $ID;
	$args{lv} = $lv;
	$args{targetID} = $targetID;
	Plugins::callHook('packet_pre/sendSkillUse', \%args);
	if ($args{return}) {
		$self->sendToServer($args{msg});
		return;
	}

	$msg = pack('v3 a4', 0x0438, $lv, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

# 0x0439,8,useitem,2:4
sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg = pack('v2 a4', 0x0439, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

=pod
//2008-09-10aRagexeRE
packet_ver: 25
0x0436,19,wanttoconnection,2:6:10:14:18
0x0437,7,actionrequest,2:6
0x0438,10,useskilltoid,2:4:6
0x0439,8,useitem,2:4
=cut

1;