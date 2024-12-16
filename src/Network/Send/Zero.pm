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
# Korea (kRO)
# by alisonrag / sctnightcore

package Network::Send::Zero;

use strict;
use base qw(Network::Send::ServerType0);
use Globals qw(%config %masterServers);
use Utils qw(getTickCount);
use Log qw(debug);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

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

sub sendMasterLogin {
	my ($self, $username, $password, $master_version, $version) = @_;

	my $accessToken = $config{accessToken};
	my $len =  length($accessToken) + 92;
	my $master = $masterServers{$config{master}};

	die "don't forget to add kRO_auth plugin to sys.txt\n".
		"https://openkore.com/wiki/loadPlugins_list\n" unless ($accessToken);

	$self->sendTokenToServer($username, $password, $master_version, $version, $accessToken, $len, $master->{OTP_ip}, $master->{OTP_port});
}

# 0x0436,23
sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	my $msg;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)

	#my $unknown = pack('C4', (0xCF, 0x00, 0x2A, 0x70));

	$msg = $self->reconstruct({
		switch => 'map_login',
		accountID => $accountID,
		charID => $charID,
		sessionID => $sessionID,
		unknown => 1881800911,# CF 00 2A 70 
		tick => getTickCount,
		sex => $sex,
	});

	$self->sendToServer($msg);
	debug "Sent sendMapLogin\n", "sendPacket", 2;
}

1;