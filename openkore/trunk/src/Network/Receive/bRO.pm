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
		'086C' => ['sync_request_ex'],
		'08AC' => ['sync_request_ex'],
		'0955' => ['sync_request_ex'],
		'083C' => ['sync_request_ex'],
		'0886' => ['sync_request_ex'],
		'092B' => ['sync_request_ex'],
		'0369' => ['sync_request_ex'],
		'08A1' => ['sync_request_ex'],
		'08A7' => ['sync_request_ex'],
		'08A5' => ['sync_request_ex'],
		'089A' => ['sync_request_ex'],
		'0959' => ['sync_request_ex'],
		'0934' => ['sync_request_ex'],
		'0948' => ['sync_request_ex'],
		'085A' => ['sync_request_ex'],
		'086D' => ['sync_request_ex'],
		'092E' => ['sync_request_ex'],
		'023B' => ['sync_request_ex'],
		'0862' => ['sync_request_ex'],
		'0891' => ['sync_request_ex'],
		'0932' => ['sync_request_ex'],
		'0876' => ['sync_request_ex'],
		'0953' => ['sync_request_ex'],
		'0917' => ['sync_request_ex'],
		'0892' => ['sync_request_ex'],
		'0951' => ['sync_request_ex'],
		'0838' => ['sync_request_ex'],
		'0802' => ['sync_request_ex'],
		'0965' => ['sync_request_ex'],
		'087B' => ['sync_request_ex'],
		'091C' => ['sync_request_ex'],
		'0927' => ['sync_request_ex'],
		'089D' => ['sync_request_ex'],
		'091D' => ['sync_request_ex'],
		'0931' => ['sync_request_ex'],
		'08A0' => ['sync_request_ex'],
		'089B' => ['sync_request_ex'],
		'07E4' => ['sync_request_ex'],
		'0925' => ['sync_request_ex'],
		'0937' => ['sync_request_ex'],
		'087C' => ['sync_request_ex'],
		'088D' => ['sync_request_ex'],
		'0872' => ['sync_request_ex'],
		'089C' => ['sync_request_ex'],
		'0921' => ['sync_request_ex'],
		'0202' => ['sync_request_ex'],
		'02C4' => ['sync_request_ex'],
		'035F' => ['sync_request_ex'],
		'0936' => ['sync_request_ex'],
		'085F' => ['sync_request_ex'],
		'0437' => ['sync_request_ex'],
		'0884' => ['sync_request_ex'],
		'0935' => ['sync_request_ex'],
		'0924' => ['sync_request_ex'],
		'086F' => ['sync_request_ex'],
		'093C' => ['sync_request_ex'],
		'0961' => ['sync_request_ex'],
		'094B' => ['sync_request_ex'],
		'088E' => ['sync_request_ex'],
		'093A' => ['sync_request_ex'],
		'08AD' => ['sync_request_ex'],
		'0360' => ['sync_request_ex'],
		'0926' => ['sync_request_ex'],
		'0835' => ['sync_request_ex'],
		'093E' => ['sync_request_ex'],
		'0941' => ['sync_request_ex'],
		'08A4' => ['sync_request_ex'],
		'0869' => ['sync_request_ex'],
		'08A2' => ['sync_request_ex'],
		'0438' => ['sync_request_ex'],
		'0366' => ['sync_request_ex'],
		'0364' => ['sync_request_ex'],
		'0895' => ['sync_request_ex'],
		'091E' => ['sync_request_ex'],
		'0881' => ['sync_request_ex'],
		'087A' => ['sync_request_ex'],
		'0861' => ['sync_request_ex'],
		'092F' => ['sync_request_ex'],
		'085C' => ['sync_request_ex'],
		'093D' => ['sync_request_ex'],
		'0880' => ['sync_request_ex'],
		'0945' => ['sync_request_ex'],
		'0929' => ['sync_request_ex'],
		'088F' => ['sync_request_ex'],
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
		'086C' => '0920',
		'08AC' => '088B',
		'0955' => '0956',
		'083C' => '087E',
		'0886' => '0947',
		'092B' => '0958',
		'0369' => '0867',
		'08A1' => '093F',
		'08A7' => '0868',
		'08A5' => '0281',
		'089A' => '0957',
		'0959' => '0894',
		'0934' => '0942',
		'0948' => '0362',
		'085A' => '091A',
		'086D' => '091F',
		'092E' => '086A',
		'023B' => '086B',
		'0862' => '095F',
		'0891' => '0365',
		'0932' => '08A8',
		'0876' => '0962',
		'0953' => '0968',
		'0917' => '0928',
		'0892' => '0819',
		'0951' => '095B',
		'0838' => '0964',
		'0802' => '0954',
		'0965' => '0817',
		'087B' => '0890',
		'091C' => '0874',
		'0927' => '0815',
		'089D' => '0896',
		'091D' => '0865',
		'0931' => '0940',
		'08A0' => '0919',
		'089B' => '0870',
		'07E4' => '092D',
		'0925' => '096A',
		'0937' => '0897',
		'087C' => '0887',
		'088D' => '095C',
		'0872' => '0939',
		'089C' => '088C',
		'0921' => '093B',
		'0202' => '0952',
		'02C4' => '0923',
		'035F' => '0963',
		'0936' => '094A',
		'085F' => '0930',
		'0437' => '022D',
		'0884' => '0864',
		'0935' => '0878',
		'0924' => '0933',
		'086F' => '0877',
		'093C' => '085B',
		'0961' => '08AB',
		'094B' => '089F',
		'088E' => '092C',
		'093A' => '0888',
		'08AD' => '095A',
		'0360' => '0879',
		'0926' => '07EC',
		'0835' => '08A9',
		'093E' => '0966',
		'0941' => '0898',
		'08A4' => '0967',
		'0869' => '085E',
		'08A2' => '094E',
		'0438' => '0368',
		'0366' => '088A',
		'0364' => '087F',
		'0895' => '0943',
		'091E' => '0960',
		'0881' => '08A3',
		'087A' => '0361',
		'0861' => '095D',
		'092F' => '0885',
		'085C' => '091B',
		'093D' => '0922',
		'0880' => '0944',
		'0945' => '08AA',
		'0929' => '094C',
		'088F' => '0811',
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