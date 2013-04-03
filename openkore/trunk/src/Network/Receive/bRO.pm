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

		'0894' => ['sync_request_ex'],
		'0899' => ['sync_request_ex'],
		'0360' => ['sync_request_ex'],
		'089A' => ['sync_request_ex'],
		'0886' => ['sync_request_ex'],
		'093B' => ['sync_request_ex'],
		'0888' => ['sync_request_ex'],
		'087C' => ['sync_request_ex'],
		'0882' => ['sync_request_ex'],
		'091D' => ['sync_request_ex'],
		'094C' => ['sync_request_ex'],
		'08A6' => ['sync_request_ex'],
		'095E' => ['sync_request_ex'],
		'0927' => ['sync_request_ex'],
		'0890' => ['sync_request_ex'],
		'092D' => ['sync_request_ex'],
		'0941' => ['sync_request_ex'],
		'092F' => ['sync_request_ex'],
		'0940' => ['sync_request_ex'],
		'085D' => ['sync_request_ex'],
		'0877' => ['sync_request_ex'],
		'093D' => ['sync_request_ex'],
		'0802' => ['sync_request_ex'],
		'0368' => ['sync_request_ex'],
		'0968' => ['sync_request_ex'],
		'08A3' => ['sync_request_ex'],
		'022D' => ['sync_request_ex'],
		'086C' => ['sync_request_ex'],
		'0364' => ['sync_request_ex'],
		'0875' => ['sync_request_ex'],
		'0961' => ['sync_request_ex'],
		'0865' => ['sync_request_ex'],
		'08A7' => ['sync_request_ex'],
		'0895' => ['sync_request_ex'],
		'023B' => ['sync_request_ex'],
		'088F' => ['sync_request_ex'],
		'0960' => ['sync_request_ex'],
		'07E4' => ['sync_request_ex'],
		'088C' => ['sync_request_ex'],
		'0363' => ['sync_request_ex'],
		'08A9' => ['sync_request_ex'],
		'0874' => ['sync_request_ex'],
		'0942' => ['sync_request_ex'],
		'0924' => ['sync_request_ex'],
		'08A0' => ['sync_request_ex'],
		'0893' => ['sync_request_ex'],
		'091B' => ['sync_request_ex'],
		'088E' => ['sync_request_ex'],
		'0887' => ['sync_request_ex'],
		'0872' => ['sync_request_ex'],
		'089B' => ['sync_request_ex'],
		'091E' => ['sync_request_ex'],
		'0957' => ['sync_request_ex'],
		'0891' => ['sync_request_ex'],
		'093F' => ['sync_request_ex'],
		'0962' => ['sync_request_ex'],
		'092A' => ['sync_request_ex'],
		'0923' => ['sync_request_ex'],
		'0921' => ['sync_request_ex'],
		'0361' => ['sync_request_ex'],
		'091A' => ['sync_request_ex'],
		'0867' => ['sync_request_ex'],
		'0947' => ['sync_request_ex'],
		'091F' => ['sync_request_ex'],
		'087B' => ['sync_request_ex'],
		'096A' => ['sync_request_ex'],
		'08A1' => ['sync_request_ex'],
		'089E' => ['sync_request_ex'],
		'085E' => ['sync_request_ex'],
		'0959' => ['sync_request_ex'],
		'08A5' => ['sync_request_ex'],
		'0963' => ['sync_request_ex'],
		'094E' => ['sync_request_ex'],
		'0880' => ['sync_request_ex'],
		'0948' => ['sync_request_ex'],
		'093A' => ['sync_request_ex'],
		'0863' => ['sync_request_ex'],
		'0946' => ['sync_request_ex'],
		'093E' => ['sync_request_ex'],
		'0969' => ['sync_request_ex'],
		'0950' => ['sync_request_ex'],
		'0866' => ['sync_request_ex'],
		'0878' => ['sync_request_ex'],
		'0885' => ['sync_request_ex'],
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
		'0894' => '0965',
		'0899' => '0897',
		'0360' => '095A',
		'089A' => '0934',
		'0886' => '0281',
		'093B' => '0367',
		'0888' => '0896',
		'087C' => '089C',
		'0882' => '08A4',
		'091D' => '087A',
		'094C' => '0860',
		'08A6' => '0898',
		'095E' => '092C',
		'0927' => '08A8',
		'0890' => '092B',
		'092D' => '0956',
		'0941' => '0933',
		'092F' => '02C4',
		'0940' => '0876',
		'085D' => '0937',
		'0877' => '089D',
		'093D' => '0811',
		'0802' => '0883',
		'0368' => '086E',
		'0968' => '0362',
		'08A3' => '0873',
		'022D' => '0953',
		'086C' => '0929',
		'0364' => '095C',
		'0875' => '085F',
		'0961' => '094A',
		'0865' => '07EC',
		'08A7' => '08AA',
		'0895' => '0926',
		'023B' => '092E',
		'088F' => '0931',
		'0960' => '08A2',
		'07E4' => '0954',
		'088C' => '085A',
		'0363' => '0835',
		'08A9' => '0932',
		'0874' => '0964',
		'0942' => '085B',
		'0924' => '0943',
		'08A0' => '0936',
		'0893' => '0935',
		'091B' => '0952',
		'088E' => '087E',
		'0887' => '094B',
		'0872' => '0202',
		'089B' => '095D',
		'091E' => '0949',
		'0957' => '095F',
		'0891' => '089F',
		'093F' => '0955',
		'0962' => '0871',
		'092A' => '0861',
		'0923' => '095B',
		'0921' => '0920',
		'0361' => '0869',
		'091A' => '0919',
		'0867' => '087D',
		'0947' => '0438',
		'091F' => '088D',
		'087B' => '091C',
		'096A' => '0437',
		'08A1' => '0939',
		'089E' => '086F',
		'085E' => '0881',
		'0959' => '094F',
		'08A5' => '0365',
		'0963' => '0966',
		'094E' => '0889',
		'0880' => '0838',
		'0948' => '083C',
		'093A' => '0944',
		'0863' => '08AB',
		'0946' => '0938',
		'093E' => '0892',
		'0969' => '088B',
		'0950' => '08AD',
		'0866' => '0369',
		'0878' => '0366',
		'0885' => '0000',
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