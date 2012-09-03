#########################################################################
#  OpenKore - Network subsystem
#  Copyright (c) 2006 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
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
		
		'0874' => ['sync_request_ex'],
		'086B' => ['sync_request_ex'],
		'0923' => ['sync_request_ex'],
		'0873' => ['sync_request_ex'],
		'0926' => ['sync_request_ex'],
		'0933' => ['sync_request_ex'],
		'091C' => ['sync_request_ex'],
		'0927' => ['sync_request_ex'],
		'08A9' => ['sync_request_ex'],
		'0897' => ['sync_request_ex'],
		'094E' => ['sync_request_ex'],
		'0920' => ['sync_request_ex'],
		'0866' => ['sync_request_ex'],
		'085A' => ['sync_request_ex'],
		'0953' => ['sync_request_ex'],
		'023B' => ['sync_request_ex'],
		'093A' => ['sync_request_ex'],
		'0885' => ['sync_request_ex'],
		'0944' => ['sync_request_ex'],
		'093E' => ['sync_request_ex'],
		'0935' => ['sync_request_ex'],
		'0436' => ['sync_request_ex'],
		'095E' => ['sync_request_ex'],
		'0925' => ['sync_request_ex'],
		'0938' => ['sync_request_ex'],
		'0966' => ['sync_request_ex'],
		'0892' => ['sync_request_ex'],
		'0962' => ['sync_request_ex'],
		'091E' => ['sync_request_ex'],
		'0917' => ['sync_request_ex'],
		'0921' => ['sync_request_ex'],
		'088F' => ['sync_request_ex'],
		'0958' => ['sync_request_ex'],
		'0928' => ['sync_request_ex'],
		'095F' => ['sync_request_ex'],
		'02C4' => ['sync_request_ex'],
		'0964' => ['sync_request_ex'],
		'0965' => ['sync_request_ex'],
		'0835' => ['sync_request_ex'],
		'092A' => ['sync_request_ex'],
		'0886' => ['sync_request_ex'],
		'0368' => ['sync_request_ex'],
		'091B' => ['sync_request_ex'],
		'08A1' => ['sync_request_ex'],
		'0838' => ['sync_request_ex'],
		'0437' => ['sync_request_ex'],
		'092C' => ['sync_request_ex'],
		'0802' => ['sync_request_ex'],
		'0876' => ['sync_request_ex'],
		'0936' => ['sync_request_ex'],
		'0362' => ['sync_request_ex'],
		'0860' => ['sync_request_ex'],
		'08A3' => ['sync_request_ex'],
		'093F' => ['sync_request_ex'],
		'0883' => ['sync_request_ex'],
		'0922' => ['sync_request_ex'],
		'0868' => ['sync_request_ex'],
		'0959' => ['sync_request_ex'],
		'0895' => ['sync_request_ex'],
		'0950' => ['sync_request_ex'],
		'0872' => ['sync_request_ex'],
		'0954' => ['sync_request_ex'],
		'092D' => ['sync_request_ex'],
		'091D' => ['sync_request_ex'],
		'08A7' => ['sync_request_ex'],
		'08A4' => ['sync_request_ex'],
		'0365' => ['sync_request_ex'],
		'0894' => ['sync_request_ex'],
		'0880' => ['sync_request_ex'],
		'0941' => ['sync_request_ex'],
		'0864' => ['sync_request_ex'],
		'0949' => ['sync_request_ex'],
		'088D' => ['sync_request_ex'],
		'0952' => ['sync_request_ex'],
		'085F' => ['sync_request_ex'],
		'0951' => ['sync_request_ex'],
		'087A' => ['sync_request_ex'],
		'0957' => ['sync_request_ex'],
		'0934' => ['sync_request_ex'],
		'08A8' => ['sync_request_ex'],
		'0865' => ['sync_request_ex'],
		'0879' => ['sync_request_ex'],
		'08AC' => ['sync_request_ex'],
		'0961' => ['sync_request_ex'],
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
		'0874' => '08A6',
		'086B' => '0882',
		'0923' => '0948',
		'0873' => '088B',
		'0926' => '087B',
		'0933' => '0898',
		'091C' => '095B',
		'0927' => '089F',
		'08A9' => '0867',
		'0897' => '0363',
		'094E' => '0361',
		'0920' => '0969',
		'0866' => '095A',
		'085A' => '0884',
		'0953' => '0888',
		'023B' => '0862',
		'093A' => '0899',
		'0885' => '0947',
		'0944' => '0930',
		'093E' => '0929',
		'0935' => '0931',
		'0436' => '0891',
		'095E' => '0817',
		'0925' => '089E',
		'0938' => '0438',
		'0966' => '07EC',
		'0892' => '094D',
		'0962' => '0875',
		'091E' => '086C',
		'0917' => '0366',
		'0921' => '0367',
		'088F' => '08A2',
		'0958' => '0946',
		'0928' => '0811',
		'095F' => '0861',
		'02C4' => '093C',
		'0964' => '0360',
		'0965' => '0890',
		'0835' => '086A',
		'092A' => '093B',
		'0886' => '022D',
		'0368' => '0364',
		'091B' => '0918',
		'08A1' => '08AB',
		'0838' => '07E4',
		'0437' => '0955',
		'092C' => '092F',
		'0802' => '0819',
		'0876' => '0942',
		'0936' => '0281',
		'0362' => '0893',
		'0860' => '088A',
		'08A3' => '0881',
		'093F' => '0919',
		'0883' => '0896',
		'0922' => '0924',
		'0868' => '0939',
		'0959' => '0815',
		'0895' => '091A',
		'0950' => '096A',
		'0872' => '094F',
		'0954' => '0871',
		'092D' => '0963',
		'091D' => '0369',
		'08A7' => '0863',
		'08A4' => '087C',
		'0365' => '086F',
		'0894' => '092B',
		'0880' => '0202',
		'0941' => '095C',
		'0864' => '089A',
		'0949' => '088C',
		'088D' => '08A0',
		'0952' => '083C',
		'085F' => '0932',
		'0951' => '0877',
		'087A' => '089C',
		'0957' => '08A5',
		'0934' => '0945',
		'08A8' => '094B',
		'0865' => '0937',
		'0879' => '093D',
		'08AC' => '087E',
		'0961' => '08AA',
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