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
		
		'092F' => ['sync_request_ex_1'],
		'092D' => ['sync_request_ex_1'],
		'085D' => ['sync_request_ex_1'],
		'0927' => ['sync_request_ex_1'],
		'0365' => ['sync_request_ex_1'],
		'089D' => ['sync_request_ex_1'],
		'0368' => ['sync_request_ex_1'],
		'0438' => ['sync_request_ex_1'],
		'0921' => ['sync_request_ex_1'],
		'094E' => ['sync_request_ex_1'],
		'0886' => ['sync_request_ex_1'],
		'08A1' => ['sync_request_ex_1'],
		'0811' => ['sync_request_ex_1'],
		'0930' => ['sync_request_ex_1'],
		'088E' => ['sync_request_ex_1'],
		'087B' => ['sync_request_ex_1'],
		'0957' => ['sync_request_ex_1'],
		'092B' => ['sync_request_ex_1'],
		'0968' => ['sync_request_ex_1'],
		'08A4' => ['sync_request_ex_1'],
		'095D' => ['sync_request_ex_1'],
		'0952' => ['sync_request_ex_1'],
		'087D' => ['sync_request_ex_1'],
		'0893' => ['sync_request_ex_1'],
		'0362' => ['sync_request_ex_1'],
		'0929' => ['sync_request_ex_1'],
		'0966' => ['sync_request_ex_1'],
		'07EC' => ['sync_request_ex_1'],
		'087A' => ['sync_request_ex_1'],
		'0895' => ['sync_request_ex_1'],
		'0202' => ['sync_request_ex_1'],
		'0931' => ['sync_request_ex_1'],
		'08AC' => ['sync_request_ex_1'],
		'086E' => ['sync_request_ex_1'],
		'0949' => ['sync_request_ex_1'],
		'0875' => ['sync_request_ex_1'],
		'0878' => ['sync_request_ex_1'],
		'0917' => ['sync_request_ex_1'],
		'086C' => ['sync_request_ex_1'],
		'093C' => ['sync_request_ex_1'],
		'0880' => ['sync_request_ex_1'],
		'091C' => ['sync_request_ex_1'],
		'0924' => ['sync_request_ex_2'],
		'0884' => ['sync_request_ex_2'],
		'089F' => ['sync_request_ex_2'],
		'089C' => ['sync_request_ex_2'],
		'0969' => ['sync_request_ex_2'],
		'08A9' => ['sync_request_ex_2'],
		'091D' => ['sync_request_ex_2'],
		'0817' => ['sync_request_ex_2'],
		'0967' => ['sync_request_ex_2'],
		'0945' => ['sync_request_ex_2'],
		'0965' => ['sync_request_ex_2'],
		'08A6' => ['sync_request_ex_2'],
		'0933' => ['sync_request_ex_2'],
		'094C' => ['sync_request_ex_2'],
		'0962' => ['sync_request_ex_2'],
		'0865' => ['sync_request_ex_2'],
		'0958' => ['sync_request_ex_2'],
		'093D' => ['sync_request_ex_2'],
		'087C' => ['sync_request_ex_2'],
		'0959' => ['sync_request_ex_2'],
		'091E' => ['sync_request_ex_2'],
		'0876' => ['sync_request_ex_2'],
		'087F' => ['sync_request_ex_2'],
		'0882' => ['sync_request_ex_2'],
		'0437' => ['sync_request_ex_2'],
		'0926' => ['sync_request_ex_2'],
		'0436' => ['sync_request_ex_2'],
		'088B' => ['sync_request_ex_2'],
		'0369' => ['sync_request_ex_2'],
		'0281' => ['sync_request_ex_2'],
		'092E' => ['sync_request_ex_2'],
		'0360' => ['sync_request_ex_2'],
		'092A' => ['sync_request_ex_2'],
		'035F' => ['sync_request_ex_2'],
		'0939' => ['sync_request_ex_2'],
		'0947' => ['sync_request_ex_2'],
		'0860' => ['sync_request_ex_2'],
		'0871' => ['sync_request_ex_2'],
		'0899' => ['sync_request_ex_2'],
		'0937' => ['sync_request_ex_2'],
		'093F' => ['sync_request_ex_2'],
		'093E' => ['sync_request_ex_2'],
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

sub sync_request_ex_1 {
	my ($self, $args) = @_;
	
	# Debug Log
	# message "Received Sync Ex : 0x" . $args->{switch} . "\n";
	
	# Computing Sync Ex - By Fr3DBr
	my $PacketID = $args->{switch};
	
	# Sync Ex Reply Array
	my %sync_ex_question_reply = (
		'092F' => '0896',		
		'092D' => '089E',		
		'085D' => '095A',		
		'0927' => '0863',		
		'0365' => '091F',		
		'089D' => '089B',		
		'0368' => '08A2',		
		'0438' => '0873',		
		'0921' => '08A8',		
		'094E' => '0364',		
		'0886' => '0361',		
		'08A1' => '0918',		
		'0811' => '07E4',		
		'0930' => '0881',		
		'088E' => '0891',		
		'087B' => '089A',		
		'0957' => '0954',		
		'092B' => '0883',		
		'0968' => '094F',		
		'08A4' => '0920',		
		'095D' => '0815',		
		'0952' => '085A',		
		'087D' => '0363',		
		'0893' => '095F',		
		'0362' => '083C',		
		'0929' => '0890',		
		'0966' => '0870',		
		'07EC' => '0938',		
		'087A' => '0963',		
		'0895' => '0894',		
		'0202' => '08A0',		
		'0931' => '0869',		
		'08AC' => '086D',		
		'086E' => '091A',		
		'0949' => '085B',		
		'0875' => '022D',		
		'0878' => '0948',		
		'0917' => '0862',		
		'086C' => '095E',		
		'093C' => '0867',		
		'0880' => '094D',		
		'091C' => '0897',		
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

sub sync_request_ex_2 {
	my ($self, $args) = @_;
	
	# Debug Log
	# message "Received Sync Ex : 0x" . $args->{switch} . "\n";
	
	# Computing Sync Ex - By Fr3DBr
	my $PacketID = $args->{switch};
	
	# Sync Ex Reply Array
	my %sync_ex_question_reply = (
		'0924' => '0864',		
		'0884' => '0919',		
		'089F' => '086F',		
		'089C' => '0935',		
		'0969' => '0928',		
		'08A9' => '088C',		
		'091D' => '085F',		
		'0817' => '0868',		
		'0967' => '0922',		
		'0945' => '0940',		
		'0965' => '0943',		
		'08A6' => '08AB',		
		'0933' => '095C',		
		'094C' => '0950',		
		'0962' => '086B',		
		'0865' => '023B',		
		'0958' => '094A',		
		'093D' => '0951',		
		'087C' => '0835',		
		'0959' => '0879',		
		'091E' => '0889',		
		'0876' => '093A',		
		'087F' => '0366',		
		'0882' => '0866',		
		'0437' => '087E',		
		'0926' => '08AA',		
		'0436' => '0944',		
		'088B' => '094B',		
		'0369' => '095B',		
		'0281' => '0925',		
		'092E' => '096A',		
		'0360' => '088A',		
		'092A' => '0872',		
		'035F' => '0932',		
		'0939' => '0819',		
		'0947' => '0953',		
		'0860' => '0898',		
		'0871' => '0956',		
		'0899' => '0955',		
		'0937' => '0885',		
		'093F' => '088D',		
		'093E' => '08A3',		
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