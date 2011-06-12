package Network::Send::kRO::RagexeRE_2010_11_24a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2010_08_03a);

use Globals qw($char $masterServer);
use Log qw(debug);
use Utils qw(getTickCount getHex getCoordString);

# 0x0436,19,wanttoconnection,2:6:10:14:18
sub sendMasterLogin {
	my ($self) = @_;
	local $masterServer->{masterLogin_packet} = '0436';
	$self->SUPER::sendMasterLogin(@_);
}

# 0x035f,5,walktoxy,2
sub sendMove {
	my ($self, $x, $y) = @_;
	$self->sendToServer(pack('v a3', 0x035F, getCoordString($x = int $x, $y = int $y, 1)));
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

# 0x0360,6,ticksend,2
sub sendSync {
	my ($self, $initialSync) = @_;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);
	
	$self->sendToServer(pack('v V', 0x0360, getTickCount));
	debug "Sent Sync\n", "sendPacket", 2;
}

# 0x0361,5,changedir,2:4
sub sendLook {
	my ($self, $body, $head) = @_;
	$self->sendToServer(pack('v C2', 0x0361, $head, $body));
	debug "Sent look: $body $head\n", "sendPacket", 2;
	$char->{look}{head} = $head;
	$char->{look}{body} = $body;
}

# 0x0362,6,takeitem,2
sub sendTake {
	my ($self, $itemID) = @_;
	$self->sendToServer(pack('v a4', 0x0362, $itemID));
	debug "Sent take\n", "sendPacket", 2;
}

# 0x0363,6,dropitem,2:4
sub sendDrop {
	my ($self, $index, $amount) = @_;
	$self->sendToServer(pack('v3', 0x0363, $index, $amount));
	debug "Sent drop: $index x $amount\n", "sendPacket", 2;
}

# 0x0364,8,movetokafra,2:4
sub sendStorageAdd {
	my ($self, $index, $amount) = @_;
	$self->sendToServer(pack('v2 V', 0x0364, $index, $amount));
	debug "Sent Storage Add: $index x $amount\n", "sendPacket", 2;
}

# 0x0365,8,movefromkafra,2:4
sub sendStorageGet {
	my ($self, $index, $amount) = @_;
	$self->sendToServer(pack('v2 V', 0x0365, $index, $amount));
	debug "Sent Storage Get: $index x $amount\n", "sendPacket", 2;
}

# 0x0366,10,useskilltopos,2:4:6:8
sub sendSkillUseLoc {
	my ($self, $ID, $lv, $x, $y) = @_;
	$self->sendToServer(pack('v5', 0x0366, $lv, $ID, $x, $y));
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

# 0x0367,90,useskilltoposinfo,2:4:6:8:10
sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;
	$self->sendToServer(pack('v5 Z80', 0x0367, $lv, $ID, $x, $y, $moreinfo));
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

# 0x0368,6,getcharnamerequest,2
sub sendGetPlayerInfo {
	my ($self, $ID) = @_;
	$self->sendToServer(pack('v a4', 0x0368, $ID));
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

# 0x0369,6,solvecharname,2
sub sendGetCharacterName {
	my ($self, $ID) = @_;
	$self->sendToServer(pack('v a4', 0x0369, $ID));
	debug "Sent get character name: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

1;
