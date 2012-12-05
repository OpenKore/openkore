#############################################################################
#  OpenKore - Network subsystem												#
#  This module contains functions for sending messages to the server.		#
#																			#
#  This software is open source, licensed under the GNU General Public		#
#  License, version 2.														#
#  Basically, this means that you're allowed to modify and distribute		#
#  this software. However, if you distribute modified versions, you MUST	#
#  also distribute the source code.											#
#  See http://www.gnu.org/licenses/gpl.html for the full license.			#
#############################################################################
# bRO (Brazil)
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
		'08A0' => ['sync_request_ex'],  
		'0436' => ['sync_request_ex'],  
		'092F' => ['sync_request_ex'],  
		'0948' => ['sync_request_ex'],  
		'0925' => ['sync_request_ex'],  
		'0919' => ['sync_request_ex'],  
		'0861' => ['sync_request_ex'],  
		'0880' => ['sync_request_ex'],  
		'0928' => ['sync_request_ex'],  
		'0918' => ['sync_request_ex'],  
		'092B' => ['sync_request_ex'],  
		'094A' => ['sync_request_ex'],  
		'08AA' => ['sync_request_ex'],  
		'092A' => ['sync_request_ex'],  
		'085C' => ['sync_request_ex'],  
		'0952' => ['sync_request_ex'],  
		'093F' => ['sync_request_ex'],  
		'091C' => ['sync_request_ex'],  
		'091E' => ['sync_request_ex'],  
		'0864' => ['sync_request_ex'],  
		'0889' => ['sync_request_ex'],  
		'0879' => ['sync_request_ex'],  
		'07EC' => ['sync_request_ex'],  
		'0882' => ['sync_request_ex'],  
		'093E' => ['sync_request_ex'],  
		'089E' => ['sync_request_ex'],  
		'088D' => ['sync_request_ex'],  
		'0898' => ['sync_request_ex'],  
		'0917' => ['sync_request_ex'],  
		'087E' => ['sync_request_ex'],  
		'0876' => ['sync_request_ex'],  
		'0957' => ['sync_request_ex'],  
		'091F' => ['sync_request_ex'],  
		'089C' => ['sync_request_ex'],  
		'089B' => ['sync_request_ex'],  
		'0935' => ['sync_request_ex'],  
		'0951' => ['sync_request_ex'],  
		'0920' => ['sync_request_ex'],  
		'0871' => ['sync_request_ex'],  
		'08A6' => ['sync_request_ex'],  
		'0802' => ['sync_request_ex'],  
		'087B' => ['sync_request_ex'],  
		'0921' => ['sync_request_ex'],  
		'0967' => ['sync_request_ex'],  
		'0361' => ['sync_request_ex'],  
		'0954' => ['sync_request_ex'],  
		'092E' => ['sync_request_ex'],  
		'0924' => ['sync_request_ex'],  
		'0934' => ['sync_request_ex'],  
		'0938' => ['sync_request_ex'],  
		'0950' => ['sync_request_ex'],  
		'0867' => ['sync_request_ex'],  
		'0862' => ['sync_request_ex'],  
		'0926' => ['sync_request_ex'],  
		'086B' => ['sync_request_ex'],  
		'0868' => ['sync_request_ex'],  
		'0886' => ['sync_request_ex'],  
		'0369' => ['sync_request_ex'],  
		'0945' => ['sync_request_ex'],  
		'088E' => ['sync_request_ex'],  
		'0367' => ['sync_request_ex'],  
		'0863' => ['sync_request_ex'],  
		'0941' => ['sync_request_ex'],  
		'0953' => ['sync_request_ex'],  
		'091D' => ['sync_request_ex'],  
		'0949' => ['sync_request_ex'],  
		'0817' => ['sync_request_ex'],  
		'0962' => ['sync_request_ex'],  
		'085F' => ['sync_request_ex'],  
		'0860' => ['sync_request_ex'],  
		'023B' => ['sync_request_ex'],  
		'0958' => ['sync_request_ex'],  
		'0969' => ['sync_request_ex'],  
		'0897' => ['sync_request_ex'],  
		'085D' => ['sync_request_ex'],  
		'0940' => ['sync_request_ex'],  
		'0892' => ['sync_request_ex'],  
		'08A2' => ['sync_request_ex'],  
		'0877' => ['sync_request_ex'],  
		'092D' => ['sync_request_ex'],  
		'085A' => ['sync_request_ex'],  
		'08A5' => ['sync_request_ex'],  
		'087C' => ['sync_request_ex'],  
		'0815' => ['sync_request_ex'],  
		'0368' => ['sync_request_ex'],  
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
		'08A0' => '0368', 
		'0436' => '089F', 
		'092F' => '095D', 
		'0948' => '0874', 
		'0925' => '0891', 
		'0919' => '0943', 
		'0861' => '087F', 
		'0880' => '0362', 
		'0928' => '0887', 
		'0918' => '08AC', 
		'092B' => '0365', 
		'094A' => '0364', 
		'08AA' => '0875', 
		'092A' => '0961', 
		'085C' => '092C', 
		'0952' => '0960', 
		'093F' => '095C', 
		'091C' => '093A', 
		'091E' => '086F', 
		'0864' => '095B', 
		'0889' => '0936', 
		'0879' => '085E', 
		'07EC' => '0927', 
		'0882' => '08A7', 
		'093E' => '094D', 
		'089E' => '0873', 
		'088D' => '094C', 
		'0898' => '0899', 
		'0917' => '086A', 
		'087E' => '091A', 
		'0876' => '0894', 
		'0957' => '0923', 
		'091F' => '0942', 
		'089C' => '0895', 
		'089B' => '0838', 
		'0935' => '0930', 
		'0951' => '0932', 
		'0920' => '0438', 
		'0871' => '0437', 
		'08A6' => '093B', 
		'0802' => '0878', 
		'087B' => '0366', 
		'0921' => '0872', 
		'0967' => '083C', 
		'0361' => '0360', 
		'0954' => '0931', 
		'092E' => '088B', 
		'0924' => '0869', 
		'0934' => '091B', 
		'0938' => '08A1', 
		'0950' => '0363', 
		'0867' => '095A', 
		'0862' => '0955', 
		'0926' => '095F', 
		'086B' => '08AD', 
		'0868' => '08A4', 
		'0886' => '088A', 
		'0369' => '0811', 
		'0945' => '0896', 
		'088E' => '093C', 
		'0367' => '093D', 
		'0863' => '088F', 
		'0941' => '0819', 
		'0953' => '0281', 
		'091D' => '086E', 
		'0949' => '0929', 
		'0817' => '0968', 
		'0962' => '089A', 
		'085F' => '094B', 
		'0860' => '0964', 
		'023B' => '0890', 
		'0958' => '096A', 
		'0969' => '095E', 
		'0897' => '088C', 
		'085D' => '035F', 
		'0940' => '0963', 
		'0892' => '0965', 
		'08A2' => '0881', 
		'0877' => '0884', 
		'092D' => '08A3', 
		'085A' => '0937', 
		'08A5' => '0883', 
		'087C' => '0835', 
		'0815' => '0947', 
		'0368' => '0187', 
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