# File contributed by #gaaradodesertoo, #cry1493, #matheus8666, #megafuji, #ovorei, #__codeplay, #roxleopardo, #freezing7
package Network::Send::ROla;

use strict;
use base qw(Network::Send::ServerType0);
use Globals qw($net %config);
use Utils qw(getTickCount);

use Log qw(debug);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0C26' => ['master_login', 'a4 Z51 a32 a5', [qw(game_code username password_rijndael flag)]],
		'0825' => ['token_login', 'v V C Z51 a17 a15 a*', [qw(len version master_version username mac_hyphen_separated ip token)]],
		'0436' => ['map_login', 'a4 a4 a4 V V C', [qw(accountID charID sessionID unknown tick sex)]],
		'0360' => ['sync', '', []],
		'0437' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0361' => ['actor_look_at', 'v', [qw(headDir)]],
		'009F' => ['item_take', 'a4', [qw(ID)]],
		'00A2' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0364' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'0365' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0366' => ['skill_use_location', 'v3', [qw(lv skillID x y)]],
		'0438' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'07E4' => ['item_list_window_selected', 'v v', [qw(index amount)]],
		'098F' => ['char_delete2_accept', 'a4 Z40 Z40 Z40', [qw(charID email1 email2 email3)]],
		'08B5' => ['pet_capture', 'a4', [qw(targetID)]],
		'0202' => ['friend_request', 'a*', [qw(username)]],
		'02C4' => ['party_join_request_by_name', 'Z24', [qw(playerName)]],
		'07D7' => ['party_setting', 'V', [qw(exp)]],
		'0811' => ['buy_bulk_openShop', 'v Z*', [qw(limit items)]],
		'0815' => ['buy_bulk_closeShop', '', []],
		'0817' => ['buy_bulk_request', 'a4 v', [qw(sellerID itemIndex)]],
		'0819' => ['buy_bulk_buyer', 'v2', [qw(itemID amount)]],
		'09F3' => ['rodex_request_items', 'C', [qw(option)]],
		'0AC0' => ['rodex_open_mailbox', '', []],
		'0AC1' => ['rodex_refresh_maillist', '', []],
		'09E9' => ['rodex_close_mailbox', '', []],
		'022D' => ['homunculus_command', 'C', [qw(command)]],
		'023B' => ['storage_password', 'v a*', [qw(type data)]],
		'096E' => ['merge_item_request', 'v a*', [qw(length itemList)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
	    master_login 0C26
	    token_login 0825
	    map_login 0436
	    char_create 0A39
	    map_loaded 007D
	    character_move 035F
	    sync 0360
	    actor_action 0437
	    actor_look_at 0361
	    item_take 0362
	    item_drop 0363
	    blocking_play_cancel 0447
	    storage_item_add 0364
	    storage_item_remove 0365
	    skill_use_location 0366
	    request_cashitems 08C9
	    skill_use 0438
	    actor_info_request 0368
	    item_list_window_selected 07E4
	    char_delete2_accept 098F
	    gameguard_reply 09D0
	    send_equip 0998
	    pet_capture 08B5
	    friend_request 0202
	    party_join_request_by_name 02C4
	    party_setting 07D7
	    buy_bulk_openShop 0811
	    buy_bulk_closeShop 0815
	    buy_bulk_request 0817
	    buy_bulk_buyer 0819
	    buy_bulk_vender 0801
	    rodex_open_mailbox 0AC0
	    rodex_refresh_maillist 0AC1
	    rodex_close_mailbox 09E9
	    rodex_request_items 09F3
	    homunculus_command 022D
	    storage_password 023B
		itemList 096E
		sell_buy_complete 09D4
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	$self->{send_buy_bulk_pack} = "v V";
	$self->{char_create_version} = 0x0A39;
	$self->{send_sell_buy_complete} = 1;

	$self->{buy_bulk_openShop_size} = "(a10)*";
	$self->{buy_bulk_openShop_size_unpack} = "V v V";
	$self->{buy_bulk_buyer_size} = "(a8)*";
	$self->{buy_bulk_buyer_size_unpack} = "a2 V v";
	return $self;
}

sub reconstruct_master_login {
	my ($self, $args) = @_;

	if (exists $args->{password}) {
		for (Digest::MD5->new) {
			$_->add($args->{password});
			$args->{password_md5} = $_->clone->digest;
			$args->{password_md5_hex} = $_->hexdigest;
		}

		my $key = pack('C32', (0x06, 0xA9, 0x21, 0x40, 0x36, 0xB8, 0xA1, 0x5B, 0x51, 0x2E, 0x03, 0xD5, 0x34, 0x12, 0x00, 0x06, 0x06, 0xA9, 0x21, 0x40, 0x36, 0xB8, 0xA1, 0x5B, 0x51, 0x2E, 0x03, 0xD5, 0x34, 0x12, 0x00, 0x06));
		my $chain = pack('C32', (0x3D, 0xAF, 0xBA, 0x42, 0x9D, 0x9E, 0xB4, 0x30, 0xB4, 0x22, 0xDA, 0x80, 0x2C, 0x9F, 0xAC, 0x41, 0x3D, 0xAF, 0xBA, 0x42, 0x9D, 0x9E, 0xB4, 0x30, 0xB4, 0x22, 0xDA, 0x80, 0x2C, 0x9F, 0xAC, 0x41));
		my $in = pack('a32', $args->{password});
		my $rijndael = Utils::Rijndael->new;
		$rijndael->MakeKey($key, $chain, 32, 32);
		$args->{password_rijndael} = $rijndael->Encrypt($in, undef, 32, 0);
	}
}

sub sendTokenToServer {
    my ($self, $username, $password, $master_version, $version, $token, $length, $otp_ip, $otp_port) = @_;
    my $len = $length + 92;

    my $ip = '192.168.0.2';
    my $mac = $config{macAddress} || sprintf("%02x%02x%02x%02x%02x%02x", (int(rand(256)) & 0xFC) | 0x02, map { int(rand(256)) } 1..5);
    my $mac_hyphen_separated = join '-', $mac =~ /(..)/g;

    $net->serverDisconnect();
    $net->serverConnect($otp_ip, $otp_port);

    my $msg = $self->reconstruct({
        switch => 'token_login',
        len => $len,
        version => $version || $self->version,
        master_version => $master_version,
        username => $username,
        mac_hyphen_separated => $mac_hyphen_separated,
        ip => $ip,
        token => $token,
    });

    $self->sendToServer($msg);

    debug "Sent sendTokenLogin\n", "sendPacket", 2;
}

sub add_checksum {
	my ($self, $msg) = @_;

	my $crc = 0x00;
	for my $byte (unpack('C*', $msg)) {
		$crc ^= $byte;
		for (1..8) {
			if ($crc & 0x80) {
				$crc = (($crc << 1) ^ 0x07) & 0xFF;
			} else {
				$crc = ($crc << 1) & 0xFF;
			}
		}
	}

	# Anexa o checksum ao final da mensagem
	$msg .= pack('C', $crc);
	return $msg;
}

sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	my $msg;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)

	my $msg = $self->reconstruct({
		switch		=> 'map_login',
		accountID	=> $accountID,
		charID		=> $charID,
		sessionID	=> $sessionID,
		unknown		=> 4011065369,# 19 00 14 EF
		tick		=> getTickCount,
		sex			=> $sex,
	});

	$msg = $self->add_checksum($msg);
	$self->sendToServer($msg);

	debug "Sent sendMapLogin\n", "sendPacket", 2;
}

1;
