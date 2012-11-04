#########################################################################
#  OpenKore - Packet sending
#  This module contains functions for sending packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http:#//www.gnu.org/licenses/gpl.html for the full license.
########################################################################
package Network::Send::kRO::RagexeRE_2011_10_05a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2011_08_16a);

use Log qw(debug);
use Utils qw(getHex);

sub version { 27 }

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0202' => undef,
		'035F' => undef,
		'0362' => undef,
		'0364' => ['character_move', 'a3', [qw(coords)]],
		'0365' => undef,
		'0366' => ['actor_look_at', 'v C', [qw(head body)]],
		'0369' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0437' => undef,
		'0438' => undef,
		'07E4' => undef,
		'0815' => ['item_take', 'a4', [qw(ID)]],
		'0817' => ['sync', 'V', [qw(time)]],
		'0885' => ['item_drop', 'v2', [qw(index amount)]],
		'088A' => ['actor_info_request', 'a4', [qw(ID)]],
		'0893' => ['storage_item_add', 'v V', [qw(index amount)]],
		'0897' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'08AD' => undef,
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		sync 0817
		character_move 0364
		actor_info_request 088A
		actor_look_at 0366
		item_take 0815
		item_drop 0885
		storage_item_add 0893
		storage_item_remove 0897
		skill_use_location 0369
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	$self;
}

# 0x0838,6,solvecharname,2
sub sendGetCharacterName {
	my ($self, $ID) = @_;
	$self->sendToServer(pack('v a4', 0x0838, $ID));
	debug "Sent get character name: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

# 0x08ad,90,useskilltoposinfo,2:4:6:8:10
sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;
	$self->sendToServer(pack('v5 Z80', 0x08AD, $lv, $ID, $x, $y, $moreinfo));
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

1;
