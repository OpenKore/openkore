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

		'086E' => ['sync_request_ex'],
		'0860' => ['sync_request_ex'],
		'0962' => ['sync_request_ex'],
		'0817' => ['sync_request_ex'],
		'0933' => ['sync_request_ex'],
		'0876' => ['sync_request_ex'],
		'0939' => ['sync_request_ex'],
		'0889' => ['sync_request_ex'],
		'093F' => ['sync_request_ex'],
		'089E' => ['sync_request_ex'],
		'086A' => ['sync_request_ex'],
		'0890' => ['sync_request_ex'],
		'089A' => ['sync_request_ex'],
		'093B' => ['sync_request_ex'],
		'0363' => ['sync_request_ex'],
		'0892' => ['sync_request_ex'],
		'035F' => ['sync_request_ex'],
		'0919' => ['sync_request_ex'],
		'095B' => ['sync_request_ex'],
		'091F' => ['sync_request_ex'],
		'087D' => ['sync_request_ex'],
		'0883' => ['sync_request_ex'],
		'08A2' => ['sync_request_ex'],
		'023B' => ['sync_request_ex'],
		'0961' => ['sync_request_ex'],
		'0930' => ['sync_request_ex'],
		'088D' => ['sync_request_ex'],
		'0881' => ['sync_request_ex'],
		'0202' => ['sync_request_ex'],
		'0888' => ['sync_request_ex'],
		'092C' => ['sync_request_ex'],
		'087C' => ['sync_request_ex'],
		'0365' => ['sync_request_ex'],
		'0884' => ['sync_request_ex'],
		'02C4' => ['sync_request_ex'],
		'0894' => ['sync_request_ex'],
		'094F' => ['sync_request_ex'],
		'0360' => ['sync_request_ex'],
		'0870' => ['sync_request_ex'],
		'0891' => ['sync_request_ex'],
		'087B' => ['sync_request_ex'],
		'0885' => ['sync_request_ex'],
		'0369' => ['sync_request_ex'],
		'085C' => ['sync_request_ex'],
		'083C' => ['sync_request_ex'],
		'0931' => ['sync_request_ex'],
		'0960' => ['sync_request_ex'],
		'0947' => ['sync_request_ex'],
		'0950' => ['sync_request_ex'],
		'087A' => ['sync_request_ex'],
		'08AD' => ['sync_request_ex'],
		'094E' => ['sync_request_ex'],
		'0882' => ['sync_request_ex'],
		'085A' => ['sync_request_ex'],
		'0955' => ['sync_request_ex'],
		'092E' => ['sync_request_ex'],
		'0946' => ['sync_request_ex'],
		'0952' => ['sync_request_ex'],
		'0929' => ['sync_request_ex'],
		'0922' => ['sync_request_ex'],
		'08A4' => ['sync_request_ex'],
		'093C' => ['sync_request_ex'],
		'091C' => ['sync_request_ex'],
		'08AB' => ['sync_request_ex'],
		'0923' => ['sync_request_ex'],
		'0921' => ['sync_request_ex'],
		'095C' => ['sync_request_ex'],
		'0956' => ['sync_request_ex'],
		'096A' => ['sync_request_ex'],
		'0959' => ['sync_request_ex'],
		'0948' => ['sync_request_ex'],
		'0941' => ['sync_request_ex'],
		'0886' => ['sync_request_ex'],
		'087E' => ['sync_request_ex'],
		'088C' => ['sync_request_ex'],
		'0366' => ['sync_request_ex'],
		'0898' => ['sync_request_ex'],
		'085B' => ['sync_request_ex'],
		'0864' => ['sync_request_ex'],
		'0867' => ['sync_request_ex'],
		'0802' => ['sync_request_ex'],
		'091A' => ['sync_request_ex'],
		'08A9' => ['sync_request_ex'],
		'088F' => ['sync_request_ex'],
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}
	
	Plugins::addHook('packet_pre/received_characters' => sub {
		$self->{lockCharScreen} = 2;
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
		'086E' => '0963',
		'0860' => '092D',
		'0962' => '08A1',
		'0817' => '095A',
		'0933' => '085F',
		'0876' => '0918',
		'0939' => '095F',
		'0889' => '093D',
		'093F' => '0866',
		'089E' => '0896',
		'086A' => '094D',
		'0890' => '0943',
		'089A' => '0957',
		'093B' => '0865',
		'0363' => '0899',
		'0892' => '0868',
		'035F' => '0966',
		'0919' => '085D',
		'095B' => '089F',
		'091F' => '0835',
		'087D' => '0932',
		'0883' => '0872',
		'08A2' => '094B',
		'023B' => '0964',
		'0961' => '0862',
		'0930' => '0968',
		'088D' => '0436',
		'0881' => '089B',
		'0202' => '0367',
		'0888' => '0877',
		'092C' => '085E',
		'087C' => '0871',
		'0365' => '0437',
		'0884' => '0861',
		'02C4' => '0361',
		'0894' => '0364',
		'094F' => '088E',
		'0360' => '0927',
		'0870' => '0874',
		'0891' => '0869',
		'087B' => '0897',
		'0885' => '086F',
		'0369' => '0942',
		'085C' => '0940',
		'083C' => '0893',
		'0931' => '0838',
		'0960' => '08A7',
		'0947' => '0887',
		'0950' => '0438',
		'087A' => '0928',
		'08AD' => '0281',
		'094E' => '089D',
		'0882' => '0938',
		'085A' => '0875',
		'0955' => '0944',
		'092E' => '0368',
		'0946' => '0953',
		'0952' => '092F',
		'0929' => '0362',
		'0922' => '08A5',
		'08A4' => '088B',
		'093C' => '0958',
		'091C' => '0917',
		'08AB' => '0926',
		'0923' => '091E',
		'0921' => '0819',
		'095C' => '0924',
		'0956' => '086C',
		'096A' => '088A',
		'0959' => '093E',
		'0948' => '086D',
		'0941' => '0949',
		'0886' => '0920',
		'087E' => '0815',
		'088C' => '0936',
		'0366' => '086B',
		'0898' => '07E4',
		'085B' => '0879',
		'0864' => '0967',
		'0867' => '092A',
		'0802' => '0873',
		'091A' => '08AA',
		'08A9' => '0937',
		'088F' => '0000',
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