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
#
#  $Revision: 6687 $
#  $Id: kRO.pm 6687 2009-04-19 19:04:25Z technologyguild $
########################################################################
# Korea (kRO)

package Network::Send::kRO;

use strict;

use base qw(Network::Send::ServerType0);
use Globals qw(%config %masterServers);
use Utils qw(getTickCount);
use Log qw(debug);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0436' => ['map_login', 'a4 a4 a4 V2 C', [qw(accountID charID sessionID unknown tick sex)]],#23
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		master_login 0ACF
		token_login 0825
		actor_action 0437
		item_use 0439
		skill_use 0438
		character_move 035F
		sync 0360
		actor_look_at 0361
		item_take 0362
		item_drop 0363
		storage_item_add 0364
		storage_item_remove 0365
		skill_use_location 0366
		actor_info_request 0368
		actor_name_request 0369
		buy_bulk_buyer 0819
		buy_bulk_request 0817
		buy_bulk_closeShop 0815
		buy_bulk_openShop 0811
		item_list_window_selected 07E4
		map_login 0436
		party_join_request_by_name 02C4
		friend_request 0202
		homunculus_command 022D
		storage_password 023B
		buy_bulk_vender 0801
		party_setting 07D7
		send_equip 0998
		pet_capture 08B5
		char_delete2_accept 098F
		rodex_open_mailbox 0AC0
		rodex_refresh_maillist 0AC1
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->{char_create_version} = 0x0A39;
	$self->{send_sell_buy_complete} = 1;

	$self->{send_buy_bulk_pack} = "v V";
	$self->{send_buy_bulk_market_pack} = "V2";

	$self->{buy_bulk_openShop_size} = "(a10)*";
	$self->{buy_bulk_openShop_size_unpack} = "V v V";

	$self->{buy_bulk_buyer_size} = "(a8)*";
	$self->{buy_bulk_buyer_size_unpack} = "a2 V v";

	return $self;
}

sub reconstruct_master_login {
	my ($self, $args) = @_;

	$args->{ip} = '192.168.0.2' unless exists $args->{ip}; # gibberish
	unless (exists $args->{mac}) {
	    $args->{mac} = $config{macAddress} || '111111111111'; # gibberish
	    $args->{mac} = uc($args->{mac});
	    $args->{mac_hyphen_separated} = join '-', $args->{mac} =~ /(..)/g;
	}
	$args->{isGravityID} = 0 unless exists $args->{isGravityID};

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

# 0x0436,23
sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	my $msg;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)

	#my $unknown = pack('C4', (0x90, 0x13, 0xE0, 0xE8));

	$msg = $self->reconstruct({
		switch => 'map_login',
		accountID => $accountID,
		charID => $charID,
		sessionID => $sessionID,
		unknown => 3906999184,# 90 13 E0 E8
		tick => getTickCount,
		sex => $sex,
	});

	$self->sendToServer($msg);
	debug "Sent sendMapLogin\n", "sendPacket", 2;
}

1;