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
		
		'08A4' => ['sync_request_ex'],
		'0366' => ['sync_request_ex'],
		'087D' => ['sync_request_ex'],
		'086C' => ['sync_request_ex'],
		'023B' => ['sync_request_ex'],
		'094A' => ['sync_request_ex'],
		'0802' => ['sync_request_ex'],
		'094C' => ['sync_request_ex'],
		'08A7' => ['sync_request_ex'],
		'035F' => ['sync_request_ex'],
		'0919' => ['sync_request_ex'],
		'091F' => ['sync_request_ex'],
		'0952' => ['sync_request_ex'],
		'0931' => ['sync_request_ex'],
		'0437' => ['sync_request_ex'],
		'0881' => ['sync_request_ex'],
		'0897' => ['sync_request_ex'],
		'086E' => ['sync_request_ex'],
		'085F' => ['sync_request_ex'],
		'08A2' => ['sync_request_ex'],
		'095C' => ['sync_request_ex'],
		'0943' => ['sync_request_ex'],
		'088C' => ['sync_request_ex'],
		'0966' => ['sync_request_ex'],
		'0917' => ['sync_request_ex'],
		'091E' => ['sync_request_ex'],
		'087C' => ['sync_request_ex'],
		'0871' => ['sync_request_ex'],
		'0873' => ['sync_request_ex'],
		'0937' => ['sync_request_ex'],
		'0935' => ['sync_request_ex'],
		'0367' => ['sync_request_ex'],
		'087B' => ['sync_request_ex'],
		'0895' => ['sync_request_ex'],
		'092A' => ['sync_request_ex'],
		'0941' => ['sync_request_ex'],
		'0885' => ['sync_request_ex'],
		'0948' => ['sync_request_ex'],
		'095F' => ['sync_request_ex'],
		'093B' => ['sync_request_ex'],
		'092B' => ['sync_request_ex'],
		'0815' => ['sync_request_ex'],
		'086A' => ['sync_request_ex'],
		'0863' => ['sync_request_ex'],
		'083C' => ['sync_request_ex'],
		'089D' => ['sync_request_ex'],
		'02C4' => ['sync_request_ex'],
		'0861' => ['sync_request_ex'],
		'0954' => ['sync_request_ex'],
		'0960' => ['sync_request_ex'],
		'0956' => ['sync_request_ex'],
		'0918' => ['sync_request_ex'],
		'095E' => ['sync_request_ex'],
		'0870' => ['sync_request_ex'],
		'085E' => ['sync_request_ex'],
		'0899' => ['sync_request_ex'],
		'089B' => ['sync_request_ex'],
		'0921' => ['sync_request_ex'],
		'094B' => ['sync_request_ex'],
		'091D' => ['sync_request_ex'],
		'0898' => ['sync_request_ex'],
		'088B' => ['sync_request_ex'],
		'088D' => ['sync_request_ex'],
		'093D' => ['sync_request_ex'],
		'095B' => ['sync_request_ex'],
		'0946' => ['sync_request_ex'],
		'0930' => ['sync_request_ex'],
		'0962' => ['sync_request_ex'],
		'0436' => ['sync_request_ex'],
		'092C' => ['sync_request_ex'],
		'089E' => ['sync_request_ex'],
		'086D' => ['sync_request_ex'],
		'0950' => ['sync_request_ex'],
		'086B' => ['sync_request_ex'],
		'0361' => ['sync_request_ex'],
		'0969' => ['sync_request_ex'],
		'0819' => ['sync_request_ex'],
		'0202' => ['sync_request_ex'],
		'093E' => ['sync_request_ex'],
		'0945' => ['sync_request_ex'],
		'091C' => ['sync_request_ex'],
		'089F' => ['sync_request_ex'],
		'0920' => ['sync_request_ex'],
		'0364' => ['sync_request_ex'],
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
		'08A4' => '089C',
		'0366' => '0886',
		'087D' => '0884',
		'086C' => '086F',
		'023B' => '08AC',
		'094A' => '0872',
		'0802' => '08AB',
		'094C' => '0882',
		'08A7' => '0947',
		'035F' => '0877',
		'0919' => '092D',
		'091F' => '0942',
		'0952' => '08A8',
		'0931' => '08A0',
		'0437' => '0860',
		'0881' => '094D',
		'0897' => '0957',
		'086E' => '0281',
		'085F' => '0880',
		'08A2' => '0890',
		'095C' => '0940',
		'0943' => '0894',
		'088C' => '0934',
		'0966' => '0955',
		'0917' => '0944',
		'091E' => '093C',
		'087C' => '0924',
		'0871' => '08A1',
		'0873' => '0864',
		'0937' => '0965',
		'0935' => '095D',
		'0367' => '0887',
		'087B' => '0874',
		'0895' => '093A',
		'092A' => '0365',
		'0941' => '0878',
		'0885' => '092E',
		'0948' => '08A3',
		'095F' => '088A',
		'093B' => '0939',
		'092B' => '0923',
		'0815' => '0363',
		'086A' => '0953',
		'0863' => '0811',
		'083C' => '0958',
		'089D' => '0893',
		'02C4' => '085A',
		'0861' => '0896',
		'0954' => '085D',
		'0960' => '089A',
		'0956' => '0959',
		'0918' => '0817',
		'095E' => '088F',
		'0870' => '088E',
		'085E' => '096A',
		'0899' => '0936',
		'089B' => '0968',
		'0921' => '07EC',
		'094B' => '0838',
		'091D' => '0867',
		'0898' => '0368',
		'088B' => '0925',
		'088D' => '095A',
		'093D' => '091A',
		'095B' => '087A',
		'0946' => '0891',
		'0930' => '087E',
		'0962' => '0865',
		'0436' => '0875',
		'092C' => '0961',
		'089E' => '0922',
		'086D' => '07E4',
		'0950' => '091B',
		'086B' => '0868',
		'0361' => '0928',
		'0969' => '0892',
		'0819' => '092F',
		'0202' => '085C',
		'093E' => '0883',
		'0945' => '08A5',
		'091C' => '0360',
		'089F' => '0866',
		'0920' => '0835',
		'0364' => '094F',
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