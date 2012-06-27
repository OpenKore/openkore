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
		
		'0932' => ['sync_request_ex'],
		'094B' => ['sync_request_ex'],
		'091D' => ['sync_request_ex'],
		'086A' => ['sync_request_ex'],
		'0366' => ['sync_request_ex'],
		'0438' => ['sync_request_ex'],
		'0954' => ['sync_request_ex'],
		'0920' => ['sync_request_ex'],
		'093E' => ['sync_request_ex'],
		'0957' => ['sync_request_ex'],
		'0917' => ['sync_request_ex'],
		'092A' => ['sync_request_ex'],
		'0919' => ['sync_request_ex'],
		'0898' => ['sync_request_ex'],
		'035F' => ['sync_request_ex'],
		'094A' => ['sync_request_ex'],
		'0965' => ['sync_request_ex'],
		'0878' => ['sync_request_ex'],
		'088B' => ['sync_request_ex'],
		'089E' => ['sync_request_ex'],
		'089C' => ['sync_request_ex'],
		'0869' => ['sync_request_ex'],
		'0860' => ['sync_request_ex'],
		'08A7' => ['sync_request_ex'],
		'0838' => ['sync_request_ex'],
		'088D' => ['sync_request_ex'],
		'0881' => ['sync_request_ex'],
		'0896' => ['sync_request_ex'],
		'088C' => ['sync_request_ex'],
		'094E' => ['sync_request_ex'],
		'08A3' => ['sync_request_ex'],
		'0923' => ['sync_request_ex'],
		'092B' => ['sync_request_ex'],
		'0934' => ['sync_request_ex'],
		'0938' => ['sync_request_ex'],
		'0897' => ['sync_request_ex'],
		'087C' => ['sync_request_ex'],
		'0361' => ['sync_request_ex'],
		'0867' => ['sync_request_ex'],
		'0936' => ['sync_request_ex'],
		'092D' => ['sync_request_ex'],
		'093C' => ['sync_request_ex'],
		'0811' => ['sync_request_ex'],
		'0882' => ['sync_request_ex'],
		'094D' => ['sync_request_ex'],
		'092C' => ['sync_request_ex'],
		'088F' => ['sync_request_ex'],
		'0890' => ['sync_request_ex'],
		'0887' => ['sync_request_ex'],
		'092E' => ['sync_request_ex'],
		'0362' => ['sync_request_ex'],
		'087E' => ['sync_request_ex'],
		'091A' => ['sync_request_ex'],
		'0861' => ['sync_request_ex'],
		'089A' => ['sync_request_ex'],
		'0918' => ['sync_request_ex'],
		'095E' => ['sync_request_ex'],
		'085C' => ['sync_request_ex'],
		'0894' => ['sync_request_ex'],
		'07E4' => ['sync_request_ex'],
		'0202' => ['sync_request_ex'],
		'0947' => ['sync_request_ex'],
		'0930' => ['sync_request_ex'],
		'0872' => ['sync_request_ex'],
		'0889' => ['sync_request_ex'],
		'0946' => ['sync_request_ex'],
		'0940' => ['sync_request_ex'],
		'08A2' => ['sync_request_ex'],
		'0874' => ['sync_request_ex'],
		'0968' => ['sync_request_ex'],
		'0963' => ['sync_request_ex'],
		'0925' => ['sync_request_ex'],
		'08A5' => ['sync_request_ex'],
		'093F' => ['sync_request_ex'],
		'093A' => ['sync_request_ex'],
		'0951' => ['sync_request_ex'],
		'091E' => ['sync_request_ex'],
		'0364' => ['sync_request_ex'],
		'08A1' => ['sync_request_ex'],
		'095C' => ['sync_request_ex'],
		'0866' => ['sync_request_ex'],
		'0815' => ['sync_request_ex'],
		'0437' => ['sync_request_ex'],
		'095F' => ['sync_request_ex'],
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
		'0932' => '08A0',
		'094B' => '093B',
		'091D' => '0892',
		'086A' => '091C',
		'0366' => '088A',
		'0438' => '094C',
		'0954' => '0880',
		'0920' => '0802',
		'093E' => '095D',
		'0957' => '08A8',
		'0917' => '093D',
		'092A' => '089D',
		'0919' => '0933',
		'0898' => '0962',
		'035F' => '0966',
		'094A' => '0942',
		'0965' => '0964',
		'0878' => '086D',
		'088B' => '08AC',
		'089E' => '0959',
		'089C' => '0886',
		'0869' => '0960',
		'0860' => '0899',
		'08A7' => '0958',
		'0838' => '095A',
		'088D' => '0864',
		'0881' => '0893',
		'0896' => '085B',
		'088C' => '094F',
		'094E' => '0876',
		'08A3' => '08A9',
		'0923' => '0363',
		'092B' => '08A4',
		'0934' => '0281',
		'0938' => '086F',
		'0897' => '0875',
		'087C' => '023B',
		'0361' => '0949',
		'0867' => '0865',
		'0936' => '0888',
		'092D' => '0817',
		'093C' => '0891',
		'0811' => '0967',
		'0882' => '0950',
		'094D' => '02C4',
		'092C' => '0862',
		'088F' => '085A',
		'0890' => '0922',
		'0887' => '092F',
		'092E' => '096A',
		'0362' => '022D',
		'087E' => '087A',
		'091A' => '0924',
		'0861' => '0835',
		'089A' => '0928',
		'0918' => '0948',
		'095E' => '0943',
		'085C' => '089F',
		'0894' => '0863',
		'07E4' => '0921',
		'0202' => '088E',
		'0947' => '0941',
		'0930' => '0929',
		'0872' => '0871',
		'0889' => '089B',
		'0946' => '0368',
		'0940' => '086B',
		'08A2' => '0884',
		'0874' => '0873',
		'0968' => '086C',
		'0963' => '087D',
		'0925' => '087B',
		'08A5' => '0937',
		'093F' => '085D',
		'093A' => '0883',
		'0951' => '0945',
		'091E' => '0436',
		'0364' => '0926',
		'08A1' => '0927',
		'095C' => '0868',
		'0866' => '091F',
		'0815' => '0360',
		'0437' => '086E',
		'095F' => '087F',
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