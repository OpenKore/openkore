package Network::Receive::bRO;
use strict;
use Log qw(message warning error debug);
use base 'Network::Receive::ServerType0';
use Globals qw($messageSender);

# Sync_Ex algorithm developed by Fr3DBr

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
	
		'0097' => ['private_message', 'v Z24 V Z*', [qw(len privMsgUser flag privMsg)]], # -1
		
		'095E' => ['sync_request_ex'],
		'095D' => ['sync_request_ex'],
		'087F' => ['sync_request_ex'],
		'091D' => ['sync_request_ex'],
		'093D' => ['sync_request_ex'],
		'0862' => ['sync_request_ex'],
		'0926' => ['sync_request_ex'],
		'089E' => ['sync_request_ex'],
		'08A4' => ['sync_request_ex'],
		'0362' => ['sync_request_ex'],
		'089C' => ['sync_request_ex'],
		'0365' => ['sync_request_ex'],
		'0891' => ['sync_request_ex'],
		'08A5' => ['sync_request_ex'],
		'0923' => ['sync_request_ex'],
		'0886' => ['sync_request_ex'],
		'092D' => ['sync_request_ex'],
		'096A' => ['sync_request_ex'],
		'0281' => ['sync_request_ex'],
		'0960' => ['sync_request_ex'],
		'091F' => ['sync_request_ex'],
		'08A6' => ['sync_request_ex'],
		'0869' => ['sync_request_ex'],
		'0874' => ['sync_request_ex'],
		'0835' => ['sync_request_ex'],
		'0963' => ['sync_request_ex'],
		'0941' => ['sync_request_ex'],
		'0934' => ['sync_request_ex'],
		'0892' => ['sync_request_ex'],
		'0875' => ['sync_request_ex'],
		'0918' => ['sync_request_ex'],
		'0951' => ['sync_request_ex'],
		'0895' => ['sync_request_ex'],
		'07EC' => ['sync_request_ex'],
		'093F' => ['sync_request_ex'],
		'0878' => ['sync_request_ex'],
		'0938' => ['sync_request_ex'],
		'087A' => ['sync_request_ex'],
		'094A' => ['sync_request_ex'],
		'0871' => ['sync_request_ex'],
		'0930' => ['sync_request_ex'],
		'086F' => ['sync_request_ex'],
		'0889' => ['sync_request_ex'],
		'0924' => ['sync_request_ex'],
		'08AD' => ['sync_request_ex'],
		'0863' => ['sync_request_ex'],
		'0967' => ['sync_request_ex'],
		'0885' => ['sync_request_ex'],
		'0950' => ['sync_request_ex'],
		'086C' => ['sync_request_ex'],
		'08AC' => ['sync_request_ex'],
		'0955' => ['sync_request_ex'],
		'0953' => ['sync_request_ex'],
		'089F' => ['sync_request_ex'],
		'0202' => ['sync_request_ex'],
		'0366' => ['sync_request_ex'],
		'0961' => ['sync_request_ex'],
		'093E' => ['sync_request_ex'],
		'0811' => ['sync_request_ex'],
		'0868' => ['sync_request_ex'],
		'092A' => ['sync_request_ex'],
		'0894' => ['sync_request_ex'],
		'0890' => ['sync_request_ex'],
		'0962' => ['sync_request_ex'],
		'0838' => ['sync_request_ex'],
		'0865' => ['sync_request_ex'],
		'089D' => ['sync_request_ex'],
		'0898' => ['sync_request_ex'],
		'094B' => ['sync_request_ex'],
		'095F' => ['sync_request_ex'],
		'0935' => ['sync_request_ex'],
		'02C4' => ['sync_request_ex'],
		'0922' => ['sync_request_ex'],
		'092B' => ['sync_request_ex'],
		'087B' => ['sync_request_ex'],
		'085B' => ['sync_request_ex'],
		'0880' => ['sync_request_ex'],
		'091C' => ['sync_request_ex'],
		'0817' => ['sync_request_ex'],
		'085E' => ['sync_request_ex'],
		'094D' => ['sync_request_ex'],
		'0940' => ['sync_request_ex'],
		'0367' => ['sync_request_ex'],
		'0877' => ['sync_request_ex'],
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

sub items_nonstackable {
	my ($self, $args) = @_;

	my $items = $self->{nested}->{items_nonstackable};

	if($args->{switch} eq '00A4' || # inventory
	   $args->{switch} eq '00A6' || # storage
	   $args->{switch} eq '0122'    # cart
	) {
		return $items->{type4};

	} elsif ($args->{switch} eq '0295' || # inventory
		 $args->{switch} eq '0296' || # storage
		 $args->{switch} eq '0297'    # cart
	) {
		return $items->{type4};

	} elsif ($args->{switch} eq '02D0' || # inventory
		 $args->{switch} eq '02D1' || # storage
		 $args->{switch} eq '02D2'    # cart
	) {
		return  $items->{type4};
	} else {
		warning("items_nonstackable: unsupported packet ($args->{switch})!\n");
	}
}

sub sync_request_ex {
	my ($self, $args) = @_;
	
	# Debug Log
	# message "Received Sync Ex : 0x" . $args->{switch} . "\n";
	
	# Computing Sync Ex - By Fr3DBr
	my $PacketID = $args->{switch};
	
	# Sync Ex Reply Array
	my %sync_ex_question_reply = (
		'095E' => '0438',
		'095D' => '087D',
		'087F' => '0867',
		'091D' => '07E4',
		'093D' => '095C',
		'0862' => '0937',
		'0926' => '0369',
		'089E' => '08A3',
		'08A4' => '035F',
		'0362' => '0873',
		'089C' => '0931',
		'0365' => '0919',
		'0891' => '0945',
		'08A5' => '08A0',
		'0923' => '093A',
		'0886' => '0920',
		'092D' => '093B',
		'096A' => '087C',
		'0281' => '085A',
		'0960' => '094F',
		'091F' => '085D',
		'08A6' => '0876',
		'0869' => '089A',
		'0874' => '0363',
		'0835' => '0957',
		'0963' => '0966',
		'0941' => '086B',
		'0934' => '086E',
		'0892' => '095B',
		'0875' => '083C',
		'0918' => '095A',
		'0951' => '086D',
		'0895' => '0943',
		'07EC' => '0436',
		'093F' => '0882',
		'0878' => '0968',
		'0938' => '0921',
		'087A' => '0949',
		'094A' => '0819',
		'0871' => '08A2',
		'0930' => '088D',
		'086F' => '088A',
		'0889' => '0815',
		'0924' => '092E',
		'08AD' => '0942',
		'0863' => '091A',
		'0967' => '0887',
		'0885' => '0802',
		'0950' => '08A7',
		'086C' => '0928',
		'08AC' => '0860',
		'0955' => '0947',
		'0953' => '085F',
		'089F' => '088B',
		'0202' => '0897',
		'0366' => '091E',
		'0961' => '094C',
		'093E' => '091B',
		'0811' => '088E',
		'0868' => '0437',
		'092A' => '0879',
		'0894' => '0939',
		'0890' => '0888',
		'0962' => '0965',
		'0838' => '0956',
		'0865' => '0944',
		'089D' => '0929',
		'0898' => '08AB',
		'094B' => '093C',
		'095F' => '0884',
		'0935' => '0368',
		'02C4' => '0360',
		'0922' => '0881',
		'092B' => '0364',
		'087B' => '0866',
		'085B' => '0954',
		'0880' => '094E',
		'091C' => '0896',
		'0817' => '087E',
		'085E' => '0927',
		'094D' => '0958',
		'0940' => '0870',
		'0367' => '088F',
		'0877' => '089B',
	);
	
	# Getting Sync Ex Reply ID from Table
	my $SyncID = $sync_ex_question_reply{$PacketID};
	
	# Cleaning Leading Zeros
	$PacketID =~ s/^0+//;	
	
	# Cleaning Leading Zeros	
	$SyncID =~ s/^0+//;
	
	# Debug Log
	# print sprintf("Received Ex Packet ID : 0x%s => 0x%s\n", $PacketID, $SyncID);

	# Converting ID to Hex Number
	$SyncID = hex($SyncID);

	# Dispatching Sync Ex Reply
	$messageSender->sendReplySyncRequestEx($SyncID);
}

*parse_quest_update_mission_hunt = *Network::Receive::ServerType0::parse_quest_update_mission_hunt_v2;
*reconstruct_quest_update_mission_hunt = *Network::Receive::ServerType0::reconstruct_quest_update_mission_hunt_v2;

1;