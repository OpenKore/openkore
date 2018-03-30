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
package Network::Send::cRO;

use strict;
use Globals;
use base qw(Network::Send::ServerType0);
use Log qw(message debug error);
use I18N qw(stringToBytes);
use Utils;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %handlers = qw(
		master_login 0AAC
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
		party_setting 07D7
		buy_bulk_vender 0801
		char_create 0970
		storage_password 023B
		send_equip 0998
		sell_buy_complete 09D4
		char_delete2_accept 098F
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

sub sendMasterLogin {
	my ($self, $username, $password, $master_version, $version) = @_;
	my $msg;
	my $password_rijndael = $self->encrypt_password($password);

	my $msg = $self->reconstruct({	
		switch => 'master_login',
		version => $version,
		username  => $username,
		password_hex  => $password_rijndael,
		master_version => $master_version,
	});

	$self->sendToServer($msg);
	debug "Sent sendMasterLogin\n", "sendPacket", 2;
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

sub sendCharCreate {
	my ($self, $slot, $name, $hair_style, $hair_color) = @_;
	
	my $msg = $self->reconstruct({
		switch => 'char_create',
		name => stringToBytes($name),
		slot => $slot,
		hair_style => $hair_style,
		hair_color => $hair_color,
	});
	
	$self->sendToServer($msg);
	debug "Sent sendCharCreate\n", "sendPacket", 2;
}

sub sendSellBuyComplete {
	my ($self) = @_;

	my $msg = $self->reconstruct({
		switch => 'sell_buy_complete',		
	});

	$messageSender->sendToServer($msg);
}

sub sendTop10 {
	my ($self, $type) = @_;
	my $type_msg;
	
	$self->sendToServer(pack("v2", 0x097C, $type));
	
	if ($type == 0x0) { $type_msg = T("Blacksmith"); }
	elsif ($type == 0x1) { $type_msg = T("Alchemist"); }
	elsif ($type == 0x2) { $type_msg = T("Taekwon"); }
	elsif ($type == 0x3) { $type_msg = T("PK"); }
	else { $type_msg = T("Unknown"); }
	
	debug TF("Sent Top 10 %s request\n", $type_msg), "sendPacket", 2;
}

sub sendTop10Blacksmith {
	sendTop10(shift, 0x0);
}

sub sendTop10Alchemist {
	sendTop10(shift, 0x1);
}

sub sendTop10Taekwon {
	sendTop10(shift, 0x2);
}

sub sendTop10PK {
	sendTop10(shift, 0x3);
}

sub reconstruct_char_delete2_accept {
	my ($self, $args) = @_;

	$args->{length} = 8 + length($args->{code});
	debug "Sent sendCharDelete2Accept. CharID: $args->{charID}, Code: $args->{code}, Length: $args->{length}\n", "sendPacket", 2;
}

1;