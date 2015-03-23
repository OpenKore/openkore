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

use Log qw(debug);

sub version {
	return 6;
}

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0072' => ['map_login', 'x3 a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0085' => ['character_move', 'x3 a3', [qw(coords)]],
		'00A7' => ['item_use', 'x3 v x2 a4', [qw(index targetID)]],#13
		'0113' => ['skill_use', 'x2 v x3 v a4', [qw(lv skillID targetID)]],#15
		'0116' => ['skill_use_location', 'x2 v x3 v3', [qw(lv skillID x y)]],
		'0208' => ['friend_response', 'a4 a4 V', [qw(friendAccountID friendCharID type)]],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	$self;
}

sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;
	my $msg = pack('v x2 v x3 v3 Z80', 0x0190, $lv, $ID, $x, $y, $moreinfo);
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

1;

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