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
		
		'0941' => ['sync_request_ex_1'],
		'08AD' => ['sync_request_ex_1'],
		'08AA' => ['sync_request_ex_1'],
		'093E' => ['sync_request_ex_1'],
		'0362' => ['sync_request_ex_1'],
		'0898' => ['sync_request_ex_1'],
		'088D' => ['sync_request_ex_1'],
		'0861' => ['sync_request_ex_1'],
		'0815' => ['sync_request_ex_1'],
		'085E' => ['sync_request_ex_1'],
		'0869' => ['sync_request_ex_1'],
		'0876' => ['sync_request_ex_1'],
		'093C' => ['sync_request_ex_1'],
		'0959' => ['sync_request_ex_1'],
		'0957' => ['sync_request_ex_1'],
		'0928' => ['sync_request_ex_1'],
		'0967' => ['sync_request_ex_1'],
		'0961' => ['sync_request_ex_1'],
		'0436' => ['sync_request_ex_1'],
		'0940' => ['sync_request_ex_1'],
		'0935' => ['sync_request_ex_1'],
		'094E' => ['sync_request_ex_1'],
		'0925' => ['sync_request_ex_1'],
		'091A' => ['sync_request_ex_1'],
		'092C' => ['sync_request_ex_1'],
		'0922' => ['sync_request_ex_1'],
		'0835' => ['sync_request_ex_1'],
		'0879' => ['sync_request_ex_1'],
		'0817' => ['sync_request_ex_1'],
		'093A' => ['sync_request_ex_1'],
		'08AC' => ['sync_request_ex_1'],
		'0919' => ['sync_request_ex_1'],
		'087D' => ['sync_request_ex_1'],
		'0965' => ['sync_request_ex_1'],
		'0956' => ['sync_request_ex_1'],
		'0438' => ['sync_request_ex_1'],
		'0895' => ['sync_request_ex_1'],
		'08A1' => ['sync_request_ex_1'],
		'095F' => ['sync_request_ex_1'],
		'0931' => ['sync_request_ex_1'],
		'0945' => ['sync_request_ex_1'],
		'095B' => ['sync_request_ex_1'],
		'094C' => ['sync_request_ex_2'],
		'022D' => ['sync_request_ex_2'],
		'0924' => ['sync_request_ex_2'],
		'0366' => ['sync_request_ex_2'],
		'089D' => ['sync_request_ex_2'],
		'0942' => ['sync_request_ex_2'],
		'0865' => ['sync_request_ex_2'],
		'0947' => ['sync_request_ex_2'],
		'096A' => ['sync_request_ex_2'],
		'0926' => ['sync_request_ex_2'],
		'0873' => ['sync_request_ex_2'],
		'0365' => ['sync_request_ex_2'],
		'08AB' => ['sync_request_ex_2'],
		'08A2' => ['sync_request_ex_2'],
		'0872' => ['sync_request_ex_2'],
		'092E' => ['sync_request_ex_2'],
		'0870' => ['sync_request_ex_2'],
		'0933' => ['sync_request_ex_2'],
		'0811' => ['sync_request_ex_2'],
		'0892' => ['sync_request_ex_2'],
		'089A' => ['sync_request_ex_2'],
		'094B' => ['sync_request_ex_2'],
		'0955' => ['sync_request_ex_2'],
		'089F' => ['sync_request_ex_2'],
		'0963' => ['sync_request_ex_2'],
		'089C' => ['sync_request_ex_2'],
		'086C' => ['sync_request_ex_2'],
		'0890' => ['sync_request_ex_2'],
		'0867' => ['sync_request_ex_2'],
		'086F' => ['sync_request_ex_2'],
		'091F' => ['sync_request_ex_2'],
		'0882' => ['sync_request_ex_2'],
		'0884' => ['sync_request_ex_2'],
		'0921' => ['sync_request_ex_2'],
		'035F' => ['sync_request_ex_2'],
		'08A7' => ['sync_request_ex_2'],
		'02C4' => ['sync_request_ex_2'],
		'0950' => ['sync_request_ex_2'],
		'0437' => ['sync_request_ex_2'],
		'087F' => ['sync_request_ex_2'],
		'0944' => ['sync_request_ex_2'],
		'0934' => ['sync_request_ex_2'],
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
		'0941' => '0946',		
		'08AD' => '0893',		
		'08AA' => '0202',		
		'093E' => '0932',		
		'0362' => '088B',		
		'0898' => '0862',		
		'088D' => '0939',		
		'0861' => '0368',		
		'0815' => '0969',		
		'085E' => '0966',		
		'0869' => '0369',		
		'0876' => '089B',		
		'093C' => '0930',		
		'0959' => '092A',		
		'0957' => '0923',		
		'0928' => '0886',		
		'0967' => '0929',		
		'0961' => '088E',		
		'0436' => '0920',		
		'0940' => '088A',		
		'0935' => '08A9',		
		'094E' => '087A',		
		'0925' => '0361',		
		'091A' => '0281',		
		'092C' => '0949',		
		'0922' => '087C',		
		'0835' => '0948',		
		'0879' => '07E4',		
		'0817' => '095A',		
		'093A' => '092D',		
		'08AC' => '087E',		
		'0919' => '091E',		
		'087D' => '0899',		
		'0965' => '085F',		
		'0956' => '085D',		
		'0438' => '0889',		
		'0895' => '0888',		
		'08A1' => '0897',		
		'095F' => '0367',		
		'0931' => '091B',		
		'0945' => '0819',		
		'095B' => '0960',		
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
		'094C' => '0887',		
		'022D' => '0875',		
		'0924' => '086B',		
		'0366' => '091D',		
		'089D' => '0363',		
		'0942' => '085B',		
		'0865' => '08A3',		
		'0947' => '0936',		
		'096A' => '0964',		
		'0926' => '086A',		
		'0873' => '023B',		
		'0365' => '0952',		
		'08AB' => '087B',		
		'08A2' => '08A6',		
		'0872' => '0868',		
		'092E' => '08A5',		
		'0870' => '0958',		
		'0933' => '0360',		
		'0811' => '095D',		
		'0892' => '0838',		
		'089A' => '0918',		
		'094B' => '0885',		
		'0955' => '0860',		
		'089F' => '088F',		
		'0963' => '0894',		
		'089C' => '0953',		
		'086C' => '0364',		
		'0890' => '0962',		
		'0867' => '0927',		
		'086F' => '07EC',		
		'091F' => '094A',		
		'0882' => '0881',		
		'0884' => '0866',		
		'0921' => '08A4',		
		'035F' => '094D',		
		'08A7' => '093D',		
		'02C4' => '0891',		
		'0950' => '083C',		
		'0437' => '093F',		
		'087F' => '08A0',		
		'0944' => '092B',		
		'0934' => '0896',		
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