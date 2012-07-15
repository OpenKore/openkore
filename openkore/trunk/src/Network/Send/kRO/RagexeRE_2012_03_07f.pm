package Network::Send::kRO::RagexeRE_2012_03_07f;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2011_11_02a);

use Log qw(debug);
use Utils qw(getHex);

sub version { 29 }

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'02C4' => ['item_drop', 'v2', [qw(index amount)]],
		'0281' => undef,
		'02C4' => undef,
		# TODO 0x0360,6,reqclickbuyingstore,2
		'0363' => undef,
		'0364' => undef,
		'0366' => undef,
		'0369' => undef, # TODO 0x0369,26,friendslistadd,2
		'0436' => undef,
		'0437' => ['character_move', 'a3', [qw(coords)]],
		'0438' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0811' => undef, # TODO 0x0811,-1,reqtradebuyingstore,2:4:8:12
		'0815' => undef, # TODO 0x0815,-1,reqopenbuyingstore,2:4:8:9:89
		'0817' => undef, # TODO 0x0817,2,reqclosebuyingstore,0
		'0835' => undef, # TODO 0x0835,2,searchstoreinfonextpage,0
		'0838' => undef, # TODO 0x0838,12,searchstoreinfolistitemclick,2:6:10
		'083C' => undef,
		# TODO 0x0861,36,storagepassword,0
		# TODO 0x0863,5,hommenu,4
		'0865' => ['item_take', 'a4', [qw(ID)]],
		'086A' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		# TODO 0x0870,-1,itemlistwindowselected,2:4:8
		# TODO 0x0884,-1,searchstoreinfo,2:4:5:9:13:14:15
		'0885' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0887' => ['sync', 'V', [qw(time)]],
		'088A' => undef,
		'088B' => undef,
		'088D' => undef,
		'0890' => ['actor_look_at', 'v C', [qw(head body)]],
		'0893' => undef,
		'0897' => undef,
		'0898' => undef,
		'089B' => undef,
		'089E' => undef,
		'08A1' => undef,
		'08A2' => undef,
		'08A5' => undef,
		'08AA' => undef,
		'08AB' => undef,
		'08AD' => undef,
		# TODO 0x0926,18,bookingregreq,2:4:6
		# TODO 0x0929,26,partyinvite2,2
		'093B' => ['storage_item_add', 'v V', [qw(index amount)]],
		'0963' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'096A' => ['actor_info_request', 'a4', [qw(ID)]],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		map_login 086A
		sync 0887
		character_move 0437
		actor_action 0885
		actor_info_request 096A
		actor_look_at 0890
		item_take 0865
		item_drop 02C4
		storage_item_add 093B
		storage_item_remove 0963
		skill_use_location 0438
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	$self;
}

# 0x0366,90,useskilltoposinfo,2:4:6:8:10
sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;
	$self->sendToServer(pack('v5 Z80', 0x0366, $lv, $ID, $x, $y, $moreinfo));
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

# 0x0368,6,solvecharname,2
sub sendGetCharacterName {
	my ($self, $ID) = @_;
	$self->sendToServer(pack('v a4', 0x0368, $ID));
	debug "Sent get character name: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

# 0x0889,10,useskilltoid,2:4:6
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

	$msg = pack('v3 a4', 0x0889, $lv, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

1;
