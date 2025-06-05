# File contributed by #gaaradodesertoo, #cry1493, #cry1493, #matheus8666, #megafuji, #ovorei, #__codeplay
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
		'0437' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0094' => ['actor_info_request', 'a4', [qw(ID)]],
		'009B' => ['actor_look_at', 'v C', [qw(head body)]],
		'035F' => ['character_move', 'a3', [qw(coords)]],
		'00A2' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'07E4' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'009F' => ['item_take', 'a4', [qw(ID)]],
		'00A7' => ['item_use', 'a2 a4', [qw(ID targetID)]],
		'0436' => ['map_login', 'a4 a4 a4 V V C', [qw(accountID charID sessionID unknown tick sex)]],
		'0C26' => ['master_login', 'a4 Z51 a32 a5', [qw(game_code username password_rijndael flag)]],
		'023B' => ['storage_password', 'v a*', [qw(type data)]],
		'0360' => ['sync', 'V', [qw(time)]],
		'0825' => ['token_login', 'v V C Z51 a17 a15 a*', [qw(len version master_version username mac_hyphen_separated ip token)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 0437
		actor_info_request 0368
		actor_look_at 0361
		actor_name_request 0369
		character_move 035F
		item_drop 0363
		item_list_window_selected 07E4
		item_take 0362
		map_login 0436
		master_login 0C26
		storage_password 023B
		sync 0360
		token_login 0825
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
