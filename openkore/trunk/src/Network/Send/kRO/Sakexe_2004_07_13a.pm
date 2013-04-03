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
use base qw(Network::Send::kRO::Sakexe_2004_07_05a);

use Log qw(debug);

sub version {
	return 7;
}

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0072' => ['map_login', 'x10 a4 x6 a4 x4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0085' => ['character_move', 'x4 a3', [qw(coords)]],
		'009B' => ['actor_look_at', 'x3 C x6 C', [qw(head body)]],
		'009F' => ['item_take', 'x4 a4', [qw(ID)]],
		'0113' => ['skill_use', 'v x5 V v x2 a4', [qw(lv skillID targetID)]],#19
		'0116' => ['skill_use_location', 'x5 v2 x4 v2', [qw(lv skillID x y)]],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	$self;
}

sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg = pack('v x4 v x5 a4', 0x00A7, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;
	my $msg = pack('v x5 v2 x4 v2 Z80', 0x0190, $lv, $ID, $x, $y, $moreinfo);
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

1;

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