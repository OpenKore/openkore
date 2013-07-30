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
# tRO (Thai)
package Network::Receive::tRO;
use strict;
use base qw(Network::Receive::ServerType0);
use Globals;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'0069' => ['account_server_info', 'x2 a4 a4 a4 x30 C1 x4 a*', [qw(sessionID accountID sessionID2 accountSex serverInfo)]],
		'0078' => ['actor_exists', 'C a4 v14 a4 a2 v2 C2 a3 C3 v', [qw(object_type ID walk_speed opt1 opt2 option type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 stance sex coords unknown1 unknown2 act lv)]], # 55 # standing
		'007C' => ['actor_connected', 'C a4 v14 C2 a3 C2', [qw(object_type ID walk_speed opt1 opt2 option hair_style weapon lowhead type shield tophead midhead hair_color clothes_color head_dir stance sex coords unknown1 unknown2)]], # 42 # spawning
		'0097' => ['private_message', 'v Z24 V Z*', [qw(len privMsgUser flag privMsg)]], # -1
		'022C' => ['actor_moved', 'C a4 v3 V v5 V v5 a4 a2 v V C2 a6 C2 v', [qw(object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 stance sex coords unknown1 unknown2 lv)]], # 65 # walking
		'082D' => ['sync_received_characters'],
		'099D' => ['received_characters', 'x2 a*', [qw(charInfo)]],
		'0886' => ['sync_request_ex'],
		'0921' => ['sync_request_ex'],
		'0936' => ['sync_request_ex'],
		'0860' => ['sync_request_ex'],
		'086A' => ['sync_request_ex'],
		'0838' => ['sync_request_ex'],
		'0815' => ['sync_request_ex'],
		'0365' => ['sync_request_ex'],
		'02C4' => ['sync_request_ex'],
		'08AD' => ['sync_request_ex'],
		'085A' => ['sync_request_ex'],
		'0881' => ['sync_request_ex'],
		'0875' => ['sync_request_ex'],
		'0882' => ['sync_request_ex'],
		'0952' => ['sync_request_ex'],
		'0878' => ['sync_request_ex'],
		'0867' => ['sync_request_ex'],
		'0880' => ['sync_request_ex'],
		'0918' => ['sync_request_ex'],
		'0885' => ['sync_request_ex'],
		'0899' => ['sync_request_ex'],
		'0888' => ['sync_request_ex'],
		'08AC' => ['sync_request_ex'],
		'07E4' => ['sync_request_ex'],
		'0802' => ['sync_request_ex'],
		'095C' => ['sync_request_ex'],
		'0891' => ['sync_request_ex'],
		'0965' => ['sync_request_ex'],
		'095D' => ['sync_request_ex'],
		'083C' => ['sync_request_ex'],
		'092B' => ['sync_request_ex'],
		'0871' => ['sync_request_ex'],
		'0945' => ['sync_request_ex'],
		'0890' => ['sync_request_ex'],
		'0934' => ['sync_request_ex'],
		'0811' => ['sync_request_ex'],
		'0929' => ['sync_request_ex'],
		'093D' => ['sync_request_ex'],
		'094D' => ['sync_request_ex'],
		'0870' => ['sync_request_ex'],
		'0883' => ['sync_request_ex'],
		'0924' => ['sync_request_ex'],
		'0877' => ['sync_request_ex'],
		'0923' => ['sync_request_ex'],
		'0896' => ['sync_request_ex'],
		'0942' => ['sync_request_ex'],
		'0367' => ['sync_request_ex'],
		'0889' => ['sync_request_ex'],
		'0879' => ['sync_request_ex'],
		'0969' => ['sync_request_ex'],
		'0966' => ['sync_request_ex'],
		'095E' => ['sync_request_ex'],
		'0893' => ['sync_request_ex'],
		'095F' => ['sync_request_ex'],
		'093A' => ['sync_request_ex'],
		'0819' => ['sync_request_ex'],
		'089E' => ['sync_request_ex'],
		'0967' => ['sync_request_ex'],
		'0963' => ['sync_request_ex'],
		'0817' => ['sync_request_ex'],
		'0873' => ['sync_request_ex'],
		'0919' => ['sync_request_ex'],
		'0862' => ['sync_request_ex'],
		'091B' => ['sync_request_ex'],
		'0961' => ['sync_request_ex'],
		'07EC' => ['sync_request_ex'],
		'094A' => ['sync_request_ex'],
		'0931' => ['sync_request_ex'],
		'0944' => ['sync_request_ex'],
		'0928' => ['sync_request_ex'],
		'096A' => ['sync_request_ex'],
		'0962' => ['sync_request_ex'],
		'0937' => ['sync_request_ex'],
		'093E' => ['sync_request_ex'],
		'0958' => ['sync_request_ex'],
		'087C' => ['sync_request_ex'],
		'094C' => ['sync_request_ex'],
		'035F' => ['sync_request_ex'],
		'0917' => ['sync_request_ex'],
		'089F' => ['sync_request_ex'],
		'093C' => ['sync_request_ex'],
		'0938' => ['sync_request_ex'],
		'0866' => ['sync_request_ex'],
		'0955' => ['sync_request_ex'],
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	my %handlers = qw(
		received_characters 099D
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

sub sync_request_ex {
	my ($self, $args) = @_;
	
	# Debug Log
	# message "Received Sync Ex : 0x" . $args->{switch} . "\n";
	
	# Computing Sync Ex - By Fr3DBr
	my $PacketID = $args->{switch};
	
	# Sync Ex Reply Array
	my %sync_ex_question_reply = (
		'0886' => '085D',
		'0921' => '086B',
		'0936' => '0948',
		'0860' => '0864',
		'086A' => '0368',
		'0838' => '0922',
		'0815' => '089C',
		'0365' => '0874',
		'02C4' => '0941',
		'08AD' => '087F',
		'085A' => '0894',
		'0881' => '085F',
		'0875' => '0437',
		'0882' => '0964',
		'0952' => '0933',
		'0878' => '094E',
		'0867' => '08AB',
		'0880' => '08A8',
		'0918' => '0925',
		'0885' => '088F',
		'0899' => '08A6',
		'0888' => '0897',
		'08AC' => '095A',
		'07E4' => '0369',
		'0802' => '0363',
		'095C' => '089D',
		'0891' => '095B',
		'0965' => '08A0',
		'095D' => '0949',
		'083C' => '088E',
		'092B' => '092E',
		'0871' => '08A7',
		'0945' => '0940',
		'0890' => '0927',
		'0934' => '022D',
		'0811' => '0281',
		'0929' => '0960',
		'093D' => '0954',
		'094D' => '0930',
		'0870' => '0863',
		'0883' => '0951',
		'0924' => '091F',
		'0877' => '08A4',
		'0923' => '088D',
		'0896' => '087A',
		'0942' => '023B',
		'0367' => '094F',
		'0889' => '0865',
		'0879' => '0950',
		'0969' => '0968',
		'0966' => '088C',
		'095E' => '088B',
		'0893' => '086D',
		'095F' => '0438',
		'093A' => '0932',
		'0819' => '0935',
		'089E' => '0362',
		'0967' => '0876',
		'0963' => '087D',
		'0817' => '0959',
		'0873' => '08A9',
		'0919' => '0953',
		'0862' => '0920',
		'091B' => '0895',
		'0961' => '089A',
		'07EC' => '08A5',
		'094A' => '0202',
		'0931' => '0366',
		'0944' => '092F',
		'0928' => '0898',
		'096A' => '0884',
		'0962' => '086E',
		'0937' => '0872',
		'093E' => '0869',
		'0958' => '0835',
		'087C' => '087E',
		'094C' => '089B',
		'035F' => '092D',
		'0917' => '08A2',
		'089F' => '088A',
		'093C' => '0943',
		'0938' => '08A3',
		'0866' => '0361',
		'0955' => '0946',
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

1;