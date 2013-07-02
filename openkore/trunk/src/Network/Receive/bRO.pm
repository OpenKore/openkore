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
use Translation;
use Misc;

# Sync_Ex algorithm developed by Fr3DBr

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0097' => ['private_message', 'v Z24 V Z*', [qw(len privMsgUser flag privMsg)]], # -1
		'088D' => ['sync_request_ex'],
		'0917' => ['sync_request_ex'],
		'0945' => ['sync_request_ex'],
		'092A' => ['sync_request_ex'],
		'0869' => ['sync_request_ex'],
		'0886' => ['sync_request_ex'],
		'089E' => ['sync_request_ex'],
		'0882' => ['sync_request_ex'],
		'0928' => ['sync_request_ex'],
		'0885' => ['sync_request_ex'],
		'0888' => ['sync_request_ex'],
		'0873' => ['sync_request_ex'],
		'0918' => ['sync_request_ex'],
		'0202' => ['sync_request_ex'],
		'08A6' => ['sync_request_ex'],
		'0889' => ['sync_request_ex'],
		'095D' => ['sync_request_ex'],
		'0871' => ['sync_request_ex'],
		'089D' => ['sync_request_ex'],
		'091A' => ['sync_request_ex'],
		'0868' => ['sync_request_ex'],
		'0866' => ['sync_request_ex'],
		'091D' => ['sync_request_ex'],
		'093F' => ['sync_request_ex'],
		'085F' => ['sync_request_ex'],
		'0361' => ['sync_request_ex'],
		'0926' => ['sync_request_ex'],
		'0861' => ['sync_request_ex'],
		'0938' => ['sync_request_ex'],
		'0897' => ['sync_request_ex'],
		'07EC' => ['sync_request_ex'],
		'0880' => ['sync_request_ex'],
		'091C' => ['sync_request_ex'],
		'087C' => ['sync_request_ex'],
		'089F' => ['sync_request_ex'],
		'0949' => ['sync_request_ex'],
		'085C' => ['sync_request_ex'],
		'087B' => ['sync_request_ex'],
		'0965' => ['sync_request_ex'],
		'0896' => ['sync_request_ex'],
		'093D' => ['sync_request_ex'],
		'0819' => ['sync_request_ex'],
		'08A4' => ['sync_request_ex'],
		'0966' => ['sync_request_ex'],
		'0363' => ['sync_request_ex'],
		'095E' => ['sync_request_ex'],
		'0895' => ['sync_request_ex'],
		'088E' => ['sync_request_ex'],
		'0890' => ['sync_request_ex'],
		'0811' => ['sync_request_ex'],
		'0887' => ['sync_request_ex'],
		'091B' => ['sync_request_ex'],
		'0959' => ['sync_request_ex'],
		'0860' => ['sync_request_ex'],
		'095F' => ['sync_request_ex'],
		'096A' => ['sync_request_ex'],
		'08A1' => ['sync_request_ex'],
		'094E' => ['sync_request_ex'],
		'0365' => ['sync_request_ex'],
		'086A' => ['sync_request_ex'],
		'0967' => ['sync_request_ex'],
		'0922' => ['sync_request_ex'],
		'089A' => ['sync_request_ex'],
		'0963' => ['sync_request_ex'],
		'0924' => ['sync_request_ex'],
		'0892' => ['sync_request_ex'],
		'094C' => ['sync_request_ex'],
		'091E' => ['sync_request_ex'],
		'0944' => ['sync_request_ex'],
		'087A' => ['sync_request_ex'],
		'0893' => ['sync_request_ex'],
		'0955' => ['sync_request_ex'],
		'0884' => ['sync_request_ex'],
		'089B' => ['sync_request_ex'],
		'0960' => ['sync_request_ex'],
		'0950' => ['sync_request_ex'],
		'0933' => ['sync_request_ex'],
		'0968' => ['sync_request_ex'],
		'0835' => ['sync_request_ex'],
		'0939' => ['sync_request_ex'],
		'0930' => ['sync_request_ex'],
		'092D' => ['sync_request_ex'],
		'08A9' => ['sync_request_ex'],
		'0934' => ['sync_request_ex'],
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}
	
	Plugins::addHook('packet_pre/received_characters' => sub {
		$self->{lockCharScreen} = 2;
		$timeout{charlogin}{time} = time;
	});
	
	Plugins::addHook(charSelectScreen => sub {
		$_[1]{return} = $self->{lockCharScreen};
	});

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
		'088D' => '0894',
		'0917' => '022D',
		'0945' => '0951',
		'092A' => '0931',
		'0869' => '094A',
		'0886' => '0838',
		'089E' => '095A',
		'0882' => '08A8',
		'0928' => '088F',
		'0885' => '08A2',
		'0888' => '0921',
		'0873' => '092E',
		'0918' => '08AD',
		'0202' => '0369',
		'08A6' => '08A7',
		'0889' => '086F',
		'095D' => '0437',
		'0871' => '086C',
		'089D' => '087D',
		'091A' => '0929',
		'0868' => '095B',
		'0866' => '08A3',
		'091D' => '094F',
		'093F' => '08AB',
		'085F' => '083C',
		'0361' => '0438',
		'0926' => '0360',
		'0861' => '0919',
		'0938' => '0881',
		'0897' => '0947',
		'07EC' => '095C',
		'0880' => '085A',
		'091C' => '0948',
		'087C' => '0874',
		'089F' => '0932',
		'0949' => '0883',
		'085C' => '0362',
		'087B' => '086E',
		'0965' => '0935',
		'0896' => '08AA',
		'093D' => '093E',
		'0819' => '0870',
		'08A4' => '0953',
		'0966' => '0946',
		'0363' => '085D',
		'095E' => '085E',
		'0895' => '0937',
		'088E' => '0867',
		'0890' => '0872',
		'0811' => '0898',
		'0887' => '0943',
		'091B' => '0366',
		'0959' => '0802',
		'0860' => '087F',
		'095F' => '02C4',
		'096A' => '0925',
		'08A1' => '0899',
		'094E' => '0956',
		'0365' => '094D',
		'086A' => '0962',
		'0967' => '0878',
		'0922' => '0923',
		'089A' => '092B',
		'0963' => '0879',
		'0924' => '0957',
		'0892' => '088B',
		'094C' => '093A',
		'091E' => '088C',
		'0944' => '092F',
		'087A' => '0952',
		'0893' => '0865',
		'0955' => '086D',
		'0884' => '08A0',
		'089B' => '0936',
		'0960' => '092C',
		'0950' => '0817',
		'0933' => '093B',
		'0968' => '088A',
		'0835' => '023B',
		'0939' => '0954',
		'0930' => '0941',
		'092D' => '086B',
		'08A9' => '0368',
		'0934' => '0942',
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