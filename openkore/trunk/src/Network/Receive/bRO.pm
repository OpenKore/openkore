#########################################################################
#  OpenKore - Network subsystem
#  Copyright (c) 2006 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gplhtml for the full license.
#########################################################################
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
		'085E' => ['sync_request_ex'],  
		'091D' => ['sync_request_ex'],  
		'092C' => ['sync_request_ex'],  
		'0932' => ['sync_request_ex'],  
		'092D' => ['sync_request_ex'],  
		'085D' => ['sync_request_ex'],  
		'0919' => ['sync_request_ex'],  
		'0865' => ['sync_request_ex'],  
		'0866' => ['sync_request_ex'],  
		'0933' => ['sync_request_ex'],  
		'0867' => ['sync_request_ex'],  
		'0936' => ['sync_request_ex'],  
		'087C' => ['sync_request_ex'],  
		'093A' => ['sync_request_ex'],  
		'0876' => ['sync_request_ex'],  
		'0367' => ['sync_request_ex'],  
		'0922' => ['sync_request_ex'],  
		'0868' => ['sync_request_ex'],  
		'0882' => ['sync_request_ex'],  
		'091E' => ['sync_request_ex'],  
		'0861' => ['sync_request_ex'],  
		'091B' => ['sync_request_ex'],  
		'0863' => ['sync_request_ex'],  
		'0923' => ['sync_request_ex'],  
		'0920' => ['sync_request_ex'],  
		'0918' => ['sync_request_ex'],  
		'091C' => ['sync_request_ex'],  
		'087B' => ['sync_request_ex'],  
		'092A' => ['sync_request_ex'],  
		'0875' => ['sync_request_ex'],  
		'0938' => ['sync_request_ex'],  
		'093F' => ['sync_request_ex'],  
		'093C' => ['sync_request_ex'],  
		'093E' => ['sync_request_ex'],  
		'023B' => ['sync_request_ex'],  
		'0926' => ['sync_request_ex'],  
		'092E' => ['sync_request_ex'],  
		'0921' => ['sync_request_ex'],  
		'0864' => ['sync_request_ex'],  
		'0935' => ['sync_request_ex'],  
		'085F' => ['sync_request_ex'],  
		'0930' => ['sync_request_ex'],  
		'091F' => ['sync_request_ex'],  
		'086D' => ['sync_request_ex'],  
		'085B' => ['sync_request_ex'],  
		'0927' => ['sync_request_ex'],  
		'0934' => ['sync_request_ex'],  
		'0917' => ['sync_request_ex'],  
		'093D' => ['sync_request_ex'],  
		'087F' => ['sync_request_ex'],  
		'0937' => ['sync_request_ex'],  
		'087E' => ['sync_request_ex'],  
		'0925' => ['sync_request_ex'],  
		'0924' => ['sync_request_ex'],  
		'0881' => ['sync_request_ex'],  
		'092F' => ['sync_request_ex'],  
		'0878' => ['sync_request_ex'],  
		'086A' => ['sync_request_ex'],  
		'085A' => ['sync_request_ex'],  
		'0871' => ['sync_request_ex'],  
		'086F' => ['sync_request_ex'],  
		'086C' => ['sync_request_ex'],  
		'0929' => ['sync_request_ex'],  
		'092B' => ['sync_request_ex'],  
		'0883' => ['sync_request_ex'],  
		'086B' => ['sync_request_ex'],  
		'0873' => ['sync_request_ex'],  
		'0869' => ['sync_request_ex'],  
		'086E' => ['sync_request_ex'],  
		'0874' => ['sync_request_ex'],  
		'0361' => ['sync_request_ex'],  
		'0870' => ['sync_request_ex'],  
		'087D' => ['sync_request_ex'],  
		'0880' => ['sync_request_ex'],  
		'093B' => ['sync_request_ex'],  
		'0928' => ['sync_request_ex'],  
		'087A' => ['sync_request_ex'],  
		'0872' => ['sync_request_ex'],  
		'091A' => ['sync_request_ex'],  
		'085C' => ['sync_request_ex'],  
		'0202' => ['sync_request_ex'],  
		'0862' => ['sync_request_ex'],  
		'0877' => ['sync_request_ex'],  
		'0879' => ['sync_request_ex'],  
		'08B9' => ['login_pin_code_request', 'V V v', [qw(seed accountID flag)]],
		'08BB' => ['login_pin_new_code_result', 'v V', [qw(flag seed)]],
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
		'085E' => '0888',  
		'091D' => '0947',  
		'092C' => '0956',  
		'0932' => '095C',  
		'092D' => '0957',  
		'085D' => '0887',  
		'0919' => '0943',  
		'0865' => '088F',  
		'0866' => '0890',  
		'0933' => '022D',  
		'0867' => '0891',  
		'0936' => '0960',  
		'087C' => '08A6',  
		'093A' => '0964',  
		'0876' => '0940',  
		'0367' => '02C4',  
		'0922' => '094C',  
		'0868' => '0892',  
		'0882' => '08AC',  
		'091E' => '0948',  
		'0861' => '088B',  
		'091B' => '0945',  
		'0863' => '088D',  
		'0923' => '094D',  
		'0920' => '094A',  
		'0918' => '0942',  
		'091C' => '0946',  
		'087B' => '08A5',  
		'092A' => '0954',  
		'0875' => '089F',  
		'0938' => '0962',  
		'093F' => '0969',  
		'093C' => '0966',  
		'093E' => '0968',  
		'023B' => '095B',  
		'0926' => '0950',  
		'092E' => '0958',  
		'0921' => '094B',  
		'0864' => '088E',  
		'0935' => '095F',  
		'085F' => '0889',  
		'0930' => '095A',  
		'091F' => '0949',  
		'086D' => '0897',  
		'085B' => '0885',  
		'0927' => '0951',  
		'0934' => '095E',  
		'0917' => '0941',  
		'093D' => '0967',  
		'087F' => '08A9',  
		'0937' => '0961',  
		'087E' => '08A8',  
		'0925' => '094F',  
		'0924' => '094E',  
		'0881' => '08AB',  
		'092F' => '0959',  
		'0878' => '08A2',  
		'086A' => '0894',  
		'085A' => '0884',  
		'0871' => '089B',  
		'086F' => '0899',  
		'086C' => '0896',  
		'0929' => '0953',  
		'092B' => '0955',  
		'0883' => '08AD',  
		'086B' => '0895',  
		'0873' => '089D',  
		'0869' => '0893',  
		'086E' => '0898',  
		'0874' => '089E',  
		'0361' => '088A',  
		'0870' => '089A',  
		'087D' => '08A7',  
		'0880' => '08AA',  
		'093B' => '0965',  
		'0928' => '0952',  
		'087A' => '08A4',  
		'0872' => '089C',  
		'091A' => '0944',  
		'085C' => '0886',  
		'0202' => '0963', 
		'0862' => '088C',  
		'0877' => '08A0', 
		'0879' => '08A3',  
		
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

# temporary patch in order to fix inventory 20121226
use Utils;

sub cart_items_nonstackable {
	my ($self, $args) = @_;

	my $newmsg;
	my $msg = $args->{RAW_MSG};
	$self->decrypt(\$newmsg, substr($msg, 4));
	$msg = substr($msg, 0, 4).$newmsg;

	my $unpack = $self->items_nonstackable($args);


	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += $unpack->{len}) {
		my ($item, $local_item);

		@{$item}{@{$unpack->{keys}}} = unpack($unpack->{types}, substr($msg, $i, $unpack->{len}));

		# TODO: different classes for inventory/cart/storage items
		$local_item = $cart{inventory}[$item->{index}] = Actor::Item->new;

		foreach (@{$unpack->{keys}}) {
			$local_item->{$_} = $item->{$_};
		}
		$local_item->{name} = itemName($local_item);
		$local_item->{amount} = 1;

		debug "Non-Stackable Cart Item: $local_item->{name} ($local_item->{index}) x 1\n", "parseMsg";
		Plugins::callHook('packet_cart', {index => $local_item->{index}});
	}

	$ai_v{'inventory_time'} = time + 1;
	$ai_v{'cart_time'} = time + 1;
}

sub cart_items_stackable {
	my ($self, $args) = @_;

	my $newmsg;
	my $msg = $args->{RAW_MSG};
	$self->decrypt(\$newmsg, substr($msg, 4));
	$msg = substr($msg, 0, 4).$newmsg;

	my $unpack = $self->items_stackable($args);

	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += $unpack->{len}) {
		my ($item, $local_item);

		@{$item}{@{$unpack->{keys}}} = unpack($unpack->{types}, substr($msg, $i, $unpack->{len}));

		$local_item = $cart{inventory}[$item->{index}] ||= Actor::Item->new;
		if ($local_item->{amount}) {
			$local_item->{amount} += $item->{amount};
		} else {

			foreach (@{$unpack->{keys}}) {
				$local_item->{$_} = $item->{$_};
			}
		}
		$local_item->{name} = itemName($local_item);

		debug "Stackable Cart Item: $local_item->{name} ($local_item->{index}) x $local_item->{amount}\n", "parseMsg";
		Plugins::callHook('packet_cart', {index => $local_item->{index}});
	}

	$ai_v{'inventory_time'} = time + 1;
	$ai_v{'cart_time'} = time + 1;
}

sub inventory_items_nonstackable {
	my ($self, $args) = @_;
	return unless changeToInGameState();
	my ($newmsg, $psize);
	$self->decrypt(\$newmsg, substr($args->{RAW_MSG}, 4));
	my $msg = substr($args->{RAW_MSG}, 0, 4) . $newmsg;

	my $unpack = $self->items_nonstackable($args);

	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += $unpack->{len}) {
		my ($item, $local_item, $add);

		@{$item}{@{$unpack->{keys}}} = unpack($unpack->{types}, substr($msg, $i, $unpack->{len}));

		unless($local_item = $char->inventory->getByServerIndex($item->{index})) {
			$local_item = new Actor::Item();
			$add = 1;
		}


		foreach (@{$unpack->{keys}}) {
			$local_item->{$_} = $item->{$_};
		}
		$local_item->{name} = itemName($local_item);
		$local_item->{amount} = 1;

		if ($local_item->{equipped}) {
			foreach (%equipSlot_rlut){
				if ($_ & $local_item->{equipped}){
					next if $_ == 10; #work around Arrow bug
					next if $_ == 32768;
					$char->{equipment}{$equipSlot_lut{$_}} = $local_item;
				}
			}
		}

		$char->inventory->add($local_item) if ($add);

		debug "Inventory: $local_item->{name} ($local_item->{invIndex}) x $local_item->{amount} - $itemTypes_lut{$local_item->{type}} - $equipTypes_lut{$local_item->{type_equip}}\n", "parseMsg";
		Plugins::callHook('packet_inventory', {index => $local_item->{invIndex}});
	}
	$ai_v{'inventory_time'} = time + 1;
	$ai_v{'cart_time'} = time + 1;
}

sub inventory_items_stackable {
	my ($self, $args) = @_;
	return unless changeToInGameState();



	my $newmsg;
	$self->decrypt(\$newmsg, substr($args->{RAW_MSG}, 4));
	my $msg = substr($args->{RAW_MSG}, 0, 4).$newmsg;

	my $unpack = $self->items_stackable($args);

	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += $unpack->{len}) {
		my ($item, $local_item, $add);

		@{$item}{@{$unpack->{keys}}} = unpack($unpack->{types}, substr($msg, $i, $unpack->{len}));

		unless($local_item = $char->inventory->getByServerIndex($item->{index})) {
			$local_item = new Actor::Item();
			$add = 1;
		}


		foreach (@{$unpack->{keys}}) {
			$local_item->{$_} = $item->{$_};
		}

		if (defined $char->{arrow} && $local_item->{index} == $char->{arrow}) {
			$local_item->{equipped} = 32768;
			$char->{equipment}{arrow} = $local_item;
		}
		$local_item->{name} = itemName($local_item);

		$char->inventory->add($local_item) if ($add);

		debug "Inventory: $local_item->{name} ($local_item->{invIndex}) x $local_item->{amount} - " .
			"$itemTypes_lut{$local_item->{type}}\n", "parseMsg";
		Plugins::callHook('packet_inventory', {index => $local_item->{invIndex}, item => $local_item});
	}
	$ai_v{'inventory_time'} = time + 1;
	$ai_v{'cart_time'} = time + 1;
}



sub storage_items_nonstackable {
	my ($self, $args) = @_;

	my $newmsg;
	$self->decrypt(\$newmsg, substr($args->{RAW_MSG}, 4));
	my $msg = substr($args->{RAW_MSG}, 0, 4).$newmsg;

	my $unpack = $self->items_nonstackable($args);

	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += $unpack->{len}) {
		my ($item, $local_item);

		@{$item}{@{$unpack->{keys}}} = unpack($unpack->{types}, substr($msg, $i, $unpack->{len}));

		binAdd(\@storageID, $item->{index});
		$local_item = $storage{$item->{index}} = Actor::Item->new;


		foreach (@{$unpack->{keys}}) {
			$local_item->{$_} = $item->{$_};
		}
		$local_item->{name} = itemName($local_item);
		$local_item->{amount} = 1;
		$local_item->{binID} = binFind(\@storageID, $item->{index});

		debug "Storage: $local_item->{name} ($local_item->{binID})\n", "parseMsg";
	}


}

sub storage_items_stackable {
	my ($self, $args) = @_;

	my $newmsg;
	$self->decrypt(\$newmsg, substr($args->{RAW_MSG}, 4));
	my $msg = substr($args->{RAW_MSG}, 0, 4).$newmsg;

	undef %storage;
	undef @storageID;

	my $unpack = $self->items_stackable($args);


	for (my $i = 4; $i < $args->{RAW_MSG_SIZE}; $i += $unpack->{len}) {
		my ($item, $local_item);

		@{$item}{@{$unpack->{keys}}} = unpack($unpack->{types}, substr($msg, $i, $unpack->{len}));

		binAdd(\@storageID, $item->{index});
		$local_item = $storage{$item->{index}} = Actor::Item->new;


		foreach (@{$unpack->{keys}}) {
			$local_item->{$_} = $item->{$_};
		}
		$local_item->{amount} = $local_item->{amount} & ~0x80000000;
		$local_item->{name} = itemName($local_item);
		$local_item->{binID} = binFind(\@storageID, $local_item->{index});
		$local_item->{identified} = 1;
		debug "Storage: $local_item->{name} ($local_item->{binID}) x $local_item->{amount}\n", "parseMsg";
	}
}

sub changeToInGameState {
	Network::Receive::changeToInGameState;
}

1;