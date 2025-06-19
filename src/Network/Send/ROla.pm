package Network::Send::ROla;
use strict;
use base    qw(Network::Send::ServerType0);
use Globals qw($net %config);
use Utils   qw(getTickCount);
use Log     qw(debug);

# Tabela checksumTable
my @checksumTable = (
	0x00, 0x07, 0x0E, 0x09, 0x1C, 0x1B, 0x12, 0x15, 0x38, 0x3F, 0x36, 0x31, 0x24, 0x23, 0x2A, 0x2D, 0x70, 0x77, 0x7E, 0x79, 0x6C, 0x6B, 0x62, 0x65, 0x48, 0x4F, 0x46, 0x41, 0x54, 0x53, 0x5A, 0x5D, 0xE0, 0xE7, 0xEE, 0xE9, 0xFC, 0xFB, 0xF2, 0xF5, 0xD8, 0xDF, 0xD6, 0xD1, 0xC4, 0xC3, 0xCA, 0xCD, 0x90, 0x97, 0x9E, 0x99, 0x8C, 0x8B, 0x82, 0x85, 0xA8, 0xAF, 0xA6, 0xA1, 0xB4, 0xB3, 0xBA, 0xBD,
	0xC7, 0xC0, 0xC9, 0xCE, 0xDB, 0xDC, 0xD5, 0xD2, 0xFF, 0xF8, 0xF1, 0xF6, 0xE3, 0xE4, 0xED, 0xEA, 0xB7, 0xB0, 0xB9, 0xBE, 0xAB, 0xAC, 0xA5, 0xA2, 0x8F, 0x88, 0x81, 0x86, 0x93, 0x94, 0x9D, 0x9A, 0x27, 0x20, 0x29, 0x2E, 0x3B, 0x3C, 0x35, 0x32, 0x1F, 0x18, 0x11, 0x16, 0x03, 0x04, 0x0D, 0x0A, 0x57, 0x50, 0x59, 0x5E, 0x4B, 0x4C, 0x45, 0x42, 0x6F, 0x68, 0x61, 0x66, 0x73, 0x74, 0x7D, 0x7A,
	0x89, 0x8E, 0x87, 0x80, 0x95, 0x92, 0x9B, 0x9C, 0xB1, 0xB6, 0xBF, 0xB8, 0xAD, 0xAA, 0xA3, 0xA4, 0xF9, 0xFE, 0xF7, 0xF0, 0xE5, 0xE2, 0xEB, 0xEC, 0xC1, 0xC6, 0xCF, 0xC8, 0xDD, 0xDA, 0xD3, 0xD4, 0x69, 0x6E, 0x67, 0x60, 0x75, 0x72, 0x7B, 0x7C, 0x51, 0x56, 0x5F, 0x58, 0x4D, 0x4A, 0x43, 0x44, 0x19, 0x1E, 0x17, 0x10, 0x05, 0x02, 0x0B, 0x0C, 0x21, 0x26, 0x2F, 0x28, 0x3D, 0x3A, 0x33, 0x34,
	0x4E, 0x49, 0x40, 0x47, 0x52, 0x55, 0x5C, 0x5B, 0x76, 0x71, 0x78, 0x7F, 0x6A, 0x6D, 0x64, 0x63, 0x3E, 0x39, 0x30, 0x37, 0x22, 0x25, 0x2C, 0x2B, 0x06, 0x01, 0x08, 0x0F, 0x1A, 0x1D, 0x14, 0x13, 0xAE, 0xA9, 0xA0, 0xA7, 0xB2, 0xB5, 0xBC, 0xBB, 0x96, 0x91, 0x98, 0x9F, 0x8A, 0x8D, 0x84, 0x83, 0xDE, 0xD9, 0xD0, 0xD7, 0xC2, 0xC5, 0xCC, 0xCB, 0xE6, 0xE1, 0xE8, 0xEF, 0xFA, 0xFD, 0xF4, 0xF3
);

# checksum
my $checksumSeed = 0;
my $addChecksum  = 0;

sub new {
	my ( $class ) = @_;
	my $self = $class->SUPER::new( @_ );

	my %packets = (
		'0C26' => [ 'master_login', 'a4 Z51 a32 a5',        [qw(game_code username password_rijndael flag)] ],
		'0825' => [ 'token_login',  'v V C Z51 a17 a15 a*', [qw(len version master_version username mac_hyphen_separated ip token)] ],
		'0436' => [ 'map_login',    'a4 a4 a4 V V C',       [qw(accountID charID sessionID unknown tick sex)] ],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		token_login 0825
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
		send_equip 0998
		skill_use 0438
		skill_use_location 0366
		storage_item_add 0364
		storage_item_remove 0365
		storage_password 023B
		sync 0360
		master_login 0C26
		rodex_open_mailbox 0AC0
		rodex_refresh_maillist 0AC1
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->{char_create_version}       = 0x0A39;
	$self->{send_buy_bulk_pack}        = "v V";
	$self->{char_create_version}       = 0x0A39;
	$self->{send_sell_buy_complete}    = 1;
	$self->{send_buy_bulk_market_pack} = "V2";

	# buyer shop
	$self->{buy_bulk_openShop_size}        = "(a10)*";
	$self->{buy_bulk_openShop_size_unpack} = "V v V";

	$self->{buy_bulk_buyer_size}        = "(a8)*";
	$self->{buy_bulk_buyer_size_unpack} = "a2 V v";

	return $self;
}

sub reconstruct_master_login {
	my ( $self, $args ) = @_;

	if ( exists $args->{password} ) {
		for ( Digest::MD5->new ) {
			$_->add( $args->{password} );
			$args->{password_md5}     = $_->clone->digest;
			$args->{password_md5_hex} = $_->hexdigest;
		}

		my $key      = pack( 'C32', ( 0x06, 0xA9, 0x21, 0x40, 0x36, 0xB8, 0xA1, 0x5B, 0x51, 0x2E, 0x03, 0xD5, 0x34, 0x12, 0x00, 0x06, 0x06, 0xA9, 0x21, 0x40, 0x36, 0xB8, 0xA1, 0x5B, 0x51, 0x2E, 0x03, 0xD5, 0x34, 0x12, 0x00, 0x06 ) );
		my $chain    = pack( 'C32', ( 0x3D, 0xAF, 0xBA, 0x42, 0x9D, 0x9E, 0xB4, 0x30, 0xB4, 0x22, 0xDA, 0x80, 0x2C, 0x9F, 0xAC, 0x41, 0x3D, 0xAF, 0xBA, 0x42, 0x9D, 0x9E, 0xB4, 0x30, 0xB4, 0x22, 0xDA, 0x80, 0x2C, 0x9F, 0xAC, 0x41 ) );
		my $in       = pack( 'a32', $args->{password} );
		my $rijndael = Utils::Rijndael->new;
		$rijndael->MakeKey( $key, $chain, 32, 32 );
		$args->{password_rijndael} = $rijndael->Encrypt( $in, undef, 32, 0 );
	}
}

sub sendTokenToServer {
	my ( $self, $username, $password, $master_version, $version, $token, $length, $otp_ip, $otp_port ) = @_;
	my $len = $length + 92;

	$net->serverDisconnect();
	$net->serverConnect( $otp_ip, $otp_port );

	my $ip                   = sprintf("192.168.%02d.%02d", (map { int(rand(255)) } 1..2));
	my $mac                  = $config{macAddress} || sprintf("E0311E%02X%02X%02X", (map { int(rand(256)) } 1..3));
	my $mac_hyphen_separated = join '-', $mac =~ /(..)/g;

	my $msg = $self->reconstruct(
		{
			switch               => 'token_login',
			len                  => $len,
			version              => $version || $self->version,
			master_version       => $master_version,
			username             => $username,
			mac_hyphen_separated => $mac_hyphen_separated,
			ip                   => $ip,
			token                => $token,
		}
	);

	$self->sendToServer( $msg );

	debug "Sent sendTokenLogin\n", "sendPacket", 2;
}

sub sendMapLogin {
	my ( $self, $accountID, $charID, $sessionID, $sex ) = @_;
	my $msg;
	$sex = 0 if ( $sex > 1 || $sex < 0 );    # Sex can only be 0 (female) or 1 (male)

	my $msg = $self->reconstruct(
		{
			switch    => 'map_login',
			accountID => $accountID,
			charID    => $charID,
			sessionID => $sessionID,
			unknown   => 4011065369,
			tick      => getTickCount,
			sex       => $sex,
		}
	);

	$self->sendToServer( $msg );

	debug "Sent sendMapLogin\n", "sendPacket", 2;
}

sub initChecksum {
	debug( "CheckSum initialized\n", "system" );
	$addChecksum  = 1;
	$checksumSeed = 0;
}

sub resetChecksum {
	debug( "CheckSum reseted\n", "system" );
	$addChecksum  = 0;
	$checksumSeed = 0;
}

sub sendToServer {
	my ( $self, $msg ) = @_;

	my $messageID = unpack( "v", $msg );

	if ( $addChecksum ) {

		# calculate checksum
		my $checksum = $self->calculate_checksum( $msg );

		# add checksum to packet
		$msg .= pack( 'C', $checksum );
		debug "Sent packet [" . ( sprintf( "%04X", $messageID ) ) . "] with checksum [seed my " . ( $checksumSeed - 1 ) . "] : 0x" . sprintf( "%02X", $checksum ) . "\n", "sendPacket";
	} else {
		debug "Sent packet [" . ( sprintf( "%04X", $messageID ) ) . "] without checksum\n", "sendPacket";
	}

	$self->SUPER::sendToServer( $msg );
}

# calculate checksum
sub calculate_checksum {
	my ( $self, $buffer ) = @_;

	my $key = $checksumSeed;

	# extract bytes
	my $byte0 = $key & 0xFF;
	my $byte1 = ( $key >> 8 ) & 0xFF;
	my $byte2 = ( $key >> 16 ) & 0xFF;
	my $byte3 = ( $key >> 24 ) & 0xFF;

	# calculate seed value
	my $xorValue = $checksumTable[$byte0] & 0xFF;
	$xorValue = $checksumTable[ $byte1 ^ $xorValue ] & 0xFF;
	$xorValue = $checksumTable[ $byte2 ^ $xorValue ] & 0xFF;
	$xorValue = $checksumTable[ $byte3 ^ $xorValue ] & 0xFF;

	# calculate checksum
	for my $i ( 0 .. length( $buffer ) - 1 ) {
		my $byte = ord( substr( $buffer, $i, 1 ) );
		$xorValue = $checksumTable[ $xorValue ^ $byte ];
	}

	# increment seed
	$checksumSeed++;

	return $xorValue & 0xFF;
}

1;
