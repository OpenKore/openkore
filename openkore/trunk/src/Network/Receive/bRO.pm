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
		
		'0923' => ['sync_request_ex'],
		'0879' => ['sync_request_ex'],
		'092D' => ['sync_request_ex'],
		'0202' => ['sync_request_ex'],
		'089B' => ['sync_request_ex'],
		'0945' => ['sync_request_ex'],
		'0882' => ['sync_request_ex'],
		'0883' => ['sync_request_ex'],
		'08A6' => ['sync_request_ex'],
		'0899' => ['sync_request_ex'],
		'093C' => ['sync_request_ex'],
		'085D' => ['sync_request_ex'],
		'085C' => ['sync_request_ex'],
		'0922' => ['sync_request_ex'],
		'086D' => ['sync_request_ex'],
		'091E' => ['sync_request_ex'],
		'093E' => ['sync_request_ex'],
		'092B' => ['sync_request_ex'],
		'0921' => ['sync_request_ex'],
		'0889' => ['sync_request_ex'],
		'0968' => ['sync_request_ex'],
		'089F' => ['sync_request_ex'],
		'08AC' => ['sync_request_ex'],
		'0952' => ['sync_request_ex'],
		'0949' => ['sync_request_ex'],
		'0878' => ['sync_request_ex'],
		'0958' => ['sync_request_ex'],
		'086E' => ['sync_request_ex'],
		'095D' => ['sync_request_ex'],
		'0876' => ['sync_request_ex'],
		'0936' => ['sync_request_ex'],
		'0948' => ['sync_request_ex'],
		'0885' => ['sync_request_ex'],
		'0944' => ['sync_request_ex'],
		'08A1' => ['sync_request_ex'],
		'085B' => ['sync_request_ex'],
		'0881' => ['sync_request_ex'],
		'0361' => ['sync_request_ex'],
		'0360' => ['sync_request_ex'],
		'094D' => ['sync_request_ex'],
		'0961' => ['sync_request_ex'],
		'0362' => ['sync_request_ex'],
		'022D' => ['sync_request_ex'],
		'0886' => ['sync_request_ex'],
		'0896' => ['sync_request_ex'],
		'0929' => ['sync_request_ex'],
		'087C' => ['sync_request_ex'],
		'0891' => ['sync_request_ex'],
		'0924' => ['sync_request_ex'],
		'091A' => ['sync_request_ex'],
		'0934' => ['sync_request_ex'],
		'092E' => ['sync_request_ex'],
		'0888' => ['sync_request_ex'],
		'088B' => ['sync_request_ex'],
		'088D' => ['sync_request_ex'],
		'0861' => ['sync_request_ex'],
		'023B' => ['sync_request_ex'],
		'087A' => ['sync_request_ex'],
		'0963' => ['sync_request_ex'],
		'0932' => ['sync_request_ex'],
		'087D' => ['sync_request_ex'],
		'091D' => ['sync_request_ex'],
		'08A3' => ['sync_request_ex'],
		'0895' => ['sync_request_ex'],
		'088F' => ['sync_request_ex'],
		'089A' => ['sync_request_ex'],
		'0925' => ['sync_request_ex'],
		'088C' => ['sync_request_ex'],
		'0957' => ['sync_request_ex'],
		'095F' => ['sync_request_ex'],
		'0865' => ['sync_request_ex'],
		'0935' => ['sync_request_ex'],
		'0965' => ['sync_request_ex'],
		'094B' => ['sync_request_ex'],
		'0863' => ['sync_request_ex'],
		'0953' => ['sync_request_ex'],
		'0941' => ['sync_request_ex'],
		'0875' => ['sync_request_ex'],
		'086C' => ['sync_request_ex'],
		'0874' => ['sync_request_ex'],
		'0930' => ['sync_request_ex'],
		'0887' => ['sync_request_ex'],
		'0365' => ['sync_request_ex'],
		'0872' => ['sync_request_ex'],
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
		'0923' => '0819',
		'0879' => '092C',
		'092D' => '08AB',
		'0202' => '0870',
		'089B' => '0947',
		'0945' => '0873',
		'0882' => '087E',
		'0883' => '088A',
		'08A6' => '0966',
		'0899' => '0939',
		'093C' => '095A',
		'085D' => '0964',
		'085C' => '093A',
		'0922' => '08A4',
		'086D' => '094A',
		'091E' => '096A',
		'093E' => '02C4',
		'092B' => '0367',
		'0921' => '0897',
		'0889' => '089E',
		'0968' => '088E',
		'089F' => '0363',
		'08AC' => '07E4',
		'0952' => '0955',
		'0949' => '0927',
		'0878' => '0815',
		'0958' => '08A8',
		'086E' => '0940',
		'095D' => '0893',
		'0876' => '0920',
		'0936' => '093F',
		'0948' => '094C',
		'0885' => '08AA',
		'0944' => '095C',
		'08A1' => '086B',
		'085B' => '0364',
		'0881' => '0919',
		'0361' => '0838',
		'0360' => '0954',
		'094D' => '08AD',
		'0961' => '092A',
		'0362' => '0437',
		'022D' => '0867',
		'0886' => '07EC',
		'0896' => '0967',
		'0929' => '095B',
		'087C' => '0868',
		'0891' => '089D',
		'0924' => '083C',
		'091A' => '0942',
		'0934' => '085F',
		'092E' => '0959',
		'0888' => '0937',
		'088B' => '085A',
		'088D' => '0931',
		'0861' => '0969',
		'023B' => '093B',
		'087A' => '093D',
		'0963' => '0860',
		'0932' => '08A0',
		'087D' => '0938',
		'091D' => '0817',
		'08A3' => '0894',
		'0895' => '0962',
		'088F' => '0933',
		'089A' => '0946',
		'0925' => '086F',
		'088C' => '0956',
		'0957' => '091B',
		'095F' => '0866',
		'0865' => '089C',
		'0935' => '095E',
		'0965' => '0877',
		'094B' => '0869',
		'0863' => '0926',
		'0953' => '0951',
		'0941' => '0928',
		'0875' => '0890',
		'086C' => '08A2',
		'0874' => '0369',
		'0930' => '086A',
		'0887' => '0862',
		'0365' => '091F',
		'0872' => '092F',
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