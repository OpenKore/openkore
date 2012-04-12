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
		
		'0894' => ['sync_request_ex_1'],
		'0888' => ['sync_request_ex_1'],
		'087B' => ['sync_request_ex_1'],
		'0872' => ['sync_request_ex_1'],
		'089D' => ['sync_request_ex_1'],
		'0367' => ['sync_request_ex_1'],
		'092F' => ['sync_request_ex_1'],
		'087A' => ['sync_request_ex_1'],
		'0940' => ['sync_request_ex_1'],
		'0922' => ['sync_request_ex_1'],
		'08A7' => ['sync_request_ex_1'],
		'08A3' => ['sync_request_ex_1'],
		'0943' => ['sync_request_ex_1'],
		'089A' => ['sync_request_ex_1'],
		'0880' => ['sync_request_ex_1'],
		'0879' => ['sync_request_ex_1'],
		'094A' => ['sync_request_ex_1'],
		'0918' => ['sync_request_ex_1'],
		'0862' => ['sync_request_ex_1'],
		'0819' => ['sync_request_ex_1'],
		'08A5' => ['sync_request_ex_1'],
		'085C' => ['sync_request_ex_1'],
		'0892' => ['sync_request_ex_1'],
		'0877' => ['sync_request_ex_1'],
		'091A' => ['sync_request_ex_1'],
		'0960' => ['sync_request_ex_1'],
		'0369' => ['sync_request_ex_1'],
		'095E' => ['sync_request_ex_1'],
		'08A6' => ['sync_request_ex_1'],
		'089C' => ['sync_request_ex_1'],
		'087F' => ['sync_request_ex_1'],
		'0959' => ['sync_request_ex_1'],
		'0933' => ['sync_request_ex_1'],
		'0946' => ['sync_request_ex_1'],
		'0867' => ['sync_request_ex_1'],
		'0438' => ['sync_request_ex_1'],
		'0938' => ['sync_request_ex_1'],
		'0868' => ['sync_request_ex_1'],
		'092A' => ['sync_request_ex_1'],
		'0365' => ['sync_request_ex_1'],
		'0898' => ['sync_request_ex_1'],
		'093C' => ['sync_request_ex_1'],
		'0939' => ['sync_request_ex_2'],
		'0962' => ['sync_request_ex_2'],
		'0948' => ['sync_request_ex_2'],
		'0361' => ['sync_request_ex_2'],
		'088B' => ['sync_request_ex_2'],
		'095A' => ['sync_request_ex_2'],
		'0967' => ['sync_request_ex_2'],
		'0921' => ['sync_request_ex_2'],
		'089E' => ['sync_request_ex_2'],
		'0927' => ['sync_request_ex_2'],
		'0360' => ['sync_request_ex_2'],
		'0865' => ['sync_request_ex_2'],
		'0957' => ['sync_request_ex_2'],
		'095B' => ['sync_request_ex_2'],
		'0873' => ['sync_request_ex_2'],
		'0817' => ['sync_request_ex_2'],
		'0281' => ['sync_request_ex_2'],
		'0869' => ['sync_request_ex_2'],
		'0969' => ['sync_request_ex_2'],
		'0881' => ['sync_request_ex_2'],
		'0929' => ['sync_request_ex_2'],
		'086C' => ['sync_request_ex_2'],
		'094E' => ['sync_request_ex_2'],
		'095C' => ['sync_request_ex_2'],
		'096A' => ['sync_request_ex_2'],
		'08A4' => ['sync_request_ex_2'],
		'087D' => ['sync_request_ex_2'],
		'086B' => ['sync_request_ex_2'],
		'0878' => ['sync_request_ex_2'],
		'094F' => ['sync_request_ex_2'],
		'0947' => ['sync_request_ex_2'],
		'092C' => ['sync_request_ex_2'],
		'091C' => ['sync_request_ex_2'],
		'093E' => ['sync_request_ex_2'],
		'0368' => ['sync_request_ex_2'],
		'0951' => ['sync_request_ex_2'],
		'085E' => ['sync_request_ex_2'],
		'093B' => ['sync_request_ex_2'],
		'0436' => ['sync_request_ex_2'],
		'091D' => ['sync_request_ex_2'],
		'088E' => ['sync_request_ex_2'],
		'086D' => ['sync_request_ex_2'],
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
		'0894' => '091B',		
		'0888' => '089B',		
		'087B' => '088C',		
		'0872' => '0917',		
		'089D' => '093F',		
		'0367' => '0835',		
		'092F' => '0811',		
		'087A' => '0893',		
		'0940' => '0919',		
		'0922' => '08AD',		
		'08A7' => '0954',		
		'08A3' => '07E4',		
		'0943' => '0890',		
		'089A' => '0956',		
		'0880' => '087E',		
		'0879' => '0889',		
		'094A' => '095F',		
		'0918' => '0884',		
		'0862' => '0871',		
		'0819' => '0936',		
		'08A5' => '094B',		
		'085C' => '0866',		
		'0892' => '091F',		
		'0877' => '08A0',		
		'091A' => '0363',		
		'0960' => '085D',		
		'0369' => '08A9',		
		'095E' => '0364',		
		'08A6' => '0860',		
		'089C' => '08AB',		
		'087F' => '0362',		
		'0959' => '0886',		
		'0933' => '08A2',		
		'0946' => '0958',		
		'0867' => '0968',		
		'0438' => '083C',		
		'0938' => '086E',		
		'0868' => '0931',		
		'092A' => '093D',		
		'0365' => '0876',		
		'0898' => '0897',		
		'093C' => '0935',		
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
		'0939' => '0202',		
		'0962' => '08AC',		
		'0948' => '0802',		
		'0361' => '0945',		
		'088B' => '0883',		
		'095A' => '095D',		
		'0967' => '085B',		
		'0921' => '0963',		
		'089E' => '08AA',		
		'0927' => '0838',		
		'0360' => '0874',		
		'0865' => '035F',		
		'0957' => '089F',		
		'095B' => '0949',		
		'0873' => '07EC',		
		'0817' => '092E',		
		'0281' => '0920',		
		'0869' => '0932',		
		'0969' => '08A8',		
		'0881' => '0437',		
		'0929' => '0964',		
		'086C' => '0952',		
		'094E' => '085A',		
		'095C' => '0928',		
		'096A' => '086A',		
		'08A4' => '092D',		
		'087D' => '0815',		
		'086B' => '0926',		
		'0878' => '0861',		
		'094F' => '093A',		
		'0947' => '0882',		
		'092C' => '0955',		
		'091C' => '0896',		
		'093E' => '0895',		
		'0368' => '0953',		
		'0951' => '0887',		
		'085E' => '0885',		
		'093B' => '0863',		
		'0436' => '0864',		
		'091D' => '0870',		
		'088E' => '091E',		
		'086D' => '0937',		
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