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
		'08AB' => ['sync_request_ex'],
		'0927' => ['sync_request_ex'],
		'0281' => ['sync_request_ex'],
		'093F' => ['sync_request_ex'],
		'0875' => ['sync_request_ex'],
		'0953' => ['sync_request_ex'],
		'092E' => ['sync_request_ex'],
		'0937' => ['sync_request_ex'],
		'086D' => ['sync_request_ex'],
		'0865' => ['sync_request_ex'],
		'086C' => ['sync_request_ex'],
		'0815' => ['sync_request_ex'],
		'0934' => ['sync_request_ex'],
		'08A4' => ['sync_request_ex'],
		'0922' => ['sync_request_ex'],
		'087C' => ['sync_request_ex'],
		'0931' => ['sync_request_ex'],
		'0361' => ['sync_request_ex'],
		'086E' => ['sync_request_ex'],
		'092D' => ['sync_request_ex'],
		'0802' => ['sync_request_ex'],
		'0965' => ['sync_request_ex'],
		'0367' => ['sync_request_ex'],
		'0878' => ['sync_request_ex'],
		'08AC' => ['sync_request_ex'],
		'0868' => ['sync_request_ex'],
		'094B' => ['sync_request_ex'],
		'089D' => ['sync_request_ex'],
		'0362' => ['sync_request_ex'],
		'0938' => ['sync_request_ex'],
		'0946' => ['sync_request_ex'],
		'0883' => ['sync_request_ex'],
		'0948' => ['sync_request_ex'],
		'0945' => ['sync_request_ex'],
		'0961' => ['sync_request_ex'],
		'094D' => ['sync_request_ex'],
		'08A0' => ['sync_request_ex'],
		'0863' => ['sync_request_ex'],
		'0891' => ['sync_request_ex'],
		'0881' => ['sync_request_ex'],
		'091B' => ['sync_request_ex'],
		'0890' => ['sync_request_ex'],
		'089F' => ['sync_request_ex'],
		'091E' => ['sync_request_ex'],
		'0939' => ['sync_request_ex'],
		'0925' => ['sync_request_ex'],
		'0935' => ['sync_request_ex'],
		'0954' => ['sync_request_ex'],
		'085C' => ['sync_request_ex'],
		'087A' => ['sync_request_ex'],
		'093E' => ['sync_request_ex'],
		'094A' => ['sync_request_ex'],
		'0917' => ['sync_request_ex'],
		'0894' => ['sync_request_ex'],
		'085A' => ['sync_request_ex'],
		'088D' => ['sync_request_ex'],
		'0864' => ['sync_request_ex'],
		'0860' => ['sync_request_ex'],
		'0943' => ['sync_request_ex'],
		'088C' => ['sync_request_ex'],
		'0366' => ['sync_request_ex'],
		'0963' => ['sync_request_ex'],
		'0876' => ['sync_request_ex'],
		'0936' => ['sync_request_ex'],
		'086B' => ['sync_request_ex'],
		'0929' => ['sync_request_ex'],
		'089A' => ['sync_request_ex'],
		'0870' => ['sync_request_ex'],
		'0884' => ['sync_request_ex'],
		'0898' => ['sync_request_ex'],
		'0861' => ['sync_request_ex'],
		'08A1' => ['sync_request_ex'],
		'093B' => ['sync_request_ex'],
		'08AD' => ['sync_request_ex'],
		'089E' => ['sync_request_ex'],
		'0838' => ['sync_request_ex'],
		'087D' => ['sync_request_ex'],
		'0895' => ['sync_request_ex'],
		'089B' => ['sync_request_ex'],
		'08A6' => ['sync_request_ex'],
		'091F' => ['sync_request_ex'],
		'0866' => ['sync_request_ex'],
		'0968' => ['sync_request_ex'],
		'0897' => ['sync_request_ex'],
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
		'08AB' => '0932',
		'0927' => '0363',
		'0281' => '08A2',
		'093F' => '08A9',
		'0875' => '02C4',
		'0953' => '089C',
		'092E' => '0962',
		'0937' => '0920',
		'086D' => '095E',
		'0865' => '0928',
		'086C' => '092A',
		'0815' => '0869',
		'0934' => '0967',
		'08A4' => '093A',
		'0922' => '07E4',
		'087C' => '0919',
		'0931' => '0942',
		'0361' => '0896',
		'086E' => '0879',
		'092D' => '095D',
		'0802' => '094F',
		'0965' => '091D',
		'0367' => '0940',
		'0878' => '085B',
		'08AC' => '0867',
		'0868' => '085F',
		'094B' => '0887',
		'089D' => '0944',
		'0362' => '0951',
		'0938' => '0871',
		'0946' => '0360',
		'0883' => '022D',
		'0948' => '0957',
		'0945' => '0892',
		'0961' => '095C',
		'094D' => '0880',
		'08A0' => '0438',
		'0863' => '0877',
		'0891' => '0437',
		'0881' => '0202',
		'091B' => '0819',
		'0890' => '023B',
		'089F' => '086F',
		'091E' => '095F',
		'0939' => '035F',
		'0925' => '0924',
		'0935' => '094E',
		'0954' => '0958',
		'085C' => '0882',
		'087A' => '0436',
		'093E' => '0369',
		'094A' => '0930',
		'0917' => '087B',
		'0894' => '0947',
		'085A' => '087F',
		'088D' => '0926',
		'0864' => '083C',
		'0860' => '096A',
		'0943' => '0949',
		'088C' => '0368',
		'0366' => '0817',
		'0963' => '0960',
		'0876' => '0874',
		'0936' => '0969',
		'086B' => '088E',
		'0929' => '095A',
		'089A' => '0955',
		'0870' => '094C',
		'0884' => '0952',
		'0898' => '0872',
		'0861' => '0941',
		'08A1' => '0966',
		'093B' => '092B',
		'08AD' => '0893',
		'089E' => '0885',
		'0838' => '092C',
		'087D' => '0862',
		'0895' => '07EC',
		'089B' => '0959',
		'08A6' => '091C',
		'091F' => '08A8',
		'0866' => '0835',
		'0968' => '093C',
		'0897' => '0899',
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