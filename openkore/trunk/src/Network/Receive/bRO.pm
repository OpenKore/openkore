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
		
		'0966' => ['sync_request_ex'],
		'087F' => ['sync_request_ex'],
		'086E' => ['sync_request_ex'],
		'0957' => ['sync_request_ex'],
		'092D' => ['sync_request_ex'],
		'094B' => ['sync_request_ex'],
		'0961' => ['sync_request_ex'],
		'0934' => ['sync_request_ex'],
		'0802' => ['sync_request_ex'],
		'0889' => ['sync_request_ex'],
		'0885' => ['sync_request_ex'],
		'0950' => ['sync_request_ex'],
		'0881' => ['sync_request_ex'],
		'088B' => ['sync_request_ex'],
		'0835' => ['sync_request_ex'],
		'0929' => ['sync_request_ex'],
		'0942' => ['sync_request_ex'],
		'085E' => ['sync_request_ex'],
		'0861' => ['sync_request_ex'],
		'08A4' => ['sync_request_ex'],
		'0871' => ['sync_request_ex'],
		'0895' => ['sync_request_ex'],
		'08AC' => ['sync_request_ex'],
		'0959' => ['sync_request_ex'],
		'0869' => ['sync_request_ex'],
		'0920' => ['sync_request_ex'],
		'087C' => ['sync_request_ex'],
		'095B' => ['sync_request_ex'],
		'0367' => ['sync_request_ex'],
		'0438' => ['sync_request_ex'],
		'0884' => ['sync_request_ex'],
		'08AB' => ['sync_request_ex'],
		'0872' => ['sync_request_ex'],
		'089D' => ['sync_request_ex'],
		'0860' => ['sync_request_ex'],
		'092A' => ['sync_request_ex'],
		'0898' => ['sync_request_ex'],
		'091D' => ['sync_request_ex'],
		'0963' => ['sync_request_ex'],
		'0883' => ['sync_request_ex'],
		'089F' => ['sync_request_ex'],
		'0964' => ['sync_request_ex'],
		'0863' => ['sync_request_ex'],
		'092E' => ['sync_request_ex'],
		'0944' => ['sync_request_ex'],
		'091A' => ['sync_request_ex'],
		'089A' => ['sync_request_ex'],
		'0437' => ['sync_request_ex'],
		'0925' => ['sync_request_ex'],
		'0958' => ['sync_request_ex'],
		'0878' => ['sync_request_ex'],
		'0947' => ['sync_request_ex'],
		'0891' => ['sync_request_ex'],
		'08A2' => ['sync_request_ex'],
		'0360' => ['sync_request_ex'],
		'0369' => ['sync_request_ex'],
		'0896' => ['sync_request_ex'],
		'0927' => ['sync_request_ex'],
		'0936' => ['sync_request_ex'],
		'0838' => ['sync_request_ex'],
		'088D' => ['sync_request_ex'],
		'08A1' => ['sync_request_ex'],
		'0281' => ['sync_request_ex'],
		'092B' => ['sync_request_ex'],
		'0876' => ['sync_request_ex'],
		'0932' => ['sync_request_ex'],
		'0940' => ['sync_request_ex'],
		'087A' => ['sync_request_ex'],
		'0894' => ['sync_request_ex'],
		'0917' => ['sync_request_ex'],
		'0870' => ['sync_request_ex'],
		'093A' => ['sync_request_ex'],
		'093D' => ['sync_request_ex'],
		'086A' => ['sync_request_ex'],
		'022D' => ['sync_request_ex'],
		'092C' => ['sync_request_ex'],
		'093C' => ['sync_request_ex'],
		'0362' => ['sync_request_ex'],
		'093F' => ['sync_request_ex'],
		'088A' => ['sync_request_ex'],
		'094D' => ['sync_request_ex'],
		'0862' => ['sync_request_ex'],
		'0882' => ['sync_request_ex'],
		'095D' => ['sync_request_ex'],
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
		'0966' => '0967',
		'087F' => '094C',
		'086E' => '094E',
		'0957' => '0890',
		'092D' => '023B',
		'094B' => '08A0',
		'0961' => '0919',
		'0934' => '088C',
		'0802' => '0874',
		'0889' => '085C',
		'0885' => '0361',
		'0950' => '087D',
		'0881' => '091F',
		'088B' => '08A5',
		'0835' => '085D',
		'0929' => '095C',
		'0942' => '095F',
		'085E' => '0956',
		'0861' => '0202',
		'08A4' => '095E',
		'0871' => '088F',
		'0895' => '08A6',
		'08AC' => '08A3',
		'0959' => '0899',
		'0869' => '086D',
		'0920' => '087E',
		'087C' => '0960',
		'095B' => '08A9',
		'0367' => '094F',
		'0438' => '0926',
		'0884' => '089C',
		'08AB' => '035F',
		'0872' => '0865',
		'089D' => '086B',
		'0860' => '094A',
		'092A' => '07EC',
		'0898' => '0938',
		'091D' => '0945',
		'0963' => '095A',
		'0883' => '091E',
		'089F' => '0866',
		'0964' => '0946',
		'0863' => '0954',
		'092E' => '0939',
		'0944' => '091B',
		'091A' => '083C',
		'089A' => '0365',
		'0437' => '0930',
		'0925' => '0922',
		'0958' => '0955',
		'0878' => '0921',
		'0947' => '0817',
		'0891' => '0888',
		'08A2' => '0892',
		'0360' => '0893',
		'0369' => '086F',
		'0896' => '0953',
		'0927' => '0965',
		'0936' => '093E',
		'0838' => '0815',
		'088D' => '0868',
		'08A1' => '0948',
		'0281' => '089E',
		'092B' => '0962',
		'0876' => '0943',
		'0932' => '0928',
		'0940' => '089B',
		'087A' => '0918',
		'0894' => '0952',
		'0917' => '0877',
		'0870' => '091C',
		'093A' => '0931',
		'093D' => '085F',
		'086A' => '0875',
		'022D' => '0935',
		'092C' => '07E4',
		'093C' => '08A7',
		'0362' => '0923',
		'093F' => '088E',
		'088A' => '0436',
		'094D' => '08AD',
		'0862' => '0366',
		'0882' => '085B',
		'095D' => '085A',
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