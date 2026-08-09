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
#  by sctnightcore
package Network::Send::kRO::RagexeRE_2020_03_04a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2018_11_21);
use Utils::Rijndael;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0064' => ['token_login', 'V Z24 Z24 C', [qw(version username password master_version)]], # 55
		'0ACF' => ['master_login', 'a4 Z25 a32 a5', [qw(game_code username password_rijndael flag)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		master_login 0ACF
		token_login 0064
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->{char_create_version} = 0x0A39;

	#buyer shop
	$self->{buy_bulk_openShop_size} = "(a10)*";
	$self->{buy_bulk_openShop_size_unpack} = "V v V";

	$self->{buy_bulk_buyer_size} = "(a8)*";
	$self->{buy_bulk_buyer_size_unpack} = "a2 V v";

	$self->{send_buy_bulk_pack} = "v V";
	$self->{send_sell_buy_complete} = 1;

	return $self;
}

# 0ACF uses a 32-byte Rijndael block. The generic master-login parser uses
# the older 24-byte variant, so modern clients need a packet-specific parser.
sub parse_master_login {
	my ($self, $args) = @_;

	return unless exists $args->{password_rijndael};

	my $key = pack('C32', (
		0x06, 0xA9, 0x21, 0x40, 0x36, 0xB8, 0xA1, 0x5B,
		0x51, 0x2E, 0x03, 0xD5, 0x34, 0x12, 0x00, 0x06,
		0x06, 0xA9, 0x21, 0x40, 0x36, 0xB8, 0xA1, 0x5B,
		0x51, 0x2E, 0x03, 0xD5, 0x34, 0x12, 0x00, 0x06,
	));
	my $chain = pack('C32', (
		0x3D, 0xAF, 0xBA, 0x42, 0x9D, 0x9E, 0xB4, 0x30,
		0xB4, 0x22, 0xDA, 0x80, 0x2C, 0x9F, 0xAC, 0x41,
		0x3D, 0xAF, 0xBA, 0x42, 0x9D, 0x9E, 0xB4, 0x30,
		0xB4, 0x22, 0xDA, 0x80, 0x2C, 0x9F, 0xAC, 0x41,
	));
	my $rijndael = Utils::Rijndael->new;
	$rijndael->MakeKey($key, $chain, 32, 32);
	$args->{password} = unpack('Z32', $rijndael->Decrypt(
		pack('a32', $args->{password_rijndael}), undef, 32, 0
	));
}

1;
