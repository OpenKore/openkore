#########################################################################
#  OpenKore - Packet sending
#  This module contains functions for sending packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
########################################################################
#  by alisonrag
package Network::Send::kRO::RagexeRE_2021_11_03;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2020_07_23);
use Log qw(debug);
use Time::HiRes qw(time);
use Globals qw(%timeout $masterServer);
use I18N qw(stringToBytes);
use Lastro::Airship qw(isEnabled normalizeMapName);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		# 2021 RE CH_ENTER carries userLevel as a 32-bit value and clientType
		# as a 16-bit value.  The second 32-bit field remains the auth/session
		# code consumed by the XKore2 character server.
		'0065' => ['game_login', 'a4 a4 V v C', [qw(accountID sessionID userLevel clientType accountSex)]],
		'0436' => ['map_login', 'a4 a4 a4 V2 C', [qw(accountID charID sessionID unknown tick sex)]],#23
		'0AFA' => ['check_bin', 'V a4', [qw(AID pinCode)]], #10
	);
	$packets{'0A49'} = ['private_airship_request', 'Z16 V4', [qw(map_name x y type nameID)]]
		if isEnabled($masterServer); #34

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	# Ordinary Lastro NPC shops do not use the inherited completion packets.
	# Lastro market shops use CZ_NPC_MARKET_CLOSE through the market code path.
	$self->{send_sell_buy_complete} = 0;
	$self->{send_buy_bulk_market_pack} = 'V2';

	return $self;
}

# 0x0065,17.  Keep the public OpenKore call signature used by the login
# handoff, but map its legacy third argument to the modern user-level field.
# The 2021 RE client also requires an explicit client type in this packet.
sub sendGameLogin {
	my ($self, $accountID, $sessionID, $userLevel, $sex) = @_;
	# DirectConnection keeps the account-server fields as raw a4 values,
	# while modern CZ_ENTER packs userLevel as a numeric V field.
	$userLevel = unpack('V', $userLevel)
		if defined $userLevel && !ref($userLevel) && length($userLevel) == 4;

	$self->sendToServer($self->reconstruct({
		switch => 'game_login',
		accountID => $accountID,
		sessionID => $sessionID,
		userLevel => $userLevel,
		clientType => $masterServer && defined $masterServer->{clientType}
			? $masterServer->{clientType}
			: 0,
		accountSex => $sex,
	}));
	debug "Sent sendGameLogin\n", "sendPacket", 2;
}

# 0x0436,23
sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	my $msg;
	$timeout{ai_sync}{timeout} = 15;
	$timeout{ai_sync}{time} = time;
	$timeout{ai_move_retry}{timeout} = 0.5;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)

	$msg = $self->reconstruct({
		switch => 'map_login',
		accountID => $accountID,
		charID => $charID,
		sessionID => $sessionID,
		unknown => 0,# 00 00 00 00
		# The web client leaves the reserved/client-time area zeroed.
		tick => 0,
		sex => $sex,
	});

	$self->sendToServer($msg);
	debug "Sent sendMapLogin\n", "sendPacket", 2;
}

sub sendMapLoaded {
	my $self = shift;

	$self->SUPER::sendMapLoaded(@_);
	# ClientVer 3 sends this fixed two-byte initialization packet after
	# CZ_NOTIFY_ACTORINIT.  0AFF is variable-length in the receive table, so
	# construct it directly to avoid adding a length field.
	$self->sendToServer(pack('v', 0x0AFF));
}

# CZ_PC_PURCHASE_ITEMLIST is a variable-length packet.  The web client uses
# a 32-bit item ID, so every entry is six bytes: count(u16), item ID(u32).
sub sendBuyBulk {
	my ($self, $items) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'buy_bulk',
		len => 4 + scalar(@{$items}) * 6,
		items => $items,
	}));

	debug("Sent bulk buy: $_->{itemID} x $_->{amount}\n", "sendPacket", 2) foreach (@{$items});
}

sub sendSync {
	my ($self, $initialSync) = @_;

	# The web client starts its 15-second ping timer after entering the map;
	# it does not send the immediate sync that OpenKore normally emits here.
	return if $initialSync;
	$self->SUPER::sendSync($initialSync);
}

sub sendGuildRequestInfo {
	# The web client does not request guild information during map entry.
	return;
}

sub sendBlockingPlayerCancel {
	# The inherited receiver enables this rAthena compatibility packet, but the
	# Lastro web client does not emit it on either map-entry callback.
	return;
}

# The Lastro web client toggles server-side follow battle with
# CZ_NOTIFY_UPDATEINFO: setting ID 37 and a constant action value of one.
# The server reports the actual state through ZC_NOTIFY_RELOADINFOS.
sub sendLastroAutoFollow {
	my ($self) = @_;
	return unless $masterServer && $masterServer->{lastroAutoFollow};

	$self->sendToServer(pack('v C V', 0x0AFE, 37, 1));
}

# The browser's CZ_PRIVATE_AIRSHIP_REQUEST is 34 bytes, unlike the legacy
# 20-byte kRO request: map name, x, y, type and item ID.  World-map transfers
# leave x/y/type at zero and use 14527 as the server-side transfer selector.
sub sendPrivateAirshipRequest {
	my ($self, $map_name, $nameID) = @_;
	return $self->SUPER::sendPrivateAirshipRequest($map_name, $nameID)
		unless isEnabled($masterServer);

	$map_name = normalizeMapName($map_name);
	$nameID = 14527 unless defined $nameID;

	# The inherited recvpackets table describes the legacy 22-byte packet and
	# would truncate this browser-specific 34-byte outbound request.
	$self->sendToServer(pack('v Z16 V4',
		0x0A49,
		stringToBytes($map_name),
		0,
		0,
		0,
		$nameID,
	));
}

sub sendCheckBin {
	my ($self, $AID, $pincode) = @_;
	my @permutation = (0 .. 9);

	# Mirrors the web client's SECOND_CHECK handler exactly.
	for my $index (1 .. 9) {
		$pincode = 4 + 2 * $pincode;
		my $swap = $pincode % ($index + 1);
		@permutation[$index, $swap] = @permutation[$swap, $index] if $index != $swap;
	}

	my $pinCode = '';
	for my $digit (split //, substr($AID, -4)) {
		for my $index (0 .. $#permutation) {
			$pinCode .= $index if $digit == $permutation[$index];
		}
	}

	# 0AFA is also a 58-byte server-to-client packet in LastRO's receive
	# table.  Do not use reconstruct(): it pads outbound CHECK_BIN to that
	# unrelated receive length.  The browser always writes exactly these 10
	# bytes: switch, AID, then the four-character response.
	$self->sendToServer(pack('v V a4', 0x0AFA, $AID, $pinCode));
}

# 0096 is a 4-byte ZC.UNK1 packet in LastRO's receive table, but CZ.WHISPER
# uses the same switch in the opposite direction and is variable-length.
# Construct the browser frame directly so reconstruct() cannot truncate it.
sub sendPrivateMsg {
	my ($self, $user, $message) = @_;
	$message = '|00' . $message if $masterServer->{chatLangCode};
	$message = stringToBytes($message);
	$user = stringToBytes($user);

	$self->sendToServer(pack('v v a24 Z*',
		0x0096,
		29 + length($message),
		$user,
		$message,
	));
}

1;
