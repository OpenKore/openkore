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
		
		'086A' => ['sync_request_ex'],
		'088C' => ['sync_request_ex'],
		'0882' => ['sync_request_ex'],
		'0365' => ['sync_request_ex'],
		'0887' => ['sync_request_ex'],
		'091C' => ['sync_request_ex'],
		'0930' => ['sync_request_ex'],
		'0932' => ['sync_request_ex'],
		'0362' => ['sync_request_ex'],
		'089E' => ['sync_request_ex'],
		'0917' => ['sync_request_ex'],
		'0957' => ['sync_request_ex'],
		'095E' => ['sync_request_ex'],
		'087B' => ['sync_request_ex'],
		'0369' => ['sync_request_ex'],
		'094C' => ['sync_request_ex'],
		'0811' => ['sync_request_ex'],
		'0880' => ['sync_request_ex'],
		'088B' => ['sync_request_ex'],
		'087E' => ['sync_request_ex'],
		'0838' => ['sync_request_ex'],
		'093D' => ['sync_request_ex'],
		'0437' => ['sync_request_ex'],
		'0937' => ['sync_request_ex'],
		'0869' => ['sync_request_ex'],
		'0938' => ['sync_request_ex'],
		'0955' => ['sync_request_ex'],
		'0890' => ['sync_request_ex'],
		'0860' => ['sync_request_ex'],
		'0368' => ['sync_request_ex'],
		'0961' => ['sync_request_ex'],
		'095B' => ['sync_request_ex'],
		'0875' => ['sync_request_ex'],
		'0954' => ['sync_request_ex'],
		'086C' => ['sync_request_ex'],
		'0888' => ['sync_request_ex'],
		'0892' => ['sync_request_ex'],
		'0956' => ['sync_request_ex'],
		'0921' => ['sync_request_ex'],
		'0881' => ['sync_request_ex'],
		'0958' => ['sync_request_ex'],
		'0835' => ['sync_request_ex'],
		'085C' => ['sync_request_ex'],
		'0923' => ['sync_request_ex'],
		'087D' => ['sync_request_ex'],
		'0928' => ['sync_request_ex'],
		'0897' => ['sync_request_ex'],
		'091A' => ['sync_request_ex'],
		'0936' => ['sync_request_ex'],
		'0367' => ['sync_request_ex'],
		'0202' => ['sync_request_ex'],
		'089A' => ['sync_request_ex'],
		'0438' => ['sync_request_ex'],
		'086B' => ['sync_request_ex'],
		'0962' => ['sync_request_ex'],
		'0934' => ['sync_request_ex'],
		'0281' => ['sync_request_ex'],
		'0861' => ['sync_request_ex'],
		'088E' => ['sync_request_ex'],
		'085F' => ['sync_request_ex'],
		'0815' => ['sync_request_ex'],
		'08AC' => ['sync_request_ex'],
		'0922' => ['sync_request_ex'],
		'0966' => ['sync_request_ex'],
		'088A' => ['sync_request_ex'],
		'0948' => ['sync_request_ex'],
		'0951' => ['sync_request_ex'],
		'0885' => ['sync_request_ex'],
		'0883' => ['sync_request_ex'],
		'08A2' => ['sync_request_ex'],
		'08A3' => ['sync_request_ex'],
		'0884' => ['sync_request_ex'],
		'083C' => ['sync_request_ex'],
		'023B' => ['sync_request_ex'],
		'08AA' => ['sync_request_ex'],
		'088F' => ['sync_request_ex'],
		'085D' => ['sync_request_ex'],
		'0949' => ['sync_request_ex'],
		'08A0' => ['sync_request_ex'],
		'0939' => ['sync_request_ex'],
		'096A' => ['sync_request_ex'],
		'0896' => ['sync_request_ex'],
		'0366' => ['sync_request_ex'],
		'093E' => ['sync_request_ex'],
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
		'086A' => '085A',
		'088C' => '0940',
		'0882' => '0819',
		'0365' => '0942',
		'0887' => '092C',
		'091C' => '0898',
		'0930' => '0436',
		'0932' => '0959',
		'0362' => '0862',
		'089E' => '0969',
		'0917' => '035F',
		'0957' => '0364',
		'095E' => '02C4',
		'087B' => '0941',
		'0369' => '0889',
		'094C' => '0924',
		'0811' => '0899',
		'0880' => '093C',
		'088B' => '092E',
		'087E' => '0817',
		'0838' => '0894',
		'093D' => '093F',
		'0437' => '0864',
		'0937' => '0886',
		'0869' => '093B',
		'0938' => '0360',
		'0955' => '094E',
		'0890' => '08AD',
		'0860' => '0943',
		'0368' => '08A9',
		'0961' => '08A6',
		'095B' => '07E4',
		'0875' => '0933',
		'0954' => '095C',
		'086C' => '0952',
		'0888' => '0968',
		'0892' => '094D',
		'0956' => '092B',
		'0921' => '0891',
		'0881' => '0963',
		'0958' => '085B',
		'0835' => '0944',
		'085C' => '08A7',
		'0923' => '094B',
		'087D' => '087A',
		'0928' => '022D',
		'0897' => '086D',
		'091A' => '0953',
		'0936' => '095D',
		'0367' => '0879',
		'0202' => '0877',
		'089A' => '089B',
		'0438' => '0927',
		'086B' => '0947',
		'0962' => '0867',
		'0934' => '0872',
		'0281' => '086F',
		'0861' => '07EC',
		'088E' => '0925',
		'085F' => '087F',
		'0815' => '0960',
		'08AC' => '0931',
		'0922' => '091E',
		'0966' => '092D',
		'088A' => '0919',
		'0948' => '0865',
		'0951' => '0361',
		'0885' => '0918',
		'0883' => '0895',
		'08A2' => '095A',
		'08A3' => '091D',
		'0884' => '0802',
		'083C' => '08AB',
		'023B' => '088D',
		'08AA' => '08A1',
		'088F' => '0950',
		'085D' => '0920',
		'0949' => '0863',
		'08A0' => '0893',
		'0939' => '0965',
		'096A' => '0871',
		'0896' => '0363',
		'0366' => '0929',
		'093E' => '093A',
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