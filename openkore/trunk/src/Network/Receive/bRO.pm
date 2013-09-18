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
		'0966' => ['sync_request_ex'],
		'094D' => ['sync_request_ex'],
		'08A3' => ['sync_request_ex'],
		'0888' => ['sync_request_ex'],
		'0965' => ['sync_request_ex'],
		'0897' => ['sync_request_ex'],
		'0281' => ['sync_request_ex'],
		'0948' => ['sync_request_ex'],
		'0889' => ['sync_request_ex'],
		'0932' => ['sync_request_ex'],
		'0802' => ['sync_request_ex'],
		'086C' => ['sync_request_ex'],
		'0957' => ['sync_request_ex'],
		'094B' => ['sync_request_ex'],
		'0944' => ['sync_request_ex'],
		'094F' => ['sync_request_ex'],
		'091A' => ['sync_request_ex'],
		'0874' => ['sync_request_ex'],
		'085F' => ['sync_request_ex'],
		'0931' => ['sync_request_ex'],
		'093C' => ['sync_request_ex'],
		'094C' => ['sync_request_ex'],
		'095A' => ['sync_request_ex'],
		'096A' => ['sync_request_ex'],
		'0838' => ['sync_request_ex'],
		'0891' => ['sync_request_ex'],
		'0940' => ['sync_request_ex'],
		'0879' => ['sync_request_ex'],
		'08A0' => ['sync_request_ex'],
		'091B' => ['sync_request_ex'],
		'0894' => ['sync_request_ex'],
		'094A' => ['sync_request_ex'],
		'0360' => ['sync_request_ex'],
		'08A7' => ['sync_request_ex'],
		'08A6' => ['sync_request_ex'],
		'0835' => ['sync_request_ex'],
		'023B' => ['sync_request_ex'],
		'022D' => ['sync_request_ex'],
		'0811' => ['sync_request_ex'],
		'035F' => ['sync_request_ex'],
		'0922' => ['sync_request_ex'],
		'092A' => ['sync_request_ex'],
		'091E' => ['sync_request_ex'],
		'087A' => ['sync_request_ex'],
		'0919' => ['sync_request_ex'],
		'0936' => ['sync_request_ex'],
		'088B' => ['sync_request_ex'],
		'0365' => ['sync_request_ex'],
		'088E' => ['sync_request_ex'],
		'0967' => ['sync_request_ex'],
		'0438' => ['sync_request_ex'],
		'0368' => ['sync_request_ex'],
		'0933' => ['sync_request_ex'],
		'0815' => ['sync_request_ex'],
		'086A' => ['sync_request_ex'],
		'0949' => ['sync_request_ex'],
		'0817' => ['sync_request_ex'],
		'088F' => ['sync_request_ex'],
		'085B' => ['sync_request_ex'],
		'088C' => ['sync_request_ex'],
		'0968' => ['sync_request_ex'],
		'095B' => ['sync_request_ex'],
		'0947' => ['sync_request_ex'],
		'095F' => ['sync_request_ex'],
		'0923' => ['sync_request_ex'],
		'0921' => ['sync_request_ex'],
		'0950' => ['sync_request_ex'],
		'085D' => ['sync_request_ex'],
		'0366' => ['sync_request_ex'],
		'0369' => ['sync_request_ex'],
		'0887' => ['sync_request_ex'],
		'0883' => ['sync_request_ex'],
		'0963' => ['sync_request_ex'],
		'088D' => ['sync_request_ex'],
		'086F' => ['sync_request_ex'],
		'0870' => ['sync_request_ex'],
		'0895' => ['sync_request_ex'],
		'0860' => ['sync_request_ex'],
		'0920' => ['sync_request_ex'],
		'08A9' => ['sync_request_ex'],
		'0436' => ['sync_request_ex'],
		'0890' => ['sync_request_ex'],
		'087B' => ['sync_request_ex'],
		'0861' => ['sync_request_ex'],
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
		'0966' => '0956',
		'094D' => '08A1',
		'08A3' => '089A',
		'0888' => '0878',
		'0965' => '0893',
		'0897' => '095C',
		'0281' => '0934',
		'0948' => '0437',
		'0889' => '0924',
		'0932' => '08AB',
		'0802' => '087D',
		'086C' => '0885',
		'0957' => '07E4',
		'094B' => '0865',
		'0944' => '092D',
		'094F' => '087F',
		'091A' => '0202',
		'0874' => '0942',
		'085F' => '0938',
		'0931' => '0892',
		'093C' => '0884',
		'094C' => '0867',
		'095A' => '0364',
		'096A' => '0960',
		'0838' => '094E',
		'0891' => '092C',
		'0940' => '0863',
		'0879' => '091C',
		'08A0' => '0946',
		'091B' => '0873',
		'0894' => '0876',
		'094A' => '089D',
		'0360' => '0954',
		'08A7' => '0918',
		'08A6' => '095E',
		'0835' => '087E',
		'023B' => '0862',
		'022D' => '0872',
		'0811' => '0969',
		'035F' => '095D',
		'0922' => '0951',
		'092A' => '0361',
		'091E' => '08A2',
		'087A' => '0880',
		'0919' => '093A',
		'0936' => '093D',
		'088B' => '0896',
		'0365' => '0877',
		'088E' => '091F',
		'0967' => '07EC',
		'0438' => '08AC',
		'0368' => '0937',
		'0933' => '091D',
		'0815' => '02C4',
		'086A' => '092B',
		'0949' => '089E',
		'0817' => '0961',
		'088F' => '0964',
		'085B' => '0882',
		'088C' => '0958',
		'0968' => '0955',
		'095B' => '0899',
		'0947' => '086E',
		'095F' => '0917',
		'0923' => '093B',
		'0921' => '0928',
		'0950' => '0941',
		'085D' => '08AD',
		'0366' => '093F',
		'0369' => '0925',
		'0887' => '0866',
		'0883' => '08A8',
		'0963' => '0962',
		'088D' => '083C',
		'086F' => '0363',
		'0870' => '0869',
		'0895' => '0927',
		'0860' => '0871',
		'0920' => '0886',
		'08A9' => '0930',
		'0436' => '0952',
		'0890' => '0881',
		'087B' => '087C',
		'0861' => '0926',
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