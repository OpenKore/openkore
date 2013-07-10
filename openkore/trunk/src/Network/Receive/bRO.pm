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
		'0361' => ['sync_request_ex'],
		'085A' => ['sync_request_ex'],
		'085B' => ['sync_request_ex'],
		'085C' => ['sync_request_ex'],
		'085D' => ['sync_request_ex'],
		'085E' => ['sync_request_ex'],
		'085F' => ['sync_request_ex'],
		'0860' => ['sync_request_ex'],
		'0861' => ['sync_request_ex'],
		'0862' => ['sync_request_ex'],
		'0863' => ['sync_request_ex'],
		'0864' => ['sync_request_ex'],
		'0865' => ['sync_request_ex'],
		'0866' => ['sync_request_ex'],
		'0867' => ['sync_request_ex'],
		'0868' => ['sync_request_ex'],
		'0869' => ['sync_request_ex'],
		'086A' => ['sync_request_ex'],
		'086B' => ['sync_request_ex'],
		'086C' => ['sync_request_ex'],
		'0436' => ['sync_request_ex'],
		'086E' => ['sync_request_ex'],
		'086F' => ['sync_request_ex'],
		'0870' => ['sync_request_ex'],
		'0871' => ['sync_request_ex'],
		'0872' => ['sync_request_ex'],
		'0873' => ['sync_request_ex'],
		'0874' => ['sync_request_ex'],
		'0875' => ['sync_request_ex'],
		'0876' => ['sync_request_ex'],
		'0877' => ['sync_request_ex'],
		'0878' => ['sync_request_ex'],
		'0879' => ['sync_request_ex'],
		'087A' => ['sync_request_ex'],
		'087B' => ['sync_request_ex'],
		'0362' => ['sync_request_ex'],
		'087D' => ['sync_request_ex'],
		'0884' => ['sync_request_ex'],
		'087F' => ['sync_request_ex'],
		'0880' => ['sync_request_ex'],
		'0881' => ['sync_request_ex'],
		'0882' => ['sync_request_ex'],
		'0883' => ['sync_request_ex'],
		'0917' => ['sync_request_ex'],
		'0918' => ['sync_request_ex'],
		'0919' => ['sync_request_ex'],
		'091A' => ['sync_request_ex'],
		'091B' => ['sync_request_ex'],
		'091C' => ['sync_request_ex'],
		'091D' => ['sync_request_ex'],
		'091E' => ['sync_request_ex'],
		'091F' => ['sync_request_ex'],
		'0920' => ['sync_request_ex'],
		'0921' => ['sync_request_ex'],
		'0922' => ['sync_request_ex'],
		'0923' => ['sync_request_ex'],
		'0924' => ['sync_request_ex'],
		'0925' => ['sync_request_ex'],
		'0926' => ['sync_request_ex'],
		'0927' => ['sync_request_ex'],
		'0928' => ['sync_request_ex'],
		'0929' => ['sync_request_ex'],
		'092A' => ['sync_request_ex'],
		'092B' => ['sync_request_ex'],
		'092C' => ['sync_request_ex'],
		'092D' => ['sync_request_ex'],
		'092E' => ['sync_request_ex'],
		'092F' => ['sync_request_ex'],
		'0930' => ['sync_request_ex'],
		'0931' => ['sync_request_ex'],
		'0932' => ['sync_request_ex'],
		'0933' => ['sync_request_ex'],
		'0934' => ['sync_request_ex'],
		'0935' => ['sync_request_ex'],
		'0802' => ['sync_request_ex'],
		'0937' => ['sync_request_ex'],
		'0938' => ['sync_request_ex'],
		'0939' => ['sync_request_ex'],
		'02C4' => ['sync_request_ex'],
		'093B' => ['sync_request_ex'],
		'093C' => ['sync_request_ex'],
		'093D' => ['sync_request_ex'],
		'093E' => ['sync_request_ex'],
		'093F' => ['sync_request_ex'],
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
		'0361' => '087E',
		'085A' => '0437',
		'085B' => '094C',
		'085C' => '0886',
		'085D' => '023B',
		'085E' => '07E4',
		'085F' => '0889',
		'0860' => '088A',
		'0861' => '088B',
		'0862' => '088C',
		'0863' => '0364',
		'0864' => '088E',
		'0865' => '088F',
		'0866' => '0890',
		'0867' => '0891',
		'0868' => '0892',
		'0869' => '0893',
		'086A' => '0894',
		'086B' => '0895',
		'086C' => '0896',
		'0436' => '0897',
		'086E' => '0898',
		'086F' => '0899',
		'0870' => '089A',
		'0871' => '089B',
		'0872' => '089C',
		'0873' => '089D',
		'0874' => '089E',
		'0875' => '089F',
		'0876' => '08A0',
		'0877' => '08A1',
		'0878' => '08A2',
		'0879' => '08A3',
		'087A' => '08A4',
		'087B' => '08A5',
		'0362' => '08A6',
		'087D' => '08A7',
		'0884' => '08A8',
		'087F' => '08A9',
		'0880' => '08AA',
		'0881' => '022D',
		'0882' => '08AC',
		'0883' => '08AD',
		'0917' => '0941',
		'0918' => '0942',
		'0919' => '0943',
		'091A' => '0944',
		'091B' => '0945',
		'091C' => '0946',
		'091D' => '0947',
		'091E' => '0948',
		'091F' => '0949',
		'0920' => '0365',
		'0921' => '0940',
		'0922' => '094B',
		'0923' => '094D',
		'0924' => '094E',
		'0925' => '094F',
		'0926' => '0950',
		'0927' => '0951',
		'0928' => '0952',
		'0929' => '0953',
		'092A' => '0954',
		'092B' => '0955',
		'092C' => '0956',
		'092D' => '0957',
		'092E' => '0958',
		'092F' => '0959',
		'0930' => '095A',
		'0931' => '095B',
		'0932' => '095C',
		'0933' => '095D',
		'0934' => '095E',
		'0935' => '095F',
		'0802' => '07EC',
		'0937' => '0961',
		'0938' => '0962',
		'0939' => '0963',
		'02C4' => '0964',
		'093B' => '0965',
		'093C' => '0966',
		'093D' => '0967',
		'093E' => '0363',
		'093F' => '0969',
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