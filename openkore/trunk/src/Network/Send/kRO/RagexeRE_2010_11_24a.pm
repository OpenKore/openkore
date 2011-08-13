package Network::Send::kRO::RagexeRE_2010_11_24a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2010_08_03a);

use Globals qw($char $masterServer);
use Log qw(debug);
use Utils qw(getTickCount getHex getCoordString);

sub version { 26 }

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0085' => undef,
		'0089' => undef,
		'00A7' => undef,
		'00F5' => undef,
		'035F' => ['character_move', 'a3', [qw(coords)]],
		'0360' => ['sync'], # TODO
		'0361' => ['actor_look_at', 'v C', [qw(head body)]],
		'0362' => ['item_take', 'a4', [qw(ID)]],
		# 0436 unchanged
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		sync 0360
		character_move 035F
		actor_look_at 0361
		item_take 0362
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	$self;
}

# 0x0436,19,wanttoconnection,2:6:10:14:18

# 0x035f,5,walktoxy,2

# 0x0360,6,ticksend,2
sub sendSync {
	my ($self, $initialSync) = @_;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);
	
	$self->sendToServer(pack('v V', 0x0360, getTickCount));
	debug "Sent Sync\n", "sendPacket", 2;
}

# 0x0361,5,changedir,2:4

# 0x0362,6,takeitem,2

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
