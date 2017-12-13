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
#bysctnightcore
package Network::Send::Zero;

use strict;
use base qw(Network::Send::ServerType0);
use Globals; 
use Network::Send::ServerType0;
use Log qw(error debug message);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'08AC' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0941' => ['actor_info_request', 'a4', [qw(ID)]],
		'0862' => ['actor_look_at', 'v C', [qw(head body)]],
		'0885' => ['actor_name_request', 'a4', [qw(ID)]],
		'087B' => ['buy_bulk_buyer', 'a4 a4 a*', [qw(buyerID buyingStoreID itemInfo)]], #Buying store
		'0934' => ['buy_bulk_closeShop'],
		'08A4' => ['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]], #Selling store
		'0436' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0864' => ['character_move', 'a3', [qw(coords)]],
		'0893' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0897' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],
		'0366' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'093A' => ['item_list_res', 'v V2 a*', [qw(len type action itemInfo)]],
		'0835' => ['item_take', 'a4', [qw(ID)]],
		'0920' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'088D' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'0281' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0878' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0870' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'0936' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0959' => ['storage_password'],
		'095F' => ['sync', 'V', [qw(time)]],
		'0ACF' => ['master_login', 'a4 Z25 a32 a5', [qw(game_code username password_rijndael flag)]],
		'0825' => ['token_login', 'v v x v Z24 a27 Z17 Z15 a*', [qw(len version master_version username password_rijndael mac ip token)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		master_login 0ACF
		actor_action 08AC
		actor_info_request 0941
		actor_look_at 0862
		actor_name_request 0885
		buy_bulk_buyer 087B
		buy_bulk_closeShop 0934
		buy_bulk_openShop 08A4
		buy_bulk_request 0436
		character_move 0864
		friend_request 0893
		homunculus_command 0897
		item_drop 0366
		item_list_res 093A
		item_take 0835
		map_login 0920
		party_join_request_by_name 088D
		skill_use 0281
		skill_use_location 0878
		storage_item_add 0870
		storage_item_remove 0936
		storage_password 0959
		sync 095F
	);

	while (my ($k, $v) = each %packets) { $handlers{$v->[0]} = $k}

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

sub sendMasterLogin {
	my ($self, $username, $password, $master_version, $version) = @_;
	my $msg;
	my $password_rijndael = $self->encrypt_password($password);

	$msg = $self->reconstruct({
		switch => 'master_login',
		game_code => '0036', # kRO Ragnarok game code
		username => $username,
		password_rijndael => $password_rijndael,
		flag => 'G000', # Maybe this say that we are connecting from client
	});

	$self->sendToServer($msg);
	debug "Sent sendMasterLogin\n", "sendPacket", 2;
}

sub sendTokenToServer {
	my ($self, $username, $password, $master_version, $version, $token, $length, $ott_ip, $ott_port) = @_;
	my $len =  $length + 92;

	my $password_rijndael = $self->encrypt_password($password);
	my $ip = '192.168.0.14';
	my $mac = '20CF3095572A';
	my $mac_hyphen_separated = join '-', $mac =~ /(..)/g;

	$net->serverConnect($ott_ip, $ott_port);

	my $msg = $self->reconstruct({
		switch => 'token_login',
		len => $len, # size of packet
		version => $version,
		master_version => $master_version,
		username => $username,
		password_rijndael => '',
		mac => $mac_hyphen_separated,
		ip => $ip,
		token => $token,
	});	
	
	$self->sendToServer($msg);

	debug "Sent sendTokenLogin\n", "sendPacket", 2;
}

sub encrypt_password {
	my ($self, $password) = @_;
	my $password_rijndael;
	if (defined $password) {
		my $key = pack('C32', (0x06, 0xA9, 0x21, 0x40, 0x36, 0xB8, 0xA1, 0x5B, 0x51, 0x2E, 0x03, 0xD5, 0x34, 0x12, 0x00, 0x06, 0x06, 0xA9, 0x21, 0x40, 0x36, 0xB8, 0xA1, 0x5B, 0x51, 0x2E, 0x03, 0xD5, 0x34, 0x12, 0x00, 0x06));
		my $chain = pack('C32', (0x3D, 0xAF, 0xBA, 0x42, 0x9D, 0x9E, 0xB4, 0x30, 0xB4, 0x22, 0xDA, 0x80, 0x2C, 0x9F, 0xAC, 0x41, 0x3D, 0xAF, 0xBA, 0x42, 0x9D, 0x9E, 0xB4, 0x30, 0xB4, 0x22, 0xDA, 0x80, 0x2C, 0x9F, 0xAC, 0x41));
		my $in = pack('a32', $password);
		my $rijndael = Utils::Rijndael->new;
		$rijndael->MakeKey($key, $chain, 32, 32);
		$password_rijndael = unpack("Z32", $rijndael->Encrypt($in, undef, 32, 0));
		return $password_rijndael;
	} else {
		error("Password is not configured");
	}
}

1;
