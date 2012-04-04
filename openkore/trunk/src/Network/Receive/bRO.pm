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
		
		'023B' => ['sync_request_ex_1'],
		'085A' => ['sync_request_ex_1'],
		'085B' => ['sync_request_ex_1'],
		'085C' => ['sync_request_ex_1'],
		'085D' => ['sync_request_ex_1'],
		'085E' => ['sync_request_ex_1'],
		'085F' => ['sync_request_ex_1'],
		'0363' => ['sync_request_ex_1'],
		'0861' => ['sync_request_ex_1'],
		'0862' => ['sync_request_ex_1'],
		'0863' => ['sync_request_ex_1'],
		'0864' => ['sync_request_ex_1'],
		'0865' => ['sync_request_ex_1'],
		'0866' => ['sync_request_ex_1'],
		'0867' => ['sync_request_ex_1'],
		'0868' => ['sync_request_ex_1'],
		'0869' => ['sync_request_ex_1'],
		'086A' => ['sync_request_ex_1'],
		'086B' => ['sync_request_ex_1'],
		'086C' => ['sync_request_ex_1'],
		'086D' => ['sync_request_ex_1'],
		'086E' => ['sync_request_ex_1'],
		'0362' => ['sync_request_ex_1'],
		'0870' => ['sync_request_ex_1'],
		'0871' => ['sync_request_ex_1'],
		'0872' => ['sync_request_ex_1'],
		'0873' => ['sync_request_ex_1'],
		'0874' => ['sync_request_ex_1'],
		'0875' => ['sync_request_ex_1'],
		'0876' => ['sync_request_ex_1'],
		'0877' => ['sync_request_ex_1'],
		'0878' => ['sync_request_ex_1'],
		'0879' => ['sync_request_ex_1'],
		'087A' => ['sync_request_ex_1'],
		'087B' => ['sync_request_ex_1'],
		'087C' => ['sync_request_ex_1'],
		'087D' => ['sync_request_ex_1'],
		'087E' => ['sync_request_ex_1'],
		'087F' => ['sync_request_ex_1'],
		'0880' => ['sync_request_ex_1'],
		'0881' => ['sync_request_ex_1'],
		'0882' => ['sync_request_ex_1'],
		'0888' => ['sync_request_ex_2'],
		'0917' => ['sync_request_ex_2'],
		'0918' => ['sync_request_ex_2'],
		'0919' => ['sync_request_ex_2'],
		'091A' => ['sync_request_ex_2'],
		'091B' => ['sync_request_ex_2'],
		'0885' => ['sync_request_ex_2'],
		'091D' => ['sync_request_ex_2'],
		'091E' => ['sync_request_ex_2'],
		'091F' => ['sync_request_ex_2'],
		'0920' => ['sync_request_ex_2'],
		'0921' => ['sync_request_ex_2'],
		'0922' => ['sync_request_ex_2'],
		'0923' => ['sync_request_ex_2'],
		'0924' => ['sync_request_ex_2'],
		'0925' => ['sync_request_ex_2'],
		'0926' => ['sync_request_ex_2'],
		'0927' => ['sync_request_ex_2'],
		'0928' => ['sync_request_ex_2'],
		'0929' => ['sync_request_ex_2'],
		'092A' => ['sync_request_ex_2'],
		'092B' => ['sync_request_ex_2'],
		'092C' => ['sync_request_ex_2'],
		'092D' => ['sync_request_ex_2'],
		'0365' => ['sync_request_ex_2'],
		'092F' => ['sync_request_ex_2'],
		'0930' => ['sync_request_ex_2'],
		'0931' => ['sync_request_ex_2'],
		'0932' => ['sync_request_ex_2'],
		'0933' => ['sync_request_ex_2'],
		'0934' => ['sync_request_ex_2'],
		'0935' => ['sync_request_ex_2'],
		'0936' => ['sync_request_ex_2'],
		'0937' => ['sync_request_ex_2'],
		'0938' => ['sync_request_ex_2'],
		'0939' => ['sync_request_ex_2'],
		'093A' => ['sync_request_ex_2'],
		'093B' => ['sync_request_ex_2'],
		'093C' => ['sync_request_ex_2'],
		'093D' => ['sync_request_ex_2'],
		'093E' => ['sync_request_ex_2'],
		'093F' => ['sync_request_ex_2'],
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
		'023B' => '0896',		
		'085A' => '091C',		
		'085B' => '0955',		
		'085C' => '0895',		
		'085D' => '0883',		
		'085E' => '089D',		
		'085F' => '0951',		
		'0363' => '088A',		
		'0861' => '088B',		
		'0862' => '088C',		
		'0863' => '088D',		
		'0864' => '088E',		
		'0865' => '088F',		
		'0866' => '0890',		
		'0867' => '0802',		
		'0868' => '0202',		
		'0869' => '0893',		
		'086A' => '0894',		
		'086B' => '0887',		
		'086C' => '0884',		
		'086D' => '0436',		
		'086E' => '0898',		
		'0362' => '0899',		
		'0870' => '0361',		
		'0871' => '089B',		
		'0872' => '089C',		
		'0873' => '0889',		
		'0874' => '089E',		
		'0875' => '089F',		
		'0876' => '08A0',		
		'0877' => '08A1',		
		'0878' => '08A2',		
		'0879' => '08A3',		
		'087A' => '08A4',		
		'087B' => '08A5',		
		'087C' => '08A6',		
		'087D' => '02C4',		
		'087E' => '07E4',		
		'087F' => '08A9',		
		'0880' => '0364',		
		'0881' => '08AB',		
		'0882' => '08AC',		
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
		'0888' => '08AD',		
		'0917' => '0941',		
		'0918' => '0942',		
		'0919' => '0943',		
		'091A' => '0944',		
		'091B' => '0945',		
		'0885' => '0946',		
		'091D' => '0947',		
		'091E' => '0948',		
		'091F' => '0949',		
		'0920' => '094A',		
		'0921' => '094B',		
		'0922' => '094C',		
		'0923' => '094D',		
		'0924' => '094E',		
		'0925' => '094F',		
		'0926' => '0940',		
		'0927' => '0950',		
		'0928' => '0952',		
		'0929' => '0953',		
		'092A' => '07EC',		
		'092B' => '0886',		
		'092C' => '0956',		
		'092D' => '0957',		
		'0365' => '0958',		
		'092F' => '0959',		
		'0930' => '095A',		
		'0931' => '095B',		
		'0932' => '095C',		
		'0933' => '095D',		
		'0934' => '095E',		
		'0935' => '095F',		
		'0936' => '0960',		
		'0937' => '0961',		
		'0938' => '0962',		
		'0939' => '0963',		
		'093A' => '0281',		
		'093B' => '0965',		
		'093C' => '0966',		
		'093D' => '0967',		
		'093E' => '0968',		
		'093F' => '0969',		
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