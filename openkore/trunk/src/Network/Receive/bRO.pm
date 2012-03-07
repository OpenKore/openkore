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
		
		'0878' => ['sync_request_ex_1'],
		'0921' => ['sync_request_ex_1'],
		'0890' => ['sync_request_ex_1'],
		'0932' => ['sync_request_ex_1'],
		'0952' => ['sync_request_ex_1'],
		'0436' => ['sync_request_ex_1'],
		'0938' => ['sync_request_ex_1'],
		'0889' => ['sync_request_ex_1'],
		'0363' => ['sync_request_ex_1'],
		'087C' => ['sync_request_ex_1'],
		'0817' => ['sync_request_ex_1'],
		'086D' => ['sync_request_ex_1'],
		'085E' => ['sync_request_ex_1'],
		'092F' => ['sync_request_ex_1'],
		'0948' => ['sync_request_ex_1'],
		'0950' => ['sync_request_ex_1'],
		'0887' => ['sync_request_ex_1'],
		'0885' => ['sync_request_ex_1'],
		'0884' => ['sync_request_ex_1'],
		'094D' => ['sync_request_ex_1'],
		'0967' => ['sync_request_ex_1'],
		'0368' => ['sync_request_ex_1'],
		'0361' => ['sync_request_ex_1'],
		'0877' => ['sync_request_ex_1'],
		'0963' => ['sync_request_ex_1'],
		'0969' => ['sync_request_ex_1'],
		'088D' => ['sync_request_ex_1'],
		'091C' => ['sync_request_ex_1'],
		'089B' => ['sync_request_ex_1'],
		'085D' => ['sync_request_ex_1'],
		'0281' => ['sync_request_ex_1'],
		'092B' => ['sync_request_ex_1'],
		'0896' => ['sync_request_ex_1'],
		'0360' => ['sync_request_ex_1'],
		'0936' => ['sync_request_ex_1'],
		'08A7' => ['sync_request_ex_1'],
		'093D' => ['sync_request_ex_1'],
		'0946' => ['sync_request_ex_1'],
		'088B' => ['sync_request_ex_1'],
		'035F' => ['sync_request_ex_1'],
		'0369' => ['sync_request_ex_1'],
		'0941' => ['sync_request_ex_1'],
		'085C' => ['sync_request_ex_2'],
		'0922' => ['sync_request_ex_2'],
		'08AC' => ['sync_request_ex_2'],
		'091D' => ['sync_request_ex_2'],
		'0931' => ['sync_request_ex_2'],
		'08A2' => ['sync_request_ex_2'],
		'088A' => ['sync_request_ex_2'],
		'0953' => ['sync_request_ex_2'],
		'0811' => ['sync_request_ex_2'],
		'08A8' => ['sync_request_ex_2'],
		'0879' => ['sync_request_ex_2'],
		'0962' => ['sync_request_ex_2'],
		'093F' => ['sync_request_ex_2'],
		'0366' => ['sync_request_ex_2'],
		'0883' => ['sync_request_ex_2'],
		'0968' => ['sync_request_ex_2'],
		'0956' => ['sync_request_ex_2'],
		'0437' => ['sync_request_ex_2'],
		'093B' => ['sync_request_ex_2'],
		'093C' => ['sync_request_ex_2'],
		'095B' => ['sync_request_ex_2'],
		'0886' => ['sync_request_ex_2'],
		'0895' => ['sync_request_ex_2'],
		'0862' => ['sync_request_ex_2'],
		'094B' => ['sync_request_ex_2'],
		'0951' => ['sync_request_ex_2'],
		'085A' => ['sync_request_ex_2'],
		'088E' => ['sync_request_ex_2'],
		'0942' => ['sync_request_ex_2'],
		'0917' => ['sync_request_ex_2'],
		'085F' => ['sync_request_ex_2'],
		'087A' => ['sync_request_ex_2'],
		'092E' => ['sync_request_ex_2'],
		'023B' => ['sync_request_ex_2'],
		'0892' => ['sync_request_ex_2'],
		'0960' => ['sync_request_ex_2'],
		'08A1' => ['sync_request_ex_2'],
		'089E' => ['sync_request_ex_2'],
		'0202' => ['sync_request_ex_2'],
		'089C' => ['sync_request_ex_2'],
		'0865' => ['sync_request_ex_2'],
		'089F' => ['sync_request_ex_2'],
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
		'0878' => '022D',		
		'0921' => '086F',		
		'0890' => '0966',		
		'0932' => '091F',		
		'0952' => '08AB',		
		'0436' => '0819',		
		'0938' => '0871',		
		'0889' => '0899',		
		'0363' => '0861',		
		'087C' => '0955',		
		'0817' => '0926',		
		'086D' => '0893',		
		'085E' => '0891',		
		'092F' => '0815',		
		'0948' => '08A0',		
		'0950' => '08AA',		
		'0887' => '089D',		
		'0885' => '087D',		
		'0884' => '0364',		
		'094D' => '0838',		
		'0967' => '0875',		
		'0368' => '07EC',		
		'0361' => '091E',		
		'0877' => '0866',		
		'0963' => '095C',		
		'0969' => '0944',		
		'088D' => '0365',		
		'091C' => '0961',		
		'089B' => '08A9',		
		'085D' => '095A',		
		'0281' => '0867',		
		'092B' => '0943',		
		'0896' => '0945',		
		'0360' => '092A',		
		'0936' => '0949',		
		'08A7' => '08AD',		
		'093D' => '086A',		
		'0946' => '086E',		
		'088B' => '0924',		
		'035F' => '091A',		
		'0369' => '095F',		
		'0941' => '0869',
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
		'085C' => '08A4',		
		'0922' => '092C',		
		'08AC' => '0925',		
		'091D' => '0957',		
		'0931' => '0881',		
		'08A2' => '0894',		
		'088A' => '0918',		
		'0953' => '0937',		
		'0811' => '0362',		
		'08A8' => '0958',		
		'0879' => '094C',		
		'0962' => '0940',		
		'093F' => '089A',		
		'0366' => '083C',		
		'0883' => '08A6',		
		'0968' => '0874',		
		'0956' => '0863',		
		'0437' => '096A',		
		'093B' => '0873',		
		'093C' => '0888',		
		'095B' => '094E',		
		'0886' => '0935',		
		'0895' => '094F',		
		'0862' => '0965',		
		'094B' => '0964',		
		'0951' => '095D',		
		'085A' => '0802',		
		'088E' => '092D',		
		'0942' => '0920',		
		'0917' => '0864',		
		'085F' => '0954',		
		'087A' => '0930',		
		'092E' => '0929',		
		'023B' => '0835',		
		'0892' => '087E',		
		'0960' => '0868',		
		'08A1' => '0919',		
		'089E' => '0939',		
		'0202' => '091B',		
		'089C' => '0897',		
		'0865' => '0928',		
		'089F' => '0898',		
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