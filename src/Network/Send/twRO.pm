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

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		# twRO related packets
		'0064' => ['master_login', 'V Z24 a24 C', [qw(version username password_rijndael master_version)]], 

		# Shuffle Packets
		'092A' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'093F' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'091C' => ['character_move', 'a3', [qw(coords)]],
		'0927' => ['sync', 'V', [qw(time)]],
		'094D' => ['actor_look_at', 'v C', [qw(head body)]],
		'08A5' => ['item_take', 'a4', [qw(ID)]],
		'0365' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'08AA' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'0887' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0879' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'088F' => ['actor_info_request', 'a4', [qw(ID)]],
		'0966' => ['actor_name_request', 'a4', [qw(ID)]],
		'0364' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]],
		'0875' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0950' => ['buy_bulk_closeShop'],
		'0936' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]],
		'08A2' => ['booking_register', 'v8', [qw(level MapID job0 job1 job2 job3 job4 job5)]],
		'0891' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0951' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'0965' => ['friend_request', 'a*', [qw(username)]],# len 26
		'087A' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'0811' => ['storage_password', 'v a*', [qw(type data)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 092A
		skill_use 093F
		character_move 091C
		sync 0927
		actor_look_at 094D
		item_take 08A5
		item_drop 0365
		storage_item_add 08AA
		storage_item_remove 0887
		skill_use_location 0879
		actor_info_request 088F
		actor_name_request 0966
		buy_bulk_buyer 0364
		buy_bulk_request 0875
		buy_bulk_closeShop 0950
		buy_bulk_openShop 0936
		item_list_window_selected 07E4
		map_login 0891
		party_join_request_by_name 0951
		friend_request 0965
		homunculus_command 087A
		storage_password 0811

		party_setting 07D7
		send_equip 0998
		pet_capture 08B5
		char_delete2_accept 098F
		char_create 0A39
		rodex_open_mailbox 0AC0
		rodex_refresh_maillist 0AC1
		buy_bulk_vender 0801		
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

1;
