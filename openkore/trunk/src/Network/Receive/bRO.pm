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
		
		'094F' => ['sync_request_ex'],
		'0365' => ['sync_request_ex'],
		'0880' => ['sync_request_ex'],
		'0863' => ['sync_request_ex'],
		'08AC' => ['sync_request_ex'],
		'0938' => ['sync_request_ex'],
		'0881' => ['sync_request_ex'],
		'0954' => ['sync_request_ex'],
		'085F' => ['sync_request_ex'],
		'0968' => ['sync_request_ex'],
		'089A' => ['sync_request_ex'],
		'0941' => ['sync_request_ex'],
		'086D' => ['sync_request_ex'],
		'0811' => ['sync_request_ex'],
		'0896' => ['sync_request_ex'],
		'0931' => ['sync_request_ex'],
		'08A9' => ['sync_request_ex'],
		'08A5' => ['sync_request_ex'],
		'0360' => ['sync_request_ex'],
		'0950' => ['sync_request_ex'],
		'0958' => ['sync_request_ex'],
		'0875' => ['sync_request_ex'],
		'0366' => ['sync_request_ex'],
		'0932' => ['sync_request_ex'],
		'0882' => ['sync_request_ex'],
		'0943' => ['sync_request_ex'],
		'093F' => ['sync_request_ex'],
		'0956' => ['sync_request_ex'],
		'0891' => ['sync_request_ex'],
		'0878' => ['sync_request_ex'],
		'091C' => ['sync_request_ex'],
		'0874' => ['sync_request_ex'],
		'0939' => ['sync_request_ex'],
		'0937' => ['sync_request_ex'],
		'0928' => ['sync_request_ex'],
		'092D' => ['sync_request_ex'],
		'0368' => ['sync_request_ex'],
		'093D' => ['sync_request_ex'],
		'088C' => ['sync_request_ex'],
		'0367' => ['sync_request_ex'],
		'08A1' => ['sync_request_ex'],
		'07E4' => ['sync_request_ex'],
		'08A3' => ['sync_request_ex'],
		'092E' => ['sync_request_ex'],
		'085E' => ['sync_request_ex'],
		'087A' => ['sync_request_ex'],
		'0951' => ['sync_request_ex'],
		'092F' => ['sync_request_ex'],
		'0802' => ['sync_request_ex'],
		'0438' => ['sync_request_ex'],
		'0436' => ['sync_request_ex'],
		'0964' => ['sync_request_ex'],
		'091E' => ['sync_request_ex'],
		'089F' => ['sync_request_ex'],
		'0888' => ['sync_request_ex'],
		'0927' => ['sync_request_ex'],
		'087B' => ['sync_request_ex'],
		'0884' => ['sync_request_ex'],
		'0893' => ['sync_request_ex'],
		'093C' => ['sync_request_ex'],
		'095D' => ['sync_request_ex'],
		'0886' => ['sync_request_ex'],
		'0955' => ['sync_request_ex'],
		'0870' => ['sync_request_ex'],
		'0933' => ['sync_request_ex'],
		'0925' => ['sync_request_ex'],
		'0953' => ['sync_request_ex'],
		'02C4' => ['sync_request_ex'],
		'035F' => ['sync_request_ex'],
		'085A' => ['sync_request_ex'],
		'091D' => ['sync_request_ex'],
		'0819' => ['sync_request_ex'],
		'0869' => ['sync_request_ex'],
		'0364' => ['sync_request_ex'],
		'089E' => ['sync_request_ex'],
		'085D' => ['sync_request_ex'],
		'0917' => ['sync_request_ex'],
		'0957' => ['sync_request_ex'],
		'0369' => ['sync_request_ex'],
		'0946' => ['sync_request_ex'],
		'07EC' => ['sync_request_ex'],
		'088E' => ['sync_request_ex'],
		'086E' => ['sync_request_ex'],
		'0963' => ['sync_request_ex'],
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
		'094F' => '087C',
		'0365' => '08A4',
		'0880' => '085C',
		'0863' => '095E',
		'08AC' => '089C',
		'0938' => '0898',
		'0881' => '0871',
		'0954' => '088D',
		'085F' => '0922',
		'0968' => '08AB',
		'089A' => '08A7',
		'0941' => '091F',
		'086D' => '0919',
		'0811' => '0866',
		'0896' => '0890',
		'0931' => '088F',
		'08A9' => '0899',
		'08A5' => '0835',
		'0360' => '0949',
		'0950' => '0437',
		'0958' => '0894',
		'0875' => '023B',
		'0366' => '095F',
		'0932' => '0883',
		'0882' => '08A2',
		'0943' => '0872',
		'093F' => '087F',
		'0956' => '0923',
		'0891' => '0926',
		'0878' => '091A',
		'091C' => '094D',
		'0874' => '0895',
		'0939' => '094E',
		'0937' => '0947',
		'0928' => '0945',
		'092D' => '0944',
		'0368' => '0935',
		'093D' => '0920',
		'088C' => '086B',
		'0367' => '0864',
		'08A1' => '0959',
		'07E4' => '0860',
		'08A3' => '093E',
		'092E' => '0838',
		'085E' => '0936',
		'087A' => '0889',
		'0951' => '0363',
		'092F' => '092C',
		'0802' => '0940',
		'0438' => '0281',
		'0436' => '095A',
		'0964' => '0918',
		'091E' => '088A',
		'089F' => '0934',
		'0888' => '08AA',
		'0927' => '092B',
		'087B' => '0897',
		'0884' => '0966',
		'0893' => '0862',
		'093C' => '0873',
		'095D' => '0969',
		'0886' => '086F',
		'0955' => '0879',
		'0870' => '0965',
		'0933' => '0362',
		'0925' => '0815',
		'0953' => '094B',
		'02C4' => '095C',
		'035F' => '083C',
		'085A' => '0202',
		'091D' => '0867',
		'0819' => '0877',
		'0869' => '093B',
		'0364' => '0930',
		'089E' => '0924',
		'085D' => '0942',
		'0917' => '095B',
		'0957' => '087D',
		'0369' => '089B',
		'0946' => '0817',
		'07EC' => '094A',
		'088E' => '022D',
		'086E' => '0961',
		'0963' => '0861',
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