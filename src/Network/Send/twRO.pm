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
# twRO (Taiwan)

package Network::Send::twRO;

use strict;
use base qw(Network::Send::ServerType0);
use Log qw(debug);
use Utils qw(getTickCount);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		# twRO related packets
		'0064' => ['master_login', 'V Z24 a24 C', [qw(version username password_rijndael master_version)]],
		'0436' => ['map_login', 'a4 a4 a4 V2 C', [qw(accountID charID sessionID unknown tick sex)]],#23
		'01AE' => ['make_arrow', 'V', [qw(nameID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 0437
		actor_info_request 0368
		actor_look_at 0361
		actor_name_request 0369
		buy_bulk_buyer 0819
		buy_bulk_closeShop 0815
		buy_bulk_openShop 0811
		buy_bulk_request 0817
		buy_bulk_vender 0801
		char_create 0A39
		char_delete2_accept 098F
		character_move 035F
		friend_request 0202
		homunculus_command 022D
		item_drop 0363
		item_list_window_selected 07E4
		item_take 0362
		map_login 0436
		party_join_request_by_name 02C4
		party_setting 07D7
		pet_capture 08B5
		rodex_open_mailbox 0AC0
		rodex_refresh_maillist 0AC1
		send_equip 0998
		skill_use 0438
		skill_use_location 0AF4
		storage_item_add 0364
		storage_item_remove 0365
		storage_password 023B
		sync 0360
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->{send_buy_bulk_pack} = "v V";
	$self->{char_create_version} = 0x0A39;
	$self->{send_sell_buy_complete} = 1;
	$self->{send_buy_bulk_market_pack} = "V2";

	#buyer shop
	$self->{buy_bulk_openShop_size} = "(a10)*";
	$self->{buy_bulk_openShop_size_unpack} = "V v V";

	$self->{buy_bulk_buyer_size} = "(a8)*";
	$self->{buy_bulk_buyer_size_unpack} = "a2 V v";

	return $self;
}

sub parse_master_login {
	my ($self, $args) = @_;

	if (exists $args->{password_md5_hex}) {
		$args->{password_md5} = pack 'H*', $args->{password_md5_hex};
	}

	if (exists $args->{password_rijndael}) {
		my $key = pack('C24', (0x06, 0xA9, 0x21, 0x40, 0x36, 0xB8, 0xA1, 0x5B, 0x51, 0x2E, 0x03, 0xD5, 0x34, 0x12, 0x00, 0x06, 0x06, 0xA9, 0x21, 0x40, 0x36, 0xB8, 0xA1, 0x5B));
		my $chain = pack('C24', (0x3D, 0xAF, 0xBA, 0x42, 0x9D, 0x9E, 0xB4, 0x30, 0xB4, 0x22, 0xDA, 0x80, 0x2C, 0x9F, 0xAC, 0x41, 0x3D, 0xAF, 0xBA, 0x42, 0x9D, 0x9E, 0xB4, 0x30));
		my $in = pack('a24', $args->{password_rijndael});
		my $rijndael = Utils::Rijndael->new;
		$rijndael->MakeKey($key, $chain, 24, 24);
		$args->{password} = unpack("Z24", $rijndael->Decrypt($in, undef, 24, 0));
	}
}

sub reconstruct_master_login {
	my ($self, $args) = @_;

	$args->{ip} = '192.168.0.2' unless exists $args->{ip}; # gibberish

	if (exists $args->{password}) {
		for (Digest::MD5->new) {
			$_->add($args->{password});
			$args->{password_md5} = $_->clone->digest;
			$args->{password_md5_hex} = $_->hexdigest;
		}

		my $key = pack('C24', (0x06, 0xA9, 0x21, 0x40, 0x36, 0xB8, 0xA1, 0x5B, 0x51, 0x2E, 0x03, 0xD5, 0x34, 0x12, 0x00, 0x06, 0x06, 0xA9, 0x21, 0x40, 0x36, 0xB8, 0xA1, 0x5B));
		my $chain = pack('C24', (0x3D, 0xAF, 0xBA, 0x42, 0x9D, 0x9E, 0xB4, 0x30, 0xB4, 0x22, 0xDA, 0x80, 0x2C, 0x9F, 0xAC, 0x41, 0x3D, 0xAF, 0xBA, 0x42, 0x9D, 0x9E, 0xB4, 0x30));
		my $in = pack('a24', $args->{password});
		my $rijndael = Utils::Rijndael->new;
		$rijndael->MakeKey($key, $chain, 24, 24);
		$args->{password_rijndael} = $rijndael->Encrypt($in, undef, 24, 0);
	}
}

# 0x0436,23
sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	my $msg;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)

	#my $unknown = pack('C4', (0x29, 0xF0, 0x40, 0x01));

	$msg = $self->reconstruct({
		switch => 'map_login',
		accountID => $accountID,
		charID => $charID,
		sessionID => $sessionID,
		unknown => 21033001,# 29 F0 40 01
		tick => getTickCount,
		sex => $sex,
	});

	$self->sendToServer($msg);
	debug "Sent sendMapLogin\n", "sendPacket", 2;
}

1;
