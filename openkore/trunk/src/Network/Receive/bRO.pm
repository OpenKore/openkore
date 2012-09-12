#########################################################################
#  OpenKore - Network subsystem
#  This module contains functions for sending messages to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
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
		
        '0922' => ['sync_request_ex'],
        '07E4' => ['sync_request_ex'],
        '0947' => ['sync_request_ex'],
        '0963' => ['sync_request_ex'],
        '093C' => ['sync_request_ex'],
        '0920' => ['sync_request_ex'],
        '0956' => ['sync_request_ex'],
        '0899' => ['sync_request_ex'],
        '086B' => ['sync_request_ex'],
        '091F' => ['sync_request_ex'],
        '0871' => ['sync_request_ex'],
        '085D' => ['sync_request_ex'],
        '0948' => ['sync_request_ex'],
        '0437' => ['sync_request_ex'],
        '0362' => ['sync_request_ex'],
        '0202' => ['sync_request_ex'],
        '0940' => ['sync_request_ex'],
        '0368' => ['sync_request_ex'],
        '093E' => ['sync_request_ex'],
        '094C' => ['sync_request_ex'],
        '0949' => ['sync_request_ex'],
        '0363' => ['sync_request_ex'],
        '02C4' => ['sync_request_ex'],
        '087D' => ['sync_request_ex'],
        '0966' => ['sync_request_ex'],
        '0861' => ['sync_request_ex'],
        '0880' => ['sync_request_ex'],
        '0954' => ['sync_request_ex'],
        '0365' => ['sync_request_ex'],
        '088D' => ['sync_request_ex'],
        '086D' => ['sync_request_ex'],
        '092A' => ['sync_request_ex'],
        '085F' => ['sync_request_ex'],
        '0923' => ['sync_request_ex'],
        '087B' => ['sync_request_ex'],
        '0936' => ['sync_request_ex'],
        '0951' => ['sync_request_ex'],
        '0364' => ['sync_request_ex'],
        '0925' => ['sync_request_ex'],
        '087E' => ['sync_request_ex'],
        '0891' => ['sync_request_ex'],
        '088F' => ['sync_request_ex'],
        '0964' => ['sync_request_ex'],
        '093F' => ['sync_request_ex'],
        '0927' => ['sync_request_ex'],
        '0878' => ['sync_request_ex'],
        '0863' => ['sync_request_ex'],
        '0835' => ['sync_request_ex'],
        '087A' => ['sync_request_ex'],
        '0887' => ['sync_request_ex'],
        '091C' => ['sync_request_ex'],
        '086C' => ['sync_request_ex'],
        '0815' => ['sync_request_ex'],
        '0879' => ['sync_request_ex'],
        '0860' => ['sync_request_ex'],
        '08A4' => ['sync_request_ex'],
        '0868' => ['sync_request_ex'],
        '0893' => ['sync_request_ex'],
        '095D' => ['sync_request_ex'],
        '0930' => ['sync_request_ex'],
        '0969' => ['sync_request_ex'],
        '0436' => ['sync_request_ex'],
        '093D' => ['sync_request_ex'],
        '0819' => ['sync_request_ex'],
        '092B' => ['sync_request_ex'],
        '0937' => ['sync_request_ex'],
        '0931' => ['sync_request_ex'],
        '086A' => ['sync_request_ex'],
        '0924' => ['sync_request_ex'],
        '035F' => ['sync_request_ex'],
        '0369' => ['sync_request_ex'],
        '0862' => ['sync_request_ex'],
        '0968' => ['sync_request_ex'],
        '0817' => ['sync_request_ex'],
        '0939' => ['sync_request_ex'],
        '0894' => ['sync_request_ex'],
        '088A' => ['sync_request_ex'],
        '089D' => ['sync_request_ex'],
        '0811' => ['sync_request_ex'],
        '091B' => ['sync_request_ex'],
        '093B' => ['sync_request_ex'],
        '094B' => ['sync_request_ex'],
        '089C' => ['sync_request_ex'],
        '0874' => ['sync_request_ex'],
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
		'0894' => '0921',
		'0939' => '0864',
		'0951' => '087F',
		'086D' => '0281',
		'0954' => '088E',
		'0940' => '089F',
		'0956' => '094E',
		'086C' => '08A8',
		'0862' => '0934',
		'0871' => '085A',
		'0891' => '0958',
		'0937' => '0875',
		'0365' => '08AB',
		'0931' => '094A',
		'0927' => '0941',
		'0930' => '0897',
		'092A' => '0802',
		'0947' => '0889',
		'088F' => '085E',
		'0968' => '0877',
		'0899' => '0366',
		'087A' => '088C',
		'093E' => '0935',
		'094B' => '0881',
		'0948' => '0933',
		'0925' => '0360',
		'089C' => '0888',
		'091C' => '0952',
		'086A' => '085B',
		'0364' => '0946',
		'0878' => '087C',
		'0969' => '0869',
		'0437' => '08AA',
		'02C4' => '0944',
		'0887' => '092F',
		'093C' => '0950',
		'088D' => '0929',
		'0920' => '08A1',
		'0922' => '094D',
		'0369' => '089E',
		'0924' => '092E',
		'0949' => '091A',
		'0963' => '022D',
		'0362' => '0886',
		'0966' => '0965',
		'086B' => '0962',
		'0815' => '0438',
		'0868' => '083C',
		'0202' => '08AD',
		'088A' => '0898',
		'095D' => '093A',
		'0436' => '0361',
		'087E' => '0919',
		'0964' => '0967',
		'08A4' => '095E',
		'092B' => '0959',
		'0893' => '0938',
		'093D' => '0926',
		'035F' => '0957',
		'093B' => '086F',
		'0811' => '0945',
		'085F' => '0890',
		'091F' => '0943',
		'087D' => '023B',
		'089D' => '0932',
		'0879' => '095B',
		'085D' => '089A',
		'0861' => '0953',
		'0874' => '08A6',
		'0835' => '08A9',
		'087B' => '096A',
		'093F' => '0882',
		'0923' => '0917',
		'0860' => '0866',
		'094C' => '0896',
		'0863' => '0867',
		'0368' => '0873',
		'091B' => '095F',
		'0819' => '092C',
		'0936' => '085C',
		'0817' => '0960',
		'07E4' => '0892',
		'0363' => '0870',
		'0880' => '091D',
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