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
		'0867' => ['sync_request_ex'],
		'0926' => ['sync_request_ex'],
		'092B' => ['sync_request_ex'],
		'0868' => ['sync_request_ex'],
		'094C' => ['sync_request_ex'],
		'0955' => ['sync_request_ex'],
		'0893' => ['sync_request_ex'],
		'092F' => ['sync_request_ex'],
		'0929' => ['sync_request_ex'],
		'0866' => ['sync_request_ex'],
		'0863' => ['sync_request_ex'],
		'0366' => ['sync_request_ex'],
		'086F' => ['sync_request_ex'],
		'08A3' => ['sync_request_ex'],
		'0917' => ['sync_request_ex'],
		'0932' => ['sync_request_ex'],
		'0361' => ['sync_request_ex'],
		'087A' => ['sync_request_ex'],
		'086A' => ['sync_request_ex'],
		'0873' => ['sync_request_ex'],
		'0878' => ['sync_request_ex'],
		'0367' => ['sync_request_ex'],
		'0895' => ['sync_request_ex'],
		'0874' => ['sync_request_ex'],
		'08AA' => ['sync_request_ex'],
		'0817' => ['sync_request_ex'],
		'0943' => ['sync_request_ex'],
		'0945' => ['sync_request_ex'],
		'0965' => ['sync_request_ex'],
		'0890' => ['sync_request_ex'],
		'092A' => ['sync_request_ex'],
		'086D' => ['sync_request_ex'],
		'092D' => ['sync_request_ex'],
		'095E' => ['sync_request_ex'],
		'0962' => ['sync_request_ex'],
		'0811' => ['sync_request_ex'],
		'0968' => ['sync_request_ex'],
		'095C' => ['sync_request_ex'],
		'0934' => ['sync_request_ex'],
		'0877' => ['sync_request_ex'],
		'0918' => ['sync_request_ex'],
		'094D' => ['sync_request_ex'],
		'0927' => ['sync_request_ex'],
		'0898' => ['sync_request_ex'],
		'0959' => ['sync_request_ex'],
		'094F' => ['sync_request_ex'],
		'092E' => ['sync_request_ex'],
		'0886' => ['sync_request_ex'],
		'0937' => ['sync_request_ex'],
		'089A' => ['sync_request_ex'],
		'088F' => ['sync_request_ex'],
		'091B' => ['sync_request_ex'],
		'0889' => ['sync_request_ex'],
		'0894' => ['sync_request_ex'],
		'08AC' => ['sync_request_ex'],
		'0884' => ['sync_request_ex'],
		'0948' => ['sync_request_ex'],
		'0861' => ['sync_request_ex'],
		'0899' => ['sync_request_ex'],
		'0944' => ['sync_request_ex'],
		'0860' => ['sync_request_ex'],
		'085D' => ['sync_request_ex'],
		'08AB' => ['sync_request_ex'],
		'0931' => ['sync_request_ex'],
		'0896' => ['sync_request_ex'],
		'0887' => ['sync_request_ex'],
		'0875' => ['sync_request_ex'],
		'07EC' => ['sync_request_ex'],
		'0940' => ['sync_request_ex'],
		'08A7' => ['sync_request_ex'],
		'0952' => ['sync_request_ex'],
		'085F' => ['sync_request_ex'],
		'0957' => ['sync_request_ex'],
		'095A' => ['sync_request_ex'],
		'0950' => ['sync_request_ex'],
		'0871' => ['sync_request_ex'],
		'096A' => ['sync_request_ex'],
		'091F' => ['sync_request_ex'],
		'088C' => ['sync_request_ex'],
		'02C4' => ['sync_request_ex'],
		'0883' => ['sync_request_ex'],
		'0362' => ['sync_request_ex'],
		'0835' => ['sync_request_ex'],
		'0281' => ['sync_request_ex'],
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
		'0867' => '0897',
		'0926' => '088E',
		'092B' => '0438',
		'0868' => '0958',
		'094C' => '094A',
		'0955' => '0819',
		'0893' => '083C',
		'092F' => '089B',
		'0929' => '035F',
		'0866' => '08A0',
		'0863' => '092C',
		'0366' => '094E',
		'086F' => '0928',
		'08A3' => '094B',
		'0917' => '08A4',
		'0932' => '0939',
		'0361' => '087F',
		'087A' => '088B',
		'086A' => '0942',
		'0873' => '08A5',
		'0878' => '087C',
		'0367' => '0881',
		'0895' => '08A1',
		'0874' => '08A9',
		'08AA' => '095F',
		'0817' => '0885',
		'0943' => '07E4',
		'0945' => '0925',
		'0965' => '0919',
		'0890' => '0964',
		'092A' => '0961',
		'086D' => '0872',
		'092D' => '0930',
		'095E' => '085C',
		'0962' => '093F',
		'0811' => '0951',
		'0968' => '0954',
		'095C' => '0969',
		'0934' => '0935',
		'0877' => '0865',
		'0918' => '08A2',
		'094D' => '093B',
		'0927' => '0369',
		'0898' => '0365',
		'0959' => '0963',
		'094F' => '0802',
		'092E' => '0967',
		'0886' => '0921',
		'0937' => '087D',
		'089A' => '0946',
		'088F' => '0880',
		'091B' => '093E',
		'0889' => '0436',
		'0894' => '0838',
		'08AC' => '0924',
		'0884' => '0862',
		'0948' => '089F',
		'0861' => '0956',
		'0899' => '08A6',
		'0944' => '095D',
		'0860' => '0437',
		'085D' => '095B',
		'08AB' => '0938',
		'0931' => '093A',
		'0896' => '093C',
		'0887' => '08AD',
		'0875' => '093D',
		'07EC' => '0870',
		'0940' => '0936',
		'08A7' => '091A',
		'0952' => '0882',
		'085F' => '0941',
		'0957' => '088A',
		'095A' => '0364',
		'0950' => '085E',
		'0871' => '023B',
		'096A' => '0920',
		'091F' => '0368',
		'088C' => '0933',
		'02C4' => '085B',
		'0883' => '0363',
		'0362' => '0876',
		'0835' => '0922',
		'0281' => '086C',
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