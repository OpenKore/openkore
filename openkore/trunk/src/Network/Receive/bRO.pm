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
		
		'0956' => ['sync_request_ex_1'],
		'094C' => ['sync_request_ex_1'],
		'088F' => ['sync_request_ex_1'],
		'0887' => ['sync_request_ex_1'],
		'0835' => ['sync_request_ex_1'],
		'095D' => ['sync_request_ex_1'],
		'093B' => ['sync_request_ex_1'],
		'0923' => ['sync_request_ex_1'],
		'0863' => ['sync_request_ex_1'],
		'0929' => ['sync_request_ex_1'],
		'087D' => ['sync_request_ex_1'],
		'085F' => ['sync_request_ex_1'],
		'092C' => ['sync_request_ex_1'],
		'07E4' => ['sync_request_ex_1'],
		'0892' => ['sync_request_ex_1'],
		'088C' => ['sync_request_ex_1'],
		'0886' => ['sync_request_ex_1'],
		'0936' => ['sync_request_ex_1'],
		'08A0' => ['sync_request_ex_1'],
		'02C4' => ['sync_request_ex_1'],
		'095C' => ['sync_request_ex_1'],
		'0864' => ['sync_request_ex_1'],
		'085D' => ['sync_request_ex_1'],
		'086F' => ['sync_request_ex_1'],
		'094D' => ['sync_request_ex_1'],
		'0361' => ['sync_request_ex_1'],
		'0945' => ['sync_request_ex_1'],
		'0869' => ['sync_request_ex_1'],
		'085A' => ['sync_request_ex_1'],
		'0870' => ['sync_request_ex_1'],
		'08A8' => ['sync_request_ex_1'],
		'0866' => ['sync_request_ex_1'],
		'0815' => ['sync_request_ex_1'],
		'085B' => ['sync_request_ex_1'],
		'0883' => ['sync_request_ex_1'],
		'095E' => ['sync_request_ex_1'],
		'0938' => ['sync_request_ex_1'],
		'0937' => ['sync_request_ex_1'],
		'0838' => ['sync_request_ex_1'],
		'0368' => ['sync_request_ex_1'],
		'087B' => ['sync_request_ex_1'],
		'091F' => ['sync_request_ex_1'],
		'0910' => ['sync_request_ex_2'],
		'0911' => ['sync_request_ex_2'],
		'0912' => ['sync_request_ex_2'],
		'0913' => ['sync_request_ex_2'],
		'0914' => ['sync_request_ex_2'],
		'090F' => ['sync_request_ex_2'],
		'0915' => ['sync_request_ex_2'],
		'0916' => ['sync_request_ex_2'],
		'089D' => ['sync_request_ex_2'],
		'093A' => ['sync_request_ex_2'],
		'0950' => ['sync_request_ex_2'],
		'0932' => ['sync_request_ex_2'],
		'0860' => ['sync_request_ex_2'],
		'0920' => ['sync_request_ex_2'],
		'0940' => ['sync_request_ex_2'],
		'087F' => ['sync_request_ex_2'],
		'0942' => ['sync_request_ex_2'],
		'0948' => ['sync_request_ex_2'],
		'0876' => ['sync_request_ex_2'],
		'0867' => ['sync_request_ex_2'],
		'0967' => ['sync_request_ex_2'],
		'0897' => ['sync_request_ex_2'],
		'08AA' => ['sync_request_ex_2'],
		'092B' => ['sync_request_ex_2'],
		'086E' => ['sync_request_ex_2'],
		'0941' => ['sync_request_ex_2'],
		'0875' => ['sync_request_ex_2'],
		'0862' => ['sync_request_ex_2'],
		'094B' => ['sync_request_ex_2'],
		'0944' => ['sync_request_ex_2'],
		'0917' => ['sync_request_ex_2'],
		'089C' => ['sync_request_ex_2'],
		'022D' => ['sync_request_ex_2'],
		'0865' => ['sync_request_ex_2'],
		'092A' => ['sync_request_ex_2'],
		'0874' => ['sync_request_ex_2'],
		'0881' => ['sync_request_ex_2'],
		'0935' => ['sync_request_ex_2'],
		'093E' => ['sync_request_ex_2'],
		'08A5' => ['sync_request_ex_2'],
		'0436' => ['sync_request_ex_2'],
		'0952' => ['sync_request_ex_2'],
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
		'0956' => '0943',		
		'094C' => '0898',		
		'088F' => '093D',		
		'0887' => '0962',		
		'0835' => '0893',		
		'095D' => '087E',		
		'093B' => '0871',		
		'0923' => '0955',		
		'0863' => '0882',		
		'0929' => '0894',		
		'087D' => '095F',		
		'085F' => '086B',		
		'092C' => '0933',		
		'07E4' => '088A',		
		'0892' => '086C',		
		'088C' => '08AD',		
		'0886' => '0872',		
		'0936' => '0888',		
		'08A0' => '08A4',		
		'02C4' => '0817',		
		'095C' => '0880',		
		'0864' => '08A1',		
		'085D' => '0953',		
		'086F' => '0363',		
		'094D' => '0895',		
		'0361' => '023B',		
		'0945' => '0360',		
		'0869' => '08AB',		
		'085A' => '088B',		
		'0870' => '0925',		
		'08A8' => '0969',		
		'0866' => '0438',		
		'0815' => '094E',		
		'085B' => '0885',		
		'0883' => '088E',		
		'095E' => '091A',		
		'0938' => '0919',		
		'0937' => '0921',		
		'0838' => '0281',		
		'0368' => '0957',		
		'087B' => '0922',		
		'091F' => '0878',		
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
		'0910' => '0958',		
		'0911' => '0961',		
		'0912' => '0896',		
		'0913' => '0934',		
		'0914' => '0364',		
		'090F' => '0949',		
		'0915' => '08A9',		
		'0916' => '0861',		
		'089D' => '0930',		
		'093A' => '094A',		
		'0950' => '096A',		
		'0932' => '0877',		
		'0860' => '0365',		
		'0920' => '0946',		
		'0940' => '0868',		
		'087F' => '0968',		
		'0942' => '0884',		
		'0948' => '0951',		
		'0876' => '0947',		
		'0867' => '089A',		
		'0967' => '0362',		
		'0897' => '089B',		
		'08AA' => '092F',		
		'092B' => '0369',		
		'086E' => '095A',		
		'0941' => '0954',		
		'0875' => '07EC',		
		'0862' => '092E',		
		'094B' => '089E',		
		'0944' => '0879',		
		'0917' => '0963',		
		'089C' => '0890',		
		'022D' => '0811',		
		'0865' => '087C',		
		'092A' => '0965',		
		'0874' => '0927',		
		'0881' => '089F',		
		'0935' => '086D',		
		'093E' => '0960',		
		'08A5' => '0889',		
		'0436' => '08AC',		
		'0952' => '085E',		
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