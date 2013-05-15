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
		'08B9' => ['login_pin_code_request', 'V V v', [qw(seed accountID flag)]],
		'08BB' => ['login_pin_new_code_result', 'v V', [qw(flag seed)]],
		'0897' => ['sync_request_ex'],
		'093A' => ['sync_request_ex'],
		'08AC' => ['sync_request_ex'],
		'0921' => ['sync_request_ex'],
		'093B' => ['sync_request_ex'],
		'08A9' => ['sync_request_ex'],
		'094C' => ['sync_request_ex'],
		'0938' => ['sync_request_ex'],
		'0838' => ['sync_request_ex'],
		'092B' => ['sync_request_ex'],
		'083C' => ['sync_request_ex'],
		'091B' => ['sync_request_ex'],
		'0819' => ['sync_request_ex'],
		'088F' => ['sync_request_ex'],
		'088D' => ['sync_request_ex'],
		'0917' => ['sync_request_ex'],
		'0956' => ['sync_request_ex'],
		'0919' => ['sync_request_ex'],
		'0963' => ['sync_request_ex'],
		'0961' => ['sync_request_ex'],
		'086B' => ['sync_request_ex'],
		'0930' => ['sync_request_ex'],
		'0931' => ['sync_request_ex'],
		'0887' => ['sync_request_ex'],
		'08AD' => ['sync_request_ex'],
		'0928' => ['sync_request_ex'],
		'0880' => ['sync_request_ex'],
		'089F' => ['sync_request_ex'],
		'0964' => ['sync_request_ex'],
		'0940' => ['sync_request_ex'],
		'0877' => ['sync_request_ex'],
		'0873' => ['sync_request_ex'],
		'0965' => ['sync_request_ex'],
		'0959' => ['sync_request_ex'],
		'086E' => ['sync_request_ex'],
		'0437' => ['sync_request_ex'],
		'089C' => ['sync_request_ex'],
		'0281' => ['sync_request_ex'],
		'085C' => ['sync_request_ex'],
		'0929' => ['sync_request_ex'],
		'0924' => ['sync_request_ex'],
		'0934' => ['sync_request_ex'],
		'07E4' => ['sync_request_ex'],
		'08A1' => ['sync_request_ex'],
		'088A' => ['sync_request_ex'],
		'094E' => ['sync_request_ex'],
		'0942' => ['sync_request_ex'],
		'0862' => ['sync_request_ex'],
		'0969' => ['sync_request_ex'],
		'0935' => ['sync_request_ex'],
		'086D' => ['sync_request_ex'],
		'0960' => ['sync_request_ex'],
		'0923' => ['sync_request_ex'],
		'0945' => ['sync_request_ex'],
		'095B' => ['sync_request_ex'],
		'0925' => ['sync_request_ex'],
		'093F' => ['sync_request_ex'],
		'0885' => ['sync_request_ex'],
		'0949' => ['sync_request_ex'],
		'0968' => ['sync_request_ex'],
		'0870' => ['sync_request_ex'],
		'095C' => ['sync_request_ex'],
		'0932' => ['sync_request_ex'],
		'0967' => ['sync_request_ex'],
		'0899' => ['sync_request_ex'],
		'087D' => ['sync_request_ex'],
		'0815' => ['sync_request_ex'],
		'08A5' => ['sync_request_ex'],
		'094A' => ['sync_request_ex'],
		'0896' => ['sync_request_ex'],
		'023B' => ['sync_request_ex'],
		'08A3' => ['sync_request_ex'],
		'0920' => ['sync_request_ex'],
		'095E' => ['sync_request_ex'],
		'0369' => ['sync_request_ex'],
		'0946' => ['sync_request_ex'],
		'093D' => ['sync_request_ex'],
		'0893' => ['sync_request_ex'],
		'086A' => ['sync_request_ex'],
		'0361' => ['sync_request_ex'],
		'0436' => ['sync_request_ex'],
		'0438' => ['sync_request_ex'],
		'0894' => ['sync_request_ex'],
		'0202' => ['sync_request_ex'],
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
		'0897' => '08AA',
		'093A' => '085F',
		'08AC' => '0937',
		'0921' => '08A4',
		'093B' => '0952',
		'08A9' => '0869',
		'094C' => '0941',
		'0938' => '086F',
		'0838' => '089D',
		'092B' => '096A',
		'083C' => '0888',
		'091B' => '0362',
		'0819' => '0367',
		'088F' => '0939',
		'088D' => '0948',
		'0917' => '088B',
		'0956' => '0918',
		'0919' => '0943',
		'0963' => '0927',
		'0961' => '089E',
		'086B' => '08A0',
		'0930' => '0871',
		'0931' => '0811',
		'0887' => '0835',
		'08AD' => '089B',
		'0928' => '085E',
		'0880' => '0951',
		'089F' => '092C',
		'0964' => '093C',
		'0940' => '0363',
		'0877' => '0950',
		'0873' => '0868',
		'0965' => '092A',
		'0959' => '0867',
		'086E' => '087B',
		'0437' => '0360',
		'089C' => '0876',
		'0281' => '0922',
		'085C' => '08A7',
		'0929' => '07EC',
		'0924' => '0866',
		'0934' => '091E',
		'07E4' => '0865',
		'08A1' => '0883',
		'088A' => '0947',
		'094E' => '08AB',
		'0942' => '094D',
		'0862' => '0886',
		'0969' => '0958',
		'0935' => '035F',
		'086D' => '095F',
		'0960' => '094F',
		'0923' => '0957',
		'0945' => '022D',
		'095B' => '087F',
		'0925' => '0878',
		'093F' => '0368',
		'0885' => '0364',
		'0949' => '087A',
		'0968' => '0864',
		'0870' => '0881',
		'095C' => '087E',
		'0932' => '0884',
		'0967' => '0892',
		'0899' => '0933',
		'087D' => '0366',
		'0815' => '0861',
		'08A5' => '094B',
		'094A' => '0365',
		'0896' => '093E',
		'023B' => '02C4',
		'08A3' => '0926',
		'0920' => '095A',
		'095E' => '092F',
		'0369' => '0875',
		'0946' => '095D',
		'093D' => '0879',
		'0893' => '0891',
		'086A' => '086C',
		'0361' => '092D',
		'0436' => '0895',
		'0438' => '089A',
		'0894' => '087C',
		'0202' => '0962',
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

sub login_pin_new_code_result {
	my ($self, $args) = @_;
	
	if ($args->{flag} == 2) {
		# PIN code invalid.
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