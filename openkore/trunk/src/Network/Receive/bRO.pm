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
use Globals;
use Translation;
use Misc;

# Sync_Ex algorithm developed by Fr3DBr

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0097' => ['private_message', 'v Z24 V Z*', [qw(len privMsgUser flag privMsg)]], # -1
		'086B' => ['sync_request_ex'],  
		'0938' => ['sync_request_ex'],  
		'035F' => ['sync_request_ex'],  
		'0802' => ['sync_request_ex'],  
		'0922' => ['sync_request_ex'],  
		'092A' => ['sync_request_ex'],  
		'0811' => ['sync_request_ex'],  
		'0873' => ['sync_request_ex'],  
		'0896' => ['sync_request_ex'],  
		'095F' => ['sync_request_ex'],  
		'0893' => ['sync_request_ex'],  
		'0937' => ['sync_request_ex'],  
		'094D' => ['sync_request_ex'],  
		'0202' => ['sync_request_ex'],  
		'094B' => ['sync_request_ex'],  
		'094C' => ['sync_request_ex'],  
		'092E' => ['sync_request_ex'],  
		'0935' => ['sync_request_ex'],  
		'0928' => ['sync_request_ex'],  
		'0891' => ['sync_request_ex'],  
		'091D' => ['sync_request_ex'],  
		'093B' => ['sync_request_ex'],  
		'093D' => ['sync_request_ex'],  
		'092C' => ['sync_request_ex'],  
		'0883' => ['sync_request_ex'],  
		'089A' => ['sync_request_ex'],  
		'0960' => ['sync_request_ex'],  
		'085B' => ['sync_request_ex'],  
		'0947' => ['sync_request_ex'],  
		'0959' => ['sync_request_ex'],  
		'087F' => ['sync_request_ex'],  
		'08A1' => ['sync_request_ex'],  
		'087E' => ['sync_request_ex'],  
		'0368' => ['sync_request_ex'],  
		'0940' => ['sync_request_ex'],  
		'0894' => ['sync_request_ex'],  
		'08A6' => ['sync_request_ex'],  
		'08A7' => ['sync_request_ex'],  
		'092F' => ['sync_request_ex'],  
		'0868' => ['sync_request_ex'],  
		'0882' => ['sync_request_ex'],  
		'08A2' => ['sync_request_ex'],  
		'095B' => ['sync_request_ex'],  
		'0877' => ['sync_request_ex'],  
		'0888' => ['sync_request_ex'],  
		'0918' => ['sync_request_ex'],  
		'085F' => ['sync_request_ex'],  
		'088B' => ['sync_request_ex'],  
		'089D' => ['sync_request_ex'],  
		'0363' => ['sync_request_ex'],  
		'0969' => ['sync_request_ex'],  
		'088F' => ['sync_request_ex'],  
		'085E' => ['sync_request_ex'],  
		'0875' => ['sync_request_ex'],  
		'0939' => ['sync_request_ex'],  
		'091A' => ['sync_request_ex'],  
		'089E' => ['sync_request_ex'],  
		'092D' => ['sync_request_ex'],  
		'0864' => ['sync_request_ex'],  
		'0365' => ['sync_request_ex'],  
		'093F' => ['sync_request_ex'],  
		'0865' => ['sync_request_ex'],  
		'0874' => ['sync_request_ex'],  
		'0876' => ['sync_request_ex'],  
		'0920' => ['sync_request_ex'],  
		'093C' => ['sync_request_ex'],  
		'086D' => ['sync_request_ex'],  
		'0954' => ['sync_request_ex'],  
		'0936' => ['sync_request_ex'],  
		'0869' => ['sync_request_ex'],  
		'0890' => ['sync_request_ex'],  
		'0919' => ['sync_request_ex'],  
		'0963' => ['sync_request_ex'],  
		'0819' => ['sync_request_ex'],  
		'091C' => ['sync_request_ex'],  
		'0360' => ['sync_request_ex'],  
		'0838' => ['sync_request_ex'],  
		'07EC' => ['sync_request_ex'],  
		'02C4' => ['sync_request_ex'],  
		'0955' => ['sync_request_ex'],  
		'086E' => ['sync_request_ex'],  
		'0924' => ['sync_request_ex'],  
		'0957' => ['sync_request_ex'],  
		'0941' => ['sync_request_ex'],  
		'08B9' => ['login_pin_code_request', 'V V v', [qw(seed accountID flag)]],
		'08BB' => ['login_pin_new_code_result', 'v V', [qw(flag seed)]],
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
	my %sync_ex_question_reply = ('086B', '0885', '0938', '086A', '035F', '085D', '0802', '094E', '0922', '08A5', '092A', '0943',
		'0811', '08A9', '0873', '0436', '0896', '089F', '095F', '0369', '0893', '0898', 
		'0937', '0956', '094D', '0931', '0202', '088D', '094B', '0886', '094C', '093E', 
		'092E', '095A', '0935', '0944', '0928', '0887', '0891', '088C', '091D', '0926', 
		'093B', '0879', '093D', '087A', '092C', '022D', '0883', '0934', '089A', '083C', 
		'0960', '0946', '085B', '08AA', '0947', '088A', '0959', '0930', '087F', '0884', 
		'08A1', '087B', '087E', '0881', '0368', '08A0', '0940', '0927', '0894', '0878', 
		'08A6', '0951', '08A7', '0967', '092F', '0925', '0868', '0861', '0882', '0835', 
		'08A2', '0895', '095B', '0866', '0877', '0968', '0888', '093A', '0918', '0966', 
		'085F', '0921', '088B', '0948', '089D', '0933', '0363', '0964', '0969', '0437', 
		'088F', '091B', '085E', '0958', '0875', '088E', '0939', '0815', '091A', '0965', 
		'089E', '092B', '092D', '094A', '0864', '0361', '0365', '08A8', '093F', '0932', 
		'0865', '0889', '0874', '0362', '0876', '094F', '0920', '0863', '093C', '07E4', 
		'086D', '08AB', '0954', '08AC', '0936', '023B', '0869', '0367', '0890', '0872', 
		'0919', '0897', '0963', '095D', '0819', '0923', '091C', '0438', '0360', '0945', 
		'0838', '0870', '07EC', '095C', '02C4', '087D', '0955', '0950', '086E', '091F', 
		'0924', '0862', '0957', '0899', '0941', '089C');
	
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

sub login_pin_new_code_result {
	my ($self, $args) = @_;
	
	if ($args->{flag} == 2) {
		#PIN code invalid.
		error T("PIN code is invalid, don't use sequences or repeated numbers.\n");
		configModify('loginPinCode', '', 1);
		return if (!($self->queryAndSaveLoginPinCode(T("PIN code is invalid, don't use sequences or repeated numbers.\n"))));
		
		# there's a bug in bRO where you can use letters or symbols or even a string as your PIN code.
		# as a result this will render you unable to login again (forever?) using the official client
		# and this is detectable and can result in a permanent ban. we're using this code in order to
		# prevent this. - revok 17.12.2012
		while ((($config{loginPinCode} =~ /[^0-9]/) || (length($config{loginPinCode}) != 4)) &&
			!($self->queryAndSaveLoginPinCode("Your PIN should never contain anything but exactly 4 numbers.\n"))) {
			error T("Your PIN should never contain anything but exactly 4 numbers.\n");
		}
		
		$messageSender->sendLoginPinCode($args->{seed}, 0);
	}

}

sub login_pin_code_request {
	my ($self, $args) = @_;
	
	if (($args->{seed} == 0) && ($args->{accountID} == 0) && ($args->{flag} == 0)) {
		message T("PIN code is correct.\n"), "success";
		# call charSelectScreen
		$self->{lockCharScreen} = 0;
		if (charSelectScreen(1) == 1) {
			$firstLoginMap = 1;
			$startingzeny = $chars[$config{'char'}]{'zeny'} unless defined $startingzeny;
			$sentWelcomeMessage = 1;
		}
	} elsif ($args->{flag} == 1) {
		# PIN code query request.
		message T("Server requested PIN password in order to select your character.\n"), "connection";
		return if ($config{loginPinCode} eq '' && !($self->queryAndSaveLoginPinCode()));
		$messageSender->sendLoginPinCode($args->{seed}, 0);
		#$messageSender->sendCharLogin($config{char});
	} elsif ($args->{flag} == 2) {
		# PIN code has never been set before, so set it.
		warning T("PIN password is not set for this account.\n"), "connection";
		return if ($config{loginPinCode} eq '' && !($self->queryAndSaveLoginPinCode()));
		
		while ((($config{loginPinCode} =~ /[^0-9]/) || (length($config{loginPinCode}) != 4)) &&
			!($self->queryAndSaveLoginPinCode("Your PIN should never contain anything but exactly 4 numbers.\n"))) {
			error T("Your PIN should never contain anything but exactly 4 numbers.\n");
		}
		$messageSender->sendLoginPinCode($args->{seed}, 1);
	} elsif ($args->{flag} == 5) {
		# PIN code invalid.
		error T("PIN code is invalid, don't use sequences or repeated numbers.\n");
		configModify('loginPinCode', '', 1);
		return if (!($self->queryAndSaveLoginPinCode(T("The login PIN code that you entered is invalid. Please re-enter your login PIN code."))));
		$messageSender->sendLoginPinCode($args->{seed}, 0);
	} elsif ($args->{flag} == 8) {
		# PIN code incorrect.
		error T("PIN code is incorrect.\n");
		configModify('loginPinCode', '', 1);
		return if (!($self->queryAndSaveLoginPinCode(T("The login PIN code that you entered is incorrect. Please re-enter your login PIN code."))));
		$messageSender->sendLoginPinCode($args->{seed}, 0);
	} else {
		debug("login_pin_code_request: unknown flag $args->{flag}\n");
	}
	$timeout{master}{time} = time;
}

*parse_quest_update_mission_hunt = *Network::Receive::ServerType0::parse_quest_update_mission_hunt_v2;
*reconstruct_quest_update_mission_hunt = *Network::Receive::ServerType0::reconstruct_quest_update_mission_hunt_v2;

1;