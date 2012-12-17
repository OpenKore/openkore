#################################################################################################
#  OpenKore - Network subsystem									#
#  This module contains functions for sending messages to the server.				#
#												#
#  This software is open source, licensed under the GNU General Public				#
#  License, version 2.										#
#  Basically, this means that you're allowed to modify and distribute				#
#  this software. However, if you distribute modified versions, you MUST			#
#  also distribute the source code.								#
#  See http://www.gnu.org/licenses/gpl.html for the full license.				#
#################################################################################################
# bRO (Brazil)
package Network::Receive::bRO;
use strict;
use Log qw(message warning error debug);
use base 'Network::Receive::ServerType0';
use Globals;

# Sync_Ex algorithm developed by Fr3DBr

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
	
		'0097' => ['private_message', 'v Z24 V Z*', [qw(len privMsgUser flag privMsg)]], # -1
		
		'0863' => ['sync_request_ex'],
		'08A3' => ['sync_request_ex'],
		'0873' => ['sync_request_ex'],
		'092E' => ['sync_request_ex'],
		'092C' => ['sync_request_ex'],
		'0929' => ['sync_request_ex'],
		'094C' => ['sync_request_ex'],
		'095B' => ['sync_request_ex'],
		'088C' => ['sync_request_ex'],
		'0930' => ['sync_request_ex'],
		'093A' => ['sync_request_ex'],
		'092D' => ['sync_request_ex'],
		'083C' => ['sync_request_ex'],
		'087F' => ['sync_request_ex'],
		'0960' => ['sync_request_ex'],
		'0892' => ['sync_request_ex'],
		'086E' => ['sync_request_ex'],
		'0877' => ['sync_request_ex'],
		'094A' => ['sync_request_ex'],
		'088A' => ['sync_request_ex'],
		'087E' => ['sync_request_ex'],
		'0920' => ['sync_request_ex'],
		'08AC' => ['sync_request_ex'],
		'0956' => ['sync_request_ex'],
		'088F' => ['sync_request_ex'],
		'0922' => ['sync_request_ex'],
		'0867' => ['sync_request_ex'],
		'0937' => ['sync_request_ex'],
		'0868' => ['sync_request_ex'],
		'0897' => ['sync_request_ex'],
		'0860' => ['sync_request_ex'],
		'093D' => ['sync_request_ex'],
		'08A1' => ['sync_request_ex'],
		'0933' => ['sync_request_ex'],
		'095E' => ['sync_request_ex'],
		'0940' => ['sync_request_ex'],
		'088E' => ['sync_request_ex'],
		'088B' => ['sync_request_ex'],
		'087C' => ['sync_request_ex'],
		'092B' => ['sync_request_ex'],
		'0938' => ['sync_request_ex'],
		'0945' => ['sync_request_ex'],
		'0869' => ['sync_request_ex'],
		'0360' => ['sync_request_ex'],
		'085E' => ['sync_request_ex'],
		'0934' => ['sync_request_ex'],
		'0935' => ['sync_request_ex'],
		'0875' => ['sync_request_ex'],
		'0888' => ['sync_request_ex'],
		'08A5' => ['sync_request_ex'],
		'0955' => ['sync_request_ex'],
		'0927' => ['sync_request_ex'],
		'0817' => ['sync_request_ex'],
		'089D' => ['sync_request_ex'],
		'0942' => ['sync_request_ex'],
		'0866' => ['sync_request_ex'],
		'0961' => ['sync_request_ex'],
		'0881' => ['sync_request_ex'],
		'086C' => ['sync_request_ex'],
		'0835' => ['sync_request_ex'],
		'023B' => ['sync_request_ex'],
		'094D' => ['sync_request_ex'],
		'0368' => ['sync_request_ex'],
		'094F' => ['sync_request_ex'],
		'0861' => ['sync_request_ex'],
		'08A0' => ['sync_request_ex'],
		'093F' => ['sync_request_ex'],
		'092A' => ['sync_request_ex'],
		'0936' => ['sync_request_ex'],
		'08A8' => ['sync_request_ex'],
		'08A4' => ['sync_request_ex'],
		'093C' => ['sync_request_ex'],
		'086A' => ['sync_request_ex'],
		'0896' => ['sync_request_ex'],
		'096A' => ['sync_request_ex'],
		'0967' => ['sync_request_ex'],
		'0958' => ['sync_request_ex'],
		'0437' => ['sync_request_ex'],
		'091D' => ['sync_request_ex'],
		'0438' => ['sync_request_ex'],
		'0952' => ['sync_request_ex'],
		'0941' => ['sync_request_ex'],
		'089C' => ['sync_request_ex'],
		'0882' => ['sync_request_ex'],
		
		'08B9' => ['pin_password_request', 'a4 a4 v', [qw(ID KEY FLAG)]],
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

sub pin_password_request {
	my ($self, $args) = @_;
	
	my $flag = $args->{FLAG};
	
	# bRO Pin Password Implementation by Fr3DBr
	
	if ( $flag == 8 || $flag == 1 )
	{
		$messageSender->sendBroPin();
	}
	else
	{
		$messageSender->sendCharLogin($config{char});
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
		'0863' => '0893',
		'08A3' => '0953',
		'0873' => '07E4',
		'092E' => '0932',
		'092C' => '095A',
		'0929' => '0871',
		'094C' => '087A',
		'095B' => '0811',
		'088C' => '0923',
		'0930' => '08A9',
		'093A' => '0872',
		'092D' => '0894',
		'083C' => '092F',
		'087F' => '0878',
		'0960' => '0950',
		'0892' => '0947',
		'086E' => '089E',
		'0877' => '093B',
		'094A' => '085C',
		'088A' => '0928',
		'087E' => '0879',
		'0920' => '0436',
		'08AC' => '0819',
		'0956' => '0363',
		'088F' => '0365',
		'0922' => '091B',
		'0867' => '0951',
		'0937' => '08AA',
		'0868' => '0963',
		'0897' => '0361',
		'0860' => '0874',
		'093D' => '0364',
		'08A1' => '0962',
		'0933' => '0954',
		'095E' => '035F',
		'0940' => '089F',
		'088E' => '0946',
		'088B' => '0959',
		'087C' => '0943',
		'092B' => '0919',
		'0938' => '0281',
		'0945' => '094B',
		'0869' => '0889',
		'0360' => '085B',
		'085E' => '086F',
		'0934' => '0815',
		'0935' => '095F',
		'0875' => '0885',
		'0888' => '0880',
		'08A5' => '087D',
		'0955' => '07EC',
		'0927' => '091F',
		'0817' => '0965',
		'089D' => '0957',
		'0942' => '0362',
		'0866' => '095D',
		'0961' => '088D',
		'0881' => '0899',
		'086C' => '0369',
		'0835' => '0917',
		'023B' => '0925',
		'094D' => '0890',
		'0368' => '085A',
		'094F' => '091C',
		'0861' => '089A',
		'08A0' => '089B',
		'093F' => '08A2',
		'092A' => '0964',
		'0936' => '095C',
		'08A8' => '0918',
		'08A4' => '0367',
		'093C' => '0876',
		'086A' => '0864',
		'0896' => '086D',
		'096A' => '094E',
		'0967' => '08AB',
		'0958' => '0926',
		'0437' => '0891',
		'091D' => '0924',
		'0438' => '085D',
		'0952' => '02C4',
		'0941' => '0838',
		'089C' => '08A6',
		'0882' => '0966',
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