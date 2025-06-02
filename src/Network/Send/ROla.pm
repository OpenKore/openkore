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
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
        master_login 0C26
        map_loaded 007D
        character_move 035F
        master_login 0C26
        token_login 0825
        char_create 0A39
        map_login 0436
        actor_action 0437
        blocking_play_cancel 0447
        request_cashitems 08C9
        sync 0360
        actor_look_at 0361
        item_take 0362
        item_drop 0363
        actor_info_request 0368
        rodex_request_items 09F3
        rodex_open_mailbox 0AC0
        rodex_close_mailbox 09E9
        rodex_refresh_maillist 0AC1
        gameguard_reply 09D0
    );

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->{char_create_version} = 0x0A39;
	
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
	my $len =  $length + 92;

	$net->serverDisconnect();
	$net->serverConnect($otp_ip, $otp_port);

	my $ip = '192.168.0.2';
	my $mac = $config{macAddress} || '111111111111'; # gibberish
	my $mac_hyphen_separated = join '-', $mac =~ /(..)/g;

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

	my $crcCheckSum = 0x00;
	for my $byte (unpack('C*', $msg)) {
		$crcCheckSum ^= $byte;
		for (1..8) {
			if ($crcCheckSum & 0x80) {
				$crcCheckSum = (($crcCheckSum << 1) ^ 0x07) & 0xFF;
			} else {
				$crcCheckSum = ($crcCheckSum << 1) & 0xFF;
			}
		}
	}

	$msg .= pack('C', $crcCheckSum);
	$self->sendToServer($msg);

	debug "Sent sendMapLogin\n", "sendPacket", 2;
}

1;