package Network::Send::kRO::RagexeRE_2011_11_02a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2011_10_05a);

use Log qw(debug);
use Utils qw(getHex);

sub version { 28 }

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		# TODO 0x0281,36,storagepassword,0
		'0436' => undef, # TODO 0x0436,26,friendslistadd,2
		'0437' => undef,
		# TODO 0x0811,-1,itemlistwindowselected,2:4:8
		# TODO 0x0835,-1,reqopenbuyingstore,2:4:8:9:89
		'083C' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		# 0x890,8 ?
		'08AA' => ['actor_action', 'a4 C', [qw(targetID type)]],
		# TODO 0x088b,2,searchstoreinfonextpage,0
		# TODO 0x088d,26,partyinvite2,2
		# TODO 0x0898,5,hommenu,4
		# TODO 0x089b,2,reqclosebuyingstore,0
		# TODO 0x089e,-1,reqtradebuyingstore,2:4:8:12
		# TODO 0x08a1,6,reqclickbuyingstore,2
		# TODO 0x08a2,12,searchstoreinfolistitemclick,2:6:10
		# TODO 0x08a5,18,bookingregreq,2:4:6
		# TODO 0x08ab,-1,searchstoreinfo,2:4:5:9:13:14:15
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		map_login 083C
		actor_action 08AA
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	$self;
}

# 0x02c4,10,useskilltoid,2:4:6
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

	$msg = pack('v3 a4', 0x02C4, $lv, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

1;
