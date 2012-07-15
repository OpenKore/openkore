package Network::Send::kRO::RagexeRE_2012_04_10a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2012_03_07f);

use Log qw(debug);
use Utils qw(getHex);

sub version { 30 }

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'02C4' => undef,
		'0368' => undef,
		'0369' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0804' => undef,
		'0806' => undef,
		'0808' => undef,
		# TODO 0x0819,-1,searchstoreinfo,2:4:5:9:13:14:15
		'0861' => undef,
		'0863' => undef,
		'0865' => undef,
		'086A' => undef,
		'086C' => ['storage_item_add', 'v V', [qw(index amount)]],
		'0870' => undef,
		'0871' => ['actor_look_at', 'v C', [qw(head body)]],
		'0884' => undef,
		'0885' => undef, # TODO 0x0885,5,hommenu,2:4
		'0886' => ['sync', 'V', [qw(time)]],
		'0887' => undef,
		'0889' => ['actor_info_request', 'a4', [qw(ID)]],
		'0890' => undef,
		'0891' => ['item_drop', 'v2', [qw(index amount)]],
		# TODO 0x089C,26,friendslistadd,2
		'08A6' => ['storage_item_remove', 'v V', [qw(index amount)]],
		# TODO 0x08D7,28,battlegroundreg,2:4
		# TODO 0x08E5,41,bookingregreq,2:4
		# TODO 0x08E7,10,bookingsearchreq,2
		# TODO 0x08E9,2,bookingdelreq,2
		# TODO 0x08EB,39,bookingupdatereq,2
		# TODO 0x08EF,6,bookingignorereq,2
		# TODO 0x08F1,6,bookingjoinpartyreq,2
		# TODO 0x08F5,-1,bookingsummonmember,2:4
		# TODO 0x08FB,6,bookingcanceljoinparty,2
		# TODO 0x0907,5,moveitem,2:4
		# TODO 0x091C,26,partyinvite2,2
		'0926' => undef,
		'0929' => undef,
		'0938' => ['item_take', 'a4', [qw(ID)]],
		'093B' => undef,
		# TODO 0x0945,-1,itemlistwindowselected,2:4:8
		'094B' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		# TODO 0x0961,36,storagepassword,0
		'096A' => undef,
		'0963' => undef,
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		map_login 094B
		sync 0886
		actor_action 0369
		actor_info_request 0889
		actor_look_at 0871
		item_take 0938
		item_drop 0891
		storage_item_add 086C
		storage_item_remove 08A6
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	$self;
}

# 0x083C,10,useskilltoid,2:4:6
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

	$msg = pack('v3 a4', 0x083C, $lv, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

# 0x0884,6,solvecharname,2
sub sendGetCharacterName {
	my ($self, $ID) = @_;
	$self->sendToServer(pack('v a4', 0x0884, $ID));
	debug "Sent get character name: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

1;
