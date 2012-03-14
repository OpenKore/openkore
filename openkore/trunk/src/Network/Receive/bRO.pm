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
		
	'095A' => ['sync_request_ex_1'],
	'0919' => ['sync_request_ex_1'],
	'0918' => ['sync_request_ex_1'],
	'088B' => ['sync_request_ex_1'],
	'08A8' => ['sync_request_ex_1'],
	'087A' => ['sync_request_ex_1'],
	'0866' => ['sync_request_ex_1'],
	'0968' => ['sync_request_ex_1'],
	'0889' => ['sync_request_ex_1'],
	'091F' => ['sync_request_ex_1'],
	'0921' => ['sync_request_ex_1'],
	'0934' => ['sync_request_ex_1'],
	'08A7' => ['sync_request_ex_1'],
	'0936' => ['sync_request_ex_1'],
	'093E' => ['sync_request_ex_1'],
	'0888' => ['sync_request_ex_1'],
	'023B' => ['sync_request_ex_1'],
	'092C' => ['sync_request_ex_1'],
	'086F' => ['sync_request_ex_1'],
	'087E' => ['sync_request_ex_1'],
	'0884' => ['sync_request_ex_1'],
	'083C' => ['sync_request_ex_1'],
	'0960' => ['sync_request_ex_1'],
	'092A' => ['sync_request_ex_1'],
	'0865' => ['sync_request_ex_1'],
	'0360' => ['sync_request_ex_1'],
	'086C' => ['sync_request_ex_1'],
	'08A9' => ['sync_request_ex_1'],
	'086D' => ['sync_request_ex_1'],
	'088A' => ['sync_request_ex_1'],
	'0835' => ['sync_request_ex_1'],
	'0365' => ['sync_request_ex_1'],
	'08A6' => ['sync_request_ex_1'],
	'0939' => ['sync_request_ex_1'],
	'0880' => ['sync_request_ex_1'],
	'0954' => ['sync_request_ex_1'],
	'0811' => ['sync_request_ex_1'],
	'08A1' => ['sync_request_ex_1'],
	'0870' => ['sync_request_ex_1'],
	'0943' => ['sync_request_ex_1'],
	'0964' => ['sync_request_ex_1'],
	'0882' => ['sync_request_ex_1'],
	'0967' => ['sync_request_ex_2'],
	'093F' => ['sync_request_ex_2'],
	'0947' => ['sync_request_ex_2'],
	'0951' => ['sync_request_ex_2'],
	'089F' => ['sync_request_ex_2'],
	'0944' => ['sync_request_ex_2'],
	'0861' => ['sync_request_ex_2'],
	'0891' => ['sync_request_ex_2'],
	'0892' => ['sync_request_ex_2'],
	'095D' => ['sync_request_ex_2'],
	'0952' => ['sync_request_ex_2'],
	'094B' => ['sync_request_ex_2'],
	'0931' => ['sync_request_ex_2'],
	'089D' => ['sync_request_ex_2'],
	'085D' => ['sync_request_ex_2'],
	'0876' => ['sync_request_ex_2'],
	'092B' => ['sync_request_ex_2'],
	'087B' => ['sync_request_ex_2'],
	'0932' => ['sync_request_ex_2'],
	'0368' => ['sync_request_ex_2'],
	'0363' => ['sync_request_ex_2'],
	'08AB' => ['sync_request_ex_2'],
	'0961' => ['sync_request_ex_2'],
	'087C' => ['sync_request_ex_2'],
	'093C' => ['sync_request_ex_2'],
	'08AA' => ['sync_request_ex_2'],
	'0887' => ['sync_request_ex_2'],
	'091A' => ['sync_request_ex_2'],
	'0937' => ['sync_request_ex_2'],
	'0926' => ['sync_request_ex_2'],
	'089B' => ['sync_request_ex_2'],
	'0945' => ['sync_request_ex_2'],
	'0959' => ['sync_request_ex_2'],
	'0838' => ['sync_request_ex_2'],
	'07E4' => ['sync_request_ex_2'],
	'035F' => ['sync_request_ex_2'],
	'0920' => ['sync_request_ex_2'],
	'094D' => ['sync_request_ex_2'],
	'07EC' => ['sync_request_ex_2'],
	'0953' => ['sync_request_ex_2'],
	'0364' => ['sync_request_ex_2'],
	'0924' => ['sync_request_ex_2'],

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
		'095A' => '0875',		
		'0919' => '086B',		
		'0918' => '08A3',		
		'088B' => '0929',		
		'08A8' => '0949',		
		'087A' => '085F',		
		'0866' => '0860',		
		'0968' => '0922',		
		'0889' => '0941',		
		'091F' => '08A0',		
		'0921' => '089E',		
		'0934' => '085A',		
		'08A7' => '0874',		
		'0936' => '0917',		
		'093E' => '0815',		
		'0888' => '0899',		
		'023B' => '0897',		
		'092C' => '0281',		
		'086F' => '0940',		
		'087E' => '085E',		
		'0884' => '08AD',		
		'083C' => '0928',		
		'0960' => '0963',		
		'092A' => '0867',		
		'0865' => '08AC',		
		'0360' => '0933',		
		'086C' => '0436',		
		'08A9' => '0965',		
		'086D' => '089A',		
		'088A' => '0868',		
		'0835' => '022D',		
		'0365' => '08A2',		
		'08A6' => '095E',		
		'0939' => '092D',		
		'0880' => '0930',		
		'0954' => '0871',		
		'0811' => '0883',		
		'08A1' => '0956',		
		'0870' => '096A',		
		'0943' => '094F',		
		'0964' => '094C',		
		'0882' => '0819',		
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
		'0967' => '0938',		
		'093F' => '0927',		
		'0947' => '0872',		
		'0951' => '091C',		
		'089F' => '0369',		
		'0944' => '088C',		
		'0861' => '0202',		
		'0891' => '091E',		
		'0892' => '089C',		
		'095D' => '092F',		
		'0952' => '085C',		
		'094B' => '0877',		
		'0931' => '088D',		
		'089D' => '0896',		
		'085D' => '0873',		
		'0876' => '0367',		
		'092B' => '0969',		
		'087B' => '0863',		
		'0932' => '0948',		
		'0368' => '0950',		
		'0363' => '0864',		
		'08AB' => '088E',		
		'0961' => '0886',		
		'087C' => '0885',		
		'093C' => '0955',		
		'08AA' => '094A',		
		'0887' => '088F',		
		'091A' => '093D',		
		'0937' => '095F',		
		'0926' => '091D',		
		'089B' => '0362',		
		'0945' => '0898',		
		'0959' => '0869',		
		'0838' => '092E',		
		'07E4' => '0946',		
		'035F' => '087D',		
		'0920' => '094E',		
		'094D' => '0893',		
		'07EC' => '0925',		
		'0953' => '095C',		
		'0364' => '02C4',		
		'0924' => '0935',		
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