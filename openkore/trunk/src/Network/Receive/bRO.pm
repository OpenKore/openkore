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
		
		'0838' => ['sync_request_ex'],
		'0860' => ['sync_request_ex'],
		'0361' => ['sync_request_ex'],
		'0869' => ['sync_request_ex'],
		'086B' => ['sync_request_ex'],
		'0875' => ['sync_request_ex'],
		'095C' => ['sync_request_ex'],
		'0963' => ['sync_request_ex'],
		'0879' => ['sync_request_ex'],
		'0930' => ['sync_request_ex'],
		'0891' => ['sync_request_ex'],
		'0437' => ['sync_request_ex'],
		'08AC' => ['sync_request_ex'],
		'0953' => ['sync_request_ex'],
		'0922' => ['sync_request_ex'],
		'093D' => ['sync_request_ex'],
		'096A' => ['sync_request_ex'],
		'0367' => ['sync_request_ex'],
		'08A7' => ['sync_request_ex'],
		'0877' => ['sync_request_ex'],
		'087F' => ['sync_request_ex'],
		'094D' => ['sync_request_ex'],
		'087B' => ['sync_request_ex'],
		'0802' => ['sync_request_ex'],
		'0935' => ['sync_request_ex'],
		'08A3' => ['sync_request_ex'],
		'023B' => ['sync_request_ex'],
		'08A0' => ['sync_request_ex'],
		'0929' => ['sync_request_ex'],
		'092B' => ['sync_request_ex'],
		'08A9' => ['sync_request_ex'],
		'0969' => ['sync_request_ex'],
		'095E' => ['sync_request_ex'],
		'092F' => ['sync_request_ex'],
		'089F' => ['sync_request_ex'],
		'08A8' => ['sync_request_ex'],
		'092C' => ['sync_request_ex'],
		'0934' => ['sync_request_ex'],
		'0880' => ['sync_request_ex'],
		'08AA' => ['sync_request_ex'],
		'089C' => ['sync_request_ex'],
		'0364' => ['sync_request_ex'],
		'091E' => ['sync_request_ex'],
		'0920' => ['sync_request_ex'],
		'0887' => ['sync_request_ex'],
		'0369' => ['sync_request_ex'],
		'086F' => ['sync_request_ex'],
		'0960' => ['sync_request_ex'],
		'0815' => ['sync_request_ex'],
		'088F' => ['sync_request_ex'],
		'0917' => ['sync_request_ex'],
		'0868' => ['sync_request_ex'],
		'093F' => ['sync_request_ex'],
		'0885' => ['sync_request_ex'],
		'0366' => ['sync_request_ex'],
		'093A' => ['sync_request_ex'],
		'094E' => ['sync_request_ex'],
		'093E' => ['sync_request_ex'],
		'094C' => ['sync_request_ex'],
		'0937' => ['sync_request_ex'],
		'094A' => ['sync_request_ex'],
		'092E' => ['sync_request_ex'],
		'086D' => ['sync_request_ex'],
		'0876' => ['sync_request_ex'],
		'0947' => ['sync_request_ex'],
		'0886' => ['sync_request_ex'],
		'0894' => ['sync_request_ex'],
		'0888' => ['sync_request_ex'],
		'089D' => ['sync_request_ex'],
		'0940' => ['sync_request_ex'],
		'022D' => ['sync_request_ex'],
		'0924' => ['sync_request_ex'],
		'0360' => ['sync_request_ex'],
		'0939' => ['sync_request_ex'],
		'0941' => ['sync_request_ex'],
		'0892' => ['sync_request_ex'],
		'091C' => ['sync_request_ex'],
		'0362' => ['sync_request_ex'],
		'0967' => ['sync_request_ex'],
		'085E' => ['sync_request_ex'],
		'086A' => ['sync_request_ex'],
		'0882' => ['sync_request_ex'],
		'091D' => ['sync_request_ex'],
		'087D' => ['sync_request_ex'],
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
		'0838' => '085F',
		'0860' => '0933',
		'0361' => '08A2',
		'0869' => '0943',
		'086B' => '0871',
		'0875' => '0862',
		'095C' => '0281',
		'0963' => '0898',
		'0879' => '0872',
		'0930' => '0923',
		'0891' => '0895',
		'0437' => '0931',
		'08AC' => '085C',
		'0953' => '08A1',
		'0922' => '0925',
		'093D' => '0959',
		'096A' => '0926',
		'0367' => '087C',
		'08A7' => '0867',
		'0877' => '0936',
		'087F' => '0365',
		'094D' => '085D',
		'087B' => '0202',
		'0802' => '07EC',
		'0935' => '0817',
		'08A3' => '088D',
		'023B' => '088C',
		'08A0' => '0863',
		'0929' => '0893',
		'092B' => '0946',
		'08A9' => '0950',
		'0969' => '0918',
		'095E' => '0363',
		'092F' => '0951',
		'089F' => '08AD',
		'08A8' => '0919',
		'092C' => '0938',
		'0934' => '07E4',
		'0880' => '0932',
		'08AA' => '08A5',
		'089C' => '0883',
		'0364' => '093B',
		'091E' => '0952',
		'0920' => '094B',
		'0887' => '0957',
		'0369' => '0865',
		'086F' => '0866',
		'0960' => '0881',
		'0815' => '0835',
		'088F' => '0966',
		'0917' => '0811',
		'0868' => '0949',
		'093F' => '0958',
		'0885' => '0964',
		'0366' => '086E',
		'093A' => '092A',
		'094E' => '0819',
		'093E' => '08A4',
		'094C' => '095A',
		'0937' => '085A',
		'094A' => '0890',
		'092E' => '087E',
		'086D' => '095D',
		'0876' => '091F',
		'0947' => '08A6',
		'0886' => '0438',
		'0894' => '095B',
		'0888' => '093C',
		'089D' => '091A',
		'0940' => '0955',
		'022D' => '0861',
		'0924' => '0873',
		'0360' => '0368',
		'0939' => '02C4',
		'0941' => '094F',
		'0892' => '0878',
		'091C' => '0965',
		'0362' => '0921',
		'0967' => '0944',
		'085E' => '035F',
		'086A' => '0948',
		'0882' => '0899',
		'091D' => '0928',
		'087D' => '087A',
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